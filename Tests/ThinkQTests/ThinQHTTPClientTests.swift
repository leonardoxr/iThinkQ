import Foundation
import Testing
@testable import ThinkQ

struct ThinQHTTPClientTests {
    @Test func messageIDIsURLSafeBase64WithoutPadding() {
        let id = ThinQHTTPClient.messageID()
        #expect(!id.contains("="))
        #expect(!id.contains("+"))
        #expect(!id.contains("/"))
        #expect(id.count >= 20)
    }
}
