import AppKit
import SwiftUI

@main
struct ThinkQApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var session = ThinQSessionStore()
    @State private var customizationStore = DeviceCustomizationStore()
    @State private var deviceStore: DeviceStore
    @State private var liveEventService = LiveEventService()

    init() {
        let customizationStore = DeviceCustomizationStore()
        _customizationStore = State(initialValue: customizationStore)
        _deviceStore = State(initialValue: DeviceStore(customizationStore: customizationStore))
    }

    var body: some Scene {
        Window("ThinkQ", id: "main") {
            ContentView()
                .environment(session)
                .environment(deviceStore)
                .environment(customizationStore)
                .environment(liveEventService)
                .task {
                    await deviceStore.refresh(session: session)
                    deviceStore.startPolling(session: session)
                    await connectLiveEventsIfPossible()
                }
                .onDisappear {
                    deviceStore.stopPolling()
                }
                .onAppear {
                    AppModeController.apply(session.menuBarMode)
                }
                .onChange(of: session.menuBarMode) { _, newMode in
                    AppModeController.apply(newMode)
                }
                .frame(minWidth: 980, minHeight: 680)
        }
        .commands {
            ThinkQCommands(session: session, deviceStore: deviceStore)
        }

        MenuBarExtra("ThinkQ", systemImage: "app.connected.to.app.below.fill") {
            MenuBarDashboardView()
                .environment(session)
                .environment(deviceStore)
                .environment(liveEventService)
                .task {
                    if deviceStore.devices.isEmpty {
                        await deviceStore.refresh(session: session)
                    }
                    await connectLiveEventsIfPossible()
                }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(session)
                .environment(deviceStore)
                .environment(liveEventService)
                .frame(width: 560)
        }
    }

    @MainActor
    private func connectLiveEventsIfPossible() async {
        if let rateLimitedUntil = deviceStore.rateLimitedUntil, rateLimitedUntil > Date() {
            return
        }
        await liveEventService.autoConnect(session: session, devices: deviceStore.devices) { message in
            deviceStore.applyLiveEvent(message)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.windowing.info("ThinkQ launched")
    }

    @MainActor
    @objc func showMainWindowFromMenuBar() {
        NSApp.setActivationPolicy(.regular)
        for window in NSApp.windows where window.canBecomeMain && window.title == "ThinkQ" {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

enum AppModeController {
    @MainActor
    static func apply(_ mode: ThinQSessionStore.MenuBarMode) {
        switch mode {
        case .fullAppAndMenuBar, .dockOnly:
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        case .menuBarFirst:
            NSApp.setActivationPolicy(.accessory)
        }
        AppLog.windowing.info("Applied app mode \(mode.rawValue, privacy: .public)")
    }
}

struct ThinkQCommands: Commands {
    let session: ThinQSessionStore
    let deviceStore: DeviceStore

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            SettingsLink {
                Label("ThinkQ Settings", systemImage: "gear")
            }
        }
        CommandMenu("Devices") {
            Button("Refresh Devices") {
                Task { await deviceStore.refresh(session: session) }
            }
            .keyboardShortcut("r", modifiers: [.command])
        }
    }
}
