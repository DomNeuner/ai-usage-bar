import Foundation

/// One rate-limit window. `utilization` is normalised to 0...1.
struct UsageWindow: Equatable {
    var utilization: Double
    var resetsAt: Date?
    /// Window length in seconds when the API reports it; otherwise rows fall back to a default.
    var length: TimeInterval? = nil
}

struct Usage: Equatable {
    var session: UsageWindow?
    var weekly: UsageWindow?
    var weeklyFable: UsageWindow?
    var fetchedAt: Date
}

// MARK: - Defensive decoding of the API response

enum UsageParsing {
    /// Parses ISO 8601 with 0...9 fractional digits, preserving the fraction.
    static func parseDate(_ s: String?) -> Date? {
        guard var s = s else { return nil }
        var frac = 0.0
        if let dot = s.firstIndex(of: ".") {
            var end = s.index(after: dot)
            while end < s.endIndex, s[end].isNumber { end = s.index(after: end) }
            frac = Double("0" + s[dot..<end]) ?? 0
            s.removeSubrange(dot..<end)
        }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)?.addingTimeInterval(frac)
    }

    static func clamp(_ v: Double) -> Double { min(max(v / 100.0, 0), 1) }
}

private struct LossyDouble: Decodable {
    let value: Double?
    init(from decoder: Decoder) throws {
        let c = try? decoder.singleValueContainer()
        value = try? c?.decode(Double.self)
    }
}

private struct LossyString: Decodable {
    let value: String?
    init(from decoder: Decoder) throws {
        let c = try? decoder.singleValueContainer()
        value = try? c?.decode(String.self)
    }
}

private struct RawWindow: Decodable {
    let utilization: LossyDouble?
    let resets_at: LossyString?
    var window: UsageWindow? {
        guard let u = utilization?.value else { return nil }
        return UsageWindow(utilization: UsageParsing.clamp(u),
                           resetsAt: UsageParsing.parseDate(resets_at?.value))
    }
}

private struct RawLimit: Decodable {
    struct Model: Decodable { let display_name: LossyString? }
    struct Scope: Decodable { let model: Model? }
    let kind: LossyString?
    let percent: LossyDouble?
    let resets_at: LossyString?
    let scope: Scope?
    var window: UsageWindow? {
        guard let p = percent?.value else { return nil }
        return UsageWindow(utilization: UsageParsing.clamp(p),
                           resetsAt: UsageParsing.parseDate(resets_at?.value))
    }
}

/// Element wrapper so one malformed array item never fails the whole decode.
private struct LossyLimit: Decodable {
    let limit: RawLimit?
    init(from decoder: Decoder) throws { limit = try? RawLimit(from: decoder) }
}

private struct RawUsage: Decodable {
    let five_hour: RawWindow?
    let seven_day: RawWindow?
    let limits: [LossyLimit]?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        five_hour = try? c.decodeIfPresent(RawWindow.self, forKey: .five_hour)
        seven_day = try? c.decodeIfPresent(RawWindow.self, forKey: .seven_day)
        limits = try? c.decodeIfPresent([LossyLimit].self, forKey: .limits)
    }
    enum Keys: String, CodingKey { case five_hour, seven_day, limits }
}

extension Usage {
    /// Decodes the raw API JSON. Throws only if the payload isn't a JSON object.
    static func decode(from data: Data, fetchedAt: Date = Date()) throws -> Usage {
        let raw = try JSONDecoder().decode(RawUsage.self, from: data)
        let limits = raw.limits?.compactMap { $0.limit } ?? []

        let session = limits.first { $0.kind?.value == "session" }?.window ?? raw.five_hour?.window
        let weekly = limits.first { $0.kind?.value == "weekly_all" }?.window ?? raw.seven_day?.window
        let fable = limits.first {
            $0.kind?.value == "weekly_scoped" && $0.scope?.model?.display_name?.value == "Fable"
        }?.window

        return Usage(session: session, weekly: weekly, weeklyFable: fable, fetchedAt: fetchedAt)
    }
}
