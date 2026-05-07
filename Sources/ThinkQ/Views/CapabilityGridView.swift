import SwiftUI

struct CapabilityGridView: View {
    let device: ThinQDevice
    let capabilities: [DeviceCapability]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Controls")
                .font(.title2.bold())
            let actionableCapabilities = DeviceControlCatalog.actionableCapabilities(capabilities, for: device.type)
            if actionableCapabilities.isEmpty {
                ContentUnavailableView("No Available Controls", systemImage: "lock", description: Text("This device has not shared configurable controls that ThinkQ can send safely."))
                    .frame(minHeight: 160)
            } else if device.type == .airConditioner {
                AirConditionerControlView(device: device, capabilities: actionableCapabilities)
            } else {
                VStack(spacing: 14) {
                    ForEach(DeviceControlCatalog.groupedCapabilities(actionableCapabilities, for: device.type), id: \.0.id) { role, capabilities in
                        DeviceControlSectionView(device: device, role: role, capabilities: capabilities)
                    }
                }
            }
        }
    }
}

struct DeviceControlSectionView: View {
    let device: ThinQDevice
    let role: DeviceControlRole
    let capabilities: [DeviceCapability]

    private let columns = [
        GridItem(.adaptive(minimum: 250, maximum: 360), spacing: 14)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(role.title, systemImage: role.systemImage)
                .font(.headline)
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(capabilities) { capability in
                    CapabilityControlView(device: device, capability: capability, role: role)
                }
            }
        }
        .padding()
        .thinkQGlassSurface(.thinMaterial)
    }
}

struct CapabilityControlView: View {
    @Environment(ThinQSessionStore.self) private var session
    @Environment(DeviceStore.self) private var deviceStore
    let device: ThinQDevice
    let capability: DeviceCapability
    let role: DeviceControlRole

    @State private var boolValue = false
    @State private var numberValue = 0.0
    @State private var enumValue = ""
    @State private var pendingValue: ThinQJSON?
    @State private var showingConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(DeviceControlCatalog.friendlyTitle(for: capability, role: role))
                        .font(.headline)
                    Text(DeviceControlCatalog.explanation(for: capability, role: role))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if deviceStore.pendingControlIDs.contains(capability.id) {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            control
                .disabled(!(deviceStore.statuses[device.id]?.isAvailable ?? true))

            if let reason = deviceStore.statuses[device.id]?.unavailableReason {
                Label(reason, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .frame(minHeight: 130, alignment: .top)
        .thinkQGlassSurface()
        .confirmationDialog("Send ThinQ Command?", isPresented: $showingConfirmation, titleVisibility: .visible) {
            Button("Send Command", role: isHighRisk ? .destructive : nil) {
                if let pendingValue {
                    send(pendingValue)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(commandPreview)
        }
        .onAppear {
            if let range = capability.range {
                numberValue = deviceStore.currentNumber(for: device, role: role) ?? range.min
            }
            enumValue = currentEnumValue ?? capability.enumValues.first ?? ""
        }
    }

    @ViewBuilder
    private var control: some View {
        switch capability.kind {
        case .bool:
            Toggle("Enabled", isOn: $boolValue)
                .onChange(of: boolValue) { _, newValue in
                    preview(.bool(newValue))
                }
        case .range:
            if let range = capability.range {
                VStack(alignment: .leading) {
                    Slider(value: $numberValue, in: range.min...range.max, step: range.step)
                    Text("\(formattedNumber(numberValue))\(unitSuffix)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        preview(.number(numberValue))
                    } label: {
                        Label("Apply", systemImage: "checkmark.circle")
                    }
                }
            }
        case .enumeration:
            HStack {
                Picker("Value", selection: $enumValue) {
                    ForEach(capability.enumValues, id: \.self) { value in
                        Text(value.thinkQTitleCasedValue)
                            .tag(value)
                    }
                }
                .pickerStyle(.menu)
                Button {
                    guard !enumValue.isEmpty else { return }
                    preview(.string(enumValue))
                } label: {
                    Label("Apply", systemImage: "checkmark.circle")
                }
            }
        default:
            EmptyView()
        }
    }

    private var isHighRisk: Bool {
        switch device.type {
        case .oven, .cooktop, .microwaveOven, .washer, .dryer, .washtower, .washtowerWasher, .washtowerDryer, .washcomboMain, .washcomboMini:
            true
        default:
            capability.property.localizedCaseInsensitiveContains("operation")
        }
    }

    private var commandPreview: String {
        let value = pendingValue?.displayText ?? "New value"
        let title = DeviceControlCatalog.friendlyTitle(for: capability, role: role)
        return "\(device.displayName) will set \(title.lowercased()) to \(value.thinkQTitleCasedValue)."
    }

    private var currentEnumValue: String? {
        deviceStore.statuses[device.id]?.values[capability.id]?.displayText
    }

    private var unitSuffix: String {
        guard let unit = capability.unit, !unit.isEmpty else { return "" }
        return " \(unit)"
    }

    private func formattedNumber(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
    }

    private func preview(_ value: ThinQJSON) {
        pendingValue = value
        showingConfirmation = true
    }

    private func send(_ value: ThinQJSON) {
        Task {
            await deviceStore.send(capability: capability, value: value, device: device, session: session)
        }
    }
}
