import Testing
@testable import ThinkQ

struct DeviceControlCatalogTests {
    @Test func airConditionerCapabilitiesAreGroupedForUsefulControlOrder() {
        let capabilities = [
            DeviceCapability(id: "operation.airConOperationMode", resource: "operation", property: "airConOperationMode", displayName: "Air Con Operation Mode", kind: .enumeration, isReadable: true, isWritable: true, unit: nil, enumValues: ["POWER_ON", "POWER_OFF"], range: nil),
            DeviceCapability(id: "temperature.targetTemperature", resource: "temperature", property: "targetTemperature", displayName: "Target Temperature", kind: .range, isReadable: true, isWritable: true, unit: "C", enumValues: [], range: .init(min: 16, max: 30, step: 1)),
            DeviceCapability(id: "airFlow.windStrength", resource: "airFlow", property: "windStrength", displayName: "Wind Strength", kind: .enumeration, isReadable: true, isWritable: true, unit: nil, enumValues: ["LOW", "AUTO"], range: nil),
            DeviceCapability(id: "airFlow.rotateUpDown", resource: "airFlow", property: "rotateUpDown", displayName: "Rotate Up Down", kind: .enumeration, isReadable: true, isWritable: true, unit: nil, enumValues: ["ON", "OFF"], range: nil),
            DeviceCapability(id: "airFlow.palletePosition", resource: "airFlow", property: "palletePosition", displayName: "Pallete Position", kind: .enumeration, isReadable: true, isWritable: true, unit: nil, enumValues: ["1", "2", "3"], range: nil)
        ]

        let grouped = DeviceControlCatalog.groupedCapabilities(capabilities, for: .airConditioner)
        #expect(grouped.map(\.0) == [.power, .temperature, .fan, .direction])
        #expect(DeviceControlCatalog.primaryCapability(.temperature, capabilities: capabilities, deviceType: .airConditioner)?.id == "temperature.targetTemperature")
        #expect(DeviceControlCatalog.role(for: capabilities[3], deviceType: .airConditioner) == .direction)
        #expect(DeviceControlCatalog.role(for: capabilities[4], deviceType: .airConditioner) == .direction)
    }
}
