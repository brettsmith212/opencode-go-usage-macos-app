import Foundation

struct WindowUsage: Codable, Equatable {
    let status: String
    let resetInSec: Int
    let usagePercent: Double
}

extension WindowUsage {
    var display: Int { Int(usagePercent.rounded()) }
}

struct GoUsagePayload: Codable, Equatable {
    let mine: Bool?
    let useBalance: Bool?
    let region: [String]?
    let rollingUsage: WindowUsage?
    let weeklyUsage: WindowUsage?
    let monthlyUsage: WindowUsage?
}