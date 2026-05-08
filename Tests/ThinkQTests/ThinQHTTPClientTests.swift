import Foundation
import Testing
@testable import ThinkQ

struct ThinQHTTPClientTests {
    @Test func messageIDIsURLSafeBase64WithoutPadding() {
        let id = ThinQHTTPClient.messageID()
        #expect(!id.contains("="))
        #expect(!id.contains("+"))
        #expect(!id.contains("/"))
        #expect(id.count >= 20)
    }

    @Test func liveEventMessageDetectsPushPayloadAndDeviceID() {
        let message = LiveEventMessage(
            topic: "app/clients/sanitized-client/push",
            payload: #"{"deviceId":"device-1","push":{"pushType":"CYCLE_DONE"}}"#
        )

        #expect(message.deviceID == "device-1")
        #expect(message.isPushNotification)
        #expect(message.safeDisplaySummary == "A cycle finished.")
    }

    @Test func liveEventMessageSummarizesStatusUpdatesWithoutPayloadDetails() {
        let message = LiveEventMessage(
            topic: "app/clients/sanitized-client/events",
            payload: #"{"deviceID":"device-1","state":{"temperature":{"target":21},"operation":{"mode":"POWER_ON"}}}"#
        )

        #expect(message.deviceID == "device-1")
        #expect(!message.isPushNotification)
        #expect(message.safeDisplaySummary == "Received a device update.")
    }

    @MainActor
    @Test func liveEventStatusMergesPartialUpdatesWithoutDroppingTemperatures() {
        let store = DeviceStore()
        let device = ThinQDevice(
            id: "device-1",
            alias: "Office AC",
            type: .airConditioner,
            modelName: "AC",
            reportable: true,
            groupID: nil,
            isFavorite: false
        )
        store.devices = [device]
        store.statuses[device.id] = DeviceStatus(values: [
            "operation.airConOperationMode": .string("POWER_ON"),
            "temperature.currentTemperature": .number(25.5),
            "temperature.targetTemperature": .number(21)
        ], updatedAt: Date())

        store.applyLiveEvent(LiveEventMessage(
            topic: "app/clients/sanitized-client/events",
            payload: #"{"deviceID":"device-1","state":{"operation":{"airConOperationMode":"POWER_OFF"}}}"#
        ))

        #expect(store.statuses[device.id]?.values["operation.airConOperationMode"]?.displayText == "POWER_OFF")
        #expect(store.statuses[device.id]?.values["temperature.currentTemperature"]?.displayText == "25.5")
        #expect(store.statuses[device.id]?.values["temperature.targetTemperature"]?.displayText == "21")
    }
}
