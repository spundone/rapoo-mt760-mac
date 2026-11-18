import Foundation

/// A physical button on the MT760 and where to draw it on the diagram (0…1 coordinates).
struct PhysicalButton: Identifiable, Hashable, Sendable {
    let id: Int            // firmware key index
    let name: String
    let anchor: CGPoint
    let defaultAction: ButtonAction

    static let mt760: [PhysicalButton] = [
        .init(id: 0, name: "Left button", anchor: CGPoint(x: 0.36, y: 0.20), defaultAction: .mouse(.left)),
        .init(id: 2, name: "Right button", anchor: CGPoint(x: 0.66, y: 0.20), defaultAction: .mouse(.right)),
        .init(id: 1, name: "Wheel click", anchor: CGPoint(x: 0.52, y: 0.13), defaultAction: .mouse(.middle)),
        .init(id: 4, name: "Top button", anchor: CGPoint(x: 0.52, y: 0.34), defaultAction: .dpi(.cycleUp)),
        .init(id: 5, name: "Forward", anchor: CGPoint(x: 0.17, y: 0.44), defaultAction: .mouse(.forward)),
        .init(id: 6, name: "Back", anchor: CGPoint(x: 0.17, y: 0.56), defaultAction: .mouse(.back)),
    ]
}

enum PollingRate: Int, CaseIterable, Identifiable, Sendable {
    case hz125 = 125, hz250 = 250, hz500 = 500, hz1000 = 1000
    var id: Int { rawValue }
    var title: String { "\(rawValue) Hz" }
}

enum ConnectionKind: String, Sendable {
    case dongle = "2.4 GHz receiver", usb = "USB cable", bluetooth = "Bluetooth", demo = "Demo"
    var symbol: String {
        switch self {
        case .dongle: "antenna.radiowaves.left.and.right"
        case .usb: "cable.connector"
        case .bluetooth: "dot.radiowaves.left.and.right"
        case .demo: "sparkles"
        }
    }
}

struct DeviceInfo: Equatable, Sendable {
    var name: String
    var firmware: String
    var connection: ConnectionKind
    var batteryPercent: Int?
    var charging: Bool
}

struct MouseSettings: Equatable, Sendable {
    var dpiLevels: [Int]          // per-stage DPI
    var enabledStages: Int        // how many stages the cycle walks through
    var currentStage: Int
    var pollingRate: PollingRate
    var buttons: [Int: ButtonAction]
    var sleepMinutes: Int

    static let factory = MouseSettings(
        dpiLevels: [800, 1200, 1600, 2400, 3200, 4000],
        enabledStages: 4,
        currentStage: 2,
        pollingRate: .hz1000,
        buttons: Dictionary(uniqueKeysWithValues: PhysicalButton.mt760.map { ($0.id, $0.defaultAction) }),
        sleepMinutes: 10)
}

/// Capability flags so the UI hides what a given connection cannot do.
struct Capabilities: OptionSet, Sendable {
    let rawValue: Int
    static let dpi = Capabilities(rawValue: 1 << 0)
    static let pollingRate = Capabilities(rawValue: 1 << 1)
    static let buttons = Capabilities(rawValue: 1 << 2)
    static let battery = Capabilities(rawValue: 1 << 3)
    static let sleep = Capabilities(rawValue: 1 << 4)
    static let factoryReset = Capabilities(rawValue: 1 << 5)
    static let all: Capabilities = [.dpi, .pollingRate, .buttons, .battery, .sleep, .factoryReset]
}

/// Anything that can talk to a mouse: the real HID driver, or a demo.
protocol MouseDriver: AnyObject, Sendable {
    var capabilities: Capabilities { get }
    /// True while writes are not yet verified on hardware.
    var isReadOnly: Bool { get }
    func readInfo() async throws -> DeviceInfo
    func readSettings() async throws -> MouseSettings
    func setDPI(levels: [Int], enabledStages: Int) async throws
    func setCurrentStage(_ stage: Int) async throws
    func setPollingRate(_ rate: PollingRate) async throws
    func setButton(_ id: Int, to action: ButtonAction) async throws
    func setSleep(minutes: Int) async throws
    func factoryReset() async throws
}

final class DemoDriver: MouseDriver, @unchecked Sendable {
    private var settings = MouseSettings.factory
    let capabilities: Capabilities = .all
    let isReadOnly = false

    func readInfo() async throws -> DeviceInfo {
        DeviceInfo(name: "MT760L (demo)", firmware: "1.4.4", connection: .demo, batteryPercent: 82, charging: false)
    }
    func readSettings() async throws -> MouseSettings { settings }
    func setDPI(levels: [Int], enabledStages: Int) async throws { settings.dpiLevels = levels; settings.enabledStages = enabledStages }
    func setCurrentStage(_ stage: Int) async throws { settings.currentStage = stage }
    func setPollingRate(_ rate: PollingRate) async throws { settings.pollingRate = rate }
    func setButton(_ id: Int, to action: ButtonAction) async throws { settings.buttons[id] = action }
    func setSleep(minutes: Int) async throws { settings.sleepMinutes = minutes }
    func factoryReset() async throws { settings = .factory }
}
