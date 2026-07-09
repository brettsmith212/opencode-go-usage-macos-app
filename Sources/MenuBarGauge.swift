import SwiftUI

struct MenuBarGauge: View {
    @ObservedObject var model: UsageModel

    var body: some View {
        Canvas { ctx, size in
            let windows: [WindowUsage?] = [
                model.payload?.rollingUsage,
                model.payload?.weeklyUsage,
                model.payload?.monthlyUsage
            ]
            let hasAny = windows.contains { $0 != nil }
            let barW: CGFloat = 7
            let gap: CGFloat = 2
            let totalW = CGFloat(windows.count) * barW + CGFloat(windows.count - 1) * gap
            let trackH = size.height
            for (i, u) in windows.enumerated() {
                let x = CGFloat(i) * (barW + gap)
                let track = CGRect(x: x, y: 0, width: barW, height: trackH)
                let trackPath = Path(roundedRect: track, cornerRadius: 2)
                ctx.fill(trackPath, with: .color(.primary.opacity(0.15)))

                let pct = u?.display ?? 0
                let hasData = u != nil
                let fillH = hasData ? max(3, CGFloat(pct) / 100 * (trackH - 1)) : 3
                let fillRect = CGRect(x: x, y: trackH - fillH, width: barW, height: fillH)
                let fillPath = Path(roundedRect: fillRect, cornerRadius: 2)
                let color = hasData ? thresholdColor(pct) : Color.secondary
                ctx.fill(fillPath, with: .color(color))
            }
            _ = hasAny
        }
        .frame(width: 30, height: 16)
        .help(helpText())
    }

    private func thresholdColor(_ pct: Int) -> Color {
        switch pct {
        case ..<70: return .green
        case ..<90: return .orange
        default: return .red
        }
    }

    private func helpText() -> String {
        guard let p = model.payload else { return "OpenCode Go Usage — no data yet" }
        let r = p.rollingUsage?.display ?? -1
        let w = p.weeklyUsage?.display ?? -1
        let m = p.monthlyUsage?.display ?? -1
        return "OpenCode Go · 5h \(r)% · week \(w)% · month \(m)%"
    }
}