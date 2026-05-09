import AppIntents
import Foundation

enum QuickActionPowerState: String, AppEnum {
    case on
    case off

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Power")
    static let caseDisplayRepresentations: [QuickActionPowerState: DisplayRepresentation] = [
        .on: "On",
        .off: "Off"
    ]
}

struct QuickActionDeviceEntity: AppEntity, Identifiable {
    let id: String
    let name: String

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "ThinkQ Device")
    static let defaultQuery = QuickActionDeviceQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct QuickActionDeviceQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [QuickActionDeviceEntity.ID]) async throws -> [QuickActionDeviceEntity] {
        try await loadEntities().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [QuickActionDeviceEntity] {
        let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return try await suggestedEntities() }
        return try await loadEntities().filter { $0.name.localizedCaseInsensitiveContains(normalized) }
    }

    @MainActor
    func suggestedEntities() async throws -> [QuickActionDeviceEntity] {
        try await loadEntities()
    }

    @MainActor
    private func loadEntities() async throws -> [QuickActionDeviceEntity] {
        let customizationStore = DeviceCustomizationStore()
        let session = ThinQSessionStore()
        let deviceStore = DeviceStore(customizationStore: customizationStore)
        deviceStore.loadCachedData(session: session)
        if deviceStore.devices.isEmpty {
            await deviceStore.refresh(session: session)
        }
        return deviceStore.quickActionDevices.map { QuickActionDeviceEntity(id: $0.id, name: $0.displayName) }
    }
}

struct SetQuickActionDevicePowerIntent: AppIntent {
    static let title: LocalizedStringResource = "Set ThinkQ Device Power"
    static let description = IntentDescription("Turn an opted-in ThinkQ device on or off.")
    static let openAppWhenRun = false

    @Parameter(title: "Device")
    var device: QuickActionDeviceEntity

    @Parameter(title: "Power")
    var powerState: QuickActionPowerState

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let customizationStore = DeviceCustomizationStore()
        let session = ThinQSessionStore()
        let deviceStore = DeviceStore(customizationStore: customizationStore)
        deviceStore.loadCachedData(session: session)
        if deviceStore.devices.isEmpty || deviceStore.profiles[device.id] == nil || deviceStore.statuses[device.id] == nil {
            await deviceStore.refresh(session: session)
        }

        guard let targetDevice = deviceStore.quickActionDevices.first(where: { $0.id == device.id }) else {
            return .result(dialog: "This device is not enabled for ThinkQ quick actions.")
        }

        await deviceStore.setPower(powerState == .on, for: targetDevice, session: session)
        if let error = deviceStore.lastControlError {
            return .result(dialog: "ThinkQ could not update \(targetDevice.displayName): \(error)")
        }

        return .result(dialog: "\(targetDevice.displayName) turned \(powerState.rawValue).")
    }
}

struct ThinkQShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SetQuickActionDevicePowerIntent(),
            phrases: [
                "Set \(.applicationName) device power",
                "Turn on my \(.applicationName) device",
                "Turn off my \(.applicationName) device"
            ],
            shortTitle: "Device Power",
            systemImageName: "power"
        )
    }
}
