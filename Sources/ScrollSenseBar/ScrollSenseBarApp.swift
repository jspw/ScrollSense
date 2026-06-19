import AppKit
import SwiftUI

@main
struct ScrollSenseBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var service = ScrollService()

    var body: some Scene {
        MenuBarExtra {
            MenuPanelView(service: service)
        } label: {
            Image(nsImage: service.menuBarIcon)
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Keeps ScrollSense out of the Dock and app switcher — it lives only in the
/// menu bar.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
