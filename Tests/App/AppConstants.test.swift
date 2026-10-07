import Foundation
import Shared
import Testing

struct AppConstantsTests {
    @Test func testInvitationURL() async throws {
        let serverURL = URL(string: "https://demo.home-assistant.io")!
        let expected = "https://my.home-assistant.io/invite/#url=https://demo.home-assistant.io"
        let result = AppConstants.invitationURL(serverURL: serverURL)?.absoluteString
        assert(result == expected, "Expected \(expected), got \(String(describing: result))")
    }

    @Test func testWebURLs() async throws {
        let base = "https://aiot.woowtech.io/en/blog/help-center-7/woowtech-aiot-app-"
        #expect(AppConstants.WebURLs.homeAssistant.absoluteString == "https://aiot.woowtech.io/en")
        #expect(AppConstants.WebURLs.homeAssistantGetStarted.absoluteString == base + "364")
        #expect(AppConstants.WebURLs.homeAssistantCompanionGetStarted.absoluteString == base + "364")
        #expect(AppConstants.WebURLs.companionAppDocs.absoluteString == base + "364")
        #expect(AppConstants.WebURLs.companionAppDocsTroubleshooting.absoluteString == base + "365")
        #expect(
            AppConstants.WebURLs.companionAppConnectionSecurityLevel
                .absoluteString == base + "365#connection-security-level"
        )
        #expect(AppConstants.WebURLs.support.absoluteString == base + "366")
        #expect(AppConstants.WebURLs.notificationsDocs.absoluteString == base + "367")
        #expect(AppConstants.WebURLs.companionLocalPush.absoluteString == base + "local-pushwebsocket-368")
        #expect(AppConstants.WebURLs.actionableNotificationsDocs.fragment == "actionable-notifications")
        #expect(AppConstants.WebURLs.notificationSoundsDocs.fragment == "notifications-sounds")
        #expect(AppConstants.WebURLs.liveActivitiesDocs.absoluteString == base + "live-activities-369#live-activities")
        #expect(AppConstants.WebURLs.widgetsDocs.absoluteString == base + "iosandroid-widgets-371#ios-widgets")
        #expect(ExternalLink.customWidgetsDocumentation == AppConstants.WebURLs.widgetsDocs)
        #expect(AppConstants.WebURLs.nfcDocs.absoluteString == base + "nfcapp-373#nfc")
        #expect(
            AppConstants.WebURLs.appleWatchDocs.absoluteString ==
                "https://companion.home-assistant.io/docs/apple-watch/"
        )
    }

    @Test func testBrandAuthenticationIdentity() {
        #expect(AppConstants.urlScheme == "woowtech")
        #expect(AppConstants.deeplinkURL.absoluteString == "woowtech://")
        #expect(AppConstants.OAuth.redirectURI == "woowtech://auth-callback")
        #expect(AppConstants.OAuth.clientID == "https://aiot.woowtech.io/ios")
    }

    @Test func testQueryItemsRawValues() async throws {
        assert(AppConstants.QueryItems.openMoreInfoDialog.rawValue == "more-info-entity-id")
        assert(AppConstants.QueryItems.isComingFromAppIntent.rawValue == "isComingFromAppIntent")
    }

    @Test func testOpenEntityDeeplinkURL() async throws {
        let entityId = "light.living_room"
        let serverId = "server123"
        let result = AppConstants.openEntityDeeplinkURL(entityId: entityId, serverId: serverId)?.absoluteString

        // Verify the URL contains empty path (navigate/?) and correct query params
        assert(result?.contains("navigate/?") == true, "URL should contain navigate/? with empty path")
        assert(
            result?.contains("more-info-entity-id=\(entityId)") == true,
            "URL should contain more-info-entity-id query parameter"
        )
        assert(result?.contains("server=\(serverId)") == true, "URL should contain server query parameter")
        assert(
            result?.contains("avoidUnnecessaryReload=true") == true,
            "URL should contain avoidUnnecessaryReload=true"
        )
        assert(
            result?.contains("isComingFromAppIntent=true") == true,
            "URL should contain isComingFromAppIntent=true"
        )
    }

    @available(iOS 16.0, *)
    @Test func testTodoListAddItemURL() async throws {
        let listId = "todo.shopping_list"
        let serverId = "server123"
        let url = AppConstants.todoListAddItemURL(listId: listId, serverId: serverId)
        assert(url != nil, "Expected URL to be created for valid listId and serverId")

        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        assert(components?.scheme == AppConstants.deeplinkURL.scheme, "URL should use the app deeplink scheme")
        assert(components?.host == "navigate", "URL host should be navigate")
        assert(components?.path == "/todo", "URL path should be /todo")

        let queryItems = components?.queryItems ?? []
        let queryValues = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value) })
        assert(queryValues["entity_id"] == listId, "URL should include entity_id query item")
        assert(queryValues["serverId"] == serverId, "URL should include serverId query item")
        assert(queryValues["add_item"] == "true", "URL should include add_item query item set to true as String")
    }

    @available(iOS 16.0, *)
    @Test func testTodoListOpenURL() async throws {
        let listId = "todo.shopping_list"
        let serverId = "server123"
        let url = AppConstants.todoListOpenURL(listId: listId, serverId: serverId)
        assert(url != nil, "Expected URL to be created for valid listId and serverId")

        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        assert(components?.scheme == AppConstants.deeplinkURL.scheme, "URL should use the app deeplink scheme")
        assert(components?.host == "navigate", "URL host should be navigate")
        assert(components?.path == "/todo", "URL path should be /todo")

        let queryItems = components?.queryItems ?? []
        let queryValues = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value) })
        assert(queryValues["entity_id"] == listId, "URL should include entity_id query item")
        assert(queryValues["serverId"] == serverId, "URL should include serverId query item")
        assert(queryValues["add_item"] == nil, "URL should not include add_item in query item")
    }

    @available(iOS 16.0, *)
    @Test func testFirebaseURL() async throws {
        assert(
            AppConstants.Firebase.pushURLString == "https://aiot.woowtech.io/api/sendPushNotification",
            "Firebase push URL should match expected value"
        )
    }

    @Test func testNormalizedNavigationDestination() async throws {
        func normalized(_ raw: String) -> String { AppConstants.normalizedNavigationDestination(raw) }

        // Rooted HA path — unchanged.
        assert(normalized("/map/0") == "/map/0")
        // Slash-less HA path — rooted so it still navigates the frontend.
        assert(normalized("map/0") == "/map/0")
        // Deep links are left untouched — the URL handler processes them as deep links.
        assert(normalized("woowtech://navigate/map/0") == "woowtech://navigate/map/0")
        assert(normalized("woowtech://navigate/map/0") == "woowtech://navigate/map/0")
        // External URLs — untouched so they open in the browser.
        assert(normalized("https://google.com") == "https://google.com")
        assert(normalized("https://www.google.com") == "https://www.google.com")
        // Other schemes — untouched.
        assert(normalized("mailto:a@b.com") == "mailto:a@b.com")
    }
}
