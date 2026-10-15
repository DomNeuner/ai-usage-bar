import Foundation

enum Pace {
    static let fiveHour: TimeInterval = 18_000
    static let weekly: TimeInterval = 604_800

    /// Fraction of the window already elapsed (0...1), or nil when the reset time is unknown.
    static func elapsedFraction(resetsAt: Date?, length: TimeInterval, now: Date = Date()) -> Double? {
        guard let resetsAt, length > 0 else { return nil }
        return min(max(1 - resetsAt.timeIntervalSince(now) / length, 0), 1)
    }

    /// Projected end-of-window utilization (1.0 = 100%) at the current rate; nil if too early to tell.
    static func projected(utilization: Double, resetsAt: Date?, length: TimeInterval, now: Date = Date()) -> Double? {
        guard let e = elapsedFraction(resetsAt: resetsAt, length: length, now: now), e >= 0.05 else { return nil }
        return utilization / e
    }
}
