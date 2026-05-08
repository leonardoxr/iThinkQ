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
    var connectedAt: Date?
    var lastDisconnectedAt: Date?
    var lastMessageAt: Date?
    var lastSubscriptionRenewalAt: Date?
    var nextSubscriptionRenewalAt: Date?
    var reportableDeviceCount = 0
    var connectionAttempts = 0
    private(set) var retryAfter: Date?
    private var autoConnectTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var subscriptionRenewalTask: Task<Void, Never>?
    private var connectionKey: String?
    private var messageHandler: (@MainActor (LiveEventMessage) -> Void)?
    private var activeSession: ThinQSessionStore?
    private var activeDevices: [ThinQDevice] = []
    private var reconnectAttempts = 0

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
        if let retryAfter, retryAfter > Date() {
            AppLog.sync.info("Skipped MQTT auto-connect during retry backoff")
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
        activeSession = session
        activeDevices = reportableDevices
        reportableDeviceCount = reportableDevices.count
        if connectionKey == key {
            switch state {
            case .preparing, .ready, .connected:
                return
            case .idle, .failed:
                break
            }
        }

        reconnectTask?.cancel()
        reconnectTask = nil
        connectionKey = key
        autoConnectTask?.cancel()
        autoConnectTask = connectionTask(session: session, devices: reportableDevices)
    }

    func prepare(session: ThinQSessionStore, devices: [ThinQDevice]) async {
        let snapshot = ThinQSessionSnapshot(token: session.personalAccessToken, country: session.country, clientID: session.clientID)
        state = .preparing
        reportableDeviceCount = devices.filter(\.reportable).count
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
                _ = try? await client.subscribePush(deviceID: device.id, session: snapshot)
                _ = try? await client.subscribeEvents(deviceID: device.id, session: snapshot)
            }
            let mqttRoute = route.stringValue("mqttServer") ?? route.stringValue("mqtt") ?? "ThinQ route available"
            certificateBundle = bundle
            state = .ready(route: mqttRoute)
            retryAfter = nil
            reconnectAttempts = 0
            AppLog.sync.info("Prepared ThinQ event client and certificate")
        } catch {
            retryAfter = Date().addingTimeInterval(15 * 60)
            state = .failed("\(error.localizedDescription). Falling back to polling; retry later.")
            nextSubscriptionRenewalAt = nil
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
            connectionAttempts += 1
            try await mqttTransport.connect(
                host: host,
                clientID: session.clientID,
                certificatePEM: certificatePEM,
                privateKeyPEM: bundle.privateKeyPEM,
                subscriptions: bundle.subscriptions
            ) { [weak self] message in
                await MainActor.run {
                    self?.lastMessageAt = message.receivedAt
                    self?.recentMessages.insert(message, at: 0)
                    if let count = self?.recentMessages.count, count > 20 {
                        self?.recentMessages.removeLast(count - 20)
                    }
                    self?.messageHandler?(message)
                }
            } onDisconnect: { [weak self] reason in
                await MainActor.run {
                    self?.handleTransportDisconnect(reason: reason)
                }
            }
            state = .connected(host: host)
            connectedAt = Date()
            lastDisconnectedAt = nil
            retryAfter = nil
            reconnectAttempts = 0
            AppLog.sync.info("Connected ThinQ MQTT stream")
        } catch {
            retryAfter = Date().addingTimeInterval(15 * 60)
            state = .failed("\(error.localizedDescription). Falling back to polling; retry later.")
            connectedAt = nil
            AppLog.sync.error("MQTT connection failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func disconnect() async {
        autoConnectTask?.cancel()
        autoConnectTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        subscriptionRenewalTask?.cancel()
        subscriptionRenewalTask = nil
        connectionKey = nil
        retryAfter = nil
        connectedAt = nil
        nextSubscriptionRenewalAt = nil
        activeSession = nil
        activeDevices = []
        try? await mqttTransport.disconnect()
        state = .idle
    }

    private func startSubscriptionRenewal(session: ThinQSessionStore, devices: [ThinQDevice]) {
        subscriptionRenewalTask?.cancel()
        nextSubscriptionRenewalAt = Date().addingTimeInterval(23 * 60 * 60)
        subscriptionRenewalTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(23 * 60 * 60))
                guard let self, !Task.isCancelled else { return }
                await self.renewSubscriptions(session: session, devices: devices)
            }
        }
    }

    private func renewSubscriptions(session: ThinQSessionStore, devices: [ThinQDevice]) async {
        guard session.hasToken else { return }
        let snapshot = ThinQSessionSnapshot(token: session.personalAccessToken, country: session.country, clientID: session.clientID)
        for device in devices where device.reportable {
            _ = try? await client.subscribePush(deviceID: device.id, session: snapshot)
            _ = try? await client.subscribeEvents(deviceID: device.id, session: snapshot)
        }
        lastSubscriptionRenewalAt = Date()
        nextSubscriptionRenewalAt = Date().addingTimeInterval(23 * 60 * 60)
        AppLog.sync.info("Renewed ThinQ push and event subscriptions")
    }

    private func connectionTask(session: ThinQSessionStore, devices: [ThinQDevice]) -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else { return }
            await self.prepare(session: session, devices: devices)
            guard !Task.isCancelled else { return }
            if case .ready = self.state {
                await self.connect(session: session)
            }
            guard !Task.isCancelled else { return }
            self.startSubscriptionRenewal(session: session, devices: devices)
        }
    }

    private func handleTransportDisconnect(reason: String?) {
        guard case .connected = state else { return }
        connectedAt = nil
        lastDisconnectedAt = Date()
        let message = reason.map { "MQTT disconnected: \($0)" } ?? "MQTT disconnected."
        state = .failed("\(message) Polling is still active; reconnect is scheduled.")
        AppLog.sync.error("ThinQ MQTT disconnected: \(reason ?? "listener ended", privacy: .public)")
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        guard let session = activeSession, !activeDevices.isEmpty else { return }
        reconnectTask?.cancel()
        reconnectAttempts += 1
        let delay = min(900, 30 * pow(2, Double(max(0, reconnectAttempts - 1))))
        retryAfter = Date().addingTimeInterval(delay)
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            self.retryAfter = nil
            self.autoConnectTask?.cancel()
            self.autoConnectTask = self.connectionTask(session: session, devices: self.activeDevices)
        }
        AppLog.sync.info("Scheduled ThinQ MQTT reconnect")
    }
}
