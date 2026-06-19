import ApplicationServices
import CoreGraphics
import Foundation

// MARK: - Scroll Engine

/// A non-blocking scroll-inversion engine for GUI hosts (the menu-bar app).
///
/// Unlike `ScrollDaemon` — which owns the process, blocks `main` on a run loop,
/// and manages a PID file — this runs the event tap on its own background
/// thread and reports the detected device back on the main queue. The same
/// inversion rules apply (see `ScrollInverter`).
public final class ScrollEngine {

    /// Called on the main queue whenever the active input device changes.
    public var onDeviceChange: ((InputDevice) -> Void)?

    /// Called on the main queue if the tap stops unexpectedly (e.g. permission
    /// revoked), so the UI can reflect that it's no longer running.
    public var onStop: (() -> Void)?

    private let lock = NSLock()
    private var config: ScrollPreferences
    private var systemNaturalScroll: Bool

    private var lastRefresh = Date()
    private let refreshInterval: TimeInterval = 2.0

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var thread: Thread?
    private var threadRunLoop: CFRunLoop?

    /// Only mutated on the tap thread.
    private var lastReportedDevice: InputDevice?

    public private(set) var isRunning = false

    public init() {
        self.config = ConfigManager.shared.load()
        self.systemNaturalScroll = ScrollController.getCurrentNaturalScroll()
    }

    /// Start inverting. Returns `false` (without starting) if Accessibility
    /// permission has not been granted.
    @discardableResult
    public func start() -> Bool {
        guard !isRunning else { return true }
        guard AXIsProcessTrusted() else { return false }

        let worker = Thread { [weak self] in self?.runTapLoop() }
        worker.name = "com.scrollsense.engine"
        thread = worker
        isRunning = true
        worker.start()
        return true
    }

    /// Stop inverting and tear the tap down.
    public func stop() {
        guard isRunning, let runLoop = threadRunLoop else {
            isRunning = false
            return
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        CFRunLoopStop(runLoop)
        isRunning = false
        eventTap = nil
        runLoopSource = nil
        threadRunLoop = nil
        thread = nil
        lastReportedDevice = nil
    }

    /// Update the per-device preferences live (call when the user toggles a switch).
    public func update(config newConfig: ScrollPreferences) {
        lock.lock()
        config = newConfig
        lock.unlock()
    }

    // MARK: - Tap thread

    private func runTapLoop() {
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon = refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let engine = Unmanaged<ScrollEngine>.fromOpaque(refcon).takeUnretainedValue()

                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = engine.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }

                engine.handleEvent(event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )

        guard let tap = tap else {
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
                self?.onStop?()
            }
            return
        }
        eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        let runLoop = CFRunLoopGetCurrent()!
        threadRunLoop = runLoop
        CFRunLoopAddSource(runLoop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        CFRunLoopRun()

        if let source = runLoopSource {
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
        }
    }

    private func handleEvent(_ event: CGEvent) {
        let now = Date()
        if now.timeIntervalSince(lastRefresh) >= refreshInterval {
            lastRefresh = now
            let sys = ScrollController.getCurrentNaturalScroll()
            lock.lock()
            systemNaturalScroll = sys
            lock.unlock()
        }

        let device = DeviceDetector.detectDevice(from: event)

        lock.lock()
        let desired = config.naturalScroll(for: device)
        let baseline = systemNaturalScroll
        lock.unlock()

        if desired != baseline {
            ScrollInverter.invert(event)
        }

        if device != lastReportedDevice {
            lastReportedDevice = device
            DispatchQueue.main.async { [weak self] in
                self?.onDeviceChange?(device)
            }
        }
    }
}
