import Foundation
import KeychainAccess
import UIKit
import Version

/// Contains shared constants
public enum AppConstants {
    /// The first phone release keeps Watch targets and source available, but does not embed a Watch app.
    public static let includesWatchAppInPhonePackage = false

    public enum WebURLs {
        public static let homeAssistant = URL(string: "https://aiot.woowtech.io/en")!
        public static let homeAssistantGetStarted = homeAssistantCompanionGetStarted
        public static let homeAssistantCompanionGetStarted =
            URL(string: "https://aiot.woowtech.io/en/blog/help-center-7/woowtech-aiot-app-364")!
        public static let companionAppDocs = homeAssistantCompanionGetStarted
        public static let companionAppDocsTroubleshooting =
            URL(string: "https://aiot.woowtech.io/en/blog/help-center-7/woowtech-aiot-app-365")!
        public static let support =
            URL(string: "https://aiot.woowtech.io/en/blog/help-center-7/woowtech-aiot-app-366")!
        public static let companionAppConnectionSecurityLevel =
            URL(string: "\(companionAppDocsTroubleshooting)#connection-security-level")!
        public static let notificationsDocs =
            URL(string: "https://aiot.woowtech.io/en/blog/help-center-7/woowtech-aiot-app-367")!
        public static let companionLocalPush =
            URL(string: "https://aiot.woowtech.io/en/blog/help-center-7/woowtech-aiot-app-local-pushwebsocket-368")!
        private static let notificationsAdvancedDocs =
            URL(string: "https://aiot.woowtech.io/en/blog/help-center-7/woowtech-aiot-app-live-activities-369")!
        public static let actionableNotificationsDocs =
            URL(string: "\(notificationsAdvancedDocs)#actionable-notifications")!
        public static let notificationSoundsDocs =
            URL(string: "\(notificationsAdvancedDocs)#notifications-sounds")!
        public static let liveActivitiesDocs =
            URL(string: "\(notificationsAdvancedDocs)#live-activities")!
        public static let widgetsDocs =
            URL(
                string: "https://aiot.woowtech.io/en/blog/help-center-7/woowtech-aiot-app-iosandroid-widgets-371#ios-widgets"
            )!
        public static let nfcDocs =
            URL(string: "https://aiot.woowtech.io/en/blog/help-center-7/woowtech-aiot-app-nfcapp-373#nfc")!
        // woowtech has no published Watch article; retain the topic-correct upstream documentation.
        public static let appleWatchDocs = URL(string: "https://companion.home-assistant.io/docs/apple-watch/")!
        public static var appleDropSupportiOS15 =
            URL(string: "https://aiot.woowtech.io")!
    }

    public enum QueryItems: String, CaseIterable {
        case openMoreInfoDialog = "more-info-entity-id"
        case isComingFromAppIntent = "isComingFromAppIntent"
    }

    public enum WebRTC {
        public static let iceServers = [
            "stun:stun.home-assistant.io:80",
            "stun:stun.home-assistant.io:3478",
        ]
    }

    public enum Firebase {
        public static let pushURLString = "https://aiot.woowtech.io/api/sendPushNotification"
    }

    /// Home Assistant Blue
    public static var tintColor: UIColor {
        #if os(iOS)
        return UIColor { [lighterTintColor, darkerTintColor] (traitCollection: UITraitCollection) -> UIColor in
            traitCollection.userInterfaceStyle == .dark ? lighterTintColor : darkerTintColor
        }
        #else
        return lighterTintColor
        #endif
    }

    public static var lighterTintColor: UIColor {
        UIColor(hue: 199.0 / 360.0, saturation: 0.99, brightness: 0.96, alpha: 1.0)
    }

    public static var darkerTintColor: UIColor {
        UIColor(hue: 199.0 / 360.0, saturation: 0.99, brightness: 0.67, alpha: 1.0)
    }

    /// Help icon UIBarButtonItem
    #if os(iOS)
    public static var helpBarButtonItem: UIBarButtonItem {
        with(UIBarButtonItem(
            icon: .helpCircleOutlineIcon,
            target: nil,
            action: nil
        )) {
            $0.accessibilityLabel = L10n.helpLabel
        }
    }
    #endif

