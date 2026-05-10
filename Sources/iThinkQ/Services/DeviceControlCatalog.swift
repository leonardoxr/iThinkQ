import Foundation

enum DeviceControlRole: String, CaseIterable, Identifiable, Sendable {
    case power
    case mode
    case temperature
    case fan
    case humidity
    case timer
    case light
    case direction
    case energy
    case cycle
    case remote
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .power: "Power"
        case .mode: "Mode"
        case .temperature: "Temperature"
        case .fan: "Air Flow"
        case .humidity: "Humidity"
        case .timer: "Timers"
        case .light: "Light"
        case .direction: "Direction"
        case .energy: "Energy"
        case .cycle: "Cycle"
        case .remote: "Remote"
        case .other: "More"
        }
    }

    var systemImage: String {
        switch self {
        case .power: "power"
        case .mode: "dial.medium"
        case .temperature: "thermometer"
        case .fan: "wind"
        case .humidity: "humidity"
        case .timer: "timer"
        case .light: "lightbulb"
        case .direction: "arrow.up.and.down.and.arrow.left.and.right"
        case .energy: "bolt"
        case .cycle: "washer"
        case .remote: "dot.radiowaves.left.and.right"
        case .other: "slider.horizontal.3"
        }
    }
}

enum DeviceControlCatalog {
    static func actionableCapabilities(_ capabilities: [DeviceCapability], for deviceType: DeviceType) -> [DeviceCapability] {
        capabilities.filter { isActionable($0, deviceType: deviceType) }
    }

    static func isActionable(_ capability: DeviceCapability, deviceType: DeviceType) -> Bool {
        guard capability.isWritable else { return false }
        switch capability.kind {
        case .bool:
            return true
        case .enumeration:
            return Set(capability.enumValues).count > 1
        case .range:
            return capability.range != nil
        default:
            return false
        }
    }

    static func friendlyTitle(for capability: DeviceCapability, role: DeviceControlRole) -> String {
        let id = capability.id.lowercased()
        if id.contains("airconoperationmode") || id.contains("operation.airconoperationmode") {
            return "Power"
        }
        if id.contains("currentjobmode") {
            return "Cooling mode"
        }
        if id.contains("targettemperature") || id.contains("cooltargettemperature") || id.contains("autotargettemperature") {
            return "Target temperature"
        }
        if id.contains("windstrengthdetail") {
            return "Fan pattern"
        }
        if id.contains("windstrength") {
            return "Fan speed"
        }
        if id.contains("rotateupdown") {
            return "Swing"
        }
        if id.contains("paletterotation") || id.contains("pallete") || id.contains("palette") || id.contains("vane") {
            return "Vane position"
        }
        if id.contains("display.light") || id.hasSuffix(".light") {
            return "Display light"
        }
        if id.contains("powersaveenabled") {
            return "Energy saver"
        }
        return capability.displayName
    }

    static func explanation(for capability: DeviceCapability, role: DeviceControlRole) -> String {
        switch role {
        case .power:
            "Turn the appliance on or off."
        case .temperature:
            "Choose the comfort target the appliance should maintain."
        case .mode:
            "Pick how the appliance should operate."
        case .fan:
            "Adjust airflow strength or pattern."
        case .direction:
            "Move air direction automatically."
        case .timer:
            "Schedule start or stop timers when supported."
        case .light:
            "Control appliance display or lamp brightness."
        case .energy:
            "Reduce energy use when comfort allows."
        case .humidity:
            "Set the preferred humidity level."
        case .cycle:
            "Choose or manage a cleaning/laundry cycle."
        case .remote:
            "Manage remote-control availability."
        case .other:
            "Additional capability exposed by this model."
        }
    }

    static func role(for capability: DeviceCapability, deviceType: DeviceType) -> DeviceControlRole {
        let token = "\(capability.resource).\(capability.property).\(capability.displayName)".lowercased()

        if token.contains("operationmode") || token.contains("operation mode") {
            return token.contains("power") || token.contains("operation") ? .power : .mode
        }
        if token.contains("jobmode") || token.contains("mode") {
            return .mode
        }
        if token.contains("temperature") || token.contains("targettemperature") {
            return .temperature
        }
        if token.contains("rotate")
            || token.contains("direction")
            || token.contains("swing")
            || token.contains("vane")
            || token.contains("palette")
            || token.contains("pallete")
            || token.contains("vertical")
            || token.contains("horizontal") {
            return .direction
        }
        if token.contains("wind") || token.contains("airflow") || token.contains("fan") {
            return .fan
        }
        if token.contains("humidity") {
            return .humidity
        }
        if token.contains("timer") || token.contains("hour") || token.contains("minute") {
            return .timer
        }
        if token.contains("light") || token.contains("display") || token.contains("lamp") {
            return .light
        }
        if token.contains("powersave") || token.contains("energy") {
            return .energy
        }
        if token.contains("cycle") || token.contains("washer") || token.contains("dryer") {
            return .cycle
        }
        if token.contains("remote") {
            return .remote
        }
        return .other
    }

