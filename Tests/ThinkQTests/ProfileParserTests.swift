import Testing
@testable import ThinkQ

struct ProfileParserTests {
    @Test func parsesWritableRangeAndEnumCapabilities() {
        let raw: [String: ThinQJSON] = [
            "property": .object([
                "operation": .object([
                    "mode": .object([
                        "type": .string("enum"),
                        "mode": .array([.string("r"), .string("w")]),
                        "value": .object(["w": .array([.string("POWER_ON"), .string("POWER_OFF")])])
                    ])
                ]),
                "temperature": .object([
                    "targetTemperature": .object([
                        "type": .string("range"),
                        "mode": .array([.string("r"), .string("w")]),
                        "unit": .string("C"),
                        "value": .object(["w": .object(["min": .number(16), "max": .number(30), "step": .number(1)])])
                    ])
                ])
            ])
        ]

        let capabilities = DeviceProfileParser.capabilities(from: raw)
        #expect(capabilities.count == 2)
        #expect(capabilities.allSatisfy { $0.isWritable })
        #expect(capabilities.first { $0.id == "operation.mode" }?.enumValues == ["POWER_ON", "POWER_OFF"])
        #expect(capabilities.first { $0.id == "temperature.targetTemperature" }?.range?.max == 30)
    }

    @Test func controlEngineValidatesRangeStep() throws {
        let capability = DeviceCapability(
            id: "temperature.targetTemperature",
            resource: "temperature",
            property: "targetTemperature",
            displayName: "Target Temperature",
            kind: .range,
            isReadable: true,
            isWritable: true,
            unit: "C",
            enumValues: [],
            range: .init(min: 16, max: 30, step: 2)
        )

        let engine = ControlEngine()
        #expect(throws: ThinQAPIError.self) {
            try engine.command(deviceID: "device", capability: capability, value: .number(17))
        }
        let command = try engine.command(deviceID: "device", capability: capability, value: .number(18))
        #expect(command.payload == ["temperature": .object(["targetTemperature": .number(18)])])
    }

    @Test func parsesListBasedWasherProfile() {
        let raw: [String: ThinQJSON] = [
            "property": .array([
                .object([
                    "location": .object(["locationName": .string("MAIN")]),
                    "operation": .object([
                        "washerOperationMode": .object([
                            "type": .string("enum"),
                            "mode": .array([.string("r"), .string("w")]),
                            "value": .object(["w": .array([.string("START"), .string("STOP")])])
                        ])
                    ]),
                    "timer": .object([
                        "remainMinute": .object([
                            "type": .string("range"),
                            "mode": .array([.string("r")]),
                            "value": .object(["r": .object(["min": .number(0), "max": .number(59)])])
                        ])
                    ])
                ])
            ])
        ]

        let capabilities = DeviceProfileParser.capabilities(from: raw)
        #expect(capabilities.contains { $0.id == "MAIN.operation.washerOperationMode" })
        #expect(capabilities.first { $0.id == "MAIN.operation.washerOperationMode" }?.isWritable == true)
        #expect(capabilities.first { $0.id == "MAIN.timer.remainMinute" }?.isWritable == false)
    }

    @Test func parsesSanitizedAirConditionerFixture() throws {
        let raw = try FixtureLoader.jsonObject("air-conditioner-profile")
        let capabilities = DeviceProfileParser.capabilities(from: raw)

        #expect(capabilities.contains { $0.id == "operation.airConOperationMode" && $0.isWritable })
        #expect(capabilities.contains { $0.id == "temperature.targetTemperature" && $0.range?.min == 18 })
        #expect(capabilities.contains { $0.id == "airFlow.rotateUpDown" && $0.kind == .bool })
        #expect(capabilities.contains { $0.id == "airFlow.vanePosition" && $0.enumValues.contains("AUTO") })
    }

    @Test func flattensSanitizedAirConditionerStatusFixture() throws {
        let raw = try FixtureLoader.jsonObject("air-conditioner-status")
        let values = DeviceProfileParser.flattenStatus(raw)

        #expect(values["operation.airConOperationMode"]?.displayText == "POWER_ON")
        #expect(values["temperature.targetTemperature"]?.displayText == "22")
        #expect(values["airFlow.rotateUpDown"]?.displayText == "On")
        #expect(values["airFlow.vanePosition"]?.displayText == "AUTO")
    }

    @Test func parsesSanitizedLaundryFixture() throws {
        let raw = try FixtureLoader.jsonObject("laundry-profile")
        let capabilities = DeviceProfileParser.capabilities(from: raw)

        #expect(capabilities.contains { $0.id == "MAIN.operation.washerOperationMode" && $0.isWritable })
        #expect(capabilities.contains { $0.id == "MAIN.cycle.currentCycle" && !$0.isWritable })
        #expect(capabilities.contains { $0.id == "MAIN.timer.remainMinute" && !$0.isWritable })
    }
}
