import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

@Suite(.serialized)
struct NFCTagApprovalTests {
    private let legacyAllowedTagsKey = "allowedTags"

    @Test("Unapproved Home Assistant tags require approval")
    func unapprovedTagsRequireApproval() throws {
        try withAllowedTagDatabase {
            let result = iOSTagManager().handle(userActivity: userActivity(tag: "front-door"))

            guard case let .requiresApproval(tag, type) = result else {
                Issue.record("Expected tag to require approval")
                return
            }

            #expect(tag == "front-door")
            #expect(isGeneric(type))
        }
    }

    @Test("New NFC tags use the branded URL and retain the Android AAR package")
    func newTagsUseBrandedURL() {
        #expect(TagActivityManager.url(for: "front-door")?.absoluteString == "https://aiot.woowtech.io/tag/front-door")
        #expect(TagActivityManager.url(for: "") == nil)
        #expect(TagActivityManager.url(for: "floor/door") == nil)
    }

    @Test("Branded and legacy tag URLs are read with exact secure semantics")
    func readsOnlySupportedTagURLs() throws {
        for url in [
            "https://aiot.woowtech.io/tag/front-door",
            "https://www.home-assistant.io/tag/front-door",
        ] {
            let parsedURL = try #require(URL(string: url))
            #expect(TagActivityManager.identifier(from: parsedURL) == "front-door")
        }

        for url in [
            "http://aiot.woowtech.io/tag/front-door",
            "https://aiot.woowtech.io.evil.example/tag/front-door",
            "https://evil.example/tag/front-door",
            "https://aiot.woowtech.io/other/tag/front-door",
            "https://aiot.woowtech.io/tag/",
            "https://aiot.woowtech.io/tag/front-door/extra",
            "https://aiot.woowtech.io/tag/front-door?url=https://evil.example",
            "https://aiot.woowtech.io/tag/front-door#fragment",
            "https://user@aiot.woowtech.io/tag/front-door",
            "https://aiot.woowtech.io:443/tag/front-door",
            "https://aiot.woowtech.io/tag/%2F",
        ] {
            let parsedURL = try #require(URL(string: url))
            #expect(TagActivityManager.identifier(from: parsedURL) == nil, "Unexpectedly accepted \(url)")
        }
    }

    @Test("Branded redirect and invitation routes require the exact host and path")
    func brandedUniversalLinkRoutes() throws {
        let redirect = try #require(
            URL(string: "https://aiot.woowtech.io/redirect/config_flow_start?domain=mobile_app")
        )
        let legacyRedirect = try #require(
            URL(string: "https://my.home-assistant.io/redirect/config_flow_start?domain=mobile_app")
        )
        #expect(BrandedUniversalLink.route(for: redirect) == .redirect(legacyRedirect))

        let invite = try #require(URL(string: "https://aiot.woowtech.io/invite/#url=https%3A%2F%2Fha.example"))
        let tag = try #require(URL(string: "https://aiot.woowtech.io/tag/front-door"))
        #expect(BrandedUniversalLink.route(for: invite) == .invite(invite))
        #expect(BrandedUniversalLink.route(for: tag) == .tag("front-door"))

        for url in [
            "http://aiot.woowtech.io/redirect/config_flow_start?domain=mobile_app",
            "https://aiot.woowtech.io.evil.example/redirect/config_flow_start?domain=mobile_app",
            "https://aiot.woowtech.io/redirect/",
            "https://aiot.woowtech.io/redirect//config_flow_start",
            "https://aiot.woowtech.io/not-redirect/config_flow_start",
            "https://aiot.woowtech.io/invite#",
            "https://aiot.woowtech.io/invite#other=https://ha.example",
            "https://aiot.woowtech.io/invite#url=javascript%3Aalert(1)",
            "https://aiot.woowtech.io/invite?url=https://evil.example#url=https://ha.example",
            "https://aiot.woowtech.io/invite/extra#url=https://ha.example",
            "https://aiot.woowtech.io/tag/",
        ] {
            let parsedURL = try #require(URL(string: url))
            #expect(BrandedUniversalLink.route(for: parsedURL) == nil, "Unexpectedly accepted \(url)")
        }
    }

    @Test("Allowed Home Assistant tags are handled immediately")
    func allowedTagsAreHandledImmediately() throws {
        try withAllowedTagDatabase {
            let previousServers = Current.servers
            Current.servers = FakeServerManager(initial: 0)
            defer { Current.servers = previousServers }

            AllowedTag.add("front-door")

            let result = iOSTagManager().handle(userActivity: userActivity(tag: "front-door"))

            guard case let .handled(type) = result else {
                Issue.record("Expected allowed tag to be handled")
                return
            }

            #expect(isGeneric(type))
        }
    }

    private func withAllowedTagDatabase(perform work: () throws -> Void) throws {
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")

        Current.settingsStore.prefs.removeObject(forKey: legacyAllowedTagsKey)
        try AllowedTagTable().createIfNeeded(database: database)
        Current.database = { database }

        defer {
            Current.database = previousDatabase
            Current.settingsStore.prefs.removeObject(forKey: legacyAllowedTagsKey)
        }

        try work()
    }

    private func userActivity(tag: String) -> NSUserActivity {
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity.webpageURL = URL(string: "https://www.home-assistant.io/tag/\(tag)")!
        return activity
    }

    private func isGeneric(_ type: TagManagerHandleResult.HandledType) -> Bool {
        if case .generic = type {
            return true
        } else {
            return false
        }
    }
}
