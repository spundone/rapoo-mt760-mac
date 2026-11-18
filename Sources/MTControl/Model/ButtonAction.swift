import Foundation

/// HID keyboard modifier usages (page 0x07, 0xE0–0xE7). On macOS, GUI is Command.
struct Modifiers: OptionSet, Hashable, Codable, Sendable {
    let rawValue: UInt8
    static let control = Modifiers(rawValue: 1 << 0)
    static let shift   = Modifiers(rawValue: 1 << 1)
    static let option  = Modifiers(rawValue: 1 << 2)
    static let command = Modifiers(rawValue: 1 << 3)

    /// HID usages in report order (left-hand modifiers).
    var usages: [UInt8] {
        var u: [UInt8] = []
        if contains(.control) { u.append(0xE0) }
        if contains(.shift) { u.append(0xE1) }
        if contains(.option) { u.append(0xE2) }
        if contains(.command) { u.append(0xE3) }
        return u
    }

    init(rawValue: UInt8) { self.rawValue = rawValue }

    init(usages: [UInt8]) {
        var m: Modifiers = []
        for u in usages {
            switch u {
            case 0xE0, 0xE4: m.insert(.control)
            case 0xE1, 0xE5: m.insert(.shift)
            case 0xE2, 0xE6: m.insert(.option)
            case 0xE3, 0xE7: m.insert(.command)
            default: break
            }
        }
        self = m
    }

    var symbols: String {
        var s = ""
        if contains(.control) { s += "⌃" }
        if contains(.option) { s += "⌥" }
        if contains(.shift) { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s
    }
}

enum MouseButton: UInt8, CaseIterable, Codable, Sendable {
    case left = 0xF0, right = 0xF1, middle = 0xF2, back = 0xF3, forward = 0xF4

    var title: String {
        switch self {
        case .left: "Left click"
        case .right: "Right click"
        case .middle: "Middle click"
        case .back: "Back"
        case .forward: "Forward"
        }
    }
}

/// HID consumer-page (0x0C) usages that macOS understands.
enum MediaKey: UInt16, CaseIterable, Codable, Sendable {
    case playPause = 0xCD, next = 0xB5, previous = 0xB6, mute = 0xE2,
         volumeUp = 0xE9, volumeDown = 0xEA, brightnessUp = 0x6F, brightnessDown = 0x70

    var title: String {
        switch self {
        case .playPause: "Play / pause"
        case .next: "Next track"
        case .previous: "Previous track"
        case .mute: "Mute"
        case .volumeUp: "Volume up"
        case .volumeDown: "Volume down"
        case .brightnessUp: "Brightness up"
        case .brightnessDown: "Brightness down"
        }
    }

    var symbol: String {
        switch self {
        case .playPause: "playpause.fill"
        case .next: "forward.end.fill"
        case .previous: "backward.end.fill"
        case .mute: "speaker.slash.fill"
        case .volumeUp: "speaker.plus.fill"
        case .volumeDown: "speaker.minus.fill"
        case .brightnessUp: "sun.max.fill"
        case .brightnessDown: "sun.min.fill"
        }
    }
}

enum DPIFunction: UInt8, CaseIterable, Codable, Sendable {
    case cycleUp = 0x03, cycleDown = 0x04, plus = 0x05, minus = 0x06

    var title: String {
        switch self {
        case .cycleUp: "DPI cycle up"
        case .cycleDown: "DPI cycle down"
        case .plus: "DPI +"
        case .minus: "DPI −"
        }
    }
}

/// What a physical button does. Mirrors what the mouse firmware can store.
enum ButtonAction: Hashable, Codable, Sendable {
    case mouse(MouseButton)
    case doubleClick
    case shortcut(Modifiers, key: UInt8)      // key = HID keyboard usage
    case media(MediaKey)
    case dpi(DPIFunction)
    case scroll(up: Bool)
    case macro(id: Int)
    case disabled

    var title: String {
        switch self {
        case .mouse(let b): return b.title
        case .doubleClick: return "Double click"
        case .shortcut(let m, let k):
            if let preset = MacShortcut.all.first(where: { $0.modifiers == m && $0.key == k }) { return preset.title }
            return m.symbols + HIDKey.name(for: k)
        case .media(let k): return k.title
        case .dpi(let f): return f.title
        case .scroll(let up): return up ? "Scroll up" : "Scroll down"
        case .macro(let id): return "Macro \(id + 1)"
        case .disabled: return "Disabled"
        }
    }

