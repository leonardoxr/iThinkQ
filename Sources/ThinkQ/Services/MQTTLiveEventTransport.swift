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

    var safeDisplaySummary: String {
        guard let data = payload.data(using: .utf8),
              let json = try? JSONDecoder().decode(ThinQJSON.self, from: data)
        else {
            return "Received an encrypted or non-JSON event."
        }

        if json.firstString(for: ["deviceId", "deviceID", "device_id"]) != nil {
            return "Received a device update."
        }

        if json.firstObject(for: ["state", "status", "snapshot", "report", "data"]) != nil {
            return "Received a status update."
        }

        return "Received a ThinQ event."
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
        onMessage: @escaping @Sendable (LiveEventMessage) async -> Void
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
            for await result in listener {
                guard !Task.isCancelled else { break }
                switch result {
                case .success(let publish):
                    var payloadBuffer = publish.payload
                    let payload = payloadBuffer.readString(length: payloadBuffer.readableBytes) ?? ""
                    await onMessage(LiveEventMessage(topic: publish.topicName, payload: payload))
                case .failure:
                    break
                }
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
