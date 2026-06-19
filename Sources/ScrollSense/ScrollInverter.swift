import CScrollHID
import CoreGraphics
import Foundation

// MARK: - Scroll Inverter

/// Negates the scroll direction of a `CGEvent`, in place.
///
/// Discrete (mouse) and continuous (trackpad) events store their delta in
/// different fields, so each needs different fields flipped — matching how
/// Scroll Reverser does it. Over-negating a mouse event (touching the
/// point/fixed/IOHID fields) breaks it, so the branch is load-bearing.
public enum ScrollInverter {

    public static func invert(_ event: CGEvent) {
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
}
