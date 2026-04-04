import Foundation

// MARK: - State Manager

/// Manages the runtime state of the ScrollSense daemon.
/// Tracks the last detected device, last applied scroll value,
/// and provides optimization by avoiding redundant system calls.
public final class StateManager {
    /// Current runtime state.
    public private(set) var state = DaemonState()

    public init() {}

    /// Whether the daemon should apply a scroll change for the given device.
    /// Returns `nil` if no change is needed, or the desired scroll value if a change is required.
    public func shouldApplyChange(for device: InputDevice, config: ScrollPreferences) -> Bool? {
        let desiredNaturalScroll = config.naturalScroll(for: device)

        // Compare against the real system value so manual System Settings
        // changes are detected and corrected on the next scroll event.
        let currentSystem = ScrollController.getCurrentNaturalScroll()
        if desiredNaturalScroll == currentSystem {
            // Keep our cache in sync so logs stay accurate.
            state.lastAppliedScrollValue = currentSystem
            return nil
        }

        return desiredNaturalScroll
    }

    /// Record that a device was detected.
    public func recordDeviceDetection(_ device: InputDevice) {
        state.eventCount += 1

        if device != state.lastDetectedDevice {
            state.switchCount += 1
            state.lastDetectedDevice = device
        }
    }

    /// Record that a scroll value was applied to the system.
    public func recordAppliedValue(_ value: Bool) {
        state.lastAppliedScrollValue = value
    }

    /// Initialize the state with the current system scroll value.
    public func initializeWithSystemState() {
        state.lastAppliedScrollValue = ScrollController.getCurrentNaturalScroll()
        state.startTime = Date()
        state.isRunning = true
    }

    /// Mark the daemon as stopped.
    public func markStopped() {
        state.isRunning = false
    }
}
