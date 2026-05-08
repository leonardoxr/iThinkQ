import Foundation
import Testing
@testable import ThinkQ

enum FixtureLoader {
    static func jsonObject(_ name: String) throws -> [String: ThinQJSON] {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
        let data = try Data(contentsOf: url)
        guard case .object(let object) = try JSONDecoder().decode(ThinQJSON.self, from: data) else {
            Issue.record("Fixture \(name).json is not a JSON object")
            return [:]
        }
        return object
    }
}
