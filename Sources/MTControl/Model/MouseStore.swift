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

    func applyDPI() {
        let levels = settings.dpiLevels, n = settings.enabledStages
        perform("DPI saved") { try await $0.setDPI(levels: levels, enabledStages: n) }
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
        settings.pollingRate = rate
        perform("Polling rate \(rate.title)") { try await $0.setPollingRate(rate) }
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

    func factoryReset() {
        perform("Restored factory settings") { d in
            try await d.factoryReset()
        }
        Task { await refresh() }
    }
}
