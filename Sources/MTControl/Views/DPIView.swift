import SwiftUI

struct DPIView: View {
    @Environment(MouseStore.self) private var store
    @Namespace private var glassNS
    static let range = 100...12000
    static let step = 50
    static let stageColors: [Color] = [.red, .orange, .yellow, .green, .cyan, .purple]

    var body: some View {
        @Bindable var store = store
        PaneScroll(title: "Sensitivity", subtitle: "The top button cycles through the active stages.") {
          CapabilityGate(capability: .dpi, what: "DPI") {
            GlassCard(title: "Active stage", symbol: "scope") {
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        ForEach(0..<store.settings.enabledStages, id: \.self) { i in
                            let on = store.settings.currentStage == i
                            Button { store.selectStage(i) } label: {
                                VStack(spacing: 4) {
                                    Circle().fill(Self.stageColors[i % 6]).frame(width: 8, height: 8)
                                    Text("\(store.settings.dpiLevels[i])").font(.title3.weight(.semibold).monospacedDigit())
                                    Text("Stage \(i + 1)").font(.caption).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .glassEffect(on ? .regular.tint(Self.stageColors[i % 6].opacity(0.4)).interactive() : .regular.interactive(),
                                         in: .rect(cornerRadius: 16))
                            .glassEffectID(i, in: glassNS)
                        }
                    }
                }
                .animation(.bouncy, value: store.settings.enabledStages)
                .disabled(store.readOnly)
                if store.readOnly {
                    Label("Read-only for now: changing settings will come once writes are tested on your mouse.", systemImage: "eye")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            GlassCard(title: "Stages", symbol: "slider.horizontal.3") {
              Group {
                Stepper("Use \(store.settings.enabledStages) stages", value: $store.settings.enabledStages, in: 1...store.settings.dpiLevels.count)
                ForEach(0..<store.settings.enabledStages, id: \.self) { i in
                    HStack(spacing: 14) {
                        Circle().fill(Self.stageColors[i % 6]).frame(width: 10, height: 10)
                        Text("Stage \(i + 1)").frame(width: 64, alignment: .leading)
                        Slider(value: Binding(
                            get: { Double(store.settings.dpiLevels[i]) },
                            set: { store.settings.dpiLevels[i] = Int(($0 / Double(Self.step)).rounded()) * Self.step }),
                            in: Double(Self.range.lowerBound)...Double(Self.range.upperBound))
                        .tint(Self.stageColors[i % 6])
                        TextField("", value: $store.settings.dpiLevels[i], format: .number.grouping(.never))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 76)
                            .multilineTextAlignment(.trailing)
                    }
                }
                HStack {
                    Spacer()
                    Button("Save to mouse") {
                        store.settings.dpiLevels = store.settings.dpiLevels.map { min(max($0, Self.range.lowerBound), Self.range.upperBound) }
                        store.applyDPI()
                    }
                    .buttonStyle(.glassProminent)
                }
              }
              .disabled(store.readOnly)
            }
          }
        }
    }
}