    /// The Bundle ID used for the AppGroupID
    public static var BundleID: String {
        let baseBundleID = Bundle.main.bundleIdentifier!
        var removeBundleSuffix = baseBundleID.replacingOccurrences(of: ".APNSAttachmentService", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".Intents", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".NotificationContentExtension", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".TodayWidget", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".watchkitapp.watchkitextension", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".watchkitapp", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".Widgets", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".ShareExtension", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".PushProvider", with: "")

        return removeBundleSuffix
    }

    public static let urlScheme = "woowtech"
    public static let deeplinkURL = URL(string: "\(urlScheme)://")!

    public enum OAuth {
        // Public client metadata advertises redirectURI; validate HA login end-to-end before release.
        public static let clientID = "https://aiot.woowtech.io/ios"
        public static let redirectURI = "\(urlScheme)://auth-callback"
    }

    /// Roots a scheme-less, slash-less navigation path (`map/0` → `/map/0`) so an HA path that is
    /// missing its leading slash still resolves in the frontend. Anything already rooted, or that
    /// carries a scheme — `https://`, `mailto:`, or the app's own `woowtech://` deep links —
    /// is returned unchanged, so external URLs open in the browser and deep links are handled by
    /// the URL handler as deep links rather than being coerced into a path.
    public static func normalizedNavigationDestination(_ raw: String) -> String {
        guard !raw.hasPrefix("/"), URL(string: raw)?.scheme == nil else { return raw }
        return "/" + raw
    }

