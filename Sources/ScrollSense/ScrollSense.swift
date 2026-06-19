import ApplicationServices
import ArgumentParser
import Foundation

// MARK: - Permission Helper

/// The on-disk path of the currently running scrollSense binary.
/// This is the exact entry that must be enabled in the Accessibility list.
private func currentBinaryPath() -> String {
    // Bundle.main.executablePath returns the real on-disk path of the running
    // binary regardless of how it was invoked. argv[0] is unreliable: when the
    // shell finds the command via PATH it may pass a bare "scrollSense", which
    // would resolve against the current directory instead of the real location.
    if let path = Bundle.main.executablePath {
        return URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    }
    let raw = CommandLine.arguments.first ?? "scrollSense"
    return URL(fileURLWithPath: raw).resolvingSymlinksInPath().path
}

/// Ensures Accessibility permission is granted before the daemon starts.
///
/// macOS applies an Accessibility grant only to a *freshly launched* process —
/// enabling the switch while this process is already running does not reliably
/// update its trust status. The previous implementation polled
/// `AXIsProcessTrusted()` in an unbounded loop, which is why the console could
/// sit on "Waiting for permission..." forever even after you'd enabled it.
///
/// Instead we prompt, poll briefly (in case macOS does update us live), and then
/// exit with actionable guidance so the next launch picks up the grant.
func ensureAccessibilityPermission() {
    if AXIsProcessTrusted() { return }

    // Trigger the system prompt and open the Accessibility pane.
    let promptOptions = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        as CFDictionary
    _ = AXIsProcessTrustedWithOptions(promptOptions)

    let path = currentBinaryPath()
    Logger.info("Accessibility permission is required to read scroll events.")
    Logger.info("Enable this exact binary in System Settings → Privacy & Security → Accessibility:")
    Logger.info("    \(path)")
    Logger.info("Waiting up to 30s for the grant to take effect...")

    // Poll briefly: on some macOS versions the running process does see the
    // grant live; if so, proceed without forcing a restart.
    let deadline = Date().addingTimeInterval(30)
    while Date() < deadline {
        if AXIsProcessTrusted() {
            usleep(500_000)  // let TCC persist the grant
            Logger.info("Permission granted.")
            return
        }
        usleep(500_000)
    }

    // Still not trusted — almost always because macOS only applies the grant to
    // a newly launched process, or because a stale entry points at an old build.
    Logger.error("Still not authorized after 30s.")
    Logger.info("If you already enabled scrollSense:")
    Logger.info("  • Remove any existing 'scrollSense' entry from the Accessibility list")
    Logger.info("    (a stale entry shows as enabled but points at a previous build),")
    Logger.info("  • re-add the path above with the + button,")
    Logger.info("  • then run scrollSense again.")
    Logger.info("macOS applies Accessibility grants only to a freshly launched process.")
    exit(1)
}

// MARK: - CLI Commands

public struct ScrollSenseCLI: ParsableCommand {

    public static var configuration = CommandConfiguration(
        commandName: "scrollSense",
        abstract: "Intelligent Natural Scroll Switching for macOS",
        discussion: """
            scrollSense automatically switches the macOS Natural Scrolling setting
            based on the active input device — mouse or trackpad.

            No manual toggling. No friction. No System Settings visits.
            """,
        version: "1.2.0",
        subcommands: [
            Start.self, Stop.self, Run.self, Set.self, Status.self,
            Install.self, Uninstall.self,
        ]
    )

    public init() {}
}

// MARK: - Start Command

public struct Start: ParsableCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Start the scrollSense daemon in the background"
    )

    public init() {}

    public func run() throws {
        // Check if already running
        if let pid = PIDManager.runningPID {
            Logger.info("scrollSense daemon is already running (PID: \(pid)).")
            return
        }

        // Ensure permission before spawning the background daemon.
        ensureAccessibilityPermission()

        // Find the executable path
        let executablePath = ProcessInfo.processInfo.arguments.first ?? ""
        guard !executablePath.isEmpty else {
            Logger.error("Could not determine scrollSense binary path.")
            throw ExitCode.failure
        }

        Logger.info("Starting scrollSense daemon in background...")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: executablePath)
        task.arguments = ["run"]
        task.standardInput = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        task.environment = ProcessInfo.processInfo.environment

        do {
            try task.run()

            // Move the child into its own process group so that closing the
            // terminal does not deliver SIGHUP to the daemon.
            setpgid(task.processIdentifier, task.processIdentifier)

            // Give it a moment to start and write PID
            usleep(500_000)  // 0.5 seconds

            if let pid = PIDManager.runningPID {
                Logger.info("scrollSense daemon started (PID: \(pid)).")
            } else if !task.isRunning {
                Logger.error("scrollSense daemon exited unexpectedly during startup.")
                Logger.error("Try running in the foreground for details: scrollSense run --debug")
                throw ExitCode.failure
            } else {
                Logger.error("scrollSense daemon did not write a PID file.")
                Logger.error("Startup may have failed before initialization completed.")
                Logger.error("Try: scrollSense run")
                throw ExitCode.failure
            }
        } catch {
            Logger.error("Failed to start daemon: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

// MARK: - Stop Command

public struct Stop: ParsableCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Stop the running scrollSense daemon"
    )

    public init() {}

    public func run() throws {
        if PIDManager.stopDaemon() {
            Logger.info("scrollSense daemon stopped.")
        } else {
            Logger.error("No running scrollSense daemon found.")
            throw ExitCode.failure
        }
    }
}

