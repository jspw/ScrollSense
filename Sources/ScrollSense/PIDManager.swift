import Foundation

// MARK: - PID Manager

/// Manages a PID file for tracking the running scrollSense daemon process.
/// PID file is stored at /tmp/scrollsense.pid
public final class PIDManager {
    public static let pidFilePath = "/tmp/scrollsense.pid"

    /// Write the current process PID to the PID file.
    public static func writePID() {
        let pid = ProcessInfo.processInfo.processIdentifier
        do {
            try "\(pid)".write(toFile: pidFilePath, atomically: true, encoding: .utf8)
            Logger.debug("PID file written: \(pidFilePath) (PID: \(pid))")
        } catch {
            Logger.warning("Failed to write PID file: \(error.localizedDescription)")
        }
    }

    /// Remove the PID file.
    public static func removePID() {
        try? FileManager.default.removeItem(atPath: pidFilePath)
        Logger.debug("PID file removed")
    }

    /// Read the PID from the PID file.
    /// Returns `nil` if the file doesn't exist or is invalid.
    public static func readPID() -> pid_t? {
        guard let content = try? String(contentsOfFile: pidFilePath, encoding: .utf8),
            let pid = Int32(content.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            return nil
        }
        return pid
    }

    /// Check if the daemon is currently running.
    /// Validates that the PID file exists AND the process is alive.
    public static var isRunning: Bool {
        guard let pid = readPID() else { return false }
        // kill with signal 0 checks if process exists without actually sending a signal
        return kill(pid, 0) == 0
    }

    /// Get the running daemon's PID, or nil if not running.
    public static var runningPID: pid_t? {
        guard let pid = readPID(), kill(pid, 0) == 0 else {
            // Clean up stale PID file
            if FileManager.default.fileExists(atPath: pidFilePath) {
                removePID()
            }
            return nil
        }
        return pid
    }

    /// Stop the running daemon by sending SIGTERM.
    /// Returns `true` if the signal was sent successfully.
    @discardableResult
    public static func stopDaemon() -> Bool {
        guard let pid = runningPID else {
            Logger.warning("No running scrollSense daemon found.")
            return false
        }

        Logger.info("Sending SIGTERM to scrollSense daemon (PID: \(pid))...")
        let result = kill(pid, SIGTERM)

        if result == 0 {
            // Wait briefly for the process to exit
            usleep(500_000)  // 0.5 seconds

            // Check if it actually stopped
            if kill(pid, 0) != 0 {
                removePID()
                return true
            } else {
                // Try SIGKILL as fallback
                Logger.warning("Daemon did not stop gracefully, sending SIGKILL...")
                kill(pid, SIGKILL)
                usleep(200_000)
                removePID()
                return true
            }
        } else {
            Logger.error("Failed to send signal to PID \(pid)")
            removePID()
            return false
        }
    }
}
