import SwiftUI

struct AirConditionerControlView: View {
    @Environment(ThinQSessionStore.self) private var session
    @Environment(DeviceStore.self) private var deviceStore

    let device: ThinQDevice
    let capabilities: [DeviceCapability]

    @State private var enumSelections: [String: String] = [:]
    @State private var boolSelections: [String: Bool] = [:]
    @State private var rangeSelections: [String: Double] = [:]
    @State private var temperatureValue = 22.0
    @State private var commandDraft: AirConditionerCommandDraft?
    @State private var showingConfirmation = false

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 360), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            powerCard
            temperatureCard
            enumCard(role: .mode, title: "Mode", symbol: "dial.medium", fallback: "Cooling, dry, fan, or auto operation.")
            fanCard
            directionCard
            boolOrEnumCard(role: .light, title: "Display Light", symbol: "lightbulb", fallback: "Turn the unit display light on or off.")
            boolOrEnumCard(role: .energy, title: "Energy Saver", symbol: "bolt", fallback: "Reduce power use when the room is already comfortable.")
        }
        .disabled(isUnavailable || deviceStore.isDeviceCommandPending(device))
        .overlay(alignment: .topTrailing) {
            if deviceStore.isDeviceCommandPending(device) {
                Label("Waiting for LG", systemImage: "hourglass")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
            }
        }
        .confirmationDialog("Send Air Conditioner Command?", isPresented: $showingConfirmation, titleVisibility: .visible) {
            Button("Apply", role: commandDraft?.isHighRisk == true ? .destructive : nil) {
                if let commandDraft {
                    send(commandDraft)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(commandPreview)
        }
        .onAppear(perform: hydrateState)
        .onChange(of: device.id) { _, _ in
            hydrateState()
        }
        .onChange(of: deviceStore.statuses[device.id]) { _, _ in
            hydrateState()
        }
    }

    @ViewBuilder
    private var directionCard: some View {
        let directionCapabilities = capabilities
            .filter { DeviceControlCatalog.role(for: $0, deviceType: device.type) == .direction }
            .sorted { lhs, rhs in
                directionSortScore(lhs) == directionSortScore(rhs)
                    ? DeviceControlCatalog.friendlyTitle(for: lhs, role: .direction) < DeviceControlCatalog.friendlyTitle(for: rhs, role: .direction)
                    : directionSortScore(lhs) < directionSortScore(rhs)
            }

        if directionCapabilities.isEmpty {
            missingCard(title: "Air Direction", subtitle: "Move the air vane automatically or set its position.", symbol: "arrow.up.and.down")
        } else {
            AirControlCard(title: "Air Direction", subtitle: "Move the air vane automatically or set its position.", symbol: "arrow.up.and.down") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(directionCapabilities) { capability in
                        LabeledControlRow(title: DeviceControlCatalog.friendlyTitle(for: capability, role: .direction)) {
                            directionControl(for: capability)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func directionControl(for capability: DeviceCapability) -> some View {
        switch capability.kind {
        case .bool:
            Toggle("Enabled", isOn: boolBinding(for: capability))
                .toggleStyle(.switch)
                .controlSize(.large)
                .onChange(of: boolSelections[capability.id] ?? false) { _, newValue in
                    preview(capability, value: .bool(newValue), title: DeviceControlCatalog.friendlyTitle(for: capability, role: .direction), highRisk: false)
                }
        case .enumeration:
            EnumApplyControl(
                capability: capability,
                selection: enumBinding(for: capability),
                applyTitle: "Apply",
                preview: { value in
                    preview(capability, value: .string(value), title: DeviceControlCatalog.friendlyTitle(for: capability, role: .direction), highRisk: false)
                }
            )
        case .range:
            if let range = capability.range {
                RangeApplyControl(
                    value: rangeBinding(for: capability, fallback: range.min),
                    range: range,
                    unit: capability.unit,
                    applyTitle: "Apply",
                    preview: { value in
                        preview(capability, value: .number(value), title: DeviceControlCatalog.friendlyTitle(for: capability, role: .direction), highRisk: false)
                    }
                )
            }
        default:
            Text("This direction control has no safe options yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var powerCard: some View {
        if let capability = capability(for: .power) {
            AirControlCard(title: "Power", subtitle: "Turn the unit on or off.", symbol: "power") {
                HStack(spacing: 10) {
                    Button {
                        preview(capability, value: .string(powerValue(on: true, capability: capability) ?? "POWER_ON"), title: "Power", highRisk: false)
                    } label: {
                        Label("On", systemImage: isPoweredOn ? "power.circle.fill" : "power.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(isPoweredOn ? .green : .secondary)
                    .disabled(powerValue(on: true, capability: capability) == nil || deviceStore.isDeviceCommandPending(device))

                    Button {
                        preview(capability, value: .string(powerValue(on: false, capability: capability) ?? "POWER_OFF"), title: "Power", highRisk: true)
                    } label: {
                        Label("Off", systemImage: isPoweredOn ? "moon.zzz" : "checkmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(powerValue(on: false, capability: capability) == nil || deviceStore.isDeviceCommandPending(device))
                }
                .frame(minHeight: 44, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var temperatureCard: some View {
        if let capability = capability(for: .temperature), let range = capability.range {
            let canAdjust = deviceStore.canAdjustTemperature(for: device)
            AirControlCard(
                title: canAdjust ? "Target Temperature" : "Room Temperature",
                subtitle: canAdjust ? "Set the room temperature the unit should maintain." : "The unit is off. Turn it on to change the target temperature.",
                symbol: "thermometer"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        Text(formattedNumber(canAdjust ? temperatureValue : roomTemperatureValue))
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(capability.unit ?? "°C")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                        if canAdjust {
                            Spacer()
                            Stepper("Temperature", value: $temperatureValue, in: range.min...range.max, step: range.step)
                                .labelsHidden()
                                .controlSize(.large)
                        }
                    }

                    if canAdjust {
                        Slider(value: $temperatureValue, in: range.min...range.max, step: range.step)

                        Button {
                            preview(capability, value: .number(temperatureValue), title: "Target Temperature", highRisk: false)
                        } label: {
                            Label("Set Temperature", systemImage: "checkmark.circle")
                        }
                        .controlSize(.large)
                    } else {
                        Label("Target controls are hidden while the AC is off.", systemImage: "power.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var fanCard: some View {
        let fanCapabilities = capabilities
            .filter { DeviceControlCatalog.role(for: $0, deviceType: device.type) == .fan && $0.kind == .enumeration }
            .sorted { lhs, rhs in
                DeviceControlCatalog.friendlyTitle(for: lhs, role: .fan) < DeviceControlCatalog.friendlyTitle(for: rhs, role: .fan)
            }

        if fanCapabilities.isEmpty {
            missingCard(title: "Fan", subtitle: "Choose airflow strength or pattern.", symbol: "wind")
        } else {
            AirControlCard(title: "Fan", subtitle: "Adjust airflow strength or pattern.", symbol: "wind") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(fanCapabilities) { capability in
                        LabeledControlRow(title: DeviceControlCatalog.friendlyTitle(for: capability, role: .fan)) {
                            EnumApplyControl(
                                capability: capability,
                                selection: enumBinding(for: capability),
                                applyTitle: "Apply",
                                preview: { value in
                                    preview(capability, value: .string(value), title: DeviceControlCatalog.friendlyTitle(for: capability, role: .fan), highRisk: false)
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func enumCard(role: DeviceControlRole, title: String, symbol: String, fallback: String) -> some View {
        if let capability = capability(for: role), capability.kind == .enumeration {
            AirControlCard(title: title, subtitle: DeviceControlCatalog.explanation(for: capability, role: role), symbol: symbol) {
                LabeledControlRow(title: nil) {
                    EnumApplyControl(
                        capability: capability,
                        selection: enumBinding(for: capability),
                        applyTitle: "Apply",
                        preview: { value in
                            preview(capability, value: .string(value), title: title, highRisk: role == .mode)
                        }
                    )
                }
            }
        } else {
            missingCard(title: title, subtitle: fallback, symbol: symbol)
        }
    }

    @ViewBuilder
    private func boolOrEnumCard(role: DeviceControlRole, title: String, symbol: String, fallback: String) -> some View {
        if let capability = capability(for: role) {
            AirControlCard(title: title, subtitle: DeviceControlCatalog.explanation(for: capability, role: role), symbol: symbol) {
                switch capability.kind {
                case .bool:
                    LabeledControlRow(title: nil) {
                        Toggle("Enabled", isOn: boolBinding(for: capability))
                            .toggleStyle(.switch)
                            .controlSize(.large)
                            .onChange(of: boolSelections[capability.id] ?? false) { _, newValue in
                                preview(capability, value: .bool(newValue), title: title, highRisk: false)
                            }
                    }
                case .enumeration:
                    LabeledControlRow(title: nil) {
                        EnumApplyControl(
                            capability: capability,
                            selection: enumBinding(for: capability),
                            applyTitle: "Apply",
                            preview: { value in
                                preview(capability, value: .string(value), title: title, highRisk: false)
                            }
                        )
                    }
                default:
                    Text("This model exposes the feature, but not enough options to configure it safely.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            missingCard(title: title, subtitle: fallback, symbol: symbol)
        }
    }

    private func missingCard(title: String, subtitle: String, symbol: String) -> some View {
        AirControlCard(title: title, subtitle: subtitle, symbol: symbol) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Not available on this unit", systemImage: "minus.circle")
                    .font(.caption.weight(.semibold))
                Text(unavailableHint(for: title))
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .frame(minHeight: 44, alignment: .leading)
        }
    }

    private var isUnavailable: Bool {
        !(deviceStore.statuses[device.id]?.isAvailable ?? true)
    }

    private var isPoweredOn: Bool {
        deviceStore.isPoweredOn(for: device)
    }

    private var roomTemperatureValue: Double {
        deviceStore.roomTemperature(for: device) ?? temperatureValue
    }

    private func capability(for role: DeviceControlRole) -> DeviceCapability? {
        if role == .temperature {
            return deviceStore.primaryCapability(.temperature, for: device)
        }
        return DeviceControlCatalog.primaryCapability(role, capabilities: capabilities, deviceType: device.type)
    }

    private func hydrateState() {
        if let capability = capability(for: .temperature), let range = capability.range {
            temperatureValue = deviceStore.currentNumber(for: device, role: .temperature) ?? range.min
        }

        for capability in capabilities where capability.kind == .enumeration {
            let current = deviceStore.statuses[device.id]?.values[capability.id]?.displayText
            enumSelections[capability.id] = current ?? capability.enumValues.first ?? ""
        }

        for capability in capabilities where capability.kind == .bool {
            let current = deviceStore.statuses[device.id]?.values[capability.id]
            if case .bool(let value)? = current {
                boolSelections[capability.id] = value
            } else {
                boolSelections[capability.id] = false
            }
        }

        for capability in capabilities where capability.kind == .range {
            rangeSelections[capability.id] = deviceStore.statuses[device.id]?.firstNumber(capability.id) ?? capability.range?.min ?? 0
        }
    }

    private func enumBinding(for capability: DeviceCapability) -> Binding<String> {
        Binding {
            enumSelections[capability.id] ?? capability.enumValues.first ?? ""
        } set: { newValue in
            enumSelections[capability.id] = newValue
        }
    }

    private func boolBinding(for capability: DeviceCapability) -> Binding<Bool> {
        Binding {
            boolSelections[capability.id] ?? false
        } set: { newValue in
            boolSelections[capability.id] = newValue
        }
    }

    private func rangeBinding(for capability: DeviceCapability, fallback: Double) -> Binding<Double> {
        Binding {
            if capability.id == self.capability(for: .temperature)?.id {
                return temperatureValue
            }
            return rangeSelections[capability.id] ?? deviceStore.statuses[device.id]?.firstNumber(capability.id) ?? fallback
        } set: { newValue in
            if capability.id == self.capability(for: .temperature)?.id {
                temperatureValue = newValue
            } else {
                rangeSelections[capability.id] = newValue
            }
        }
    }

    private func powerValue(on: Bool, capability: DeviceCapability) -> String? {
        capability.enumValues.first { value in
            let upper = value.uppercased()
            return on ? (upper.contains("ON") || upper == "START") : (upper.contains("OFF") || upper == "STOP")
        }
    }

    private func preview(_ capability: DeviceCapability, value: ThinQJSON, title: String, highRisk: Bool) {
        commandDraft = AirConditionerCommandDraft(capability: capability, value: value, title: title, isHighRisk: highRisk)
        showingConfirmation = true
    }

    private func send(_ draft: AirConditionerCommandDraft) {
        Task {
            await deviceStore.send(capability: draft.capability, value: draft.value, device: device, session: session)
        }
    }

    private func formattedNumber(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
    }

    private func directionSortScore(_ capability: DeviceCapability) -> Int {
        let id = capability.id.lowercased()
        if id.contains("rotate") || id.contains("swing") { return 0 }
        if id.contains("palette") || id.contains("pallete") || id.contains("vane") { return 1 }
        return 2
    }

    private func unavailableHint(for title: String) -> String {
        switch title {
        case "Air Direction":
            "This profile did not expose swing or vane positioning as writable."
        case "Fan":
            "This profile did not expose fan speed or pattern controls."
        default:
            "iThinkQ will show it here when LG exposes a writable capability."
        }
    }

    private var commandPreview: String {
        guard let commandDraft else { return "iThinkQ will send this command." }
        return "\(device.displayName) will set \(commandDraft.title.lowercased()) to \(commandDraft.value.displayText.thinkQTitleCasedValue)."
    }
}

private struct AirConditionerCommandDraft: Identifiable {
    let id = UUID()
    let capability: DeviceCapability
    let value: ThinQJSON
    let title: String
    let isHighRisk: Bool
}

private struct AirControlCard<Content: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    @ViewBuilder var content: Content

    init(title: String, subtitle: String, symbol: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(.cyan)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .thinkQGlassSurface(interactive: true)
    }
}

private struct LabeledControlRow<Content: View>: View {
    let title: String?
    @ViewBuilder var content: Content

    init(title: String?, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            content
        }
        .frame(minHeight: 44)
    }
}

private struct EnumApplyControl: View {
    let capability: DeviceCapability
    @Binding var selection: String
    let applyTitle: String
    let preview: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Picker("Value", selection: $selection) {
                ForEach(capability.enumValues, id: \.self) { value in
                    Text(value.thinkQTitleCasedValue)
                        .tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.large)
            .frame(minWidth: 130, maxWidth: 160)

            Button {
                guard !selection.isEmpty else { return }
                preview(selection)
            } label: {
                Label(applyTitle, systemImage: "checkmark.circle")
            }
            .controlSize(.large)
            .frame(minWidth: 112, maxWidth: 132)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RangeApplyControl: View {
    @Binding var value: Double
    let range: DeviceCapability.RangeRule
    let unit: String?
    let applyTitle: String
    let preview: (Double) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Stepper(value: $value, in: range.min...range.max, step: range.step) {
                Text("\(formattedNumber(value))\(unitSuffix)")
                    .monospacedDigit()
                    .frame(width: 64, alignment: .leading)
            }
            .controlSize(.large)
            .frame(minWidth: 130, maxWidth: 160)

            Button {
                preview(value)
            } label: {
                Label(applyTitle, systemImage: "checkmark.circle")
            }
            .controlSize(.large)
            .frame(minWidth: 112, maxWidth: 132)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var unitSuffix: String {
        guard let unit, !unit.isEmpty else { return "" }
        return " \(unit)"
    }

    private func formattedNumber(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
    }
}
