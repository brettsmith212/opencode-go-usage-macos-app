import Foundation
import Combine

@MainActor
final class UsageModel: ObservableObject {
    @Published var payload: GoUsagePayload?
    @Published var error: String?
    @Published var lastFetch: Date?
    @Published var isFetching = false
    @Published var intervalSeconds: TimeInterval
    @Published var lastRawHTML: String?
    @Published var useSegmentedLabel: Bool

    private var timerCancellable: AnyCancellable?

    init() {
        let v = UserDefaults.standard.double(forKey: "refreshIntervalSeconds")
        self.intervalSeconds = v > 0 ? v : 300
        if UserDefaults.standard.object(forKey: "useSegmentedLabel") == nil {
            self.useSegmentedLabel = false
            UserDefaults.standard.set(false, forKey: "useSegmentedLabel")
        } else {
            self.useSegmentedLabel = UserDefaults.standard.bool(forKey: "useSegmentedLabel")
        }
    }

    func setUseSegmentedLabel(_ value: Bool) {
        useSegmentedLabel = value
        UserDefaults.standard.set(value, forKey: "useSegmentedLabel")
    }

    func start() {
        Task { await refresh() }
        scheduleTimer()
    }

    func scheduleTimer() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: intervalSeconds, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refresh() }
            }
    }

    @discardableResult
    func refresh() async -> Bool {
        guard !isFetching else { return false }
        isFetching = true
        defer { isFetching = false }
        let outcome = await UsageFetcher.fetch()
        lastRawHTML = outcome.rawHTML
        if let p = outcome.payload {
            self.payload = p
            self.error = nil
            self.lastFetch = Date()
            return true
        } else {
            self.error = outcome.error
            return false
        }
    }
}