@testable import HomeAssistant
import Testing

struct WKUserContentControllerMessageTests {
    @Test func testWKUserContentControllerMessageCases() async throws {
        // Assert the total count of cases
        #expect(WKUserContentControllerMessage.allCases.count == 5)

        // Assert each case's rawValue
        #expect(WKUserContentControllerMessage.externalBus.rawValue == "externalBus")
        #expect(WKUserContentControllerMessage.updateThemeColors.rawValue == "updateThemeColors")
        #expect(WKUserContentControllerMessage.getExternalAuth.rawValue == "getExternalAuth")
        #expect(WKUserContentControllerMessage.revokeExternalAuth.rawValue == "revokeExternalAuth")
        #expect(WKUserContentControllerMessage.logError.rawValue == "logError")
    }
}
