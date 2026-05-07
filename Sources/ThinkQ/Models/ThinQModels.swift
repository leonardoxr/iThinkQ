import Foundation
import SwiftUI

enum DeviceType: String, Codable, CaseIterable, Identifiable, Sendable {
    case airConditioner = "DEVICE_AIR_CONDITIONER"
    case airPurifier = "DEVICE_AIR_PURIFIER"
    case airPurifierFan = "DEVICE_AIR_PURIFIER_FAN"
    case washer = "DEVICE_WASHER"
    case dryer = "DEVICE_DRYER"
    case washtower = "DEVICE_WASHTOWER"
    case washtowerWasher = "DEVICE_WASHTOWER_WASHER"
    case washtowerDryer = "DEVICE_WASHTOWER_DRYER"
    case refrigerator = "DEVICE_REFRIGERATOR"
    case dishWasher = "DEVICE_DISH_WASHER"
    case oven = "DEVICE_OVEN"
    case cooktop = "DEVICE_COOKTOP"
    case microwaveOven = "DEVICE_MICROWAVE_OVEN"
    case hood = "DEVICE_HOOD"
    case robotCleaner = "DEVICE_ROBOT_CLEANER"
    case dehumidifier = "DEVICE_DEHUMIDIFIER"
    case humidifier = "DEVICE_HUMIDIFIER"
    case waterHeater = "DEVICE_WATER_HEATER"
    case waterPurifier = "DEVICE_WATER_PURIFIER"
    case wineCellar = "DEVICE_WINE_CELLAR"
    case styler = "DEVICE_STYLER"
    case systemBoiler = "DEVICE_SYSTEM_BOILER"
    case ceilingFan = "DEVICE_CEILING_FAN"
    case kimchiRefrigerator = "DEVICE_KIMCHI_REFRIGERATOR"
    case stickCleaner = "DEVICE_STICK_CLEANER"
    case homeBrew = "DEVICE_HOME_BREW"
    case plantCultivator = "DEVICE_PLANT_CULTIVATOR"
    case washcomboMain = "DEVICE_WASHCOMBO_MAIN"
    case washcomboMini = "DEVICE_WASHCOMBO_MINI"
    case ventilator = "DEVICE_VENTILATOR"
    case unknown

    var id: String { rawValue }

    init(apiValue: String) {
        self = DeviceType(rawValue: apiValue) ?? .unknown
    }

    var title: String {
        switch self {
        case .airConditioner: "Air Conditioner"
        case .airPurifier, .airPurifierFan: "Air Care"
        case .washer, .dryer, .washtower, .washtowerWasher, .washtowerDryer, .washcomboMain, .washcomboMini: "Laundry"
        case .refrigerator, .kimchiRefrigerator: "Refrigerator"
        case .dishWasher: "Dishwasher"
        case .oven, .cooktop, .microwaveOven, .hood: "Kitchen"
        case .robotCleaner, .stickCleaner: "Cleaning"
        case .dehumidifier, .humidifier, .ceilingFan, .ventilator: "Air"
        case .waterHeater, .waterPurifier, .systemBoiler: "Water"
        case .wineCellar: "Wine Cellar"
        case .styler: "Styler"
        case .homeBrew: "Home Brew"
        case .plantCultivator: "Plant Cultivator"
        case .unknown: "ThinQ Device"
        }
    }

    var symbolName: String {
        switch self {
        case .airConditioner: "thermometer.snowflake"
        case .airPurifier, .airPurifierFan: "wind"
        case .washer, .dryer, .washtower, .washtowerWasher, .washtowerDryer, .washcomboMain, .washcomboMini: "washer"
        case .refrigerator, .kimchiRefrigerator, .wineCellar: "refrigerator"
        case .dishWasher: "dishwasher"
        case .oven, .cooktop, .microwaveOven, .hood: "stove"
        case .robotCleaner, .stickCleaner: "sparkles"
        case .dehumidifier, .humidifier: "humidity"
        case .waterHeater, .waterPurifier, .systemBoiler: "drop"
        case .ceilingFan, .ventilator: "fan"
        case .styler: "hanger"
        case .homeBrew: "mug"
        case .plantCultivator: "leaf"
        case .unknown: "app.connected.to.app.below.fill"
        }
    }

