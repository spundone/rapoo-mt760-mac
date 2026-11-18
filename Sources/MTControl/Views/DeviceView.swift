import SwiftUI

struct DeviceView: View {
    @Environment(MouseStore.self) private var store
    @State private var confirmReset = false

    var body: some View {
        PaneScroll(title: "Device") {
            GlassCard(title: "About this mouse", symbol: "info.circle") {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                    row("Name", store.info?.name)
                    row("Connection", store.info?.connection.rawValue)
                    row("Firmware", store.info?.firmware)
                    row("Battery", store.info?.batteryPercent.map { "\($0)%" })
                }
                HStack {
                    Button("Refresh") { Task { await store.refresh() } }.buttonStyle(.glass)
                    Button("Show HID log") { NSWorkspace.shared.activateFileViewerSelecting([HIDLog.url]) }.buttonStyle(.glass)
                }
            }
            if store.capabilities.contains(.factoryReset), !store.readOnly {
                GlassCard(title: "Factory settings", symbol: "arrow.counterclockwise") {
                    Text("Puts DPI, polling rate and every button back to how the mouse shipped.")
                        .foregroundStyle(.secondary)
                    Button("Restore factory settings…", role: .destructive) { confirmReset = true }
                        .buttonStyle(.glass)
                }
            }
            GlassCard(title: "HID interfaces", symbol: "cable.connector") {
                if store.interfaces.isEmpty {
                    Text("No Rapoo USB interfaces are connected.").foregroundStyle(.secondary)
                } else {
                    ForEach(store.interfaces) { Text($0.description).font(.caption.monospaced()) }
                }
            }
            .textSelection(.enabled)
        }
        .confirmationDialog("Restore factory settings?", isPresented: $confirmReset) {
            Button("Restore", role: .destructive) { store.factoryReset() }
        }
    }

    @ViewBuilder private func row(_ k: String, _ v: String?) -> some View {
        GridRow {
            Text(k).foregroundStyle(.secondary)
            Text(v ?? "—")
        }
    }
}

struct MenuBarView: View {
    @Environment(MouseStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ConnectionBadge()
            if store.phase == .connected, store.capabilities.contains(.dpi) {
                Text("DPI stage").font(.caption).foregroundStyle(.secondary)
                GlassEffectContainer(spacing: 6) {
                    HStack(spacing: 6) {
                        ForEach(0..<store.settings.enabledStages, id: \.self) { i in
                            Button("\(store.settings.dpiLevels[i])") { store.selectStage(i) }
                                .buttonStyle(.glass)
                                .tint(store.settings.currentStage == i ? .accentColor : nil)
                                .disabled(store.readOnly)
                        }
                    }
                }
            }
            Divider()
            HStack {
                Button("Open MT Control") {
                    NSApp.activate()
                    openWindow(id: "main")
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 320)
    }
}
