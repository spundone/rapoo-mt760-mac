import SwiftUI

struct PerformanceView: View {
    @Environment(MouseStore.self) private var store
    @Namespace private var ns

    var body: some View {
        PaneScroll(title: "Performance", subtitle: "Higher polling feels smoother and uses more battery.") {
            if store.capabilities.contains(.pollingRate) {
                Panel(title: "Polling rate", symbol: "speedometer") {
                    GlassEffectContainer(spacing: 8) {
                        HStack(spacing: 8) {
                            ForEach(PollingRate.allCases) { r in
                                let on = store.settings.pollingRate == r
                                Button { store.setPollingRate(r) } label: {
                                    Text(r.title).font(.headline.monospacedDigit())
                                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                                        .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                .glassEffect(on ? .regular.tint(.accentColor.opacity(0.5)).interactive() : .regular.interactive(),
                                             in: .capsule)
                                .glassEffectID(r.rawValue, in: ns)
                            }
                        }
                    }
                    .disabled(!store.writable.contains(.pollingRate))
                }
            }
            if !store.capabilities.contains(.pollingRate) && !store.capabilities.contains(.sleep) {
                CapabilityGate(capability: .pollingRate, what: "the polling rate") { EmptyView() }
            }
            if store.capabilities.contains(.sleep) {
                Panel(title: "Sleep", symbol: "moon.zzz") {
                    Picker("Sleep after", selection: Binding(get: { store.settings.sleepMinutes }, set: { store.setSleep($0) })) {
                        ForEach([1, 2, 5, 10, 15, 30], id: \.self) { Text("\($0) min").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text("How long the mouse waits before sleeping on the receiver or Bluetooth.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
