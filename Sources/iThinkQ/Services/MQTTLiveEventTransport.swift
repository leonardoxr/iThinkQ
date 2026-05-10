import Foundation
import MQTTNIO
import NIOCore
import NIOPosix
import NIOSSL

struct LiveEventMessage: Identifiable, Hashable, Sendable {
    var id = UUID()
    var topic: String
    var payload: String
    var receivedAt = Date()

    var safeDisplayTitle: String {
        "Live event"
    }

    var deviceID: String? {
        guard let data = payload.data(using: .utf8),
              let json = try? JSONDecoder().decode(ThinQJSON.self, from: data)
        else { return nil }
        return json.firstString(for: ["deviceId", "deviceID", "device_id"])
    }

    var isPushNotification: Bool {
        guard let data = payload.data(using: .utf8),
              let json = try? JSONDecoder().decode(ThinQJSON.self, from: data)
        else {
            return topic.localizedCaseInsensitiveContains("push")
        }
        if case .object(let object) = json {
            return object["push"] != nil || topic.localizedCaseInsensitiveContains("push")
        }
        return topic.localizedCaseInsensitiveContains("push")
    }

    var safeDisplaySummary: String {
        guard let data = payload.data(using: .utf8),
              let json = try? JSONDecoder().decode(ThinQJSON.self, from: data)
        else {
            return "Received an encrypted or non-JSON event."
        }

        if let pushType = json.firstString(for: ["pushType", "type", "eventType", "alertType"]) {
            return Self.summary(forPushType: pushType)
        }

        if json.firstString(for: ["deviceId", "deviceID", "device_id"]) != nil {
            return "Received a device update."
        }

        if json.firstObject(for: ["state", "status", "snapshot", "report", "data"]) != nil {
            return "Received a status update."
        }

        return "Received a ThinQ event."
    }

    private static func summary(forPushType pushType: String) -> String {
        let normalized = pushType
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .lowercased()

        if normalized.contains("cycle") && (normalized.contains("done") || normalized.contains("complete")) {
            return "A cycle finished."
        }
        if normalized.contains("error") || normalized.contains("fault") {
            return "The appliance reported an error."
        }
        if normalized.contains("filter") {
            return "Filter attention may be needed."
        }
        if normalized.contains("door") {
            return "Door status changed."
        }
        if normalized.contains("energy") {
            return "Energy usage changed."
        }
        return "Received a ThinQ alert."
    }
}

actor MQTTLiveEventTransport {
    private var client: MQTTClient?
    private var eventTask: Task<Void, Never>?

    func connect(
        host: String,
        clientID: String,
        certificatePEM: String,
        privateKeyPEM: String,
        subscriptions: [String],
        onMessage: @escaping @Sendable (LiveEventMessage) async -> Void,
        onDisconnect: @escaping @Sendable (String?) async -> Void
    ) async throws {
        try await disconnect()

        let certificate = try NIOSSLCertificate(bytes: Array(certificatePEM.utf8), format: .pem)
        let privateKey = try NIOSSLPrivateKey(bytes: Array(privateKeyPEM.utf8), format: .pem)
        var tls = TLSConfiguration.makeClientConfiguration()
        tls.certificateChain = [.certificate(certificate)]
        tls.privateKey = .privateKey(privateKey)

        let mqttClient = MQTTClient(
            host: host,
            port: 8883,
            identifier: clientID,
            eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton),
            configuration: .init(
                version: .v3_1_1,
                keepAliveInterval: .seconds(6),
                useSSL: true,
                tlsConfiguration: .niossl(tls),
                sniServerName: host
            )
        )

        let listener = mqttClient.createPublishListener()
        _ = try await mqttClient.connect(cleanSession: false)
        _ = try await mqttClient.subscribe(to: subscriptions.map { MQTTSubscribeInfo(topicFilter: $0, qos: .atLeastOnce) })

        eventTask = Task {
            var disconnectReason: String?
            listenLoop: for await result in listener {
                guard !Task.isCancelled else { break }
                switch result {
                case .success(let publish):
                    var payloadBuffer = publish.payload
                    let payload = payloadBuffer.readString(length: payloadBuffer.readableBytes) ?? ""
                    await onMessage(LiveEventMessage(topic: publish.topicName, payload: payload))
                case .failure(let error):
                    disconnectReason = error.localizedDescription
                    break listenLoop
                }
            }
            if !Task.isCancelled {
                await onDisconnect(disconnectReason)
            }
        }

        client = mqttClient
    }

    func disconnect() async throws {
        eventTask?.cancel()
        eventTask = nil
        if let client {
            try? await client.disconnect()
            try await client.shutdown()
        }
        client = nil
    }
}