// MARK: - Run Command

public struct Run: ParsableCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Run the scrollSense daemon in the foreground"
    )

    @Flag(name: .shortAndLong, help: "Enable verbose debug logging")
    var debug = false

    public init() {}

    public func run() throws {
        // Ensure permission here too — `run` can be invoked directly without
        // going through `start`, so it must own the full permission flow.
        ensureAccessibilityPermission()

        let daemon = ScrollDaemon()
        daemon.start(debug: debug)
    }
}

// MARK: - Set Command

public struct Set: ParsableCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Set scroll preferences per device"
    )

    @Option(name: .long, help: "Natural scroll for mouse (true/false)")
    var mouse: Bool?

    @Option(name: .long, help: "Natural scroll for trackpad (true/false)")
    var trackpad: Bool?

    @Option(name: .long, help: "Enable or disable ScrollSense (true/false)")
    var enabled: Bool?

    public init() {}

    public func run() throws {
        if mouse == nil && trackpad == nil && enabled == nil {
            Logger.error("Please specify at least one option: --mouse, --trackpad, or --enabled")
            Logger.info("Example: scrollSense set --mouse false --trackpad true")
            throw ExitCode.failure
        }

        var config = ConfigManager.shared.load()

        if let mouse = mouse {
            config.mouseNatural = mouse
            Logger.info("Mouse natural scroll → \(mouse)")
        }

        if let trackpad = trackpad {
            config.trackpadNatural = trackpad
            Logger.info("Trackpad natural scroll → \(trackpad)")
        }

        if let enabled = enabled {
            config.enabled = enabled
            Logger.info("ScrollSense → \(enabled ? "enabled" : "disabled")")
        }

        if ConfigManager.shared.save(config) {
            Logger.info("Preferences saved to \(ConfigManager.shared.configPath)")
        } else {
            Logger.error("Failed to save preferences.")
            throw ExitCode.failure
        }
    }
}

// MARK: - Status Command

public struct Status: ParsableCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Show current scroll preferences and system state"
    )

    public init() {}

    public func run() throws {
        let config = ConfigManager.shared.load()
        let currentSystem = ScrollController.getCurrentNaturalScroll()
        let isRunning = PIDManager.isRunning
        let runningPID = PIDManager.runningPID

        print("")
        print("  scrollSense Status")
        print("  ──────────────────────────────────")
        if isRunning, let pid = runningPID {
            Logger.status("Daemon", "Running (PID: \(pid))")
        } else {
            Logger.status("Daemon", "Stopped")
        }
        Logger.status("ScrollSense", config.enabled ? "Enabled" : "Disabled (paused)")
        Logger.status("Mouse natural scroll", config.mouseNatural ? "ON" : "OFF")
        Logger.status("Trackpad natural scroll", config.trackpadNatural ? "ON" : "OFF")
        Logger.status("System natural scroll", currentSystem ? "ON" : "OFF")
        Logger.status("Config file", ConfigManager.shared.configPath)
        Logger.status(
            "LaunchAgent installed", LaunchAgentManager.isInstalled ? "Yes" : "No")
        if LaunchAgentManager.isInstalled {
            Logger.status("LaunchAgent plist", LaunchAgentManager.plistPath)
        }
        print("  ──────────────────────────────────")
        print("")
    }
}

// MARK: - Install Command

public struct Install: ParsableCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Install LaunchAgent for auto-start at login"
    )

    @Option(name: .long, help: "Path to the scrollSense binary")
    var path: String?

    public init() {}

    public func run() throws {
        Logger.info("Installing scrollSense LaunchAgent...")

        if LaunchAgentManager.install(executablePath: path) {
            Logger.info("LaunchAgent installed successfully.")
            Logger.info("scrollSense will start automatically at login.")
            Logger.info("Plist: \(LaunchAgentManager.plistPath)")
            Logger.info("Logs: /tmp/scrollsense.log")
        } else {
            Logger.error("Failed to install LaunchAgent.")
            throw ExitCode.failure
        }
    }
}

// MARK: - Uninstall Command

public struct Uninstall: ParsableCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Remove LaunchAgent (stop auto-start at login)"
    )

    public init() {}

    public func run() throws {
        Logger.info("Uninstalling scrollSense LaunchAgent...")

        if LaunchAgentManager.uninstall() {
            Logger.info("LaunchAgent removed successfully.")
            Logger.info("scrollSense will no longer start at login.")
        } else {
            Logger.error("Failed to uninstall LaunchAgent.")
            throw ExitCode.failure
        }
    }
}
