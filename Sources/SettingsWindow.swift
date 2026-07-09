import SwiftUI
import AppKit

enum SettingsWindow {
    private static var nsWindow: NSWindow?
    private static var hostingController: NSHostingController<SettingsView>?

    /// Opens the settings window once. If it's already open, brings it to
    /// the front. Never spawns a duplicate.
    @MainActor
    static func openOrFocus(model: UsageModel) {
        if let w = nsWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = SettingsView(model: model)
        let controller = NSHostingController(rootView: view)
        hostingController = controller
        let w = NSWindow(contentViewController: controller)
        w.title = "Go Usage Settings"
        w.styleMask = [.titled, .closable, .miniaturizable]
        w.setContentSize(controller.view.fittingSize)
        w.center()
        w.isReleasedWhenClosed = false
        w.level = .floating
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        nsWindow = w
    }

    /// Called when the window closes (via NSWindowDelegate) to drop our ref.
    @MainActor
    static func windowDidClose() {
        nsWindow = nil
        hostingController = nil
    }
}