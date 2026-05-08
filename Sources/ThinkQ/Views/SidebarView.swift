import SwiftUI

struct SidebarView: View {
    @Environment(DeviceStore.self) private var deviceStore
    @Binding var selection: ThinQDevice.ID?

    var body: some View {
        List(selection: $selection) {
            Section("Devices") {
                ForEach(deviceStore.filteredDevices) { device in
                    DeviceSidebarRow(device: device)
                        .tag(device.id)
                        .contextMenu {
                            Button(device.isFavorite ? "Remove Favorite" : "Add Favorite") {
                                deviceStore.toggleFavorite(device)
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            SyncStatusView()
                .padding(10)
        }
    }
}

struct DeviceSidebarRow: View {
    @Environment(ThinQSessionStore.self) private var session
    @Environment(DeviceStore.self) private var deviceStore
    let device: ThinQDevice
    private var listingStatus: DeviceListingStatus {
        deviceStore.listingStatus(for: device)
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: deviceStore.symbolName(for: device))
                    .foregroundStyle(deviceStore.accent(for: device))
                Circle()
                    .fill(listingStatus.tint)
                    .frame(width: 7, height: 7)
                    .offset(x: 3, y: 3)
            }
            .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .lineLimit(1)
                Text("\(device.type.title) · \(listingStatus.detail)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            SidebarQuickControls(device: device, listingStatus: listingStatus)
            if device.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 2)
    }
}

struct SidebarQuickControls: View {
    @Environment(ThinQSessionStore.self) private var session
    @Environment(DeviceStore.self) private var deviceStore

    let device: ThinQDevice
    let listingStatus: DeviceListingStatus

    var body: some View {
        HStack(spacing: 4) {
            if hasTemperatureControl, listingStatus.isOnline, listingStatus.isPoweredOn, temperatureText != "--" {
                Button {
                    Task { await deviceStore.adjustTemperature(for: device, delta: -1, session: session) }
                } label: {
                    Image(systemName: "minus")
                }
                .help("Lower temperature")

                Text(temperatureText)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                Button {
                    Task { await deviceStore.adjustTemperature(for: device, delta: 1, session: session) }
                } label: {
                    Image(systemName: "plus")
                }
                .help("Raise temperature")
            } else if device.type == .airConditioner {
                Text(temperatureText)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 48, alignment: .trailing)
                    .help("Last known room temperature")
            }

            if hasPowerControl {
                Button {
                    Task { await deviceStore.setPower(!listingStatus.isPoweredOn, for: device, session: session) }
                } label: {
                    Image(systemName: listingStatus.isPoweredOn ? "power.circle.fill" : "power.circle")
                }
                .foregroundStyle(listingStatus.tint)
                .help(listingStatus.isPoweredOn ? "Turn off" : "Turn on")
            } else {
                Label(listingStatus.title, systemImage: listingStatus.symbol)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(listingStatus.tint)
                    .help("\(listingStatus.title): \(listingStatus.detail)")
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
    }

    private var hasPowerControl: Bool {
        deviceStore.primaryCapability(.power, for: device) != nil
    }

    private var hasTemperatureControl: Bool {
        deviceStore.primaryCapability(.temperature, for: device) != nil
    }

    private var temperatureText: String {
        deviceStore.sidebarTemperatureText(for: device) ?? "--"
    }
}

struct SyncStatusView: View {
    @Environment(DeviceStore.self) private var deviceStore

    var body: some View {
        HStack(spacing: 8) {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var statusIcon: some View {
        Group {
            switch deviceStore.state {
            case .loading:
                ProgressView()
                    .controlSize(.small)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            default:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .frame(width: 16)
    }

    private var title: String {
        switch deviceStore.state {
        case .idle: "Ready"
        case .loading: "Refreshing"
        case .ready: "Connected"
        case .failed: "Needs Attention"
        }
    }

    private var subtitle: String {
        switch deviceStore.state {
        case .failed(let message): message
        default:
            if let lastSync = deviceStore.lastSync {
                "Updated \(lastSync.formatted(date: .omitted, time: .shortened))"
            } else {
                "Sample devices until configured"
            }
        }
    }
}
