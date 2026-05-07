import Foundation

extension String {
    var thinkQHumanizedIdentifier: String {
        replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "air con", with: "AC", options: .caseInsensitive)
            .capitalized
    }

    var thinkQTitleCasedValue: String {
        let normalized = replacingOccurrences(of: "_", with: " ")
            .lowercased()
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
        switch normalized.lowercased() {
        case "power on", "on":
            return "On"
        case "power off", "off":
            return "Off"
        case "cool":
            return "Cool"
        case "air dry":
            return "Air Dry"
        default:
            return normalized
        }
    }
}
