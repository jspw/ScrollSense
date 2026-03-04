import Foundation

// MARK: - Input Device Type

/// Represents the type of input device detected.
public enum InputDevice: String, Codable {
    case mouse
    case trackpad

    public var displayName: String {
        switch self {
        case .mouse: return "Mouse"
        case .trackpad: return "Trackpad"
        }
    }
}

// MARK: - Scroll Preferences

/// User-defined scroll preferences per device.
public struct ScrollPreferences: Codable, Equatable {
    public var mouseNatural: Bool
    public var trackpadNatural: Bool

    public init(mouseNatural: Bool, trackpadNatural: Bool) {
        self.mouseNatural = mouseNatural
        self.trackpadNatural = trackpadNatural
    }

    /// Returns the desired natural scroll setting for the given device.
    public func naturalScroll(for device: InputDevice) -> Bool {
        switch device {
        case .mouse: return mouseNatural
        case .trackpad: return trackpadNatural
        }
    }

    /// Default preferences: trackpad natural ON, mouse natural OFF.
    public static let `default` = ScrollPreferences(mouseNatural: false, trackpadNatural: true)
}

// MARK: - Daemon State

/// Runtime state of the daemon for status reporting.
public struct DaemonState {
    public var lastDetectedDevice: InputDevice?
    public var lastAppliedScrollValue: Bool?
    public var isRunning: Bool = false
    public var eventCount: Int = 0
    public var switchCount: Int = 0
    public var startTime: Date?

    public init() {}

    public var uptime: TimeInterval? {
        guard let start = startTime else { return nil }
        return Date().timeIntervalSince(start)
    }

    public var uptimeFormatted: String {
        guard let uptime = uptime else { return "N/A" }
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        let seconds = Int(uptime) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
