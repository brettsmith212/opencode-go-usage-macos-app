import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var model: UsageModel
    @State private var cookie: String = KeychainStore.get(UsageFetcher.cookieKey) ?? ""
    @State private var wsID: String = UserDefaults.standard.string(forKey: "workspaceID") ?? ""
    @State private var intervalMin: Double
    @State private var saved = false
    @State private var copied = false
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchAtLoginMessage: String?
    @State private var needsApproval = false

    init(model: UsageModel) {
        self._model = ObservedObject(wrappedValue: model)
        let raw = UserDefaults.standard.double(forKey: "refreshIntervalSeconds")
        let initial = raw > 0 ? raw / 60 : 5
        self._intervalMin = State(initialValue: initial.rounded())
    }

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch GoUsage at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        if let msg = LaunchAtLogin.setEnabled(newValue) {
                            launchAtLogin = LaunchAtLogin.isEnabled
                            if msg == "needs-approval" {
                                needsApproval = true
                                launchAtLoginMessage = nil
                            } else {
                                needsApproval = false
                                launchAtLoginMessage = msg
                            }
                        } else {
                            launchAtLogin = newValue
                            needsApproval = false
                            launchAtLoginMessage = nil
                        }
                    }
                ))
                if needsApproval {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("Click below to allow GoUsage in Login Items, then toggle again.")
                            .font(.caption).foregroundStyle(.orange)
                        Spacer()
                    }
                    Button("Open System Settings → Login Items") {
                        LaunchAtLogin.openSystemSettings()
                    }
                }
                if let msg = launchAtLoginMessage {
                    Text(msg).font(.caption).foregroundStyle(.red)
                }
            }

            Section("Menu bar label") {
                Toggle("Use 3-segment gauge (otherwise show \"Go\")", isOn: Binding(
                    get: { model.useSegmentedLabel },
                    set: { model.setUseSegmentedLabel($0) }
                ))
            }

            Section("opencode.ai session") {
                SecureField("auth cookie", text: $cookie)
                    .textContentType(.password)
                TextField("workspace ID", text: $wsID)
                    .autocorrectionDisabled()
                HStack {
                    Text("Refresh every")
                    Slider(value: $intervalMin, in: 1...60, step: 1)
                    Text("\(Int(intervalMin)) min")
                        .monospacedDigit()
                        .frame(width: 52, alignment: .trailing)
                }
            }

            Section {
                HStack {
                    Button("Save") {
                        save()
                    }
                    .disabled(cookie.isEmpty || wsID.isEmpty)

                    Button("Save & Fetch Now") {
                        save()
                        Task { await model.refresh() }
                    }
                    .disabled(cookie.isEmpty || wsID.isEmpty)

                    if saved { Text("Saved").foregroundStyle(.green).font(.caption) }
                    Spacer()
                }
            }

            Section("How to get these") {
                Text("""
                • Cookie: sign in at opencode.ai/auth, open browser DevTools → Application/Storage → Cookies → opencode.ai → `auth`. Copy its value.
                • Workspace ID: the last path segment of the URL when viewing your Go page: opencode.ai/workspace/XXXXXXXX/go
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Debug") {
                HStack {
                    Button("Copy last raw HTML to clipboard") {
                        if let raw = model.lastRawHTML {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(raw, forType: .string)
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                        }
                    }
                    .disabled(model.lastRawHTML == nil)
                    if copied { Text("Copied").foregroundStyle(.green).font(.caption) }
                }
                if let err = model.error {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 460)
    }

    private func save() {
        KeychainStore.set(cookie, for: UsageFetcher.cookieKey)
        UserDefaults.standard.set(wsID, forKey: "workspaceID")
        let secs = TimeInterval(intervalMin * 60)
        UserDefaults.standard.set(secs, forKey: "refreshIntervalSeconds")
        model.intervalSeconds = secs
        model.scheduleTimer()
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
    }
}