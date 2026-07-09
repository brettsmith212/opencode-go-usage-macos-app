import Foundation

struct FetchOutcome {
    let payload: GoUsagePayload?
    let error: String?
    let rawHTML: String
}

enum UsageFetcher {
    static let cookieKey = "opencode.auth.cookie"

    static func fetch() async -> FetchOutcome {
        guard let cookie = KeychainStore.get(cookieKey), !cookie.isEmpty else {
            return FetchOutcome(payload: nil, error: "No session cookie set — open Settings and paste your `auth` cookie.", rawHTML: "")
        }
        let wsID = (UserDefaults.standard.string(forKey: "workspaceID") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wsID.isEmpty else {
            return FetchOutcome(payload: nil, error: "No workspace ID set — paste it in Settings.", rawHTML: "")
        }
        guard let url = URL(string: "https://opencode.ai/workspace/\(wsID)/go") else {
            return FetchOutcome(payload: nil, error: "Invalid workspace ID.", rawHTML: "")
        }

        var req = URLRequest(url: url)
        req.setValue("auth=\(cookie)", forHTTPHeaderField: "Cookie")
        req.setValue("GoUsage/1.0 (macOS menu bar)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let html = String(data: data, encoding: .utf8) ?? ""
            guard let http = response as? HTTPURLResponse else {
                return FetchOutcome(payload: nil, error: "Non-HTTP response.", rawHTML: html)
            }
            if !(200..<300).contains(http.statusCode) {
                return FetchOutcome(payload: nil, error: "HTTP \(http.statusCode) — cookie likely expired or workspace id wrong.", rawHTML: html)
            }
            do {
                let p = try parse(html: html)
                return FetchOutcome(payload: p, error: nil, rawHTML: html)
            } catch {
                return FetchOutcome(payload: nil, error: "Parse failed: \(error.localizedDescription)", rawHTML: html)
            }
        } catch {
            return FetchOutcome(payload: nil, error: "Network error: \(error.localizedDescription)", rawHTML: "")
        }
    }

    /// Extracts the Go usage payload from the server-rendered SolidStart HTML.
    ///
    /// The page inlines server-query results as minified **JavaScript** source
    /// (not JSON): keys are unquoted, booleans are `!0`/`!1`, and values are
    /// often prefixed with `$R[N]=` hydration refs. We therefore locate each
    /// window object via `<name>Usage:` then capture its balanced `{...}` and
    /// regex-extract individual fields — order-independent, tolerant of both
    /// JS-minified and (defensively) pretty-JSON future forms.
    static func parse(html: String) throws -> GoUsagePayload {
        guard html.contains("lite.subscription.get") else {
            throw NSError(domain: "GoUsage.parse", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "anchor `lite.subscription.get` not found — not a Go page or not logged in"])
        }

        let useBalance = matchBool(in: html, key: "useBalance")
        let region = matchStringArray(in: html, key: "region")
        let mine = matchBool(in: html, key: "mine")

        let rolling = extractWindow(html, name: "rolling")
        let weekly = extractWindow(html, name: "weekly")
        let monthly = extractWindow(html, name: "monthly")

        guard rolling != nil || weekly != nil || monthly != nil else {
            throw NSError(domain: "GoUsage.parse", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "found anchor but no *Usage objects"])
        }

        return GoUsagePayload(
            mine: mine, useBalance: useBalance, region: region,
            rollingUsage: rolling, weeklyUsage: weekly, monthlyUsage: monthly
        )
    }

    // MARK: - Window extraction

    private static func extractWindow(_ html: String, name: String) -> WindowUsage? {
        // Require `<name>Usage:$R[N]=` — the lite subscription inlines each
        // window as a `$R` ref + object literal. This deliberately skips the
        // billing object's `monthlyUsage:<int>` form, which has no `$R` ref
        // and was intermittently matching first on some renders.
        let pattern = "\(name)Usage\\s*:\\s*\\$R\\[\\d+\\]="
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsr = NSRange(html.startIndex..., in: html)
        guard let m = re.firstMatch(in: html, range: nsr),
              let r = Range(m.range, in: html) else { return nil }
        let after = html[r.upperBound...]
        guard let lbrace = after.firstIndex(of: "{") else { return nil }
        guard let objStr = balancedObject(in: after, start: lbrace) else { return nil }

        guard let s = matchString(in: objStr, key: "status"),
              let reset = matchInt(in: objStr, key: "resetInSec"),
              let pct = matchDouble(in: objStr, key: "usagePercent") else { return nil }
        return WindowUsage(status: s, resetInSec: reset, usagePercent: pct)
    }

    // MARK: - Regex field matchers (order-independent, JS- and JSON-tolerant)

    private static func firstCapture(_ pattern: String, in s: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsr = NSRange(s.startIndex..., in: s)
        guard let m = re.firstMatch(in: s, range: nsr), m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: s) else { return nil }
        return String(s[r])
    }

    /// Handles `!0`/`!1` (minified JS) and `true`/`false` (JSON).
    private static func matchBool(in s: String, key: String) -> Bool? {
        guard let v = firstCapture("\(key)\\s*:\\s*(!0|!1|true|false)", in: s) else { return nil }
        switch v {
        case "!0", "true": return true
        case "!1", "false": return false
        default: return nil
        }
    }

    private static func matchInt(in s: String, key: String) -> Int? {
        firstCapture("\(key)\\s*:\\s*(\\d+)", in: s).flatMap(Int.init)
    }

    private static func matchDouble(in s: String, key: String) -> Double? {
        firstCapture("\(key)\\s*:\\s*(\\d+(?:\\.\\d+)?)", in: s).flatMap(Double.init)
    }

    private static func matchString(in s: String, key: String) -> String? {
        firstCapture("\(key)\\s*:\\s*\"([^\"]*)\"", in: s)
    }

    /// Handles `region:["us","eu","sg"]` and `region:$R[30]=["us","eu","sg"]`.
    private static func matchStringArray(in s: String, key: String) -> [String]? {
        guard let inside = firstCapture("\(key)\\s*:\\s*(?:\\$R\\[\\d+\\]=)?\\[([^\\]]*)\\]", in: s) else { return nil }
        return inside.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Balanced-brace capture (string/escape aware)

    /// Returns the substring from `start` (a `{`) through its matching `}`,
    /// respecting string literals and escape sequences.
    private static func balancedObject(in s: Substring, start: String.Index) -> String? {
        var depth = 0
        var inStr = false
        var esc = false
        var i = start
        while i < s.endIndex {
            let c = s[i]
            if inStr {
                if esc { esc = false }
                else if c == "\\" { esc = true }
                else if c == "\"" { inStr = false }
            } else {
                if c == "\"" { inStr = true }
                else if c == "{" { depth += 1 }
                else if c == "}" {
                    depth -= 1
                    if depth == 0 {
                        return String(s[start...i])
                    }
                }
            }
            i = s.index(after: i)
        }
        return nil
    }
}