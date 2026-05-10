import AppKit
import SwiftUI

@main
struct IThinkQApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var session = ThinQSessionStore()
    @State private var customizationStore = DeviceCustomizationStore()
    @State private var deviceStore: DeviceStore
    @State private var liveEventService = LiveEventService()
    @State private var notificationService = NotificationService()
    @State private var launchAtLoginService = LaunchAtLoginService()

    init() {
        let customizationStore = DeviceCustomizationStore()
        _customizationStore = State(initialValue: customizationStore)
        _deviceStore = State(initialValue: DeviceStore(customizationStore: customizationStore))
    }

    var body: some Scene {
        Window("iThinkQ", id: "main") {
            ContentView()
                .environment(session)
                .environment(deviceStore)
                .environment(customizationStore)
                .environment(liveEventService)
                .environment(notificationService)
                .environment(launchAtLoginService)
                .task {
                    await notificationService.refreshAuthorizationState()
                    if session.notificationsEnabled {
                        await notificationService.requestAuthorization()
                    }
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
                .onOpenURL { url in
                    Task { await handleQuickActionURL(url) }
                }
                .frame(minWidth: 980, minHeight: 680)
        }
        .commands {
            IThinkQCommands(session: session, deviceStore: deviceStore)
        }

        MenuBarExtra("iThinkQ", systemImage: "app.connected.to.app.below.fill") {
            MenuBarDashboardView()
                .environment(session)
                .environment(deviceStore)
                .environment(liveEventService)
                .environment(notificationService)
                .environment(launchAtLoginService)
                .task {
                    await notificationService.refreshAuthorizationState()
                    if deviceStore.devices.isEmpty {
                        await deviceStore.refresh(session: session)
                    }
                    await connectLiveEventsIfPossible()
                }
                .onOpenURL { url in
                    Task { await handleQuickActionURL(url) }
                }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(session)
                .environment(deviceStore)
                .environment(liveEventService)
                .environment(notificationService)
                .environment(launchAtLoginService)
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
            Task {
                await notificationService.deliver(message: message, devices: deviceStore.devices, enabled: session.notificationsEnabled)
            }
        }
    }

    @MainActor
    private func handleQuickActionURL(_ url: URL) async {
        guard url.scheme == "ithinkq",
              url.host == "quick-action",
              url.path == "/power",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let deviceID = components.queryItems?.first(where: { $0.name == "device" })?.value,
              let state = components.queryItems?.first(where: { $0.name == "state" })?.value
        else { return }

        deviceStore.loadCachedData(session: session)
        if deviceStore.devices.isEmpty || deviceStore.profiles[deviceID] == nil || deviceStore.statuses[deviceID] == nil {
            await deviceStore.refresh(session: session)
        }
        guard let device = deviceStore.quickActionDevices.first(where: { $0.id == deviceID }) else {
            AppLog.control.error("Rejected quick action for a device that is not enabled")
            return
        }
        await deviceStore.setPower(state == "on", for: device, session: session)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.windowing.info("iThinkQ launched")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let mode = UserDefaults.standard.string(forKey: "preferences.menuBarMode")
            let backgroundNotifications = UserDefaults.standard.bool(forKey: "preferences.backgroundNotifications")
            guard mode == ThinQSessionStore.MenuBarMode.menuBarFirst.rawValue || backgroundNotifications else { return }
            for window in NSApp.windows where window.title == "iThinkQ" {
                window.close()
            }
            NSApp.setActivationPolicy(.accessory)
        }
    }

    @MainActor
    @objc func showMainWindowFromMenuBar() {
        NSApp.setActivationPolicy(.regular)
        for window in NSApp.windows where window.canBecomeMain && window.title == "iThinkQ" {
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

struct IThinkQCommands: Commands {
    let session: ThinQSessionStore
    let deviceStore: DeviceStore

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            SettingsLink {
                Label("iThinkQ Settings", systemImage: "gear")
            }
        }
        CommandMenu("Devices") {
            Button("Refresh Devices") {
                Task { await deviceStore.refresh(session: session, force: true) }
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(deviceStore.state == .loading)
        }
    }
}