    var detail: String? {
        if case .shortcut(let m, let k) = self { return m.symbols + HIDKey.name(for: k) }
        return nil
    }

    var symbol: String {
        switch self {
        case .mouse(let b):
            switch b {
            case .left: return "computermouse"
            case .right: return "computermouse.fill"
            case .middle: return "circle.circle"
            case .back: return "chevron.backward.circle"
            case .forward: return "chevron.forward.circle"
            }
        case .doubleClick: return "cursorarrow.click.2"
        case .shortcut: return "command"
        case .media(let k): return k.symbol
        case .dpi: return "gauge.with.dots.needle.67percent"
        case .scroll(let up): return up ? "arrow.up.circle" : "arrow.down.circle"
        case .macro: return "record.circle"
        case .disabled: return "nosign"
        }
    }
}

/// Mac-native shortcut presets (the vendor app ships Windows ones).
struct MacShortcut: Identifiable, Hashable {
    let title: String
    let modifiers: Modifiers
    let key: UInt8
    let symbol: String
    var id: String { title }
    var action: ButtonAction { .shortcut(modifiers, key: key) }

    static let all: [MacShortcut] = [
        .init(title: "Copy", modifiers: .command, key: HIDKey.c, symbol: "doc.on.doc"),
        .init(title: "Paste", modifiers: .command, key: HIDKey.v, symbol: "doc.on.clipboard"),
        .init(title: "Cut", modifiers: .command, key: HIDKey.x, symbol: "scissors"),
        .init(title: "Undo", modifiers: .command, key: HIDKey.z, symbol: "arrow.uturn.backward"),
        .init(title: "Redo", modifiers: [.command, .shift], key: HIDKey.z, symbol: "arrow.uturn.forward"),
        .init(title: "Select all", modifiers: .command, key: HIDKey.a, symbol: "selection.pin.in.out"),
        .init(title: "Close window", modifiers: .command, key: HIDKey.w, symbol: "xmark.square"),
        .init(title: "New tab", modifiers: .command, key: HIDKey.t, symbol: "plus.square.on.square"),
        .init(title: "Next tab", modifiers: [.command, .shift], key: HIDKey.rightBracket, symbol: "arrow.right.square"),
        .init(title: "Previous tab", modifiers: [.command, .shift], key: HIDKey.leftBracket, symbol: "arrow.left.square"),
        .init(title: "Spotlight", modifiers: .command, key: HIDKey.space, symbol: "magnifyingglass"),
        .init(title: "Mission Control", modifiers: .control, key: HIDKey.upArrow, symbol: "rectangle.3.group"),
        .init(title: "App windows", modifiers: .control, key: HIDKey.downArrow, symbol: "rectangle.stack"),
        .init(title: "Space left", modifiers: .control, key: HIDKey.leftArrow, symbol: "arrow.left.to.line"),
        .init(title: "Space right", modifiers: .control, key: HIDKey.rightArrow, symbol: "arrow.right.to.line"),
        .init(title: "Lock screen", modifiers: [.control, .command], key: HIDKey.q, symbol: "lock"),
        .init(title: "Screenshot", modifiers: [.command, .shift], key: HIDKey.n4, symbol: "camera.viewfinder"),
        .init(title: "Zoom in", modifiers: .command, key: HIDKey.equal, symbol: "plus.magnifyingglass"),
        .init(title: "Zoom out", modifiers: .command, key: HIDKey.minus, symbol: "minus.magnifyingglass"),
        .init(title: "Switch app", modifiers: .command, key: HIDKey.tab, symbol: "square.on.square"),
        .init(title: "Quit app", modifiers: .command, key: HIDKey.q, symbol: "power"),
    ]
}

/// HID keyboard page (0x07) usages.
enum HIDKey {
    static let a: UInt8 = 0x04, c: UInt8 = 0x06, q: UInt8 = 0x14, t: UInt8 = 0x17, v: UInt8 = 0x19,
               w: UInt8 = 0x1A, x: UInt8 = 0x1B, z: UInt8 = 0x1D, n4: UInt8 = 0x21,
               enter: UInt8 = 0x28, escape: UInt8 = 0x29, tab: UInt8 = 0x2B, space: UInt8 = 0x2C,
               minus: UInt8 = 0x2D, equal: UInt8 = 0x2E, leftBracket: UInt8 = 0x2F, rightBracket: UInt8 = 0x30,
               rightArrow: UInt8 = 0x4F, leftArrow: UInt8 = 0x50, downArrow: UInt8 = 0x51, upArrow: UInt8 = 0x52

