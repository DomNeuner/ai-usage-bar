import SwiftUI
import AppKit

@main
struct AIUsageBarApp: App {
    @StateObject private var model = UsageViewModel()

    private static let _defaults: Void = UserDefaults.standard.register(defaults: [SettingsKey.notifications: Notifier.isAvailable])

    init() { _ = Self._defaults; NSApplication.shared.setActivationPolicy(.accessory) }

    var body: some Scene {
        MenuBarExtra {
            UsagePopover(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

struct UsagePopover: View {
    @ObservedObject var model: UsageViewModel
    @State private var showSettings = false

    private var codexHeader: String {
        guard let p = model.codex?.planType, !p.isEmpty else { return "Codex" }
        return "Codex · \(p.capitalized)"
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
        VStack(alignment: .leading, spacing: 14) {
            Text("Claude").font(.caption).foregroundStyle(.secondary)
            if let error = model.error {
                Text(error).foregroundStyle(.secondary)
            }
            if let u = model.usage {
                UsageRow(title: "5-hour session", window: u.session, defaultLength: Pace.fiveHour)
                UsageRow(title: "Weekly · all models", window: u.weekly, defaultLength: Pace.weekly)
                if let f = u.weeklyFable { UsageRow(title: "Weekly · Fable", window: f, defaultLength: Pace.weekly) }
            } else if model.error == nil {
                Text("Loading…").foregroundStyle(.secondary)
            }
            if model.codexConfigured {
                Divider()
                Text(codexHeader).font(.caption).foregroundStyle(.secondary)
                if let error = model.codexError {
                    Text(error).foregroundStyle(.secondary)
                }
                if let x = model.codex {
                    UsageRow(title: "5-hour session", window: x.session, defaultLength: Pace.fiveHour)
                    UsageRow(title: "Weekly", window: x.weekly, defaultLength: Pace.weekly)
                } else if model.codexError == nil {
                    Text("Loading…").foregroundStyle(.secondary)
                }
            }
            Divider()
            if showSettings { SettingsPanel(model: model); Divider() }
            HStack {
                if let u = model.usage {
                    Text("Updated \(u.fetchedAt, format: .relative(presentation: .numeric))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { showSettings.toggle() } label: { Image(systemName: "gearshape") }
                    .help("Settings")
                Button("Refresh") { model.refresh() }.disabled(model.isLoading)
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 280)
        .onAppear { model.refreshIfStale() }
        }
    }
}

struct UsageRow: View {
    let title: String
    let window: UsageWindow?
    let defaultLength: TimeInterval

    private var tint: Color {
        guard let p = window?.utilization else { return .accentColor }
        if p >= 0.9 { return .red }
        if p >= 0.7 { return .orange }
        return .accentColor
    }

    var body: some View {
        let now = Date()
        let length = window?.length ?? defaultLength
        let elapsed = Pace.elapsedFraction(resetsAt: window?.resetsAt, length: length, now: now)
        let projected = window.flatMap { Pace.projected(utilization: $0.utilization, resetsAt: $0.resetsAt, length: length, now: now) }
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(window.map { "\(Int(($0.utilization * 100).rounded()))%" } ?? "—")
                    .font(.subheadline.monospacedDigit())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.12))
                    Capsule().fill(tint)
                        .frame(width: geo.size.width * min(max(window?.utilization ?? 0, 0), 1))
                    if let e = elapsed, e >= 0.05 {
                        Rectangle().fill(Color.primary.opacity(0.5))
                            .frame(width: 1.5, height: 10)
                            .offset(x: min(geo.size.width * e, geo.size.width - 1.5), y: 0)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 10)
            if let r = window?.resetsAt {
                HStack(spacing: 0) {
                    Text(Self.resetText(r)).foregroundStyle(.secondary)
                    if let p = projected {
                        Text(" · on pace for \(min(Int((p * 100).rounded()), 999))%")
                            .foregroundStyle(p >= 1.0 ? Color.orange : Color.secondary)
                    }
                }
                .font(.caption)
            }
        }
    }

    static func resetText(_ date: Date) -> String {
        let secs = date.timeIntervalSinceNow
        if secs <= 0 { return "resets soon" }
        if secs < 24 * 3600 {
            let m = Int(secs / 60)
            return m >= 60 ? "resets in \(m / 60)h \(m % 60)m" : "resets in \(m)m"
        }
        let f = DateFormatter()
        f.dateFormat = "EEE HH:mm"
        return "resets \(f.string(from: date))"
    }
}
