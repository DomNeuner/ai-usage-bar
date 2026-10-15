import SwiftUI
import AppKit

enum MenuBarMetric: String, CaseIterable, Identifiable {
    case fiveHour, weekly, highest
    var id: String { rawValue }
    var title: String {
        switch self {
        case .fiveHour: return "5-hour"
        case .weekly: return "Weekly"
        case .highest: return "Highest"
        }
    }

    /// Utilization (0...1) this setting shows for one provider; `extras` are additional weekly windows.
    func value(session: UsageWindow?, weekly: UsageWindow?, extras: [UsageWindow?] = []) -> Double? {
        switch self {
        case .fiveHour: return session?.utilization
        case .weekly: return weekly?.utilization
        case .highest: return ([session, weekly] + extras).compactMap { $0?.utilization }.max()
        }
    }
}

enum SettingsKey {
    static let metric = "menuBarMetric"
    static let showClaude = "menuBarShowClaude"
    static let showCodex = "menuBarShowCodex"
    static let colour = "menuBarColour"
    static let notifications = "notificationsEnabled"
}

/// Menu bar label: one pre-rendered image so it works in MenuBarExtra and follows the menu bar tint.
struct MenuBarLabel: View {
    @ObservedObject var model: UsageViewModel
    @AppStorage(SettingsKey.metric) private var metricRaw = MenuBarMetric.fiveHour.rawValue
    @AppStorage(SettingsKey.showClaude) private var showClaude = true
    @AppStorage(SettingsKey.showCodex) private var showCodex = true
    @AppStorage(SettingsKey.colour) private var colour = true
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let metric = MenuBarMetric(rawValue: metricRaw) ?? .fiveHour
        var entries: [(name: String, logo: NSImage, value: Double?)] = []
        let claudeOn = showClaude || !(showCodex && model.codexConfigured)
        if claudeOn {
            let v = model.usage.flatMap { metric.value(session: $0.session, weekly: $0.weekly, extras: [$0.weeklyFable]) }
            entries.append(("Claude", Logos.claude, v))
        }
        if showCodex && model.codexConfigured {
            let v = model.codex.flatMap { metric.value(session: $0.session, weekly: $0.weekly) }
            entries.append(("Codex", Logos.openAI, v))
        }
        let threshold = colour && entries.contains { ($0.value ?? 0) >= 0.7 }
        let dark = scheme == .dark  // the label's environment follows the menu bar, not the app
        let items = entries.map { e -> MenuBarRenderer.Item in
            let tint: NSColor? = (e.value ?? 0) >= 0.9 ? .systemRed : (e.value ?? 0) >= 0.7 ? .systemOrange : nil
            return .init(logo: e.logo, text: Self.pct(e.value), valueColor: tint)
        }
        let image = MenuBarRenderer.render(items, base: threshold ? (dark ? .white : .black) : nil)
        let label = entries.map { "\($0.name) \(Self.pct($0.value))" }.joined(separator: ", ")
        image.accessibilityDescription = label
        return Image(nsImage: image).accessibilityLabel(label)
    }

    static func pct(_ v: Double?) -> String { v.map { "\(Int(($0 * 100).rounded()))%" } ?? "—" }
}

struct SettingsPanel: View {
    @ObservedObject var model: UsageViewModel
    @AppStorage(SettingsKey.metric) private var metricRaw = MenuBarMetric.fiveHour.rawValue
    @AppStorage(SettingsKey.showClaude) private var showClaude = true
    @AppStorage(SettingsKey.showCodex) private var showCodex = true
    @AppStorage(SettingsKey.colour) private var colour = true
    @AppStorage(SettingsKey.notifications) private var notifications = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Menu bar shows").font(.caption)
                Spacer()
                Picker("Menu bar shows", selection: $metricRaw) {
                    ForEach(MenuBarMetric.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .labelsHidden().pickerStyle(.menu).fixedSize()
            }
            Toggle("Show Claude", isOn: $showClaude)
                .disabled(showClaude && !(showCodex && model.codexConfigured))
            if model.codexConfigured {
                Toggle("Show Codex", isOn: $showCodex).disabled(showCodex && !showClaude)
            }
            Toggle("Colour menu bar % at 70/90%", isOn: $colour)
            Toggle("Notifications", isOn: Binding(
                get: { notifications && Notifier.isAvailable },
                set: { notifications = $0; if $0 { Notifier.requestAuthorization() } }
            ))
            .disabled(!Notifier.isAvailable)
            .help(Notifier.isAvailable ? "Notify at 80% and 95% and when a limit resets"
                                       : "Only available when running from the installed .app")
            LaunchAtLoginToggle()
        }
        .toggleStyle(.checkbox)
        .font(.caption)
    }
}
