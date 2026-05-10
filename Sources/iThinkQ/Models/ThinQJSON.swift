import Foundation

enum ThinQJSON: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: ThinQJSON])
    case array([ThinQJSON])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: ThinQJSON].self) {
            self = .object(value)
        } else {
            self = .array(try container.decode([ThinQJSON].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var displayText: String {
        switch self {
        case .string(let value): value
        case .number(let value):
            value.rounded() == value ? String(Int(value)) : String(value)
        case .bool(let value): value ? "On" : "Off"
        case .array(let values): values.map(\.displayText).joined(separator: ", ")
        case .object: "Details"
        case .null: "Unavailable"
        }
    }

    func firstString(for keys: Set<String>) -> String? {
        switch self {
        case .object(let object):
            for key in keys {
                if case .string(let value)? = object[key] {
                    return value
                }
            }
            for value in object.values {
                if let found = value.firstString(for: keys) {
                    return found
                }
            }
            return nil
        case .array(let values):
            for value in values {
                if let found = value.firstString(for: keys) {
                    return found
                }
            }
            return nil
        default:
            return nil
        }
    }

    func firstObject(for keys: Set<String>) -> ThinQJSON? {
        switch self {
        case .object(let object):
            for key in keys {
                if let value = object[key], case .object = value {
                    return value
                }
            }
            for value in object.values {
                if let found = value.firstObject(for: keys) {
                    return found
                }
            }
            return nil
        case .array(let values):
            for value in values {
                if let found = value.firstObject(for: keys) {
                    return found
                }
            }
            return nil
        default:
            return nil
        }
    }
}
