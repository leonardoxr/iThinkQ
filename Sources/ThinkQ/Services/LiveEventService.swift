import Foundation
import Observation

@MainActor
@Observable
final class LiveEventService {
    enum State: Equatable {
        case idle
        case preparing
        case ready(route: String)
        case connected(host: String)
        case failed(String)

        var title: String {
            switch self {
            case .idle: "Not Prepared"
            case .preparing: "Preparing"
            case .ready: "Ready for MQTT"
            case .connected: "Connected"
            case .failed: "Failed"
            }
        }
    }

    private let client: ThinQClient
    private let certificateService: CertificateService
    private let mqttTransport: MQTTLiveEventTransport
    var state: State = .idle
    var certificateBundle: ClientCertificateBundle?
    var recentMessages: [LiveEventMessage] = []
    private var autoConnectTask: Task<Void, Never>?
    private var connectionKey: String?
    private var messageHandler: (@MainActor (LiveEventMessage) -> Void)?

    init(
        client: ThinQClient = ThinQHTTPClient(),
        certificateService: CertificateService = CertificateService(),
        mqttTransport: MQTTLiveEventTransport = MQTTLiveEventTransport()
    ) {
        self.client = client
        self.certificateService = certificateService
        self.mqttTransport = mqttTransport
    }

    func autoConnect(
        session: ThinQSessionStore,
        devices: [ThinQDevice],
        onMessage: @escaping @MainActor (LiveEventMessage) -> Void
    ) async {
        guard session.hasToken else {
            await disconnect()
            return
        }
        let reportableDevices = devices.filter(\.reportable)
        guard !reportableDevices.isEmpty else { return }

        let key = [
            session.country.rawValue,
            session.clientID,
            reportableDevices.map(\.id).sorted().joined(separator: ",")
        ].joined(separator: "|")

        messageHandler = onMessage
        if connectionKey == key {
            switch state {
            case .preparing, .ready, .connected:
                return
            case .idle, .failed:
                break
            }
        }

        connectionKey = key
        autoConnectTask?.cancel()
        autoConnectTask = Task { [weak self] in
            guard let self else { return }
            await self.prepare(session: session, devices: reportableDevices)
            guard !Task.isCancelled else { return }
            await self.connect(session: session)
        }
    }

    func prepare(session: ThinQSessionStore, devices: [ThinQDevice]) async {
        let snapshot = ThinQSessionSnapshot(token: session.personalAccessToken, country: session.country, clientID: session.clientID)
        state = .preparing
        do {
            let route = try await client.fetchRoute(session: snapshot)
            _ = try await client.registerClient(session: snapshot)
            var bundle = try certificateService.generateCSR()
            let certificateResponse = try await client.issueClientCertificate(csr: bundle.csrBody, session: snapshot)
            if case .object(let result)? = certificateResponse["result"] {
                bundle.certificatePEM = result.stringValue("certificatePem")
                if case .array(let topics)? = result["subscriptions"] {
                    bundle.subscriptions = topics.compactMap {
                        if case .string(let topic) = $0 { topic } else { nil }
                    }
                }
            }
            for device in devices where device.reportable {
                _ = try? await client.subscribeEvents(deviceID: device.id, session: snapshot)
            }
            let mqttRoute = route.stringValue("mqttServer") ?? route.stringValue("mqtt") ?? "ThinQ route available"
            certificateBundle = bundle
            state = .ready(route: mqttRoute)
            AppLog.sync.info("Prepared ThinQ event client and certificate")
        } catch {
            state = .failed(error.localizedDescription)
            AppLog.sync.error("Live event preparation failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func connect(session: ThinQSessionStore) async {
        guard case .ready(let route) = state,
              let bundle = certificateBundle,
              let certificatePEM = bundle.certificatePEM,
              !bundle.subscriptions.isEmpty
        else {
            state = .failed("Prepare the event client before connecting MQTT.")
            return
        }

        let host = route
            .replacingOccurrences(of: "mqtts://", with: "")
            .split(separator: ":")
            .first
            .map(String.init) ?? route

        do {
            try await mqttTransport.connect(
                host: host,
                clientID: session.clientID,
                certificatePEM: certificatePEM,
                privateKeyPEM: bundle.privateKeyPEM,
                subscriptions: bundle.subscriptions
            ) { [weak self] message in
                await MainActor.run {
                    self?.recentMessages.insert(message, at: 0)
                    if let count = self?.recentMessages.count, count > 20 {
                        self?.recentMessages.removeLast(count - 20)
                    }
                    self?.messageHandler?(message)
                }
            }
            state = .connected(host: host)
            AppLog.sync.info("Connected ThinQ MQTT stream")
        } catch {
            state = .failed(error.localizedDescription)
            AppLog.sync.error("MQTT connection failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func disconnect() async {
        autoConnectTask?.cancel()
        autoConnectTask = nil
        connectionKey = nil
        try? await mqttTransport.disconnect()
        state = .idle
    }
}
