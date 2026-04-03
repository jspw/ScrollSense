import ApplicationServices
import CoreGraphics
import Foundation

// MARK: - Scroll Daemon

/// The main daemon that listens for scroll events and switches
/// the macOS natural scroll setting based on the active input device.
public final class ScrollDaemon {

    private let stateManager = StateManager()
    private var config: ScrollPreferences
    private var lastConfigCheck = Date()
    private var eventTap: CFMachPort?

    /// Serial queue for applying system setting changes off the event callback thread.
    private let applyQueue = DispatchQueue(label: "com.scrollsense.apply")

    /// How often to reload config from disk (seconds).
    private let configReloadInterval: TimeInterval = 2.0

    public init() {
        self.config = ConfigManager.shared.load()
    }

    /// Start the daemon and begin listening for scroll events.
    /// - Parameter debug: If `true`, enables verbose debug logging.
    public func start(debug: Bool = false) {
        Logger.debugEnabled = debug
        Logger.info("scrollSense daemon starting..." )

        // Check Accessibility permission before doing anything else.
        // Passing kAXTrustedCheckOptionPrompt=true makes macOS automatically
        // show a dialog and open System Settings → Accessibility pre-focused
        // on this binary — no manual Finder navigation needed.
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            let binaryPath = ProcessInfo.processInfo.arguments.first ?? "scrollSense"
            Logger.error("Accessibility permission is required.")
            Logger.error("A system dialog has opened — click \"Open System Settings\"")
            Logger.error("and enable scrollSense in Privacy & Security → Accessibility.")
            Logger.error("Binary: \(binaryPath)")
            Logger.error("Then run: scrollSense start")
            exit(1)
        }

        // Write PID file for tracking
        PIDManager.writePID()

        // Initialize state with current system setting
        stateManager.initializeWithSystemState()
        Logger.debug(
            "Initial system natural scroll: \(stateManager.state.lastAppliedScrollValue ?? false)")
        Logger.debug("Config: mouse=\(config.mouseNatural), trackpad=\(config.trackpadNatural)")
        Logger.debug("Config path: \(ConfigManager.shared.configPath)")

        // Create event tap for scroll wheel events
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let daemon = Unmanaged<ScrollDaemon>
                    .fromOpaque(refcon)
                    .takeUnretainedValue()

                daemon.handleEvent(event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )

        guard let eventTap = eventTap else {
            Logger.error("Failed to create event tap (permission may have been revoked).")
            Logger.error("Re-run scrollSense to trigger the permission prompt again.")
            exit(1)
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        let mainRunLoop = CFRunLoopGetCurrent()!
        CFRunLoopAddSource(mainRunLoop, runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        Logger.info("scrollSense daemon running. Listening for scroll events...")
        if debug {
            Logger.info("Debug mode enabled. Press Ctrl+C to stop.")
        }

        // Install signal handlers for graceful shutdown using DispatchSource
        // (signal() handlers can't reliably reference the correct run loop)
        let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)

        // Ignore default signal handling so DispatchSource receives the signals
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)

        sigintSource.setEventHandler {
            Logger.info("\nscrollSense daemon stopping...")
            CFRunLoopStop(mainRunLoop)
        }
        sigtermSource.setEventHandler {
            Logger.info("\nscrollSense daemon stopping...")
            CFRunLoopStop(mainRunLoop)
        }
        sigintSource.resume()
        sigtermSource.resume()

        CFRunLoopRun()

        sigintSource.cancel()
        sigtermSource.cancel()

        stateManager.markStopped()
        PIDManager.removePID()
        Logger.info("scrollSense daemon stopped.")
        Logger.debug(
            "Stats: \(stateManager.state.eventCount) events, \(stateManager.state.switchCount) device switches"
        )
    }

    /// Handle a single scroll event.
    private func handleEvent(_ event: CGEvent) {
        // Periodically reload config to pick up changes from `set` command
        reloadConfigIfNeeded()

        // Detect device
        let device = DeviceDetector.detectDevice(from: event)

        // Record the detection
        let previousDevice = stateManager.state.lastDetectedDevice
        stateManager.recordDeviceDetection(device)

        // Log device switch
        if device != previousDevice {
            Logger.debug(
                "Device switch: \(previousDevice?.rawValue ?? "none") → \(device.rawValue)")
            Logger.debug("Event details: \(DeviceDetector.debugDescription(for: event))")
        }

        // Check if we need to apply a change — dispatch off the event callback thread
        // so the handler returns immediately and never stalls scroll event processing.
        if let desiredValue = stateManager.shouldApplyChange(for: device, config: config) {
            // Optimistically record the value now (on the main thread) to prevent
            // duplicate dispatches for events that arrive before the write completes.
            stateManager.recordAppliedValue(desiredValue)
            let displayName = device.displayName
            applyQueue.async {
                Logger.debug("Applying scroll change: natural=\(desiredValue) (for \(displayName))")
                ScrollController.setNaturalScroll(desiredValue)
            }
        }
    }

    /// Reload configuration from disk if enough time has passed.
    private func reloadConfigIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastConfigCheck) >= configReloadInterval else { return }

        let newConfig = ConfigManager.shared.load()
        if newConfig != config {
            Logger.debug(
                "Config reloaded: mouse=\(newConfig.mouseNatural), trackpad=\(newConfig.trackpadNatural)"
            )
            config = newConfig
        }
        lastConfigCheck = now
    }
}
