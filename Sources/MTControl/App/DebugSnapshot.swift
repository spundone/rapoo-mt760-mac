import AppKit
import ScreenCaptureKit

/// Developer aid: MTC_SNAPSHOT=/path.png writes the main window to a PNG and quits.
enum DebugSnapshot {
    static var env: [String: String] { ProcessInfo.processInfo.environment }
    static var demo: Bool { env["MTC_DEMO"] == "1" }
    static var pane: Pane? { env["MTC_PANE"].flatMap { p in Pane.allCases.first { "\($0)" == p } } }

    @MainActor static func scheduleIfRequested() {
        guard let path = env["MTC_SNAPSHOT"] else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            Task { @MainActor in
                defer { NSApp.terminate(nil) }
                guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil && $0.level == .normal }) else { return }
                if let image = try? await capture(window) {
                    let rep = NSBitmapImageRep(cgImage: image)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
                    return
                }
                // Fallback without the window server (glass will be flattened).
                guard let view = window.contentView?.superview ?? window.contentView,
                      let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                view.cacheDisplay(in: view.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path + ".fallback.png"))
            }
        }
    }

    @MainActor private static func capture(_ window: NSWindow) async throws -> CGImage? {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let scw = content.windows.first(where: { $0.windowID == CGWindowID(window.windowNumber) }) else { return nil }
        let filter = SCContentFilter(desktopIndependentWindow: scw)
        let cfg = SCStreamConfiguration()
        cfg.width = Int(window.frame.width * 2)
        cfg.height = Int(window.frame.height * 2)
        cfg.showsCursor = false
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: cfg)
    }
}
