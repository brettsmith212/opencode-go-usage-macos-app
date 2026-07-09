import Foundation
import ServiceManagement
import AppKit

@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var needsApproval: Bool {
        let s = SMAppService.mainApp.status
        return s == .requiresApproval || s == .notRegistered
    }

    /// Returns nil on success; otherwise a user-facing message.
    static func setEnabled(_ enabled: Bool) -> String? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                // First call often lands in .requiresApproval for ad-hoc
                // signed apps — the user has to allow it once in System
                // Settings → General → Login Items.
                if SMAppService.mainApp.status == .requiresApproval || SMAppService.mainApp.status == .notRegistered {
                    return "needs-approval"
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return "Couldn't change launch-at-login (\(error.localizedDescription))."
        }
    }

    /// Deep-links to the Login Items pane of System Settings.
    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}