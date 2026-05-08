import Foundation

protocol ThinQClient: Sendable {
    func fetchDevices(session: ThinQSessionSnapshot) async throws -> [ThinQDevice]
    func fetchProfile(deviceID: String, session: ThinQSessionSnapshot) async throws -> DeviceProfile
    func fetchStatus(deviceID: String, session: ThinQSessionSnapshot) async throws -> DeviceStatus
    func sendControl(_ command: ControlCommand, session: ThinQSessionSnapshot) async throws
    func fetchRoute(session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON]
    func registerClient(session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON]
    func unregisterClient(session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON]
    func issueClientCertificate(csr: String, session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON]
    func subscribePush(deviceID: String, session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON]
    func unsubscribePush(deviceID: String, session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON]
    func subscribeEvents(deviceID: String, session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON]
    func unsubscribeEvents(deviceID: String, session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON]
}

struct ThinQSessionSnapshot: Sendable {
    var token: String
    var country: ThinQCountry
    var clientID: String
}

struct ThinQHTTPClient: ThinQClient {
    // Canonical API reference: APIReference.thinQConnectDeveloperPortal.
    // The values below mirror LG ThinQ Connect's public SDK behavior until the
    // developer portal exposes a newer contract for app-specific credentials.
    private let apiKey = "v6GFvkweNo7DK7yD3ylIZ9w52aKBU0eJ7wLXkSR3"
    private let phase = "OP"
    private let urlSession: URLSession
    private let decoder: JSONDecoder

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        self.decoder = JSONDecoder()
    }

    func fetchDevices(session: ThinQSessionSnapshot) async throws -> [ThinQDevice] {
        let values: [ThinQJSON] = try await request(endpoint: "devices", session: session, includeServicePhase: false)
        return values.compactMap(Self.decodeDevice)
    }

    func fetchProfile(deviceID: String, session: ThinQSessionSnapshot) async throws -> DeviceProfile {
        let raw: [String: ThinQJSON] = try await request(endpoint: "devices/\(deviceID)/profile", session: session, includeServicePhase: false)
        return DeviceProfile(raw: raw, capabilities: DeviceProfileParser.capabilities(from: raw))
    }

    func fetchStatus(deviceID: String, session: ThinQSessionSnapshot) async throws -> DeviceStatus {
        let raw: [String: ThinQJSON] = try await request(endpoint: "devices/\(deviceID)/state", session: session, includeServicePhase: false)
        let flattened = DeviceProfileParser.flattenStatus(raw)
        return DeviceStatus(values: flattened, updatedAt: Date())
    }

    func sendControl(_ command: ControlCommand, session: ThinQSessionSnapshot) async throws {
        let _: [String: ThinQJSON] = try await request(
            endpoint: "devices/\(command.deviceID)/control",
            method: "POST",
            body: .object(command.payload),
            session: session,
            includeServicePhase: false,
            extraHeaders: ["x-conditional-control": "true"]
        )
    }

    func fetchRoute(session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON] {
        try await request(endpoint: "route", session: session, includeAuthorization: false, includeClientID: false)
    }

    func registerClient(session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON] {
        try await request(endpoint: "client", method: "POST", body: .object(Self.clientRegistrationBody), session: session, includeServicePhase: false)
    }

    func unregisterClient(session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON] {
        try await request(endpoint: "client", method: "DELETE", body: .object(Self.clientRegistrationBody), session: session, includeServicePhase: false)
    }

    func issueClientCertificate(csr: String, session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON] {
        try await request(
            endpoint: "client/certificate",
            method: "POST",
            body: .object(["service-code": .string("SVC202"), "csr": .string(csr)]),
            session: session,
            includeServicePhase: false
        )
    }

    func subscribePush(deviceID: String, session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON] {
        try await request(endpoint: "push/\(deviceID)/subscribe", method: "POST", session: session, includeServicePhase: false)
    }

    func unsubscribePush(deviceID: String, session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON] {
        try await request(endpoint: "push/\(deviceID)/unsubscribe", method: "DELETE", session: session, includeServicePhase: false)
    }

    func subscribeEvents(deviceID: String, session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON] {
        try await request(
            endpoint: "event/\(deviceID)/subscribe",
            method: "POST",
            body: .object(["expire": .object(["unit": .string("HOUR"), "timer": .number(24)])]),
            session: session,
            includeServicePhase: false
        )
    }

    func unsubscribeEvents(deviceID: String, session: ThinQSessionSnapshot) async throws -> [String: ThinQJSON] {
        try await request(endpoint: "event/\(deviceID)/unsubscribe", method: "DELETE", session: session, includeServicePhase: false)
    }

    private func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: ThinQJSON? = nil,
        session: ThinQSessionSnapshot,
        includeAuthorization: Bool = true,
        includeClientID: Bool = true,
        includeServicePhase: Bool = true,
        extraHeaders: [String: String] = [:]
    ) async throws -> T {
        if includeAuthorization {
            guard !session.token.isEmpty else { throw ThinQAPIError.missingToken }
        }
        guard var components = URLComponents(string: "https://api-\(session.country.region.rawValue).lgthinq.com/\(endpoint)") else {
            throw ThinQAPIError.invalidURL
        }
        components.percentEncodedPath = components.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? components.path
        guard let url = components.url else { throw ThinQAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        if includeAuthorization {
            request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue(session.country.rawValue, forHTTPHeaderField: "x-country")
        request.setValue(Self.messageID(), forHTTPHeaderField: "x-message-id")
        if includeClientID {
            request.setValue(session.clientID, forHTTPHeaderField: "x-client-id")
        }
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        if includeServicePhase {
            request.setValue(phase, forHTTPHeaderField: "x-service-phase")
        }
        extraHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ThinQAPIError.httpStatus(-1)
        }
        let envelope = try decoder.decode(ThinQEnvelope<T>.self, from: data)
        if (200..<300).contains(http.statusCode), let response = envelope.response {
            return response
        }
        if let error = envelope.error {
            throw ThinQAPIError.api(code: error.code, message: error.message)
        }
        throw ThinQAPIError.httpStatus(http.statusCode)
    }

    static func messageID() -> String {
        let data = withUnsafeBytes(of: UUID().uuid) { Data($0) }
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func decodeDevice(_ value: ThinQJSON) -> ThinQDevice? {
        guard case .object(let object) = value,
              case .string(let id)? = object["deviceId"],
              case .object(let info)? = object["deviceInfo"]
        else { return nil }
        let alias = info.stringValue("alias") ?? object.stringValue("alias") ?? "LG Device"
        let model = info.stringValue("modelName") ?? info.stringValue("model") ?? "Unknown model"
        let type = DeviceType(apiValue: info.stringValue("deviceType") ?? object.stringValue("deviceType") ?? "")
        let reportable = info.boolValue("reportable") ?? object.boolValue("reportable") ?? true
        let groupID = object.stringValue("groupId")
        return ThinQDevice(id: id, alias: alias, type: type, modelName: model, reportable: reportable, groupID: groupID, isFavorite: false)
    }

    private static let clientRegistrationBody: [String: ThinQJSON] = [
        "type": .string("MQTT"),
        "service-code": .string("SVC202"),
        "device-type": .string("607"),
        "allowExist": .bool(true)
    ]
}

struct ThinQEnvelope<Response: Decodable>: Decodable {
    struct APIError: Decodable {
        var code: String
        var message: String
    }

    var response: Response?
    var error: APIError?
}

extension [String: ThinQJSON] {
    func stringValue(_ key: String) -> String? {
        guard case .string(let value)? = self[key] else { return nil }
        return value
    }

    func boolValue(_ key: String) -> Bool? {
        guard case .bool(let value)? = self[key] else { return nil }
        return value
    }
}
