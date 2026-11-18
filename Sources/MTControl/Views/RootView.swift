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
        .task { await store.pollStage() }
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

/// Plain window background; glass is reserved for controls.
struct Backdrop: View {
    var body: some View {
        Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
    }
}

struct ConnectionBadge: View {
    @Environment(MouseStore.self) private var store
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: store.info?.connection.symbol ?? "magnifyingglass")
                .font(.body).foregroundStyle(.secondary)
                .symbolEffect(.pulse, isActive: store.phase == .searching)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.info?.name ?? "No mouse").font(.callout.weight(.semibold))
                Text(store.info?.connection.rawValue ?? "Searching…").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let b = store.info?.batteryPercent { BatteryGlyph(percent: b, charging: store.info?.charging ?? false) }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
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
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundStyle(.secondary)
                .symbolEffect(.breathe)
            VStack(spacing: 6) {
                switch store.phase {
                case .failed(let msg):
                    Text("Couldn't talk to the mouse").font(.title3.weight(.medium))
                    Text(msg).foregroundStyle(.secondary).multilineTextAlignment(.center)
                default:
                    Text("Looking for your MT760").font(.title3.weight(.medium))
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
                .font(.caption)
                .foregroundStyle(.secondary)
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
                Text(t)
                    .font(.callout)
                    .padding(.horizontal, 14).padding(.vertical, 8)
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

/// A quiet content group: small caption title, faint fill, no glass.
struct Panel<Content: View>: View {
    var title: String?
    var symbol: String?          // kept for call sites; not drawn in the minimal theme
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            VStack(alignment: .leading, spacing: 12) { content }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quinary, in: .rect(cornerRadius: 14))
        }
    }
}

struct PaneScroll<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title2.weight(.semibold))
                    if let subtitle { Text(subtitle).font(.callout).foregroundStyle(.secondary) }
                }
                content
            }
            .padding(.horizontal, 32).padding(.vertical, 24)
            .frame(maxWidth: 760, alignment: .leading)
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
            Panel(title: "Not available yet") {
                Text("MT Control is connected to the receiver, but reading \(what) isn't supported yet. Rapoo's protocol for it is still being worked out.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
