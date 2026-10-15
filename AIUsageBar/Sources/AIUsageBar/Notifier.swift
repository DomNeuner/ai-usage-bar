import Foundation
import UserNotifications

/// Pure decision logic for threshold / reset notifications (testable without UserNotifications).
enum NotifyPlanner {
    struct Message: Equatable { var title: String; var body: String }
    struct Previous: Equatable { var utilization: Double; var resetsAt: Date? }

    static let thresholds: [Int] = [80, 95]
    static let keepFor: TimeInterval = 8 * 24 * 3600

    /// `sent` maps dedupe keys to the time they were recorded; it is updated and pruned in place.
    static func plan(id: String, name: String, shortName: String, window: UsageWindow, previous: Previous?,
                     sent: inout [String: Double], now: Date = Date()) -> [Message] {
        sent = sent.filter { now.timeIntervalSince1970 - $0.value < keepFor }
        var out: [Message] = []
        let cycle = window.resetsAt.map { String(Int(($0.timeIntervalSince1970 / 60).rounded()) * 60) } ?? "none"
        let pct = Int((window.utilization * 100).rounded())

        if let p = previous, p.utilization >= 0.95 {
            let newCycle = (window.resetsAt.map { r in p.resetsAt.map { r.timeIntervalSince($0) > 600 } ?? true }) ?? false
            if newCycle || window.utilization < 0.5 {
                out.append(Message(title: "\(shortName) limit has reset",
                                   body: "Usage is back to \(pct)%."))
            }
        }
        var fired = false
        for t in thresholds.reversed() where window.utilization >= Double(t) / 100 {
            let key = "\(id).\(cycle).\(t)"
            if sent[key] == nil {
                sent[key] = now.timeIntervalSince1970
                if !fired {
                    out.append(Message(title: "\(name) at \(t)%", body: resetBody(window.resetsAt, now: now)))
                    fired = true
                }
            }
        }
        return out
    }

    static func resetBody(_ date: Date?, now: Date) -> String {
        guard let date, date > now else { return "Limit resets soon." }
        let f = DateFormatter()
        f.dateFormat = date.timeIntervalSince(now) < 24 * 3600 ? "HH:mm" : "EEE HH:mm"
        return "Resets \(f.string(from: date))."
    }
}

enum Notifier {
    static var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }
    private static let sentKey = "notifySent"
    private static let lastKey = "notifyLast"

    private final class Delegate: NSObject, UNUserNotificationCenterDelegate {
        func userNotificationCenter(_ c: UNUserNotificationCenter, willPresent n: UNNotification,
                                    withCompletionHandler h: @escaping (UNNotificationPresentationOptions) -> Void) {
            h([.banner, .sound])
        }
    }
    private static let delegate = Delegate()

    static var isEnabled: Bool {
        isAvailable && (UserDefaults.standard.object(forKey: SettingsKey.notifications) as? Bool ?? true)
    }

    /// Call once at launch.
    static func start() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().delegate = delegate
        if isEnabled { requestAuthorization() }
    }

    static func requestAuthorization() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Evaluates every window of a successful fetch and posts any due notifications.
    static func process(usage: Usage?, codex: CodexUsage?) {
        guard isEnabled else { return }
        var windows: [(String, String, String, UsageWindow?)] = []
        if let u = usage {
            windows += [("claude.session", "Claude · 5-hour session", "Claude 5-hour", u.session),
                        ("claude.weekly", "Claude · Weekly", "Claude weekly", u.weekly),
                        ("claude.fable", "Claude · Weekly Fable", "Claude Fable weekly", u.weeklyFable)]
        }
        if let x = codex {
            windows += [("codex.session", "Codex · 5-hour session", "Codex 5-hour", x.session),
                        ("codex.weekly", "Codex · Weekly", "Codex weekly", x.weekly)]
        }
        let d = UserDefaults.standard
        var sent = d.dictionary(forKey: sentKey) as? [String: Double] ?? [:]
        var last = d.dictionary(forKey: lastKey) as? [String: [Double]] ?? [:]
        for (id, name, short, w) in windows {
            guard let w else { continue }
            let prev = last[id].flatMap { $0.count == 2 ? NotifyPlanner.Previous(
                utilization: $0[0], resetsAt: $0[1] > 0 ? Date(timeIntervalSince1970: $0[1]) : nil) : nil }
            for m in NotifyPlanner.plan(id: id, name: name, shortName: short, window: w, previous: prev, sent: &sent) { post(m) }
            last[id] = [w.utilization, w.resetsAt?.timeIntervalSince1970 ?? 0]
        }
        d.set(sent, forKey: sentKey)
        d.set(last, forKey: lastKey)
    }

    private static func post(_ m: NotifyPlanner.Message) {
        let c = UNMutableNotificationContent()
        c.title = m.title
        c.body = m.body
        c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }
}
