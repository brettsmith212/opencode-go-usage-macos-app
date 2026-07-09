import SwiftUI
import AppKit

struct SegmentedLabelImage: View {
    @ObservedObject var model: UsageModel

    var body: some View {
        if let nsImage = renderImage() {
            Image(nsImage: nsImage)
                .help(helpText())
        } else {
            Text("Go").help(helpText())
        }
    }

    private func renderImage() -> NSImage? {
        let gauge = MenuBarGauge(model: model)
            .frame(width: 30, height: 16)
            .frame(width: 36, height: 22)
        let r = ImageRenderer(content: gauge)
        r.scale = 2.0
        return r.nsImage
    }

    private func helpText() -> String {
        guard let p = model.payload else { return "OpenCode Go Usage — no data yet" }
        let rr = p.rollingUsage?.display ?? -1
        let w = p.weeklyUsage?.display ?? -1
        let m = p.monthlyUsage?.display ?? -1
        return "OpenCode Go · 5h \(rr)% · week \(w)% · month \(m)%"
    }
}