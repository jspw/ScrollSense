import AppKit
import ApplicationServices
import Combine
import Foundation
import ScrollSenseCore
import ServiceManagement

/// Bridges the menu-bar UI to `ScrollEngine`, `ConfigManager`, the Accessibility
/// permission, and Login Items. All published state is main-actor owned so the
/// SwiftUI views can bind to it directly.
@MainActor
final class ScrollService: ObservableObject {

    /// The device behind the most recent scroll event (nil until the first scroll).
    @Published private(set) var activeDevice: InputDevice?

    /// Whether the engine is actively inverting events.
    @Published private(set) var isRunning = false

    /// Whether Accessibility permission has been granted.
    @Published private(set) var hasAccessibility = false

    /// Whether the CLI daemon is also running. When true, both invertors are
    /// active and their inversions cancel out — we surface a warning so the user
    /// can disable one.
    @Published private(set) var cliDaemonRunning = false

    /// Master switch. When off, ScrollSense pauses — events pass through unchanged.
    @Published var isEnabled: Bool { didSet { persistAndApply() } }

    /// Per-device preferences. Writing persists to disk and updates the engine live.
    @Published var mouseNatural: Bool { didSet { persistAndApply() } }
    @Published var trackpadNatural: Bool { didSet { persistAndApply() } }

    /// Whether ScrollSense launches at login.
    @Published var launchAtLogin: Bool { didSet { applyLaunchAtLogin() } }

    private let engine = ScrollEngine()
    private var permissionTimer: Timer?
    private var isApplyingLoginItem = false

    init() {
        let config = ConfigManager.shared.load()
        isEnabled = config.enabled
        mouseNatural = config.mouseNatural
        trackpadNatural = config.trackpadNatural
        launchAtLogin = (SMAppService.mainApp.status == .enabled)

        engine.onDeviceChange = { [weak self] device in
            self?.activeDevice = device
        }
        engine.onStop = { [weak self] in
            self?.isRunning = false
        }

        refreshPermission()
        refreshExternalDaemon()
        startEngineIfPossible()
        startPermissionWatch()
    }

    /// The icon shown in the menu bar — reflects the active device, dimmed when
    /// permission is missing.
    var menuBarIcon: NSImage {
        guard hasAccessibility && isEnabled else { return MenuBarIcon.image(for: .disabled) }
        switch activeDevice {
        case .mouse: return MenuBarIcon.image(for: .mouse)
        case .trackpad: return MenuBarIcon.image(for: .trackpad)
        case nil: return MenuBarIcon.image(for: .idle)
        }
    }

    // MARK: - Permission

    func requestAccessibility() {
        let options =
            [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(
            URL(
                string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )!)
    }

    func refreshPermission() {
        let granted = AXIsProcessTrusted()
        if granted != hasAccessibility {
            hasAccessibility = granted
        }
        // If permission appears while we're not yet running, start.
        if granted && !isRunning {
            startEngineIfPossible()
        }
    }

    /// Poll for the grant so the UI flips to "running" once the user enables it,
    /// without requiring an app restart. The same tick re-checks for a competing
    /// CLI daemon so the double-inversion warning appears/clears on its own.
    private func startPermissionWatch() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) {
            [weak self] _ in
            Task { @MainActor in
                self?.refreshPermission()
                self?.refreshExternalDaemon()
            }
        }
    }

    // MARK: - External daemon

    /// Detect a running CLI daemon via its PID file. If one is up alongside the
    /// app, both invert every scroll event and the two inversions cancel.
    func refreshExternalDaemon() {
        let running = PIDManager.runningPID != nil
        if running != cliDaemonRunning {
            cliDaemonRunning = running
        }
    }

    // MARK: - Engine

    private func startEngineIfPossible() {
        guard !isRunning else { return }
        isRunning = engine.start()
    }

    private func persistAndApply() {
        let config = ScrollPreferences(
            mouseNatural: mouseNatural, trackpadNatural: trackpadNatural, enabled: isEnabled)
        ConfigManager.shared.save(config)
        engine.update(config: config)
    }

    // MARK: - Login item

    private func applyLaunchAtLogin() {
        guard !isApplyingLoginItem else { return }
        isApplyingLoginItem = true
        defer { isApplyingLoginItem = false }
        do {
            if launchAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            // Revert the toggle to reflect the real state on failure.
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }

    func quit() {
        engine.stop()
        NSApplication.shared.terminate(nil)
    }
}
