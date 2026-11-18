import SwiftUI

struct OverviewView: View {
    @Environment(MouseStore.self) private var store
    @Binding var pane: Pane

    var body: some View {
        PaneScroll(title: store.info?.name ?? "Mouse", subtitle: store.info.map { "\($0.connection.rawValue) · firmware \($0.firmware)" }) {
            HStack(alignment: .top, spacing: 28) {
                MouseDiagram(selected: nil) { _ in pane = .buttons }
                    .frame(width: 200, height: 300)

                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 12) {
                        StatTile(title: "Sensitivity",
                                 value: store.capabilities.contains(.dpi) ? "\(store.settings.dpiLevels[safe: store.settings.currentStage] ?? 0)" : "—",
                                 unit: "DPI") { pane = .dpi }
                        StatTile(title: "Polling",
                                 value: store.capabilities.contains(.pollingRate) ? "\(store.settings.pollingRate.rawValue)" : "—",
                                 unit: "Hz") { pane = .performance }
                        if let b = store.info?.batteryPercent {
                            StatTile(title: store.info?.charging == true ? "Charging" : "Battery",
                                     value: "\(b)", unit: "%") { pane = .device }
                        }
                    }
                    if store.capabilities.contains(.buttons) {
                        Panel(title: "Buttons") {
                            ForEach(PhysicalButton.mt760) { b in
                                HStack {
                                    Text(b.name).foregroundStyle(.secondary)
                                    Spacer()
                                    Text(store.settings.buttons[b.id]?.title ?? "—")
                                }
                                .font(.callout)
                            }
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
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value).font(.system(size: 28, weight: .medium).monospacedDigit())
                        .lineLimit(1).minimumScaleFactor(0.5).contentTransition(.numericText())
                    Text(unit).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quinary, in: .rect(cornerRadius: 14))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
