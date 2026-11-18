import SwiftUI

struct DPIView: View {
    @Environment(MouseStore.self) private var store
    @Namespace private var glassNS
    static let range = 100...12000
    static let step = 50

    var body: some View {
        @Bindable var store = store
        PaneScroll(title: "Sensitivity", subtitle: "Click a stage to switch to it. The button on top of the mouse cycles through them too.") {
          CapabilityGate(capability: .dpi, what: "DPI") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Stage").font(.subheadline.weight(.medium)).foregroundStyle(.secondary).padding(.leading, 4)
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(0..<store.settings.enabledStages, id: \.self) { i in
                            StageChip(dpi: store.settings.dpiLevels[i], index: i,
                                      active: store.settings.currentStage == i) { store.selectStage(i) }
                                .glassEffectID(i, in: glassNS)
                        }
                    }
                }
                .disabled(!store.writable.contains(.dpiStage) || store.busy)
                .animation(.smooth, value: store.settings.currentStage)
            }

            Panel(title: "Stage values") {
                Stepper("\(store.settings.enabledStages) stages", value: $store.settings.enabledStages, in: 1...store.settings.dpiLevels.count)
                ForEach(0..<store.settings.enabledStages, id: \.self) { i in
                    HStack(spacing: 12) {
                        Text("\(i + 1)").font(.callout.monospacedDigit()).foregroundStyle(.secondary).frame(width: 16)
                        Slider(value: Binding(
                            get: { Double(store.settings.dpiLevels[i]) },
                            set: { store.settings.dpiLevels[i] = Int(($0 / Double(Self.step)).rounded()) * Self.step }),
                            in: Double(Self.range.lowerBound)...Double(Self.range.upperBound))
                        Text("\(store.settings.dpiLevels[i])").font(.callout.monospacedDigit()).frame(width: 48, alignment: .trailing)
                    }
                }
                HStack {
                    if !store.writable.contains(.dpi) {
                        Text("Editing stage values isn't enabled yet.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Save to mouse") {
                        store.settings.dpiLevels = store.settings.dpiLevels.map { min(max($0, Self.range.lowerBound), Self.range.upperBound) }
                        store.applyDPI()
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .disabled(!store.writable.contains(.dpi))
          }
        }
    }
}

struct StageChip: View {
    let dpi: Int
    let index: Int
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(dpi)").font(.title3.weight(active ? .semibold : .regular).monospacedDigit())
                Text("Stage \(index + 1)").font(.caption2).foregroundStyle(active ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(active ? .regular.tint(.accentColor.opacity(0.35)).interactive() : .regular.interactive(),
                     in: .rect(cornerRadius: 14))
    }
}
