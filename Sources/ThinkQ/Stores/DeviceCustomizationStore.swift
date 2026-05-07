import Foundation
import Observation

@MainActor
@Observable
final class DeviceCustomizationStore {
    private let defaults: UserDefaults
    private let key = "device.customizations"

    var customizations: [ThinQDevice.ID: DeviceCustomization] = [:]

    static let symbolChoices = [
        "thermometer.snowflake",
        "wind",
        "washer",
        "refrigerator",
        "dishwasher",
        "stove",
        "sparkles",
        "humidity",
        "drop",
        "fan",
        "hanger",
        "leaf",
        "app.connected.to.app.below.fill"
    ]

    static let accentChoices = ["cyan", "indigo", "mint", "blue", "orange", "teal", "green", "purple", "brown"]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func customization(for deviceID: ThinQDevice.ID) -> DeviceCustomization {
        customizations[deviceID] ?? .empty
    }

    func apply(to device: ThinQDevice) -> ThinQDevice {
        let customization = customization(for: device.id)
        var copy = device
        if !customization.alias.isEmpty {
            copy.alias = customization.alias
        }
        copy.isFavorite = customization.isFavorite
        return copy
    }

    func symbolName(for device: ThinQDevice) -> String {
        customization(for: device.id).symbolName ?? device.type.symbolName
    }

    func accentName(for device: ThinQDevice) -> String? {
        customization(for: device.id).accentName
    }

    func setFavorite(_ isFavorite: Bool, for deviceID: ThinQDevice.ID) {
        var customization = customization(for: deviceID)
        customization.isFavorite = isFavorite
        customizations[deviceID] = customization
        save()
    }

    func setAlias(_ alias: String, for deviceID: ThinQDevice.ID) {
        var customization = customization(for: deviceID)
        customization.alias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        customizations[deviceID] = customization
        save()
    }

    func setVisual(symbolName: String?, accentName: String?, for deviceID: ThinQDevice.ID) {
        var customization = customization(for: deviceID)
        customization.symbolName = symbolName
        customization.accentName = accentName
        customizations[deviceID] = customization
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ThinQDevice.ID: DeviceCustomization].self, from: data)
        else { return }
        customizations = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(customizations) else { return }
        defaults.set(data, forKey: key)
    }
}
