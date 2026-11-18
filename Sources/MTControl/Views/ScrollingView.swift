import SwiftUI

struct ScrollingView: View {
    @Environment(HostController.self) private var host

    var body: some View {
        @Bindable var host = host
        PaneScroll(title: "Scrolling", subtitle: "Applies to mouse wheels only. Your trackpad keeps its own settings.") {
            AccessibilityBanner()
            Panel(title: "Wheel") {
                Toggle("Reverse scroll direction", isOn: $host.settings.reverseScroll)
                Text("Lets the wheel scroll the classic way while the trackpad stays on natural scrolling.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                Toggle("Smooth scrolling", isOn: $host.settings.smoothScroll)
                Text("Turns each wheel notch into a short glide instead of a jump.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                HStack {
                    Text("Speed")
                    Slider(value: $host.settings.scrollSpeed, in: 0.25...3, step: 0.25)
                    Text(String(format: "%.2g×", host.settings.scrollSpeed))
                        .font(.callout.monospacedDigit()).frame(width: 40, alignment: .trailing)
                }
            }
            if host.engineRunning {
                Label("Active", systemImage: "checkmark.circle").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct GeneralPanel: View {
    @Environment(HostController.self) private var host

    var body: some View {
        @Bindable var host = host
        Panel(title: "General") {
            Toggle("Warn when the battery is low", isOn: $host.settings.lowBatteryAlerts)
            Toggle("Show battery in the menu bar", isOn: $host.settings.batteryInMenuBar)
            Toggle("Open at login", isOn: Binding(get: { host.launchAtLogin }, set: { host.launchAtLogin = $0 }))
            HStack {
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                    .foregroundStyle(.secondary)
                Spacer()
                Link("Check for updates", destination: AppLinks.latestRelease)
                Link("Help", destination: AppLinks.howItWorks)
            }
            .font(.callout)
        }
    }
}

enum AppLinks {
    static let repo = URL(string: "https://github.com/spundone/rapoo-mt760-mac")!
    static let latestRelease = URL(string: "https://github.com/spundone/rapoo-mt760-mac/releases/latest")!
    static let howItWorks = URL(string: "https://github.com/spundone/rapoo-mt760-mac/blob/main/docs/how-it-works.md")!
}