    var accent: Color {
        switch self {
        case .airConditioner, .airPurifier, .airPurifierFan, .ceilingFan, .ventilator: .cyan
        case .washer, .dryer, .washtower, .washtowerWasher, .washtowerDryer, .washcomboMain, .washcomboMini: .indigo
        case .refrigerator, .kimchiRefrigerator, .wineCellar: .mint
        case .dishWasher, .waterHeater, .waterPurifier, .systemBoiler: .blue
        case .oven, .cooktop, .microwaveOven, .hood, .homeBrew: .orange
        case .robotCleaner, .stickCleaner: .teal
        case .dehumidifier, .humidifier: .green
        case .styler: .purple
        case .plantCultivator: .brown
        case .unknown: .secondary
        }
    }
}

struct ThinQDevice: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var alias: String
    var type: DeviceType
    var modelName: String
    var reportable: Bool
    var groupID: String?
    var isFavorite: Bool

    var displayName: String { alias.isEmpty ? modelName : alias }
}

struct DeviceStatus: Codable, Hashable, Sendable {
    var values: [String: ThinQJSON]
    var updatedAt: Date

    subscript(_ key: String) -> ThinQJSON? {
        values[key]
    }

    var unavailableReason: String? {
        values["connection.error"]?.displayText
    }

    var isAvailable: Bool {
        unavailableReason == nil
    }

    func firstText(_ keys: String...) -> String? {
        for key in keys {
            if let value = values[key] {
                return value.displayText
            }
        }
        return nil
    }

    func firstNumber(_ keys: String...) -> Double? {
        for key in keys {
            if case .number(let value)? = values[key] {
                return value
            }
            if case .string(let value)? = values[key], let number = Double(value) {
                return number
            }
        }
        return nil
    }
}

struct DeviceProfile: Codable, Hashable, Sendable {
    var raw: [String: ThinQJSON]
    var capabilities: [DeviceCapability]

    var writableCapabilities: [DeviceCapability] {
        capabilities.filter(\.isWritable)
    }
}

struct DeviceCapability: Identifiable, Codable, Hashable, Sendable {
    enum ValueKind: String, Codable, Sendable {
        case string
        case number
        case bool
        case enumeration
        case range
        case list
        case unknown
    }

    struct RangeRule: Codable, Hashable, Sendable {
        var min: Double
        var max: Double
        var step: Double
    }

    var id: String
    var resource: String
    var property: String
    var displayName: String
    var kind: ValueKind
    var isReadable: Bool
    var isWritable: Bool
    var unit: String?
    var enumValues: [String]
    var range: RangeRule?
}

struct ControlCommand: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var deviceID: String
    var resource: String
    var property: String
    var value: ThinQJSON

    var payload: [String: ThinQJSON] {
        [resource: .object([property: value])]
    }
}

struct EnergyUsagePoint: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var date: Date
    var value: Double
    var unit: String
}

struct DeviceCustomization: Codable, Hashable, Sendable {
    var alias: String
    var symbolName: String?
    var accentName: String?
    var isFavorite: Bool

    static let empty = DeviceCustomization(alias: "", symbolName: nil, accentName: nil, isFavorite: false)
}

extension Color {
    static func thinkQAccent(named name: String?) -> Color? {
        switch name {
        case "cyan": .cyan
        case "indigo": .indigo
        case "mint": .mint
        case "blue": .blue
        case "orange": .orange
        case "teal": .teal
        case "green": .green
        case "purple": .purple
        case "brown": .brown
        default: nil
        }
    }
}

struct DeviceSyncIssue: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var deviceID: ThinQDevice.ID
    var deviceName: String
    var area: String
    var message: String
    var date = Date()
}

extension DeviceSyncIssue {
    var isNonCriticalThinQFeatureGap: Bool {
        let normalized = message.lowercased()
        return normalized.contains("not provided feature")
            || normalized.contains("unsupported feature")
            || normalized.contains("not supported")
    }

    var userFacingSummary: String {
        if isNonCriticalThinQFeatureGap {
            return "\(area) is not exposed by ThinQ for this device."
        }
        if message.localizedCaseInsensitiveContains("not connected") {
            return "\(area) failed because the device is offline."
        }
        return "\(area): \(message)"
    }
}
