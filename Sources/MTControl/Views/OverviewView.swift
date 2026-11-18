import SwiftUI

struct OverviewView: View {
    @Environment(MouseStore.self) private var store
    @Environment(HostController.self) private var host
    @Binding var pane: Pane

    var body: some View {
        PaneScroll(title: store.info?.name ?? "Mouse", subtitle: store.info.map { "\($0.connection.rawValue) · firmware \($0.firmware)" }) {
            MouseDiagram(selected: nil, labels: diagramLabels(store: store, host: host, app: nil)) { _ in pane = .buttons }
                .frame(height: 360)

            VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 12) {
                        StatTile(title: "Sensitivity",
                                 value: store.capabilities.contains(.dpi) ? "\(store.settings.dpiLevels[safe: store.settings.currentStage] ?? 0)" : "—",
                                 unit: "DPI",
                                 stages: store.capabilities.contains(.dpi) ? (store.settings.enabledStages, store.settings.currentStage) : nil) { pane = .dpi }
                        StatTile(title: "Polling",
                                 value: store.capabilities.contains(.pollingRate) ? "\(store.settings.pollingRate.rawValue)" : "—",
                                 unit: "Hz") { pane = .performance }
                        if let b = store.info?.batteryPercent {
                            StatTile(title: store.info?.charging == true ? "Charging" : "Battery",
                                     value: "\(b)", unit: "%", level: Double(b) / 100) { pane = .device }
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
    var stages: (count: Int, current: Int)?
    var level: Double?
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
                if let stages {
                    HStack(spacing: 4) {
                        ForEach(0..<stages.count, id: \.self) { i in
                            Capsule()
                                .fill(i == stages.current ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary))
                                .frame(width: i == stages.current ? 14 : 6, height: 4)
                        }
                    }
                    .animation(.smooth, value: stages.current)
                    .padding(.top, 4)
                } else if let level {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.quaternary)
                            Capsule().fill(level <= 0.15 ? Color.red : Color.green)
                                .frame(width: g.size.width * max(0.04, min(level, 1)))
                        }
                    }
                    .frame(height: 4)
                    .padding(.top, 4)
                } else {
                    Color.clear.frame(height: 8)
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
