import SwiftUI

struct DeviceDetailView: View {
    @Environment(ThinQSessionStore.self) private var session
    @Environment(DeviceStore.self) private var deviceStore
    let device: ThinQDevice
    @State private var aliasDraft = ""
    @State private var symbolDraft = ""
    @State private var accentDraft = ""

    var profile: DeviceProfile? {
        deviceStore.profiles[device.id]
    }

    var status: DeviceStatus? {
        deviceStore.statuses[device.id]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let reason = status?.unavailableReason {
                    Label(reason, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .thinkQGlassSurface()
                }

                if let error = deviceStore.lastControlError {
                    Label(error, systemImage: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .thinkQGlassSurface()
                }

                if deviceStore.isDeviceCommandPending(device) {
                    HStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.small)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Waiting for LG")
                                .font(.headline)
                            Text("Command sent. Controls are paused until ThinkQ receives the updated device state.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .thinkQGlassSurface()
                }

                DeviceHeroView(device: device, status: status)
                DeviceCustomizationView(device: device, aliasDraft: $aliasDraft, symbolDraft: $symbolDraft, accentDraft: $accentDraft)
                DevicePrimaryPanel(device: device, profile: profile, status: status)
                CapabilityGridView(device: device, capabilities: profile?.writableCapabilities ?? [])
                StatusInspectorView(status: status, profile: profile)
            }
            .padding(24)
            .frame(maxWidth: 1040, alignment: .leading)
        }
        .navigationTitle(device.displayName)
        .onAppear {
            aliasDraft = device.displayName
            symbolDraft = deviceStore.customization(for: device).symbolName ?? device.type.symbolName
            accentDraft = deviceStore.customization(for: device).accentName ?? ""
        }
        .toolbar {
            ToolbarItemGroup {
                TextField("Alias", text: $aliasDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                    .onSubmit {
                        deviceStore.rename(device, alias: aliasDraft)
                    }

                Button {
                    deviceStore.rename(device, alias: aliasDraft)
                } label: {
                    Label("Save Alias", systemImage: "text.badge.checkmark")
                }

                Button {
                    deviceStore.toggleFavorite(device)
                } label: {
                    Label(device.isFavorite ? "Unfavorite" : "Favorite", systemImage: device.isFavorite ? "star.fill" : "star")
                }

                Button {
                    Task { await deviceStore.refresh(session: session, force: true) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(deviceStore.state == .loading)
            }
        }
    }
}

struct DeviceHeroView: View {
    @Environment(DeviceStore.self) private var deviceStore
    let device: ThinQDevice
    let status: DeviceStatus?

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            ZStack {
                Circle()
                    .fill(deviceStore.accent(for: device).opacity(0.18))
                Circle()
                    .stroke(deviceStore.accent(for: device).opacity(0.35), lineWidth: 2)
                    .padding(8)
                Image(systemName: deviceStore.symbolName(for: device))
                    .font(.system(size: 56, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(deviceStore.accent(for: device))
            }
            .frame(width: 148, height: 148)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "wave.3.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green, .regularMaterial)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(device.displayName)
                    .font(.largeTitle.bold())
                Text(device.modelName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    StatusPill(text: statusValue("operation.mode") ?? "Ready", systemImage: "power", tint: .green)
                    StatusPill(text: device.type.title, systemImage: deviceStore.symbolName(for: device), tint: deviceStore.accent(for: device))
                }
            }
            Spacer()
        }
        .padding(22)
        .thinkQGlassSurface()
    }

    private func statusValue(_ key: String) -> String? {
        status?.values[key]?.displayText
    }
}

struct DeviceCustomizationView: View {
    @Environment(DeviceStore.self) private var deviceStore
    let device: ThinQDevice
    @Binding var aliasDraft: String
    @Binding var symbolDraft: String
    @Binding var accentDraft: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Customize")
                .font(.title2.bold())
            HStack(spacing: 14) {
                TextField("Alias", text: $aliasDraft)
                    .textFieldStyle(.roundedBorder)
                Picker("Icon", selection: $symbolDraft) {
                    ForEach(DeviceCustomizationStore.symbolChoices, id: \.self) { symbol in
                        Label(symbol, systemImage: symbol).tag(symbol)
                    }
                }
                Picker("Accent", selection: $accentDraft) {
                    Text("Default").tag("")
                    ForEach(DeviceCustomizationStore.accentChoices, id: \.self) { accent in
                        Text(accent.capitalized).tag(accent)
                    }
                }
                Button {
                    deviceStore.rename(device, alias: aliasDraft)
                    deviceStore.setVisual(device, symbolName: symbolDraft, accentName: accentDraft.isEmpty ? nil : accentDraft)
                } label: {
                    Label("Save", systemImage: "checkmark.circle")
                }
            }
        }
        .padding()
        .thinkQGlassSurface()
    }
}

struct DevicePrimaryPanel: View {
    let device: ThinQDevice
    let profile: DeviceProfile?
    let status: DeviceStatus?

    var body: some View {
        Group {
            switch device.type {
            case .airConditioner:
                ClimatePanel(status: status)
            case .airPurifier, .airPurifierFan, .dehumidifier, .humidifier, .ceilingFan, .ventilator:
                AirPanel(status: status)
            case .washer, .dryer, .washtower, .washtowerWasher, .washtowerDryer, .washcomboMain, .washcomboMini:
                LaundryPanel(status: status)
            case .refrigerator, .kimchiRefrigerator, .wineCellar:
                RefrigeratorPanel(status: status)
            case .robotCleaner, .stickCleaner:
                RobotPanel(status: status)
            default:
                GenericDevicePanel(profile: profile, status: status)
            }
        }
    }
}

struct StatusPill: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(text.thinkQTitleCasedValue, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.16), in: Capsule())
            .foregroundStyle(tint)
    }
}