    static let names: [UInt8: String] = {
        var n: [UInt8: String] = [:]
        for (i, ch) in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".enumerated() { n[UInt8(0x04 + i)] = String(ch) }
        for (i, ch) in "1234567890".enumerated() { n[UInt8(0x1E + i)] = String(ch) }
        let rest: [UInt8: String] = [
            0x28: "Return", 0x29: "Esc", 0x2A: "Delete", 0x2B: "Tab", 0x2C: "Space", 0x2D: "-", 0x2E: "=",
            0x2F: "[", 0x30: "]", 0x31: "\\", 0x33: ";", 0x34: "'", 0x35: "`", 0x36: ",", 0x37: ".", 0x38: "/",
            0x39: "Caps Lock", 0x4A: "Home", 0x4B: "Page Up", 0x4C: "Fwd Delete", 0x4D: "End", 0x4E: "Page Down",
            0x4F: "→", 0x50: "←", 0x51: "↓", 0x52: "↑",
        ]
        n.merge(rest) { $1 }
        for i in 0..<12 { n[UInt8(0x3A + i)] = "F\(i + 1)" }
        for i in 0..<12 { n[UInt8(0x68 + i)] = "F\(i + 13)" }
        return n
    }()

    static func name(for usage: UInt8) -> String { names[usage] ?? String(format: "Key 0x%02X", usage) }

    /// Keys offered in the custom-shortcut recorder, in a sensible order.
    static let pickerOrder: [UInt8] = Array(0x04...0x1D) + Array(0x1E...0x27) + Array(0x3A...0x45) + Array(0x68...0x73)
        + [0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F, 0x30, 0x31, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38,
           0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F, 0x50, 0x51, 0x52]

    /// macOS virtual keycode → HID usage, for recording shortcuts from the keyboard.
    static func fromMacKeyCode(_ code: UInt16) -> UInt8? {
        let map: [UInt16: UInt8] = [
            0: 0x04, 11: 0x05, 8: 0x06, 2: 0x07, 14: 0x08, 3: 0x09, 5: 0x0A, 4: 0x0B, 34: 0x0C, 38: 0x0D,
            40: 0x0E, 37: 0x0F, 46: 0x10, 45: 0x11, 31: 0x12, 35: 0x13, 12: 0x14, 15: 0x15, 1: 0x16, 17: 0x17,
            32: 0x18, 9: 0x19, 13: 0x1A, 7: 0x1B, 16: 0x1C, 6: 0x1D,
            18: 0x1E, 19: 0x1F, 20: 0x20, 21: 0x21, 23: 0x22, 22: 0x23, 26: 0x24, 28: 0x25, 25: 0x26, 29: 0x27,
            36: 0x28, 53: 0x29, 51: 0x2A, 48: 0x2B, 49: 0x2C, 27: 0x2D, 24: 0x2E, 33: 0x2F, 30: 0x30, 42: 0x31,
            41: 0x33, 39: 0x34, 50: 0x35, 43: 0x36, 47: 0x37, 44: 0x38, 57: 0x39,
            122: 0x3A, 120: 0x3B, 99: 0x3C, 118: 0x3D, 96: 0x3E, 97: 0x3F, 98: 0x40, 100: 0x41, 101: 0x42,
            109: 0x43, 103: 0x44, 111: 0x45, 105: 0x68, 107: 0x69, 113: 0x6A, 106: 0x6B, 64: 0x6C, 79: 0x6D,
            80: 0x6E, 90: 0x6F,
            115: 0x4A, 116: 0x4B, 117: 0x4C, 119: 0x4D, 121: 0x4E, 124: 0x4F, 123: 0x50, 125: 0x51, 126: 0x52,
        ]
        return map[code]
    }
}
