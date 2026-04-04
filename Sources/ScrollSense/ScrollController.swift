import CoreFoundation
import Foundation

// MARK: - Scroll Controller

/// Reads and writes the macOS system natural scroll direction setting.
///
/// Uses CoreFoundation `CFPreferences` API to interact with the global preference:
/// `com.apple.swipescrolldirection`
public final class ScrollController {

    private static let preferenceKey = "com.apple.swipescrolldirection" as CFString
    private static let appID = kCFPreferencesAnyApplication
    private static let userID = kCFPreferencesCurrentUser
    private static let hostID = kCFPreferencesAnyHost

    /// Read the current system natural scroll setting.
    /// - Returns: `true` if natural scrolling is enabled, `false` otherwise.
    public static func getCurrentNaturalScroll() -> Bool {
        guard
            let value = CFPreferencesCopyValue(preferenceKey, appID, userID, hostID),
            CFGetTypeID(value) == CFBooleanGetTypeID()
        else {
            return true  // Default assumption
        }
        return CFBooleanGetValue((value as! CFBoolean))
    }

    /// Set the system natural scroll direction.
    /// - Parameter enabled: `true` to enable natural scrolling, `false` to disable.
    public static func setNaturalScroll(_ enabled: Bool) {
        let value = enabled ? kCFBooleanTrue : kCFBooleanFalse
        CFPreferencesSetValue(preferenceKey, value, appID, userID, hostID)
        CFPreferencesSynchronize(appID, userID, hostID)

        // Notify the system so the WindowServer applies the change immediately.
        // This is the same notification System Settings posts when toggling the switch.
        DistributedNotificationCenter.default().postNotificationName(
            .init("SwipeScrollDirectionDidChangeNotification"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        Logger.debug("System natural scroll set to: \(enabled)")
    }
}
