import AppKit
import SwiftUI

struct MenuBarDashboardView: View {
    @Environment(ThinQSessionStore.self) private var session
    @Environment(DeviceStore.self) private var deviceStore
    @Environment(LiveEventService.self) private var liveEventService
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("ThinkQ", systemImage: "app.connected.to.app.below.fill")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await deviceStore.refresh(session: session) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }

            if !session.hasToken {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Sample mode", systemImage: "wand.and.stars")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        openFullWindow()
                    } label: {
                        Label("Set Up ThinkQ", systemImage: "key")
                    }
                }
            }

            if session.menuBarMode == .dockOnly {
                Label("Dock-only mode selected", systemImage: "dock.rectangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if deviceStore.onlineDevices.isEmpty {
                ContentUnavailableView("No Online Devices", systemImage: "wifi.slash", description: Text("Refresh or wake a device."))
                    .frame(height: 120)
            } else {
                ForEach(deviceStore.menuBarDevices.prefix(5)) { device in
                    MenuBarDeviceRow(device: device)
                }
            }

            Divider()

            Button {
                openFullWindow()
            } label: {
                Label("Open Full Window", systemImage: "macwindow")
            }

            Button {
                openSettingsWindow()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }

            Divider()

            Label(liveEventService.state.title, systemImage: "dot.radiowaves.left.and.right")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(role: .destructive) {
                NSApp.terminate(nil)
            } label: {
                Label("Quit ThinkQ", systemImage: "power")
            }
        }
        .padding(14)
        .frame(width: 320)
    }

    private func openFullWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "main")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApp.windows.first(where: { $0.title == "ThinkQ" || $0.identifier?.rawValue == "main" }) {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                NSApp.sendAction(#selector(AppDelegate.showMainWindowFromMenuBar), to: nil, from: nil)
            }
        }
    }

    private func openSettingsWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }
}

struct MenuBarDeviceRow: View {
    @Environment(ThinQSessionStore.self) private var session
    @Environment(DeviceStore.self) private var deviceStore
    @Environment(\.openWindow) private var openWindow

    let device: ThinQDevice
    private var listingStatus: DeviceListingStatus {
        deviceStore.listingStatus(for: device)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                deviceStore.selection = device.id
                openWindow(id: "main")
                AppLog.menuBar.info("Opened device from menu bar")
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: deviceStore.symbolName(for: device))
                        .foregroundStyle(deviceStore.accent(for: device))
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shortTitle(device.displayName))
                            .lineLimit(1)
                        Text(listingStatus.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if deviceStore.primaryCapability(.power, for: device) != nil {
                        Button {
                            Task { await deviceStore.setPower(!isPoweredOn, for: device, session: session) }
                        } label: {
                            Label(listingStatus.title, systemImage: listingStatus.symbol)
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(listingStatus.tint)
                        .help(listingStatus.isPoweredOn ? "Turn off" : "Turn on")
                    } else {
                        Label(listingStatus.title, systemImage: listingStatus.symbol)
                            .font(.caption)
                            .foregroundStyle(listingStatus.tint)
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                if deviceStore.primaryCapability(.power, for: device) != nil {
                    Button {
                        Task { await deviceStore.setPower(!isPoweredOn, for: device, session: session) }
                    } label: {
                        Image(systemName: listingStatus.isPoweredOn ? "power.circle.fill" : "power.circle")
                    }
                    .foregroundStyle(listingStatus.tint)
                    .help(listingStatus.isPoweredOn ? "Turn off" : "Turn on")
                }

                if deviceStore.primaryCapability(.temperature, for: device) != nil {
                    Button {
                        Task { await deviceStore.adjustTemperature(for: device, delta: -1, session: session) }
                    } label: {
                        Image(systemName: "minus")
                    }
                    .help("Lower temperature")

                    Text(temperatureText)
                        .font(.caption.monospacedDigit())
                        .frame(minWidth: 42)

                    Button {
                        Task { await deviceStore.adjustTemperature(for: device, delta: 1, session: session) }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Raise temperature")
                }

                Spacer()

                if device.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(10)
        .thinkQGlassSurface(interactive: true)
    }

    private var isPoweredOn: Bool {
        listingStatus.isPoweredOn
    }

    private var temperatureText: String {
        if let value = deviceStore.currentNumber(for: device, role: .temperature) {
            return "\(Int(value))°"
        }
        return "--"
    }

    private func shortTitle(_ title: String) -> String {
        title.count <= 30 ? title : String(title.prefix(27)) + "..."
    }
}
