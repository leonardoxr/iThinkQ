import Foundation

struct MockThinQClient: ThinQClient {
    func fetchDevices(session: ThinQSessionSnapshot) async throws -> [ThinQDevice] {
        [
            ThinQDevice(id: "ac-main", alias: "Living Room Air", type: .airConditioner, modelName: "LG Dual Inverter", reportable: true, groupID: "home", isFavorite: true),
            ThinQDevice(id: "washer", alias: "Laundry Tower", type: .washtower, modelName: "WashTower WKEX", reportable: true, groupID: "home", isFavorite: true),
            ThinQDevice(id: "fridge", alias: "Kitchen Fridge", type: .refrigerator, modelName: "InstaView", reportable: true, groupID: "home", isFavorite: false),
            ThinQDevice(id: "robot", alias: "Robot Cleaner", type: .robotCleaner, modelName: "CordZero R9", reportable: true, groupID: "home", isFavorite: false)
        ]
    }

    func fetchProfile(deviceID: String, session: ThinQSessionSnapshot) async throws -> DeviceProfile {
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
                ]),
                "airFlow": .object([
                    "windStrength": .object([
                        "type": .string("enum"),
                        "mode": .array([.string("r"), .string("w")]),
                        "value": .object(["w": .array([.string("LOW"), .string("MID"), .string("HIGH"), .string("AUTO")])])
                    ])
                ])
            ])
        ]
        return DeviceProfile(raw: raw, capabilities: DeviceProfileParser.capabilities(from: raw))
    }

    func fetchStatus(deviceID: String, session: ThinQSessionSnapshot) async throws -> DeviceStatus {
        let status: [String: ThinQJSON] = [
            "operation.mode": deviceID == "robot" ? .string("DOCKED") : .string("POWER_ON"),
            "temperature.targetTemperature": .number(23),
            "temperature.currentTemperature": .number(24),
            "airFlow.windStrength": .string("AUTO"),
            "timer.remaining": .string("42 min")
        ]
        return DeviceStatus(values: status, updatedAt: Date())
    }

    func sendControl(_ command: ControlCommand, session: ThinQSessionSnapshot) async throws {
        try await Task.sleep(for: .milliseconds(250))
    }

    func fetchRoute(session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON] {
        ["mqttServer": .string("mqtts://example.iot.amazonaws.com")]
    }

    func registerClient(session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON] {
        ["registered": .bool(true)]
    }

    func unregisterClient(session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON] {
        ["registered": .bool(false)]
    }

    func issueClientCertificate(csr: String, session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON] {
        ["result": .object(["certificatePem": .string("mock"), "subscriptions": .array([.string("mock/topic")])])]
    }

    func subscribePush(deviceID: String, session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON] {
        ["subscribed": .bool(true)]
    }

    func unsubscribePush(deviceID: String, session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON] {
        ["subscribed": .bool(false)]
    }

    func subscribeEvents(deviceID: String, session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON] {
        ["subscribed": .bool(true)]
    }

    func unsubscribeEvents(deviceID: String, session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON] {
        ["subscribed": .bool(false)]
    }
}
