import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Mac-side button actions, gestures and per-app profiles.
struct ButtonsView: View {
    @Environment(MouseStore.self) private var store
    @Environment(HostController.self) private var host
    /// nil = All apps
    @State private var scope: String?
    @State private var selected: HostButton = .middle
    @Namespace private var ns

    var body: some View {
        PaneScroll(title: "Buttons", subtitle: "Actions run on your Mac, so they can differ per app.") {
            AccessibilityBanner()
            ScopeBar(scope: $scope)

            HStack(alignment: .top, spacing: 28) {
                MouseDiagram(selected: selected.physicalID) { b in
                    if let hb = HostButton.allCases.first(where: { $0.physicalID == b.id }) { selected = hb }
                }
                .frame(width: 180, height: 270)

                VStack(alignment: .leading, spacing: 22) {
                    Panel(title: scope.flatMap { host.settings.profile(for: $0)?.name } ?? "All apps") {
                        ForEach(HostButton.allCases) { b in
                            ActionRow(title: b.title, highlighted: selected == b,
                                      action: binding(for: b), allowDefaultLabel: scope == nil ? "Default" : "Same as All apps")
                                .onTapGesture { selected = b }
                        }
                        HStack {
                            Text("Top button").foregroundStyle(.secondary)
                            Spacer()
                            Text("DPI cycle (set on the mouse)").foregroundStyle(.tertiary)
                        }
                        .font(.callout)
                    }

                    if usesGesture {
                        GesturePanel()
                    }

                    if let id = scope, let idx = host.settings.apps.firstIndex(where: { $0.bundleID == id }) {
                        Panel(title: "When this app is in front") {
                            Picker("DPI stage", selection: Binding(
                                get: { host.settings.apps[idx].dpiStage },
                                set: { host.settings.apps[idx].dpiStage = $0 })) {
                                Text("Don't change").tag(Int?.none)
                                ForEach(0..<store.settings.enabledStages, id: \.self) { i in
                                    Text("Stage \(i + 1) · \(store.settings.dpiLevels[i]) DPI").tag(Int?.some(i))
                                }
                            }
                            HStack {
                                Spacer()
                                Button("Remove app", role: .destructive) {
                                    host.removeProfile(id)
                                    scope = nil
                                }
                                .buttonStyle(.glass)
                            }
                        }
                    }
                }
            }
        }
    }

    private var usesGesture: Bool {
        let s = host.settings
        return s.global.actions.values.contains(.gesture) || s.apps.contains { $0.buttons.actions.values.contains(.gesture) }
    }

    private func binding(for b: HostButton) -> Binding<HostAction?> {
        Binding(
            get: {
                if let id = scope { return host.settings.profile(for: id)?.buttons.actions[b] }
                return host.settings.global.actions[b] ?? .passthrough
            },
            set: { new in
                if let id = scope, let i = host.settings.apps.firstIndex(where: { $0.bundleID == id }) {
                    host.settings.apps[i].buttons.actions[b] = new
                } else {
                    host.settings.global.actions[b] = new ?? .passthrough
                }
            })
    }
}

