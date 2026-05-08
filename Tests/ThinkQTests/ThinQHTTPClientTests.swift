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
        #expect(message.safeDisplaySummary == "Received a device update.")
    }
}