    public static func invitationURL(serverURL: URL) -> URL? {
        guard let encodedURLString = serverURL.absoluteString
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "https://my.home-assistant.io/invite/#url=\(encodedURLString)")
    }

    public static func navigateDeeplinkURL(
        path: String,
        serverId: String,
        queryParams: String? = nil,
        avoidUnnecessaryReload: Bool
    ) -> URL? {
        var url = URL(
            string: "\(AppConstants.deeplinkURL.absoluteString)navigate/\(path)?server=\(serverId)&avoidUnnecessaryReload=\(avoidUnnecessaryReload)&\(AppConstants.QueryItems.isComingFromAppIntent.rawValue)=true"
        )

        if let queryParams, let newURL = URL(string: "\(url?.absoluteString ?? "")&\(queryParams)") {
            url = newURL
        }

        return url
    }

    public static func openPageDeeplinkURL(path: String, serverId: String) -> URL? {
        AppConstants.navigateDeeplinkURL(path: path, serverId: serverId, avoidUnnecessaryReload: true)?
            .withWidgetAuthenticity()
    }

    public static func openEntityDeeplinkURL(entityId: String, serverId: String) -> URL? {
        AppConstants.navigateDeeplinkURL(
            path: "",
            serverId: serverId,
            queryParams: "\(AppConstants.QueryItems.openMoreInfoDialog.rawValue)=\(entityId)",
            avoidUnnecessaryReload: true
        )?.withWidgetAuthenticity()
    }

    public static func openCameraDeeplinkURL(entityId: String, serverId: String) -> URL? {
        URL(
            string: "\(AppConstants.deeplinkURL.absoluteString)camera/?entityId=\(entityId)&serverId=\(serverId)&\(AppConstants.QueryItems.isComingFromAppIntent.rawValue)=true"
        )
    }

    @available(iOS 16.0, watchOS 9.0, *)
    public static func todoListAddItemURL(listId: String, serverId: String) -> URL? {
        guard !serverId.isEmpty, !listId.isEmpty else {
            return nil
        }
        return URL(string: "\(AppConstants.deeplinkURL.absoluteString)navigate/todo")?.appending(queryItems: [
            URLQueryItem(name: "entity_id", value: listId),
            URLQueryItem(name: "serverId", value: serverId),
            URLQueryItem(name: "add_item", value: "true"),
        ])
    }

    @available(iOS 16.0, watchOS 9.0, *)
    public static func todoListOpenURL(listId: String, serverId: String) -> URL? {
        guard !serverId.isEmpty, !listId.isEmpty else {
            return nil
        }
        return URL(string: "\(AppConstants.deeplinkURL.absoluteString)navigate/todo")?.appending(queryItems: [
            URLQueryItem(name: "entity_id", value: listId),
            URLQueryItem(name: "serverId", value: serverId),
        ])
    }

    public static func assistDeeplinkURL(serverId: String, pipelineId: String, startListening: Bool) -> URL? {
        URL(
            string: "\(AppConstants.deeplinkURL.absoluteString)assist?serverId=\(serverId)&pipelineId=\(pipelineId)&startListening=\(startListening)"
        )?.withWidgetAuthenticity()
    }

    public static var createCustomWidgetURL: URL {
        URL(string: "\(AppConstants.deeplinkURL.absoluteString)createCustomWidget")!
    }

    /// The App Group ID used by the app and extensions for sharing data.
    public static var AppGroupID: String {
        "group." + BundleID.lowercased()
    }

    public static var AppGroupContainer: URL {
        let fileManager = FileManager.default

        let groupDir = fileManager.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.AppGroupID)

        guard let groupDir else {
            // This path also initializes the logger. Accessing Current here would
            // recursively initialize AppEnvironment; the local logger warns after setup.
            return URL(fileURLWithPath: NSTemporaryDirectory())
        }

        return groupDir
    }

    public static var appGRDBFile: URL {
        let fileManager = FileManager.default
        let directoryURL = Self.AppGroupContainer.appendingPathComponent("databases", isDirectory: true)
        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                Current.Log.error("Failed to create App GRDB file")
            }
        }
        let databaseURL = directoryURL.appendingPathComponent("App.sqlite")
        return databaseURL
    }

    public static var clientEventsFile: URL {
        let fileManager = FileManager.default
        let directoryURL = Self.AppGroupContainer.appendingPathComponent("databases", isDirectory: true)
        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                Current.Log.error("Failed to create Client Events file")
            }
        }
        let eventsURL = directoryURL.appendingPathComponent("clientEvents.json")
        return eventsURL
    }

    public static var notificationHistoryFile: URL {
        let fileManager = FileManager.default
        let directoryURL = Self.AppGroupContainer.appendingPathComponent("databases", isDirectory: true)
        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                Current.Log.error("Failed to create Notification History file")
            }
        }
        let historyURL = directoryURL.appendingPathComponent("notificationHistory.json")
        return historyURL
    }

    public static var widgetsCacheURL: URL = {
        let fileManager = FileManager.default
        let directoryURL = Self.AppGroupContainer.appendingPathComponent("caches/widgets", isDirectory: true)
        return directoryURL
    }()

    public static func widgetCachedStates(widgetId: String) -> URL {
        let fileManager = FileManager.default
        let directoryURL = Self.widgetsCacheURL
        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                Current.Log.error("Failed to create Client Events file")
            }
        }
        let eventsURL = directoryURL.appendingPathComponent("/widgetId-\(widgetId).json")
        return eventsURL
    }

    public static var watchMagicItemsInfo: URL {
        let fileManager = FileManager.default
        let directoryURL = Self.AppGroupContainer.appendingPathComponent("caches", isDirectory: true)
        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                Current.Log.error("Failed to magic items info file")
            }
        }
        let eventsURL = directoryURL.appendingPathComponent("magicItemsInfo.json")
        return eventsURL
    }

    public static var LogsDirectory: URL {
        let fileManager = FileManager.default
        let directoryURL = AppGroupContainer.appendingPathComponent("logs", isDirectory: true)

        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("Error while attempting to create data store URL: \(error)")
            }
        }

        return directoryURL
    }

    public static var DownloadsDirectory: URL {
        var directoryURL: URL = FileManager.default.urls(for: .cachesDirectory, in: .allDomainsMask).first!

        // Save directly in macOS Downloads folder if running on Catalyst and allowed access to download folder when
        // prompted.
        if Current.isCatalyst, let macDownloadFolder = FileManager.default.urls(
            for: .downloadsDirectory,
            in: .userDomainMask
        ).first {
            directoryURL = macDownloadFolder
        } else {
            directoryURL = directoryURL.appendingPathComponent(
                "Downloads",
                isDirectory: true
            )
        }
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            do {
                try FileManager.default.createDirectory(
                    at: directoryURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                fatalError("Error while attempting to create downloads path URL: \(error)")
            }
        }

        return directoryURL
    }

    /// An initialized Keychain from KeychainAccess.
    public static var Keychain: KeychainAccess.Keychain {
        KeychainAccess.Keychain(service: BundleID)
    }

    /// A permanent ID stored in UserDefaults and Keychain.
    public static var PermanentID: String {
        let storageKey = "deviceUID"
        let defaultsStore = UserDefaults(suiteName: AppConstants.AppGroupID)
        let keychain = KeychainAccess.Keychain(service: storageKey)

        if let keychainUID = keychain[storageKey] {
            return keychainUID
        }

        if let userDefaultsUID = defaultsStore?.object(forKey: storageKey) as? String {
            return userDefaultsUID
        }

        let newID = UUID().uuidString

        if keychain[storageKey] == nil {
            keychain[storageKey] = newID
        }

        if defaultsStore?.object(forKey: storageKey) == nil {
            defaultsStore?.setValue(newID, forKey: storageKey)
        }

        return newID
    }

    public static var build: String {
        SharedPlistFiles.Info.cfBundleVersion
    }

    public static var version: String {
        SharedPlistFiles.Info.cfBundleShortVersionString
    }

    static var clientVersion: Version {
        // swiftlint:disable:next force_try
        var clientVersion = try! Version(version)
        clientVersion.build = build
        return clientVersion
    }
}

