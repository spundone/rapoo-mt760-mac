import SwiftUI
import AppKit

@main
struct MTControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = MouseStore()

    var body: some Scene {
        WindowGroup("MT Control", id: "main") {
            RootView()
                .environment(store)
                .frame(minWidth: 860, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Mouse") {
                Button("Refresh") { Task { await store.refresh() } }
                    .keyboardShortcut("r")
                Divider()
                if store.isDemo {
                    Button("Leave demo") { store.stopDemo() }
                } else {
                    Button("Demo mode") { store.startDemo() }
                }
            }
        }

        MenuBarExtra {
            MenuBarView().environment(store)
        } label: {
            Image(systemName: "computermouse.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftPM executables launch as background tools unless told otherwise.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        DebugSnapshot.scheduleIfRequested()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
