import CoreGraphics
import Foundation

// MARK: - Device Detector

/// Detects whether a scroll event originated from a mouse or trackpad.
///
/// Uses CGEvent fields to heuristically determine the device type:
/// - `.scrollWheelEventIsContinuous`: Trackpads produce continuous (momentum) scroll events.
///   Mice with discrete scroll wheels produce non-continuous events.
/// - `.scrollWheelEventMomentumPhase` and `.scrollWheelEventScrollPhase`:
///   Trackpad events have gesture phases; mouse events typically do not.
public final class DeviceDetector {

    /// Detect the input device type from a CGEvent.
    ///
    /// Heuristic:
    /// - `scrollWheelEventIsContinuous == 1` → Trackpad (continuous/momentum scrolling)
    /// - `scrollWheelEventIsContinuous == 0` → Mouse (discrete scroll wheel)
    public static func detectDevice(from event: CGEvent) -> InputDevice {
        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous)

        if isContinuous == 1 {
            return .trackpad
        } else {
            return .mouse
        }
    }

    /// Returns a debug description of the event's device-related fields.
    public static func debugDescription(for event: CGEvent) -> String {
        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous)
        let momentumPhase = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        let scrollPhase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
        let deltaY = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let deltaX = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)

        return
            "continuous=\(isContinuous) momentum=\(momentumPhase) phase=\(scrollPhase) deltaY=\(deltaY) deltaX=\(deltaX)"
    }
}
