import Foundation
import Testing
@testable import WaffleCore

struct HandoffEligibilityTests {
    @Test func acceptsHTTPAndHTTPS() {
        #expect(HandoffEligibility.webpageURL(for: "https://example.com/a?b=1") != nil)
        #expect(HandoffEligibility.webpageURL(for: "HTTP://example.com") != nil)
    }

    @Test(arguments: ["", "   ", "about:blank", "file:///tmp/a.html", "javascript:alert(1)", "data:text/html,hi", "ftp://example.com", "https://", "not a url", "example.com"])
    func rejectsEverythingElse(_ address: String) {
        #expect(HandoffEligibility.webpageURL(for: address) == nil)
    }
}
