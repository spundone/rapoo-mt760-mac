import Foundation

/// An action performed on the Mac when a mouse button is pressed.
enum HostAction: Codable, Hashable, Sendable {
    case passthrough                 // leave the button alone
    case shortcut(Modifiers, key: UInt8)
    case system(SystemAction)
    case gesture                     // hold and move for gestures, click for `gestureClick`
    case mouse(MouseButton)
    case disabled

    var title: String {
        switch self {
        case .passthrough: "Default"
        case .shortcut(let m, let k):
            MacShortcut.all.first { $0.modifiers == m && $0.key == k }?.title ?? (m.symbols + HIDKey.name(for: k))
        case .system(let s): s.title
        case .gesture: "Gesture button"
        case .mouse(let b): b.title
        case .disabled: "Do nothing"
        }
    }
}

/// System actions resolved from the user's own Keyboard Shortcuts settings.
enum SystemAction: String, Codable, CaseIterable, Sendable {
    case missionControl, appExpose, showDesktop, spaceLeft, spaceRight

    var title: String {
        switch self {
        case .missionControl: "Mission Control"
        case .appExpose: "App windows"
        case .showDesktop: "Show desktop"
        case .spaceLeft: "Space left"
        case .spaceRight: "Space right"
        }
    }
}

/// Buttons the Mac can see. The top button is handled by the mouse (DPI cycle).
enum HostButton: Int, CaseIterable, Codable, Identifiable, Sendable {
    case middle = 2, back = 3, forward = 4
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .middle: "Wheel click"
        case .back: "Back"
        case .forward: "Forward"
        }
    }

    /// Matching firmware key on the diagram.
    var physicalID: Int {
        switch self {
        case .middle: 1
        case .back: 6
        case .forward: 5
        }
    }
}

struct GestureMap: Codable, Hashable, Sendable {
    var click: HostAction = .system(.missionControl)
    var up: HostAction = .system(.missionControl)
    var down: HostAction = .system(.appExpose)
    var left: HostAction = .system(.spaceRight)
    var right: HostAction = .system(.spaceLeft)
}

struct ButtonBindings: Codable, Hashable, Sendable {
    var actions: [HostButton: HostAction] = [:]

    func action(for b: HostButton) -> HostAction { actions[b] ?? .passthrough }
}

struct AppProfile: Codable, Hashable, Identifiable, Sendable {
    var bundleID: String
    var name: String
    var buttons: ButtonBindings = .init()
    /// Overrides only the buttons set here; others fall back to "All apps".
    var dpiStage: Int?
    var id: String { bundleID }
}

struct HostSettings: Codable, Equatable, Sendable {
    var buttonsEnabled = true
    var global = ButtonBindings()
    var gestures = GestureMap()
    var gestureThreshold: Double = 60
    var apps: [AppProfile] = []

    var scrollEnabled = true
    var reverseScroll = false
    var smoothScroll = false
    var scrollSpeed: Double = 1.0

    var lowBatteryAlerts = true
    var batteryInMenuBar = false

    func profile(for bundleID: String?) -> AppProfile? {
        guard let bundleID else { return nil }
        return apps.first { $0.bundleID == bundleID }
    }

    func action(for button: HostButton, app bundleID: String?) -> HostAction {
        if let p = profile(for: bundleID), let a = p.buttons.actions[button] { return a }
        return global.action(for: button)
    }

    var needsEventTap: Bool {
        let anyButton = buttonsEnabled && (global.actions.values.contains { $0 != .passthrough }
            || apps.contains { $0.buttons.actions.values.contains { $0 != .passthrough } })
        let anyScroll = scrollEnabled && (reverseScroll || smoothScroll || abs(scrollSpeed - 1) > 0.01)
        return anyButton || anyScroll
    }

    static let key = "hostSettings.v1"

    var encoded: Data? { try? JSONEncoder().encode(self) }

    static func decode(_ data: Data?) -> HostSettings? {
        data.flatMap { try? JSONDecoder().decode(HostSettings.self, from: $0) }
    }

    static func load() -> HostSettings {
        decode(UserDefaults.standard.data(forKey: key)) ?? HostSettings()
    }

    func save() {
        if let data = encoded { UserDefaults.standard.set(data, forKey: Self.key) }
    }
}
