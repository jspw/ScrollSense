import ScrollSenseCore
import SwiftUI

/// The dropdown panel shown from the menu-bar item.
struct MenuPanelView: View {
    @ObservedObject var service: ScrollService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if service.hasAccessibility {
                if service.cliDaemonRunning {
                    conflictBanner
                }
                Divider().padding(.horizontal, 14)
                Group {
                    currentDevice
                    Divider().padding(.horizontal, 14)
                    deviceControls
                }
                .opacity(service.isEnabled ? 1 : 0.4)
                .disabled(!service.isEnabled)
                .animation(.easeOut(duration: 0.18), value: service.isEnabled)
                Divider().padding(.horizontal, 14)
                footer
            } else {
                permissionPrompt
            }
        }
        .frame(width: 268)
        .onAppear { service.refreshPermission() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text("ScrollSense")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Toggle("", isOn: $service.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .disabled(!service.hasAccessibility)
            }
            HStack(spacing: 5) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(statusText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var statusText: String {
        if !service.hasAccessibility { return "Accessibility needed" }
        if !service.isEnabled { return "Paused — scrolling unchanged" }
        return service.isRunning ? "Active" : "Starting…"
    }

    private var statusColor: Color {
        if !service.hasAccessibility { return .orange }
        if !service.isEnabled { return Color.secondary.opacity(0.6) }
        return service.isRunning ? .green : Color.secondary.opacity(0.6)
    }

    // MARK: - Current device

    private var currentDevice: some View {
        HStack(spacing: 8) {
            Image(systemName: activeSymbol)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text("Currently")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(service.activeDevice?.displayName ?? "—")
                .font(.system(size: 12, weight: .medium))
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.18), value: service.activeDevice)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var activeSymbol: String {
        switch service.activeDevice {
        case .mouse: return "computermouse"
        case .trackpad: return "hand.point.up.left"
        case nil: return "circle.dotted"
        }
    }

    // MARK: - Device controls

    private var deviceControls: some View {
        VStack(spacing: 0) {
            deviceRow(
                symbol: "computermouse",
                title: "Mouse",
                isActive: service.activeDevice == .mouse,
                isOn: $service.mouseNatural)
            deviceRow(
                symbol: "hand.point.up.left",
                title: "Trackpad",
                isActive: service.activeDevice == .trackpad,
                isOn: $service.trackpadNatural)
        }
        .padding(.vertical, 4)
    }

    private func deviceRow(symbol: String, title: String, isActive: Bool, isOn: Binding<Bool>)
        -> some View
    {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(isOn.wrappedValue ? "Scrolls naturally" : "Scrolls reversed")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
                    .animation(.easeOut(duration: 0.18), value: isOn.wrappedValue)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isActive ? Color.accentColor.opacity(0.10) : .clear)
                .padding(.horizontal, 8)
        )
        .animation(.easeOut(duration: 0.18), value: isActive)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $service.launchAtLogin) {
                Text("Launch at login")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)

            MenuButton(title: "Quit ScrollSense", shortcut: "⌘Q") { service.quit() }
                .keyboardShortcut("q")
        }
        .padding(.bottom, 5)
        .padding(.top, 1)
    }

    // MARK: - Conflict banner

    /// Shown when the CLI daemon is also running: both invert every event and the
    /// two inversions cancel, so scrolling looks broken until one is stopped.
    private var conflictBanner: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
            Text("The scrollSense CLI daemon is also running. Stop it with `scrollSense stop`, or scrolling may misbehave.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    // MARK: - Permission prompt

    private var permissionPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.orange)
                Text("Accessibility access needed")
                    .font(.system(size: 12, weight: .medium))
            }
            Text("ScrollSense needs Accessibility permission to read scroll events.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: { service.requestAccessibility() }) {
                Text("Open Accessibility Settings")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .padding(.top, 2)

            MenuButton(title: "Quit", shortcut: nil) { service.quit() }
                .keyboardShortcut("q")
                .padding(.top, 2)
        }
        .padding(14)
    }
}

/// A full-width menu row button with hover highlight, matching native menu feel.
private struct MenuButton: View {
    let title: String
    let shortcut: String?
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hovering ? Color.accentColor.opacity(0.15) : .clear)
                    .padding(.horizontal, 8)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