/// "All apps" plus one chip per app profile, and an add button.
struct ScopeBar: View {
    @Environment(HostController.self) private var host
    @Binding var scope: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    chip(nil, "All apps", nil)
                    ForEach(host.settings.apps) { p in chip(p.bundleID, p.name, HostController.icon(for: p.bundleID)) }
                    Button { addApp() } label: {
                        Image(systemName: "plus").frame(width: 28, height: 28).contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .help("Add an app")
                }
                .padding(2)
            }
        }
    }

    private func chip(_ id: String?, _ title: String, _ icon: NSImage?) -> some View {
        let on = scope == id
        return Button { scope = id } label: {
            HStack(spacing: 6) {
                if let icon { Image(nsImage: icon).resizable().frame(width: 16, height: 16) }
                Text(title).font(.callout)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(on ? .regular.tint(.accentColor.opacity(0.35)).interactive() : .regular.interactive(), in: .capsule)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"
        if panel.runModal() == .OK, let url = panel.url {
            host.addProfile(for: url)
            if let id = Bundle(url: url)?.bundleIdentifier { scope = id }
        }
    }
}

/// A labelled action menu. `nil` means "inherit" in app profiles.
struct ActionRow: View {
    let title: String
    var highlighted = false
    @Binding var action: HostAction?
    var allowDefaultLabel = "Default"
    @State private var recording = false

    var body: some View {
        HStack {
            Text(title).foregroundStyle(highlighted ? .primary : .secondary)
            Spacer()
            Menu {
                Button(allowDefaultLabel) { action = allowDefaultLabel == "Default" ? .passthrough : nil }
                Divider()
                Button("Gesture button") { action = .gesture }
                Section("System") {
                    ForEach(SystemAction.allCases, id: \.self) { s in Button(s.title) { action = .system(s) } }
                }
                Section("Shortcuts") {
                    ForEach(MacShortcut.all) { s in
                        Button("\(s.title)   \(s.modifiers.symbols)\(HIDKey.name(for: s.key))") { action = s.action.hostAction }
                    }
                    Button("Record a shortcut…") { recording = true }
                }
                Section("Mouse") {
                    ForEach(MouseButton.allCases, id: \.self) { b in Button(b.title) { action = .mouse(b) } }
                }
                Divider()
                Button("Do nothing") { action = .disabled }
            } label: {
                Text(label)
            }
            .menuStyle(.button)
            .buttonStyle(.glass)
            .fixedSize()
        }
        .font(.callout)
        .contentShape(.rect)
        .popover(isPresented: $recording) {
            ShortcutRecorder { m, k in action = .shortcut(m, key: k); recording = false }
                .padding(16)
        }
    }

    private var label: String {
        guard let action else { return allowDefaultLabel }
        if action == .passthrough { return "Default" }
        return action.title
    }
}

extension ButtonAction {
    var hostAction: HostAction {
        switch self {
        case .shortcut(let m, let k): .shortcut(m, key: k)
        case .mouse(let b): .mouse(b)
        case .disabled: .disabled
        default: .passthrough
        }
    }
}

struct GesturePanel: View {
    @Environment(HostController.self) private var host

    var body: some View {
        @Bindable var host = host
        Panel(title: "Gesture button") {
            Text("Hold the button and move the mouse, or just click it.").font(.caption).foregroundStyle(.secondary)
            ActionRow(title: "Click", action: opt(\.click))
            ActionRow(title: "Move up", action: opt(\.up))
            ActionRow(title: "Move down", action: opt(\.down))
            ActionRow(title: "Move left", action: opt(\.left))
            ActionRow(title: "Move right", action: opt(\.right))
            HStack {
                Text("Distance").foregroundStyle(.secondary)
                Slider(value: $host.settings.gestureThreshold, in: 20...200)
            }
            .font(.callout)
        }
    }

    private func opt(_ kp: WritableKeyPath<GestureMap, HostAction>) -> Binding<HostAction?> {
        Binding(get: { host.settings.gestures[keyPath: kp] },
                set: { host.settings.gestures[keyPath: kp] = $0 ?? .passthrough })
    }
}

struct AccessibilityBanner: View {
    @Environment(HostController.self) private var host

    var body: some View {
        if host.settings.needsEventTap && !host.accessibilityGranted {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised").foregroundStyle(.secondary)
                Text("Button actions and scrolling need Accessibility access.").font(.callout)
                Spacer()
                Button("Allow…") { host.requestAccessibility() }.buttonStyle(.glassProminent)
            }
            .padding(12)
            .background(.quinary, in: .rect(cornerRadius: 12))
        }
    }
}

/// Press a key combination to capture it.
struct ShortcutRecorder: View {
    let done: (Modifiers, UInt8) -> Void
    @State private var monitor: Any?

    var body: some View {
        VStack(spacing: 8) {
            Text("Press a shortcut").font(.headline)
            Text("Any of ⌃ ⌥ ⇧ ⌘ plus one key").font(.caption).foregroundStyle(.secondary)
        }
        .onAppear {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
                guard let usage = HIDKey.fromMacKeyCode(e.keyCode) else { return nil }
                var m: Modifiers = []
                if e.modifierFlags.contains(.control) { m.insert(.control) }
                if e.modifierFlags.contains(.option) { m.insert(.option) }
                if e.modifierFlags.contains(.shift) { m.insert(.shift) }
                if e.modifierFlags.contains(.command) { m.insert(.command) }
                done(m, usage)
                return nil
            }
        }
        .onDisappear {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}
