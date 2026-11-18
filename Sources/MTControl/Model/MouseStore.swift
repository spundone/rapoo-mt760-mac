import Foundation
import Observation
import AppKit

@MainActor
@Observable
final class MouseStore {
    enum Phase: Equatable {
        case searching
        case connected
        case failed(String)
    }

    private(set) var phase: Phase = .searching
    private(set) var info: DeviceInfo?
    var settings: MouseSettings = .factory
    private(set) var capabilities: Capabilities = []
    private(set) var writable: Capabilities = []
    private(set) var interfaces: [HIDInterfaceInfo] = []
    private(set) var busy = false
    var toast: String?

    private var driver: MouseDriver?
    private let watcher = HIDWatcher()
    private(set) var isDemo = false

    init() {
        watcher.onChange = { [weak self] list in
            Task { @MainActor in self?.interfacesChanged(list) }
        }
        interfacesChanged(watcher.interfaces)
    }

    private func interfacesChanged(_ list: [HIDInterfaceInfo]) {
        interfaces = list
        guard !isDemo else { return }
        if let (driver, _) = DriverFactory.makeDriver(for: list, watcher: watcher) {
            if self.driver == nil { attach(driver) }
        } else {
            self.driver = nil
            info = nil
            capabilities = []
            phase = .searching
        }
    }

    func startDemo() {
        isDemo = true
        attach(DemoDriver())
    }

    func stopDemo() {
        isDemo = false
        driver = nil
        info = nil
        phase = .searching
        interfacesChanged(watcher.interfaces)
    }

    private func attach(_ d: MouseDriver) {
        driver = d
        capabilities = d.capabilities
        writable = d.writable
        Task { await refresh() }
    }

    func refresh() async {
        guard let driver else { return }
        busy = true
        defer { busy = false }
        do {
            info = try await driver.readInfo()
            settings = try await driver.readSettings()
            phase = .connected
        } catch {
            phase = .failed(error.localizedDescription)
            scheduleRetry()
        }
    }

    @ObservationIgnored private var retryTask: Task<Void, Never>?

    /// A sleeping mouse doesn't answer; keep trying quietly until it wakes up.
    private func scheduleRetry() {
        retryTask?.cancel()
        retryTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, driver != nil, phase != .connected else { return }
            await refresh()
        }
    }

    private func perform(_ label: String, _ op: @escaping (MouseDriver) async throws -> Void) {
        guard let driver else { return }
        Task {
            busy = true
            defer { busy = false }
            do {
                try await op(driver)
                toast = label
            } catch {
                toast = "\(label) failed: \(error.localizedDescription)"
            }
        }
    }

    /// Unsaved DPI edits. Refreshes from the mouse never overwrite these.
    var dpiDraft: [Int]?
    var stagesDraft: Int?
    var hasDPIDraft: Bool {
        (dpiDraft != nil && dpiDraft! != settings.dpiLevels) || (stagesDraft != nil && stagesDraft! != settings.enabledStages)
    }
    var editingLevels: [Int] { dpiDraft ?? settings.dpiLevels }
    var editingStages: Int { stagesDraft ?? settings.enabledStages }

    func setDraftLevel(_ i: Int, _ value: Int) {
        var d = editingLevels
        guard d.indices.contains(i) else { return }
        d[i] = value
        dpiDraft = d
    }

    func discardDPIDraft() {
        dpiDraft = nil
        stagesDraft = nil
    }

    func applyDPI() {
        let range = TelinkCodec.dpiRange
        let levels = editingLevels.map { min(max($0, range.lowerBound), range.upperBound) }
        let n = editingStages
        discardDPIDraft()
        settings.dpiLevels = levels
        settings.enabledStages = n
        writeThenVerify(success: "DPI saved", check: { $0.dpiLevels.prefix(n) == levels.prefix(n) && $0.enabledStages == n }) {
            try await $0.setDPI(levels: levels, enabledStages: n)
        }
    }

    /// Runs a write, re-reads settings, and reports whether the mouse took it.
    private func writeThenVerify(success: String, check: @escaping (MouseSettings) -> Bool,
                                 _ op: @escaping (MouseDriver) async throws -> Void) {
        guard let driver else { return }
        Task {
            busy = true
            defer { busy = false }
            do {
                try await op(driver)
                if let fresh = try? await driver.readSettings() {
                    settings = fresh
                    toast = check(fresh) ? success : "The mouse didn't keep that change"
                } else {
                    toast = success
                }
            } catch {
                toast = "Couldn't save: \(error.localizedDescription)"
                if let fresh = try? await driver.readSettings() { settings = fresh }
            }
        }
    }

    func selectStage(_ stage: Int) {
        guard writable.contains(.dpiStage), stage != settings.currentStage else { return }
        let previous = settings.currentStage
        settings.currentStage = stage
        guard let driver else { return }
        Task {
            busy = true
            defer { busy = false }
            do {
                try await driver.setCurrentStage(stage)
                // Read back so the UI shows what the mouse actually did.
                if let fresh = try? await driver.readSettings() { settings = fresh }
                toast = settings.currentStage == stage
                    ? "\(settings.dpiLevels[stage]) DPI"
                    : "The mouse didn't switch stage"
            } catch {
                settings.currentStage = previous
                toast = "Couldn't switch stage: \(error.localizedDescription)"
            }
        }
    }

    func setPollingRate(_ rate: PollingRate) {
        guard rate != settings.pollingRate else { return }
        settings.pollingRate = rate
        writeThenVerify(success: "Polling rate \(rate.title)", check: { $0.pollingRate == rate }) {
            try await $0.setPollingRate(rate)
        }
    }

    func assign(_ action: ButtonAction, to button: PhysicalButton) {
        settings.buttons[button.id] = action
        perform("\(button.name): \(action.title)") { try await $0.setButton(button.id, to: action) }
    }

    func setSleep(_ minutes: Int) {
        settings.sleepMinutes = minutes
        perform("Sleep after \(minutes) min") { try await $0.setSleep(minutes: minutes) }
    }

    private var snapshotCount = 0

    /// Read-only: logs the mouse's settings memory so changes can be diffed.
    func snapshotMemory() {
        guard let d = driver as? TelinkDriver else { toast = "Snapshots need the real mouse"; return }
        snapshotCount += 1
        let n = snapshotCount
        Task {
            busy = true
            defer { busy = false }
            do {
                try await d.dumpSettingsMemory(label: "#\(n)")
                toast = "Snapshot \(n) saved to the log"
            } catch {
                toast = "Snapshot failed: \(error.localizedDescription)"
            }
        }
    }

    /// Keeps the stage in sync with the mouse's own DPI button while the app is frontmost.
    func pollStage() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3))
            guard phase == .connected, !busy, let d = driver as? TelinkDriver,
                  NSApp.isActive else { continue }
            if let s = try? await d.readCurrentStage(), s < settings.enabledStages, s != settings.currentStage {
                settings.currentStage = s
            }
        }
    }

    /// Re-reads battery quietly; returns the new level.
    @discardableResult
    func refreshBattery() async -> Int? {
        guard phase == .connected, !busy, let d = driver as? TelinkDriver,
              let b = try? await d.readBattery() else { return info?.batteryPercent }
        info?.batteryPercent = b.percent
        info?.charging = b.charging
        return b.percent
    }

    func factoryReset() {
        perform("Restored factory settings") { d in
            try await d.factoryReset()
        }
        Task { await refresh() }
    }
}
