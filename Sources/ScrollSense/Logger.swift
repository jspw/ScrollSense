import Foundation

// MARK: - Logger

/// Simple logging utility for ScrollSense.
public enum Logger {
    /// Whether debug logging is enabled.
    public static var debugEnabled: Bool = false

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()

    /// Log an informational message.
    public static func info(_ message: String) {
        print("[scrollSense] \(message)")
    }

    /// Log a debug message (only when debug mode is enabled).
    public static func debug(_ message: String) {
        guard debugEnabled else { return }
        let timestamp = dateFormatter.string(from: Date())
        print("[scrollSense DEBUG \(timestamp)] \(message)")
    }

    /// Log a warning message.
    public static func warning(_ message: String) {
        print("[scrollSense WARNING] \(message)")
    }

    /// Log an error message.
    public static func error(_ message: String) {
        fputs("[scrollSense ERROR] \(message)\n", stderr)
    }

    /// Log a status line (for status command output).
    public static func status(_ label: String, _ value: String) {
        print("  \(label): \(value)")
    }
}
