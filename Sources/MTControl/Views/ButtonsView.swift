import SwiftUI
import AppKit

struct ButtonsView: View {
    @Environment(MouseStore.self) private var store
    @State private var selectedID = 4

    private var selected: PhysicalButton { PhysicalButton.mt760.first { $0.id == selectedID }! }

    var body: some View {
        PaneScroll(title: "Buttons", subtitle: "Pick a button, then choose what it does. Settings are saved on the mouse.") {
          CapabilityGate(capability: .buttons, what: "button assignments") {
            HStack(alignment: .top, spacing: 18) {
                Panel {
                    MouseDiagram(selected: selectedID) { selectedID = $0.id }
                        .frame(height: 340)
                    Picker("Button", selection: $selectedID) {
                        ForEach(PhysicalButton.mt760) { Text($0.name).tag($0.id) }
                    }
                    .labelsHidden()
                }
                .frame(width: 280)

                VStack(alignment: .leading, spacing: 18) {
                    Panel(title: selected.name, symbol: store.settings.buttons[selectedID]?.symbol) {
                        HStack {
                            Text(store.settings.buttons[selectedID]?.title ?? "—").font(.title2.weight(.semibold))
                            if let d = store.settings.buttons[selectedID]?.detail {
                                Text(d).font(.title3.monospaced()).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Default") { store.assign(selected.defaultAction, to: selected) }
                                .buttonStyle(.glass)
                        }
                    }
                    ActionSection(title: "Mouse", symbol: "computermouse", actions:
                        MouseButton.allCases.map { ButtonAction.mouse($0) } + [.doubleClick, .scroll(up: true), .scroll(up: false)],
                        current: store.settings.buttons[selectedID]) { assign($0) }
                    ActionSection(title: "macOS shortcuts", symbol: "command", actions: MacShortcut.all.map(\.action),
                        current: store.settings.buttons[selectedID]) { assign($0) }
                    ShortcutRecorderCard { assign($0) }
                    ActionSection(title: "Media", symbol: "music.note", actions: MediaKey.allCases.map { .media($0) },
                        current: store.settings.buttons[selectedID]) { assign($0) }
                    ActionSection(title: "Sensitivity & other", symbol: "scope",
                        actions: DPIFunction.allCases.map { .dpi($0) } + [.disabled],
                        current: store.settings.buttons[selectedID]) { assign($0) }
                }
            }
          }
        }
    }

    private func assign(_ a: ButtonAction) {
        if selectedID == 0, a != .mouse(.left), !store.settings.buttons.contains(where: { $0.key != 0 && $0.value == .mouse(.left) }) {
            store.toast = "Keep at least one button as left click"
            return
        }
        store.assign(a, to: selected)
    }
}

struct ActionSection: View {
    let title: String
    let symbol: String
    let actions: [ButtonAction]
    let current: ButtonAction?
    let pick: (ButtonAction) -> Void

    var body: some View {
        Panel(title: title, symbol: symbol) {
            GlassEffectContainer(spacing: 8) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                    ForEach(actions, id: \.self) { a in
                        Button { pick(a) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: icon(for: a)).frame(width: 18)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(a.title).lineLimit(1)
                                    if let d = a.detail { Text(d).font(.caption.monospaced()).foregroundStyle(.secondary) }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(current == a ? .regular.tint(.accentColor.opacity(0.55)).interactive() : .regular.interactive(),
                                     in: .rect(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private func icon(for a: ButtonAction) -> String {
        if case .shortcut(let m, let k) = a, let p = MacShortcut.all.first(where: { $0.modifiers == m && $0.key == k }) { return p.symbol }
        return a.symbol
    }
}

/// Press a key combination on the keyboard to capture it.
struct ShortcutRecorderCard: View {
    let pick: (ButtonAction) -> Void
    @State private var recording = false
    @State private var captured: (Modifiers, UInt8)?
    @State private var monitor: Any?

    var body: some View {
        Panel(title: "Custom shortcut", symbol: "keyboard") {
            HStack(spacing: 12) {
                Text(label)
                    .font(.title3.monospaced())
                    .frame(minWidth: 160, alignment: .leading)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .glassEffect(recording ? .regular.tint(.red.opacity(0.35)) : .regular, in: .capsule)
                Button(recording ? "Cancel" : "Record") { recording ? stop() : start() }
                    .buttonStyle(.glass)
                Button("Assign") {
                    if let (m, k) = captured { pick(.shortcut(m, key: k)) }
                }
                .buttonStyle(.glassProminent)
                .disabled(captured == nil)
            }
            Text("Any combination of ⌃ ⌥ ⇧ ⌘ plus one key.").font(.caption).foregroundStyle(.secondary)
        }
        .onDisappear { stop() }
    }

    private var label: String {
        if recording { return "Press keys…" }
        if let (m, k) = captured { return m.symbols + HIDKey.name(for: k) }
        return "None"
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            guard let usage = HIDKey.fromMacKeyCode(e.keyCode) else { return nil }
            var m: Modifiers = []
            if e.modifierFlags.contains(.control) { m.insert(.control) }
            if e.modifierFlags.contains(.option) { m.insert(.option) }
            if e.modifierFlags.contains(.shift) { m.insert(.shift) }
            if e.modifierFlags.contains(.command) { m.insert(.command) }
            captured = (m, usage)
            stop()
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
