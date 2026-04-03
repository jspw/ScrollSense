import Foundation

// MARK: - LaunchAgent Manager

/// Manages the macOS LaunchAgent plist for auto-starting scrollSense at login.
public final class LaunchAgentManager {
    public static let label = "com.scrollsense.daemon"

    /// The current user's UID as a string, used by `launchctl bootstrap`/`bootout`.
    private static var userDomain: String { "gui/\(getuid())" }

    private static var launchAgentDir: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/LaunchAgents")
    }

    private static var plistURL: URL {
        return launchAgentDir.appendingPathComponent("\(label).plist")
    }

    /// Install the LaunchAgent plist to auto-start scrollSense at login.
    /// - Parameter executablePath: Path to the scrollSense binary.
    @discardableResult
    public static func install(executablePath: String? = nil) -> Bool {
        let binaryPath = executablePath ?? resolveExecutablePath()

        guard !binaryPath.isEmpty else {
            Logger.error("Could not determine scrollSense binary path.")
            Logger.error("Please provide the path: scrollSense install --path /path/to/scrollSense")
            return false
        }

        // Ensure LaunchAgents directory exists
        do {
            try FileManager.default.createDirectory(
                at: launchAgentDir, withIntermediateDirectories: true)
        } catch {
            Logger.error("Failed to create LaunchAgents directory: \(error.localizedDescription)")
            return false
        }

        let plistContent = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>\(label)</string>
                <key>ProgramArguments</key>
                <array>
                    <string>\(binaryPath)</string>
                    <string>run</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
                <key>KeepAlive</key>
                <true/>
                <key>StandardOutPath</key>
                <string>/tmp/scrollsense.log</string>
                <key>StandardErrorPath</key>
                <string>/tmp/scrollsense.error.log</string>
            </dict>
            </plist>
            """

        do {
            try plistContent.write(to: plistURL, atomically: true, encoding: .utf8)
        } catch {
            Logger.error("Failed to write LaunchAgent plist: \(error.localizedDescription)")
            return false
        }

        // Bootstrap the agent using the modern launchctl API (macOS 10.11+).
        // `launchctl bootstrap gui/<uid> <plist>` replaces the deprecated `launchctl load`.
        let loadTask = Process()
        loadTask.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        loadTask.arguments = ["bootstrap", userDomain, plistURL.path]
        loadTask.standardOutput = Pipe()
        loadTask.standardError = Pipe()

        do {
            try loadTask.run()
            loadTask.waitUntilExit()
        } catch {
            Logger.warning("Failed to bootstrap LaunchAgent: \(error.localizedDescription)")
            Logger.warning(
                "You may need to load it manually: launchctl bootstrap \(userDomain) \(plistURL.path)"
            )
        }

        return true
    }

    /// Uninstall the LaunchAgent plist.
    @discardableResult
    public static func uninstall() -> Bool {
        guard FileManager.default.fileExists(atPath: plistURL.path) else {
            Logger.warning("LaunchAgent not installed.")
            return true
        }

        // Bootout the agent using the modern launchctl API (macOS 10.11+).
        // `launchctl bootout gui/<uid> <plist>` replaces the deprecated `launchctl unload`.
        let unloadTask = Process()
        unloadTask.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        unloadTask.arguments = ["bootout", userDomain, plistURL.path]
        unloadTask.standardOutput = Pipe()
        unloadTask.standardError = Pipe()

        do {
            try unloadTask.run()
            unloadTask.waitUntilExit()
        } catch {
            Logger.warning("Failed to bootout LaunchAgent: \(error.localizedDescription)")
        }

        // Remove the plist file
        do {
            try FileManager.default.removeItem(at: plistURL)
        } catch {
            Logger.error("Failed to remove LaunchAgent plist: \(error.localizedDescription)")
            return false
        }

        return true
    }

    /// Check if the LaunchAgent is installed.
    public static var isInstalled: Bool {
        return FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// Get the plist file path.
    public static var plistPath: String {
        return plistURL.path
    }

    /// Resolve the path to the current executable.
    private static func resolveExecutablePath() -> String {
        // Try to find the binary in common locations
        let possiblePaths = [
            "/usr/local/bin/scrollSense",
            "/opt/homebrew/bin/scrollSense",
            ProcessInfo.processInfo.arguments.first ?? "",
        ]

        for path in possiblePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Fall back to the current process path
        return ProcessInfo.processInfo.arguments.first ?? ""
    }
}