    static func groupedCapabilities(_ capabilities: [DeviceCapability], for deviceType: DeviceType) -> [(DeviceControlRole, [DeviceCapability])] {
        let grouped = Dictionary(grouping: actionableCapabilities(capabilities, for: deviceType)) { capability in
            role(for: capability, deviceType: deviceType)
        }
        let order = roleOrder(for: deviceType)
        return order.compactMap { role in
            guard let capabilities = grouped[role], !capabilities.isEmpty else { return nil }
            return (role, capabilities.sorted(by: capabilitySort))
        }
    }

    static func primaryCapability(_ role: DeviceControlRole, capabilities: [DeviceCapability], deviceType: DeviceType) -> DeviceCapability? {
        actionableCapabilities(capabilities, for: deviceType)
            .filter { self.role(for: $0, deviceType: deviceType) == role }
            .sorted(by: capabilitySort)
            .first
    }

    static func primaryTemperatureCapability(
        capabilities: [DeviceCapability],
        deviceType: DeviceType,
        currentMode: String?
    ) -> DeviceCapability? {
        let temperatureCapabilities = actionableCapabilities(capabilities, for: deviceType)
            .filter { self.role(for: $0, deviceType: deviceType) == .temperature }
        guard !temperatureCapabilities.isEmpty else { return nil }

        return temperatureCapabilities
            .sorted { lhs, rhs in
                temperatureScore(lhs, currentMode: currentMode) == temperatureScore(rhs, currentMode: currentMode)
                    ? capabilitySort(lhs, rhs)
                    : temperatureScore(lhs, currentMode: currentMode) < temperatureScore(rhs, currentMode: currentMode)
            }
            .first
    }

    private static func roleOrder(for deviceType: DeviceType) -> [DeviceControlRole] {
        switch deviceType {
        case .airConditioner, .airPurifier, .airPurifierFan, .dehumidifier, .humidifier, .ceilingFan, .ventilator:
            [.power, .temperature, .mode, .fan, .humidity, .direction, .timer, .light, .energy, .other]
        case .washer, .dryer, .washtower, .washtowerWasher, .washtowerDryer, .washcomboMain, .washcomboMini:
            [.power, .cycle, .remote, .timer, .mode, .other]
        case .refrigerator, .kimchiRefrigerator, .wineCellar:
            [.temperature, .mode, .light, .energy, .other]
        case .robotCleaner, .stickCleaner:
            [.power, .mode, .timer, .other]
        default:
            [.power, .temperature, .mode, .fan, .timer, .light, .energy, .other]
        }
    }

    private static func capabilitySort(_ lhs: DeviceCapability, _ rhs: DeviceCapability) -> Bool {
        score(lhs) == score(rhs) ? lhs.displayName < rhs.displayName : score(lhs) < score(rhs)
    }

    private static func temperatureScore(_ capability: DeviceCapability, currentMode: String?) -> Int {
        let id = capability.id.lowercased()
        let mode = currentMode?.lowercased() ?? ""

        if mode.contains("cool"), id.contains("cooltargettemperature") { return 0 }
        if mode.contains("auto") || mode.contains("ai"), id.contains("autotargettemperature") { return 0 }
        if mode.contains("heat"), id.contains("heattargettemperature") { return 0 }
        if mode.contains("dry"), id.contains("drytargettemperature") { return 0 }
        if mode.contains("fan"), id.contains("fantargettemperature") { return 0 }

        if id.hasSuffix(".targettemperature") || id.contains(".targettemperature") { return 2 }
        if id.contains("targettemperature") { return 3 }
        return 10
    }

    private static func score(_ capability: DeviceCapability) -> Int {
        let id = capability.id.lowercased()
        if id.contains("operation") { return 0 }
        if id.contains("targettemperature") { return 1 }
        if id.contains("windstrength") { return 2 }
        if id.contains("currentjobmode") { return 3 }
        if id.contains("timer") { return 4 }
        return 10
    }
}
