import Foundation

enum ThinQAPIError: LocalizedError, Equatable, Sendable {
    case missingToken
    case unsupportedCountry
    case invalidURL
    case httpStatus(Int)
    case api(code: String, message: String)
    case decoding(String)
    case unsupportedControl(String)

    var errorDescription: String? {
        switch self {
        case .missingToken: "Add a ThinQ Personal Access Token in Settings."
        case .unsupportedCountry: "This country is not supported by ThinQ Connect."
        case .invalidURL: "ThinkQ could not build the ThinQ API URL."
        case .httpStatus(let status): "ThinQ returned HTTP \(status)."
        case .api(let code, let message): "ThinQ \(code): \(message)"
        case .decoding(let detail): "ThinkQ could not read the ThinQ response: \(detail)"
        case .unsupportedControl(let detail): detail
        }
    }

    var isRateLimit: Bool {
        switch self {
        case .api(let code, let message):
            code == "1314" || message.localizedCaseInsensitiveContains("exceeded")
        case .httpStatus(let status):
            status == 429
        default:
            false
        }
    }

    var userFacingMessage: String {
        isRateLimit ? "LG ThinQ API limit reached. ThinkQ will pause requests for a while." : (errorDescription ?? "Unknown ThinQ error.")
    }
}
