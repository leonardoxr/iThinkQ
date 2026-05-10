import Foundation

enum DeviceProfileParser {
    static func capabilities(from raw: [String: ThinQJSON]) -> [DeviceCapability] {
        guard let propertyRoot = raw["property"] else {
            return []
        }

        var capabilities: [DeviceCapability] = []
        switch propertyRoot {
        case .object(let properties):
            capabilities.append(contentsOf: parsePropertyDictionary(properties, prefix: nil))
        case .array(let subProfiles):
            for item in subProfiles {
                guard case .object(let subProfile) = item else { continue }
                let locationName = subProfile.locationName
                capabilities.append(contentsOf: parsePropertyDictionary(subProfile, prefix: locationName))
            }
        default:
            break
        }
        return capabilities
    }

    static func flattenStatus(_ raw: [String: ThinQJSON]) -> [String: ThinQJSON] {
        var values: [String: ThinQJSON] = [:]
        for (resource, value) in raw {
            guard case .object(let properties) = value else {
                if case .array(let items) = value {
                    for (index, item) in items.enumerated() {
                        values["\(resource)[\(index)]"] = item
                        guard case .object(let object) = item else { continue }
                        for (property, propertyValue) in object {
                            values["\(resource)[\(index)].\(property)"] = propertyValue
                        }
                    }
                } else {
                    values[resource] = value
                }
                continue
            }
            for (property, propertyValue) in properties {
                values["\(resource).\(property)"] = propertyValue
            }
        }
        return values
    }

    private static func parsePropertyDictionary(_ properties: [String: ThinQJSON], prefix: String?) -> [DeviceCapability] {
        var capabilities: [DeviceCapability] = []
        for (resourceName, resourceValue) in properties.sorted(by: { $0.key < $1.key }) {
            guard resourceName != "location" else { continue }
            if case .object(let resourceObject) = resourceValue {
                capabilities.append(contentsOf: parseResource(resourceName, resourceObject, prefix: prefix))
            }
        }
        return capabilities
    }

    private static func parseResource(_ resourceName: String, _ resourceObject: [String: ThinQJSON], prefix: String?) -> [DeviceCapability] {
        var capabilities: [DeviceCapability] = []
        for (propertyName, propertyValue) in resourceObject.sorted(by: { $0.key < $1.key }) {
            guard case .object(let property) = propertyValue else { continue }
            let mode = property.arrayStrings("mode")
            let type = property.stringValue("type") ?? "unknown"
            let unit = property.stringValue("unit") ?? resourceObject.stringValue("unit")
            let enumValues = property.writableEnumValues()
            let range = property.rangeRule()
            let id = [prefix, resourceName, propertyName].compactMap(\.self).joined(separator: ".")
            capabilities.append(DeviceCapability(
                id: id,
                resource: resourceName,
                property: propertyName,
                displayName: [prefix?.thinkQHumanizedIdentifier, propertyName.thinkQHumanizedIdentifier].compactMap(\.self).joined(separator: " "),
                kind: kind(for: type),
                isReadable: mode.contains("r") || mode.isEmpty,
                isWritable: mode.contains("w"),
                unit: unit,
                enumValues: enumValues,
                range: range
            ))
        }
        return capabilities
    }

    private static func kind(for value: String) -> DeviceCapability.ValueKind {
        switch value.lowercased() {
        case "string": .string
        case "number": .number
        case "boolean", "bool": .bool
        case "enum": .enumeration
        case "range": .range
        case "list": .list
        default: .unknown
        }
    }
}

private extension [String: ThinQJSON] {
    var locationName: String? {
        guard case .object(let location)? = self["location"],
              case .string(let locationName)? = location["locationName"]
        else { return nil }
        return locationName
    }

    func arrayStrings(_ key: String) -> [String] {
        guard case .array(let values)? = self[key] else { return [] }
        return values.compactMap {
            if case .string(let value) = $0 { return value }
            return nil
        }
    }

    func writableEnumValues() -> [String] {
        guard case .object(let value)? = self["value"] else { return [] }
        if case .array(let writable)? = value["w"] {
            return writable.compactMap {
                if case .string(let value) = $0 { return value }
                return nil
            }
        }
        return []
    }

    func rangeRule() -> DeviceCapability.RangeRule? {
        guard case .object(let value)? = self["value"],
              case .object(let writable)? = value["w"],
              case .number(let min)? = writable["min"],
              case .number(let max)? = writable["max"]
        else { return nil }
        let step: Double
        if case .number(let rawStep)? = writable["step"] {
            step = rawStep
        } else {
            step = 1
        }
        return DeviceCapability.RangeRule(min: min, max: max, step: step)
    }
}
