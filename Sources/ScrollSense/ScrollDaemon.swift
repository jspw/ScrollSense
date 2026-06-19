import ApplicationServices
import CScrollHID
import CoreGraphics
import Foundation

// MARK: - Scroll Daemon

/// The main daemon that listens for scroll events and corrects the scroll
/// direction per input device by inverting scroll deltas in-flight.
///
/// macOS has a single global "natural scrolling" toggle, but users often want
/// opposite behavior for mouse vs. trackpad. Rather than flipping the global
/// setting (which macOS does not reliably apply to live input), we intercept
/// each scroll event and negate its deltas when the active device's desired
/// direction differs from the current system setting.
public final class ScrollDaemon {

    private let stateManager = StateManager()
    private var config: ScrollPreferences

    /// The system's current global natural-scroll setting, used as the baseline
    /// against which per-device inversion is decided. Refreshed periodically.
    private var systemNaturalScroll: Bool
    private var lastRefresh = Date()
    private var eventTap: CFMachPort?

    /// How often to reload config + system baseline from disk (seconds).
    private let refreshInterval: TimeInterval = 2.0

    public init() {
        self.config = ConfigManager.shared.load()
        self.systemNaturalScroll = ScrollController.getCurrentNaturalScroll()
    }

    /// Start the daemon and begin listening for scroll events.
    /// - Parameter debug: If `true`, enables verbose debug logging.
    public func start(debug: Bool = false) {
        Logger.debugEnabled = debug
        Logger.info("scrollSense daemon starting...")

        // Write PID file for tracking
        PIDManager.writePID()

        // Initialize state with current system setting
        stateManager.initializeWithSystemState()
        Logger.debug("System natural scroll (baseline): \(systemNaturalScroll)")
        Logger.debug("Config: mouse=\(config.mouseNatural), trackpad=\(config.trackpadNatural)")
        Logger.debug("Config path: \(ConfigManager.shared.configPath)")

        // Create event tap for scroll wheel events. We need a *default* (active)
        // tap, not listen-only, so we can modify and re-emit events.
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let daemon = Unmanaged<ScrollDaemon>
                    .fromOpaque(refcon)
                    .takeUnretainedValue()

                // The system disables a tap if the callback is too slow or on
                // certain input events. Re-enable it so we keep receiving events.
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = daemon.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }

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

    /// Handle a single scroll event, inverting its direction if the active
    /// device's desired direction differs from the system baseline.
    private func handleEvent(_ event: CGEvent) {
        // Periodically reload config + system baseline to pick up changes.
        refreshIfNeeded()

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

        // The active device should scroll in `desired` direction. An untouched
        // event already scrolls in the system baseline direction, so we only
        // need to invert when the two differ.
        let desired = config.naturalScroll(for: device)
        if desired != systemNaturalScroll {
            invertScroll(event)
            if device != previousDevice {
                Logger.debug(
                    "Inverting scroll for \(device.displayName) (desired natural=\(desired), system=\(systemNaturalScroll))"
                )
            }
        }
    }

    /// Negate the scroll direction of an event. Discrete (mouse) and continuous
    /// (trackpad) events store their delta differently, so each needs different
    /// fields flipped — matching how Scroll Reverser does it. Over-negating a
    /// mouse event (touching the point/fixed/IOHID fields) breaks it.
    private func invertScroll(_ event: CGEvent) {
        // Line deltas apply to both, and are the only thing a discrete mouse uses.
        let line1 = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let line2 = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -line1)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -line2)

        // Only continuous (trackpad) events carry precise data in the point,
        // fixed-point, and embedded IOHID fields. Flip those for trackpads only.
        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        guard isContinuous else { return }

        let point1 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        let point2 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -point1)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: -point2)

        let fixed1 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let fixed2 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -fixed1)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -fixed2)

        // Apps read the trackpad scroll amount from the embedded IOHID event.
        ss_invert_iohid_scroll(event)
    }

    /// Reload configuration and the system baseline from disk if enough time has passed.
    private func refreshIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastRefresh) >= refreshInterval else { return }
        lastRefresh = now

        let newConfig = ConfigManager.shared.load()
        if newConfig != config {
            Logger.debug(
                "Config reloaded: mouse=\(newConfig.mouseNatural), trackpad=\(newConfig.trackpadNatural)"
            )
            config = newConfig
        }

        let newSystem = ScrollController.getCurrentNaturalScroll()
        if newSystem != systemNaturalScroll {
            Logger.debug("System natural scroll baseline changed: \(newSystem)")
            systemNaturalScroll = newSystem
        }
    }
}
