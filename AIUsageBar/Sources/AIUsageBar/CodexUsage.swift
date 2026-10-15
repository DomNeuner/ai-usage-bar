import Foundation

struct CodexUsage: Equatable {
    var session: UsageWindow?
    var weekly: UsageWindow?
    var planType: String?
    var fetchedAt: Date
}

private struct LossyNumber: Decodable {
    let value: Double?
    init(from decoder: Decoder) throws {
        let c = try? decoder.singleValueContainer()
        value = try? c?.decode(Double.self)
    }
}

private struct LossyText: Decodable {
    let value: String?
    init(from decoder: Decoder) throws {
        let c = try? decoder.singleValueContainer()
        value = try? c?.decode(String.self)
    }
}

private struct RawCodexWindow: Decodable {
    let used_percent: LossyNumber?
    let reset_at: LossyNumber?
    let reset_after_seconds: LossyNumber?
    let limit_window_seconds: LossyNumber?

    func window(fetchedAt: Date) -> UsageWindow? {
        guard let u = used_percent?.value else { return nil }
        var reset: Date?
        if let at = reset_at?.value { reset = Date(timeIntervalSince1970: at) }
        else if let after = reset_after_seconds?.value { reset = fetchedAt.addingTimeInterval(after) }
        let len = limit_window_seconds?.value.flatMap { $0 > 0 ? $0 : nil }
        return UsageWindow(utilization: UsageParsing.clamp(u), resetsAt: reset, length: len)
    }
}

private struct RawRateLimit: Decodable {
    let primary_window: RawCodexWindow?
    let secondary_window: RawCodexWindow?
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        primary_window = try? c.decodeIfPresent(RawCodexWindow.self, forKey: .primary_window)
        secondary_window = try? c.decodeIfPresent(RawCodexWindow.self, forKey: .secondary_window)
    }
    enum Keys: String, CodingKey { case primary_window, secondary_window }
}

private struct RawCodexUsage: Decodable {
    let plan_type: LossyText?
    let rate_limit: RawRateLimit?
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        plan_type = try? c.decodeIfPresent(LossyText.self, forKey: .plan_type)
        rate_limit = try? c.decodeIfPresent(RawRateLimit.self, forKey: .rate_limit)
    }
    enum Keys: String, CodingKey { case plan_type, rate_limit }
}

extension CodexUsage {
    /// Decodes the raw API JSON. Throws only if the payload isn't a JSON object.
    static func decode(from data: Data, fetchedAt: Date = Date()) throws -> CodexUsage {
        let raw = try JSONDecoder().decode(RawCodexUsage.self, from: data)
        let plan = raw.plan_type?.value.flatMap { $0.isEmpty ? nil : $0 }
        return CodexUsage(session: raw.rate_limit?.primary_window?.window(fetchedAt: fetchedAt),
                          weekly: raw.rate_limit?.secondary_window?.window(fetchedAt: fetchedAt),
                          planType: plan, fetchedAt: fetchedAt)
    }
}
