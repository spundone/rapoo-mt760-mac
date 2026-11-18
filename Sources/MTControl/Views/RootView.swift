import SwiftUI

enum Pane: String, CaseIterable, Identifiable {
    case overview = "Overview", buttons = "Buttons", dpi = "Sensitivity", performance = "Performance", device = "Device"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: "computermouse"
        case .buttons: "button.programmable"
        case .dpi: "scope"
        case .performance: "speedometer"
        case .device: "info.circle"
        }
    }
}

struct RootView: View {
    @Environment(MouseStore.self) private var store
    @State private var pane: Pane = DebugSnapshot.pane ?? .overview

    var body: some View {
        NavigationSplitView {
            List(Pane.allCases, selection: $pane) { p in
                Label(p.rawValue, systemImage: p.symbol).tag(p)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .safeAreaInset(edge: .bottom) { ConnectionBadge().padding(12) }
        } detail: {
            ZStack {
                Backdrop()
                Group {
                    if store.phase == .connected {
                        detail
                    } else {
                        SearchingView()
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            .animation(.smooth, value: store.phase)
            .overlay(alignment: .bottom) { ToastView() }
        }
        .task { if DebugSnapshot.demo, !store.isDemo { store.startDemo() } }
    }

    @ViewBuilder private var detail: some View {
        switch pane {
        case .overview: OverviewView(pane: $pane)
        case .buttons: ButtonsView()
        case .dpi: DPIView()
        case .performance: PerformanceView()
        case .device: DeviceView()
        }
    }
}

/// Soft colour field behind the glass so it has something to refract.
struct Backdrop: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        MeshGradient(width: 3, height: 3, points: [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.5], [0.6, 0.45], [1, 0.5],
            [0, 1], [0.5, 1], [1, 1],
        ], colors: scheme == .dark ? [
            .black, Color(red: 0.05, green: 0.08, blue: 0.2), .black,
            Color(red: 0.12, green: 0.05, blue: 0.22), Color(red: 0.0, green: 0.22, blue: 0.35), Color(red: 0.05, green: 0.05, blue: 0.12),
            .black, Color(red: 0.2, green: 0.07, blue: 0.1), .black,
        ] : [
            Color(red: 0.93, green: 0.95, blue: 1), Color(red: 0.85, green: 0.9, blue: 1), Color(red: 0.97, green: 0.94, blue: 1),
            Color(red: 0.9, green: 0.86, blue: 1), Color(red: 0.75, green: 0.9, blue: 1), Color(red: 0.95, green: 0.97, blue: 1),
            Color(red: 1, green: 0.93, blue: 0.92), Color(red: 0.92, green: 0.95, blue: 1), Color(red: 0.95, green: 0.95, blue: 0.98),
        ])
        .ignoresSafeArea()
    }
}

struct ConnectionBadge: View {
    @Environment(MouseStore.self) private var store
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: store.info?.connection.symbol ?? "magnifyingglass")
                .font(.title3)
                .symbolEffect(.pulse, isActive: store.phase == .searching)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.info?.name ?? "No mouse").font(.callout.weight(.semibold))
                Text(store.info?.connection.rawValue ?? "Searching…").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let b = store.info?.batteryPercent { BatteryGlyph(percent: b, charging: store.info?.charging ?? false) }
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

struct BatteryGlyph: View {
    let percent: Int
    let charging: Bool
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: charging ? "battery.100percent.bolt" : symbol)
                .foregroundStyle(percent <= 15 ? .red : .primary)
            Text("\(percent)%").font(.caption.monospacedDigit())
        }
    }
    private var symbol: String {
        switch percent {
        case ..<13: "battery.0percent"
        case ..<38: "battery.25percent"
        case ..<63: "battery.50percent"
        case ..<88: "battery.75percent"
        default: "battery.100percent"
        }
    }
}

struct SearchingView: View {
    @Environment(MouseStore.self) private var store
    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "computermouse")
                .font(.system(size: 64, weight: .light))
                .symbolEffect(.breathe)
                .frame(width: 140, height: 140)
                .glassEffect(.regular.interactive(), in: .circle)
            VStack(spacing: 6) {
                switch store.phase {
                case .failed(let msg):
                    Text("Couldn't talk to the mouse").font(.title2.weight(.semibold))
                    Text(msg).foregroundStyle(.secondary).multilineTextAlignment(.center)
                default:
                    Text("Looking for your MT760").font(.title2.weight(.semibold))
                    Text("Plug in the 2.4 GHz receiver or the USB cable.").foregroundStyle(.secondary)
                }
            }
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    Button("Try again") { Task { await store.refresh() } }
                        .buttonStyle(.glass)
                    Button("Explore demo") { store.startDemo() }
                        .buttonStyle(.glassProminent)
                }
            }
            if !store.interfaces.isEmpty {
                DisclosureGroup("Rapoo interfaces seen (\(store.interfaces.count))") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(store.interfaces) { Text($0.description).font(.caption.monospaced()) }
                    }
                    .textSelection(.enabled)
                }
                .frame(maxWidth: 520)
                .padding()
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
            }
        }
        .padding(40)
    }
}

struct ToastView: View {
    @Environment(MouseStore.self) private var store
    var body: some View {
        Group {
            if let t = store.toast {
                Label(t, systemImage: t.contains("failed") ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: t) {
                        try? await Task.sleep(for: .seconds(2.2))
                        store.toast = nil
                    }
            }
        }
        .animation(.bouncy, value: store.toast)
    }
}

/// Shared card chrome.
struct GlassCard<Content: View>: View {
    var title: String?
    var symbol: String?
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Label(title, systemImage: symbol ?? "circle").font(.headline)
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}

struct PaneScroll<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.largeTitle.weight(.bold))
                    if let subtitle { Text(subtitle).foregroundStyle(.secondary) }
                }
                .padding(.bottom, 4)
                content
            }
            .padding(28)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}

/// Shows `content` only when the connected mouse supports `capability`.
struct CapabilityGate<Content: View>: View {
    @Environment(MouseStore.self) private var store
    let capability: Capabilities
    let what: String
    @ViewBuilder var content: Content

    var body: some View {
        if store.capabilities.contains(capability) {
            content
        } else {
            GlassCard(title: "Not available yet", symbol: "lock.circle") {
                Text("MT Control is connected to the receiver, but reading \(what) isn't supported yet. Rapoo's protocol for it is still being worked out.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
