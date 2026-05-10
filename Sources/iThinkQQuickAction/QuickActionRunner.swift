import Foundation

@main
struct QuickActionRunner {
    static func main() async {
        do {
            let arguments = try Arguments(CommandLine.arguments.dropFirst())
            let runner = HeadlessPowerRunner()
            if arguments.checkTokenOnly {
                try runner.checkToken()
            } else {
                try await runner.setPower(deviceID: arguments.deviceID, on: arguments.state == "on")
            }
        } catch {
            fputs("iThinkQ quick action failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}

private struct Arguments {
    var deviceID: String
    var state: String
    var checkTokenOnly: Bool

    init(_ arguments: ArraySlice<String>) throws {
        var deviceID: String?
        var state: String?
        var checkTokenOnly = false
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--check-token":
                checkTokenOnly = true
            case "--device":
                deviceID = iterator.next()
            case "--state":
                state = iterator.next()
            default:
                continue
            }
        }
        if checkTokenOnly {
            self.deviceID = ""
            self.state = "off"
            self.checkTokenOnly = true
            return
        }
        guard let deviceID, !deviceID.isEmpty else { throw QuickActionError.invalidArguments }
        guard let state, state == "on" || state == "off" else { throw QuickActionError.invalidArguments }
        self.deviceID = deviceID
        self.state = state
        self.checkTokenOnly = false
    }
}

private struct HeadlessPowerRunner {
    private let defaults = UserDefaults(suiteName: "com.xavier.ithinkq") ?? .standard
    private let keychain = KeychainStore(service: "com.xavier.ithinkq")
    private let tokenAccount = "thinq-personal-access-token"

    func checkToken() throws {
        let token = try keychain.string(for: tokenAccount) ?? ""
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ThinQAPIError.missingToken
        }
    }

    func setPower(deviceID: String, on: Bool) async throws {
        let token = try keychain.string(for: tokenAccount) ?? ""
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ThinQAPIError.missingToken
        }

        let countryCode = defaults.string(forKey: "session.country") ?? ThinQCountry.US.rawValue
        let country = ThinQCountry(rawValue: countryCode) ?? .US
        let clientID = defaults.string(forKey: "session.clientID") ?? "thinq-open-\(UUID().uuidString.lowercased())"
        let session = ThinQSessionSnapshot(token: token, country: country, clientID: clientID)
        let client = ThinQHTTPClient()
        let deviceType = try await client.fetchDevices(session: session)
            .first(where: { $0.id == deviceID })?
            .type ?? .unknown
        let profile = try await client.fetchProfile(deviceID: deviceID, session: session)

        guard let capability = DeviceControlCatalog.primaryCapability(
            .power,
            capabilities: profile.writableCapabilities,
            deviceType: deviceType
        ) else {
            throw QuickActionError.missingPowerCapability
        }
        guard let selectedValue = capability.enumValues.first(where: { value in
            let upper = value.uppercased()
            return on ? (upper.contains("ON") || upper == "START") : (upper.contains("OFF") || upper == "STOP")
        }) else {
            throw QuickActionError.missingPowerValue
        }

        let command = try ControlEngine().command(deviceID: deviceID, capability: capability, value: .string(selectedValue))
        try await client.sendControl(command, session: session)
    }
}

private enum QuickActionError: LocalizedError {
    case invalidArguments
    case missingPowerCapability
    case missingPowerValue

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            "Expected --device <id> --state on|off."
        case .missingPowerCapability:
            "This device does not expose a writable power control."
        case .missingPowerValue:
            "This device does not expose a supported on/off value."
        }
    }
}
