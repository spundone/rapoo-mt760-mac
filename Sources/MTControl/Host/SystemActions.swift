import AppKit
import CoreGraphics

/// Posts keyboard shortcuts and system actions from the Mac side.
enum KeyPoster {
    /// Marks events we create so our own event tap lets them through.
    static let marker: Int64 = 0x4D54_4354   // "MTCT"

    static let source: CGEventSource? = {
        let s = CGEventSource(stateID: .hidSystemState)
        s?.userData = marker
        return s
    }()

    static func post(keyCode: UInt16, flags: CGEventFlags) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }
        down.flags = flags
        up.flags = flags
        down.setIntegerValueField(.eventSourceUserData, value: marker)
        up.setIntegerValueField(.eventSourceUserData, value: marker)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    static func post(_ modifiers: Modifiers, hidKey: UInt8) {
        guard let code = HIDKey.macKeyCode(forHID: hidKey) else { return }
        var flags: CGEventFlags = []
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        // Arrow and function keys carry these flags when typed on a real keyboard.
        if (0x4F...0x52).contains(hidKey) { flags.insert([.maskNumericPad, .maskSecondaryFn]) }
        if (0x3A...0x45).contains(hidKey) || (0x68...0x73).contains(hidKey) { flags.insert(.maskSecondaryFn) }
        post(keyCode: code, flags: flags)
    }

    static func post(mouse button: MouseButton, down: Bool) {
        let loc = CGEvent(source: nil)?.location ?? .zero
        let (type, cgButton, number): (CGEventType, CGMouseButton, Int64) = {
            switch button {
            case .left: return (down ? .leftMouseDown : .leftMouseUp, .left, 0)
            case .right: return (down ? .rightMouseDown : .rightMouseUp, .right, 1)
            case .middle: return (down ? .otherMouseDown : .otherMouseUp, .center, 2)
            case .back: return (down ? .otherMouseDown : .otherMouseUp, .center, 3)
            case .forward: return (down ? .otherMouseDown : .otherMouseUp, .center, 4)
            }
        }()
        guard let e = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: loc, mouseButton: cgButton) else { return }
        e.setIntegerValueField(.mouseEventButtonNumber, value: number)
        e.setIntegerValueField(.eventSourceUserData, value: marker)
        e.post(tap: .cghidEventTap)
    }
}

/// Reads the user's shortcuts for system actions from com.apple.symbolichotkeys, so
/// custom bindings (e.g. Show Desktop on Cmd+F11) keep working.
enum SymbolicHotKeys {
    struct Binding { let keyCode: UInt16; let flags: CGEventFlags }

    private static let ids: [SystemAction: Int] = [
        .missionControl: 32, .appExpose: 33, .showDesktop: 36, .spaceLeft: 79, .spaceRight: 81,
    ]

    private static let defaults: [SystemAction: Binding] = [
        .missionControl: Binding(keyCode: 126, flags: CGEventFlags(rawValue: 8_650_752)),  // ⌃↑
        .appExpose: Binding(keyCode: 125, flags: CGEventFlags(rawValue: 8_650_752)),       // ⌃↓
        .showDesktop: Binding(keyCode: 103, flags: CGEventFlags(rawValue: 8_388_608)),     // F11
        .spaceLeft: Binding(keyCode: 123, flags: CGEventFlags(rawValue: 8_650_752)),       // ⌃←
        .spaceRight: Binding(keyCode: 124, flags: CGEventFlags(rawValue: 8_650_752)),      // ⌃→
    ]

    static func binding(for action: SystemAction) -> Binding? {
        guard let id = ids[action] else { return nil }
        let prefs = UserDefaults(suiteName: "com.apple.symbolichotkeys")
        if let all = prefs?.dictionary(forKey: "AppleSymbolicHotKeys"),
           let entry = all[String(id)] as? [String: Any] {
            if let enabled = entry["enabled"] as? Bool, !enabled { return defaults[action] }
            if let value = entry["value"] as? [String: Any],
               let p = value["parameters"] as? [Int], p.count == 3, p[1] != 65535 {
                return Binding(keyCode: UInt16(p[1]), flags: CGEventFlags(rawValue: UInt64(p[2])))
            }
        }
        return defaults[action]
    }

    static func perform(_ action: SystemAction) {
        guard let b = binding(for: action) else { return }
        KeyPoster.post(keyCode: b.keyCode, flags: b.flags)
    }
}

enum ActionRunner {
    /// Fires a one-shot action (anything except passthrough/gesture/mouse hold).
    static func fire(_ action: HostAction) {
        switch action {
        case .shortcut(let m, let k): KeyPoster.post(m, hidKey: k)
        case .system(let s): SymbolicHotKeys.perform(s)
        case .mouse(let b): KeyPoster.post(mouse: b, down: true); KeyPoster.post(mouse: b, down: false)
        case .passthrough, .gesture, .disabled: break
        }
    }
}
