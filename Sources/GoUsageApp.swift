import SwiftUI

@main
struct GoUsageApp: App {
    @StateObject private var model = UsageModel()

    var body: some Scene {
        MenuBarExtra {
            UsageView(model: model)
        } label: {
            if model.useSegmentedLabel, model.payload != nil {
                SegmentedLabelImage(model: model)
            } else if model.useSegmentedLabel {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .imageScale(.small)
                    .foregroundStyle(.primary)
            } else {
                Text("Go")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
        .menuBarExtraStyle(.window)

        WindowGroup("Go Usage Settings", id: "settings") {
            SettingsView(model: model)
        }
        .windowResizability(.contentSize)
    }
}