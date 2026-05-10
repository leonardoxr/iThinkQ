import Foundation

struct ControlEngine: Sendable {
    func command(deviceID: String, capability: DeviceCapability, value: ThinQJSON) throws -> ControlCommand {
        guard capability.isWritable else {
            throw ThinQAPIError.unsupportedControl("\(capability.displayName) is read-only.")
        }

        switch capability.kind {
        case .enumeration:
            guard case .string(let stringValue) = value, capability.enumValues.contains(stringValue) else {
                throw ThinQAPIError.unsupportedControl("Choose a supported \(capability.displayName) value.")
            }
        case .range:
            guard let range = capability.range, case .number(let number) = value else {
                throw ThinQAPIError.unsupportedControl("Enter a numeric \(capability.displayName) value.")
            }
            guard number >= range.min, number <= range.max else {
                throw ThinQAPIError.unsupportedControl("\(capability.displayName) must be between \(range.min) and \(range.max).")
            }
            let offset = number - range.min
            guard range.step == 0 || offset.truncatingRemainder(dividingBy: range.step) == 0 else {
                throw ThinQAPIError.unsupportedControl("\(capability.displayName) must use step \(range.step).")
            }
        case .bool:
            guard case .bool = value else {
                throw ThinQAPIError.unsupportedControl("\(capability.displayName) expects On or Off.")
            }
        default:
            break
        }

        return ControlCommand(deviceID: deviceID, resource: capability.resource, property: capability.property, value: value)
    }
}