public extension Version {
    static let canSendDeviceID: Version = .init(minor: 104)
    static let pedometerIconsAvailable: Version = .init(minor: 105)
    static let tagWebhookAvailable: Version = .init(minor: 114, prerelease: "b5")
    static let mobileAppConfig: Version = .init(minor: 115, prerelease: "any0")
    static let localPushConfirm: Version = .init(major: 2021, minor: 10, prerelease: "any0")
    static let externalBusCommandRestart: Version = .init(major: 2021, minor: 12, prerelease: "b6")
    static let updateLocationGPSOptional: Version = .init(major: 2022, minor: 2, prerelease: "any0")
    static let fullWebhookSecretKey: Version = .init(major: 2022, minor: 3)
    static let conversationWebhook: Version = .init(major: 2023, minor: 2, prerelease: "any0")
    static let externalBusCommandSidebar: Version = .init(major: 2023, minor: 4, prerelease: "b3")
    static let externalBusCommandAutomationEditor: Version = .init(major: 2024, minor: 2, prerelease: "any0")
    static let canUseAppThemeForStatusBar: Version = .init(major: 2024, minor: 7)
    /// The version where the app can subscribe to entities changes with a filter (e.g. only state changes from sensor
    /// domain)
    static let canSubscribeEntitiesChangesWithFilter: Version = .init(major: 2024, minor: 10)
    /// Allows app to ask frontend to navigate to a specific page
    static let canNavigateThroughFrontend: Version = .init(major: 2025, minor: 6, prerelease: "any0")
    /// Allows app to ask frontend to navigate to a more info dialog
    static let canNavigateMoreInfoDialogThroughFrontend: Version = .init(major: 2026, minor: 1, prerelease: "any0")
    /// Frontend introduces the quickbar with Ctrl+K keyboard shortcut in 2026.2
    static let quickSearchKeyboardShortcut: Version = .init(major: 2026, minor: 2, prerelease: "any0")
    /// Core accepts `in_zones` in update_location payloads from 2026.6.0.
    static let inZonesOnLocationUpdate: Version = .init(major: 2026, minor: 6, patch: 0, prerelease: "any0")

    var coreRequiredString: String {
        L10n.requiresVersion(String(format: "core-%d.%d", major, minor ?? -1))
    }
}
