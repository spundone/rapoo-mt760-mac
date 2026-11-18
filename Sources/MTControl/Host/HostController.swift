import AppKit
import Observation
import ServiceManagement
import UserNotifications

/// Mac-side features: button remaps, gestures, scrolling, per-app profiles, alerts.
@MainActor
@Observable
final class HostController {
    var settings: HostSettings {
        didSet {
            guard settings != oldValue else { return }
            settings.save()
            engine.settings = settings
            updateEngine()
        }
    }

    private(set) var accessibilityGranted = EventEngine.accessibilityGranted
    private(set) var engineRunning = false
    private(set) var frontmost: NSRunningApplication?
    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Launch at login: \(error)")
            }
        }
    }

    @ObservationIgnored private let engine = EventEngine()
    @ObservationIgnored private weak var store: MouseStore?
    @ObservationIgnored private var stageBeforeOverride: Int?
    @ObservationIgnored private var lastAlertLevel = 100

    init(store: MouseStore) {
        self.store = store
        settings = HostSettings.load()
        engine.settings = settings
        engine.frontmostBundleID = { [weak self] in
            MainActor.assumeIsolated { self?.frontmost?.bundleIdentifier }
        }
        frontmost = NSWorkspace.shared.frontmostApplication
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.appActivated(app) }
        }
        updateEngine()
        Task { await watchLoop() }
    }

    // MARK: Event tap

    func requestAccessibility() {
        EventEngine.requestAccessibility()
    }

    private func updateEngine() {
        accessibilityGranted = EventEngine.accessibilityGranted
        if settings.needsEventTap {
            engineRunning = engine.start()
        } else {
            engine.stop()
            engineRunning = false
        }
    }

    /// Picks up an Accessibility grant without a relaunch, and polls the battery.
    private func watchLoop() async {
        var ticks = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2))
            ticks += 1
            if !engineRunning, settings.needsEventTap, EventEngine.accessibilityGranted { updateEngine() }
            accessibilityGranted = EventEngine.accessibilityGranted
            if ticks % 150 == 0 { await checkBattery() }      // every 5 minutes
        }
    }

    // MARK: Per-app

    private func appActivated(_ app: NSRunningApplication?) {
        guard app?.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        frontmost = app
        applyAppDPI()
    }

    private func applyAppDPI() {
        guard let store, store.phase == .connected, store.writable.contains(.dpiStage) else { return }
        if let stage = settings.profile(for: frontmost?.bundleIdentifier)?.dpiStage,
           stage < store.settings.enabledStages {
            if stageBeforeOverride == nil { stageBeforeOverride = store.settings.currentStage }
            store.selectStage(stage)
        } else if let back = stageBeforeOverride {
            stageBeforeOverride = nil
            store.selectStage(back)
        }
    }

    func addProfile(for url: URL) {
        guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier,
              settings.profile(for: id) == nil else { return }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        settings.apps.append(AppProfile(bundleID: id, name: name))
    }

    func removeProfile(_ id: String) {
        settings.apps.removeAll { $0.bundleID == id }
    }

    static func icon(for bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    // MARK: Battery

    func checkBattery() async {
        guard let store, let level = await store.refreshBattery() else { return }
        let charging = store.info?.charging ?? false
        if charging || level > 20 { lastAlertLevel = 100; return }
        guard settings.lowBatteryAlerts else { return }
        for threshold in [15, 5] where level <= threshold && lastAlertLevel > threshold {
            lastAlertLevel = threshold
            notify(title: "Mouse battery at \(level)%", body: "Plug in the MT760 with its USB-C cable.")
        }
    }

    private func notify(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}
