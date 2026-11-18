import SwiftUI

struct OverviewView: View {
    @Environment(MouseStore.self) private var store
    @Binding var pane: Pane

    var body: some View {
        PaneScroll(title: store.info?.name ?? "Mouse", subtitle: store.info.map { "\($0.connection.rawValue) · firmware \($0.firmware)" }) {
            HStack(alignment: .top, spacing: 18) {
                GlassCard {
                    MouseDiagram(selected: nil) { _ in pane = .buttons }
                        .frame(height: 320)
                }
                .frame(width: 260)

                VStack(spacing: 18) {
                    GlassEffectContainer(spacing: 18) {
                        HStack(spacing: 18) {
                            StatTile(title: "Sensitivity", value: store.capabilities.contains(.dpi) ? "\(store.settings.dpiLevels[safe: store.settings.currentStage] ?? 0)" : "—", unit: "DPI", symbol: "scope") { pane = .dpi }
                            StatTile(title: "Polling", value: store.capabilities.contains(.pollingRate) ? "\(store.settings.pollingRate.rawValue)" : "—", unit: "Hz", symbol: "speedometer") { pane = .performance }
                        }
                    }
                    if let b = store.info?.batteryPercent {
                        GlassCard(title: "Battery", symbol: "battery.75percent") {
                            Gauge(value: Double(b), in: 0...100) {
                                EmptyView()
                            } currentValueLabel: {
                                Text("\(b)%\(store.info?.charging == true ? " · charging" : "")")
                            }
                            .gaugeStyle(.linearCapacity)
                            .tint(b <= 15 ? .red : .green)
                        }
                    }
                    if store.capabilities.contains(.buttons) {
                    GlassCard(title: "Buttons", symbol: "button.programmable") {
                        VStack(spacing: 8) {
                            ForEach(PhysicalButton.mt760) { b in
                                HStack {
                                    Text(b.name).foregroundStyle(.secondary)
                                    Spacer()
                                    Label(store.settings.buttons[b.id]?.title ?? "—", systemImage: store.settings.buttons[b.id]?.symbol ?? "questionmark")
                                }
                                .font(.callout)
                            }
                        }
                        Button("Customise buttons") { pane = .buttons }.buttonStyle(.glass)
                    }
                    }
                }
            }
        }
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let unit: String
    let symbol: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: symbol).font(.subheadline).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value).font(.system(size: 40, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.5).contentTransition(.numericText())
                    Text(unit).font(.headline).foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
