import SwiftUI
import AppKit

struct UsageView: View {
    @ObservedObject var model: UsageModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            UsageRow(title: "Rolling", subtitle: "5-hour window", limit: "$12", usage: model.payload?.rollingUsage)
            UsageRow(title: "Weekly", subtitle: "resets at week boundary", limit: "$30", usage: model.payload?.weeklyUsage)
            UsageRow(title: "Monthly", subtitle: "resets on sub day", limit: "$60", usage: model.payload?.monthlyUsage)

            Divider()

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if model.isFetching {
                    ProgressView().controlSize(.small)
                }
                if let err = model.error {
                    Text(err).font(.caption).foregroundStyle(.red).lineLimit(3)
                    Spacer()
                } else if model.payload == nil {
                    Text("Open Settings to add your cookie + workspace ID.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
            }

            HStack(spacing: 8) {
                Button("Refresh") { Task { await model.refresh() } }
                    .disabled(model.isFetching)
                Button("Settings…") { SettingsWindow.openOrFocus(model: model) }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("OpenCode Go").font(.headline)
                let region = model.payload?.region
                let usingBalance = model.payload?.useBalance ?? false
                let regionText = region.map { "region " + $0.joined(separator: ",") }
                Text([regionText, usingBalance ? "using Zen balance" : nil]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
                    .opacity(regionText == nil && !usingBalance ? 0 : 1)
            }
            Spacer()
            if let last = model.lastFetch {
                Text("updated \(last, style: .relative) ago")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

struct UsageRow: View {
    let title: String
    let subtitle: String
    let limit: String
    let usage: WindowUsage?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(title).font(.system(.body, design: .rounded))
                    Text(limit).font(.caption2).foregroundStyle(.secondary)
                }
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                if let u = usage, u.status == "rate-limited" {
                    Text("rate-limited").font(.caption2).foregroundStyle(.red)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(usage.map { "\($0.display)%" } ?? "—")
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(thresholdColor(usage?.display ?? 0))
                ProgressView(value: Double(usage?.display ?? 0), total: 100)
                    .progressViewStyle(.linear).tint(thresholdColor(usage?.display ?? 0))
                    .frame(width: 90)
                Text(usage.map { "resets in \(humanize($0.resetInSec))" } ?? "")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func humanize(_ s: Int) -> String {
        if s <= 0 { return "now" }
        let h = s / 3600
        let m = (s % 3600) / 60
        if h > 0 { return h >= 24 ? "\(h / 24)d \(h % 24)h" : "\(h)h \(m)m" }
        return "\(m)m"
    }

    private func thresholdColor(_ pct: Int) -> Color {
        switch pct {
        case ..<70: return .green
        case ..<90: return .orange
        default: return .red
        }
    }
}