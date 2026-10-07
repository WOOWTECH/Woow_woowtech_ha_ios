@testable import HomeAssistant
@testable import Shared
import Testing

struct AboutViewTests {
    @MainActor
    @Test func testUI() async throws {
        assertLightDarkSnapshots(of: AboutView(), drawHierarchyInKeyWindow: true)
    }

    @Test func acknowledgementsUsesLocalizedNavigationTitle() {
        #expect(AcknowledgementsView.title == L10n.About.Acknowledgements.title)
        #expect(!AcknowledgementsView.title.isEmpty)
    }

    @Test func labsBadgeIsInteractiveOnlyWhenItHasInformation() {
        #expect(!LabsLabel().isInformational)
        #expect(LabsLabel(info: "Details").isInformational)
    }
}
