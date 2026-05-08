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
        NSApp.sendAction(#selector(AppDelegate.showMainWindowFromMenuBar), to: nil, from: nil)
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
            HStack(spacing: 10) {
                Button {
                    openDevice()
                } label: {
                    Image(systemName: deviceStore.symbolName(for: device))
                        .foregroundStyle(deviceStore.accent(for: device))
                        .frame(width: 18)
                }
                .buttonStyle(.plain)
                .help("Open device")

                Button {
                    openDevice()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shortTitle(device.displayName))
                            .lineLimit(1)
                        Text(listingStatus.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                powerControl
            }

            HStack(spacing: 8) {
                if deviceStore.pendingQuickControl(.power, for: device) {
                    ProgressView()
                        .controlSize(.small)
                        .help("Sending power command")
                } else if deviceStore.primaryCapability(.power, for: device) != nil {
                    Button {
                        Task { await togglePower() }
                    } label: {
                        Image(systemName: listingStatus.isPoweredOn ? "power.circle.fill" : "power.circle")
                    }
                    .foregroundStyle(listingStatus.tint)
                    .disabled(!deviceStore.canSendQuickControl(.power, for: device))
                    .help(controlHelp(.power, fallback: listingStatus.isPoweredOn ? "Turn off" : "Turn on"))
                }

                if deviceStore.pendingQuickControl(.temperature, for: device) {
                    ProgressView()
                        .controlSize(.small)
                        .help("Sending temperature command")
                } else if deviceStore.primaryCapability(.temperature, for: device) != nil, listingStatus.isOnline, listingStatus.isPoweredOn {
                    Button {
                        Task { await deviceStore.adjustTemperature(for: device, delta: -1, session: session) }
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(!deviceStore.canSendQuickControl(.temperature, for: device))
                    .help(controlHelp(.temperature, fallback: "Lower temperature"))

                    Text(temperatureText ?? "--")
                        .font(.caption.monospacedDigit())
                        .frame(minWidth: 42)

                    Button {
                        Task { await deviceStore.adjustTemperature(for: device, delta: 1, session: session) }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!deviceStore.canSendQuickControl(.temperature, for: device))
                    .help(controlHelp(.temperature, fallback: "Raise temperature"))
                } else if device.type == .airConditioner, let temperatureText {
                    Text(temperatureText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 58, alignment: .leading)
                        .help("Last known room temperature")
                }

                quickEnumControl(role: .mode, title: "Mode")
                quickEnumControl(role: .fan, title: "Fan")

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

    @ViewBuilder
    private var powerControl: some View {
        if deviceStore.primaryCapability(.power, for: device) != nil {
            Button {
                Task { await togglePower() }
            } label: {
                if deviceStore.pendingQuickControl(.power, for: device) {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label(listingStatus.title, systemImage: listingStatus.symbol)
                        .font(.caption)
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(listingStatus.tint)
            .disabled(!deviceStore.canSendQuickControl(.power, for: device))
            .help(controlHelp(.power, fallback: listingStatus.isPoweredOn ? "Turn off" : "Turn on"))
        } else {
            Label(listingStatus.title, systemImage: listingStatus.symbol)
                .font(.caption)
                .foregroundStyle(listingStatus.tint)
                .labelStyle(.titleAndIcon)
        }
    }

    @ViewBuilder
    private func quickEnumControl(role: DeviceControlRole, title: String) -> some View {
        if let capability = deviceStore.primaryCapability(role, for: device),
           capability.kind == .enumeration,
           listingStatus.isOnline {
            if deviceStore.pendingQuickControl(role, for: device) {
                ProgressView()
                    .controlSize(.small)
                    .help("Sending \(title.lowercased()) command")
            } else {
                Picker(title, selection: enumSelectionBinding(role: role, capability: capability)) {
                    ForEach(capability.enumValues, id: \.self) { value in
                        Text(value.thinkQTitleCasedValue)
                            .tag(value)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: role == .mode ? 86 : 72)
                .disabled(!deviceStore.canSendQuickControl(role, for: device))
                .help(controlHelp(role, fallback: "Change \(title.lowercased())"))
            }
        }
    }

    private var isPoweredOn: Bool {
        listingStatus.isPoweredOn
    }

    private var temperatureText: String? {
        deviceStore.sidebarTemperatureText(for: device)
    }

    private func enumSelectionBinding(role: DeviceControlRole, capability: DeviceCapability) -> Binding<String> {
        Binding {
            let current = deviceStore.currentText(for: device, role: role) ?? capability.enumValues.first ?? ""
            return capability.enumValues.contains(current) ? current : capability.enumValues.first ?? ""
        } set: { newValue in
            Task { await deviceStore.sendEnumQuickControl(role, value: newValue, for: device, session: session) }
        }
    }

    private func controlHelp(_ role: DeviceControlRole, fallback: String) -> String {
        deviceStore.unavailableQuickControlReason(role, for: device) ?? fallback
    }

    private func openDevice() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        deviceStore.selection = device.id
        openWindow(id: "main")
        NSApp.sendAction(#selector(AppDelegate.showMainWindowFromMenuBar), to: nil, from: nil)
        AppLog.menuBar.info("Opened device from menu bar")
    }

    private func togglePower() async {
        await deviceStore.setPower(!isPoweredOn, for: device, session: session)
    }

    private func shortTitle(_ title: String) -> String {
        title.count <= 30 ? title : String(title.prefix(27)) + "..."
    }
}
