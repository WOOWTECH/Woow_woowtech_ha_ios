#!/usr/bin/env python3
"""Offline identity/destination contract checks; not a signed-build or device test.

Run from any directory: python3 Tools/brand/test_woowtech_aiot.py
Never opens signing overrides, service credentials, or a Home Assistant server.
"""
import json
import plistlib
import re
import subprocess
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = "$(BUNDLE_ID_PREFIX).$(BRAND_BUNDLE_BASE)$(BUNDLE_ID_SUFFIX)"
SEMANTIC_EXPECTATIONS = ROOT / "Tools/brand/woowtech_aiot_semantic_expectations.json"
PRIVACY_KEYS = {
    "NSCameraUsageDescription", "NSLocalNetworkUsageDescription", "NSLocationUsageDescription",
    "NSLocationWhenInUseUsageDescription", "NSMicrophoneUsageDescription",
}
INTENTS_KEYS = {
    "2KWKqM", "5ZzwZD", "FBQiVD", "KHH48D", "NdG9Jz", "RMQY3r", "T06Fka", "ZRPVYO", "cuflz3",
    "foI0Fv", "fuRWMi", "glRCfJ", "mAibJP", "mJ6CrP", "mZnRHS", "pQhTjo", "vAIAF2", "wfPQQQ",
}
CORE_KEYS = {"component::improv_ble::config::abort::already_configured"}


def read(name):
    return (ROOT / name).read_text()


class WoowtechAiotContractTests(unittest.TestCase):
    def test_notification_rate_limits_use_woowtech_relay(self):
        text = read("Sources/App/Settings/Notifications/NotificationRateLimitsAPI.swift")
        endpoint = re.search(r'URLRequest\(url: URL\(\s*string: "([^"]+)"', text)
        self.assertIsNotNone(endpoint)
        self.assertEqual(endpoint.group(1), "https://aiot.woowtech.io/api/checkRateLimits")
        self.assertNotIn("mobile-apps.home-assistant.io", text)
        self.assertIn('urlRequest.httpMethod = "POST"', text)
        self.assertIn('urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")', text)
        self.assertIn('"push_token": pushID', text)

    def test_catalyst_associated_domains_are_not_duplicated(self):
        for path in sorted((ROOT / "Configuration/Entitlements").rglob("App-catalyst.entitlements")):
            with self.subTest(path=str(path.relative_to(ROOT))):
                domains = plistlib.loads(path.read_bytes()).get("com.apple.developer.associated-domains", [])
                self.assertEqual(len(domains), len(set(domains)))
                if domains:
                    self.assertEqual(domains, ["applinks:aiot.woowtech.io"])

    def test_nfc_uses_branded_writes_and_compatible_exact_reads(self):
        text = read("Sources/App/Settings/NFC/iOSTagManager.swift")
        self.assertIn('androidPackage(payload: "com.woowtech.aiot")', text)
        self.assertNotIn('androidPackage(payload: "io.homeassistant.companion.android")', text)
        self.assertIn('components.host = "aiot.woowtech.io"', text)
        self.assertIn('["aiot.woowtech.io", "www.home-assistant.io"]', text)
        self.assertIn('components.path = "/tag/" + identifier', text)
        self.assertIn('requiredPayload: [uriPayload], optionalPayload: [aarPayload]', text)
        self.assertIn('components.scheme?.lowercased() == "https"', text)
        self.assertIn('components.query == nil', text)

    def test_regression_and_owner_decision_source_contracts(self):
        labs = read("Sources/Shared/DesignSystem/Components/LabsLabel.swift")
        self.assertIn("if isInformational", labs)
        self.assertIn("Do not install a gesture recognizer", labs)

        about = read("Sources/App/Settings/AboutView.swift")
        self.assertIn("AcknowledgementsView().navigationTitle(AcknowledgementsView.title)", about)

        zh_hant = json.loads(subprocess.check_output([
            "plutil", "-convert", "json", "-o", "-",
            str(ROOT / "Sources/App/Resources/zh-Hant.lproj/Localizable.strings")
        ]))
        self.assertEqual(
            zh_hant["settings_sensors.periodic_update.description"],
            "開啟後，這些感測器會在 App 於前景開啟時依此頻率更新。"
        )
        self.assertEqual(
            zh_hant["settings_sensors.periodic_update.description_mac"],
            "開啟後，這些感測器會在 App 開啟時依此頻率更新，部分感測器會自動更頻繁地更新。"
        )
        self.assertEqual(
            zh_hant["settings_details.widgets.reload_all.description"],
            "這會重新載入所有小工具時間線。如果小工具因某些原因卡在空白狀態或未更新，請使用此功能。"
        )

        incoming = read("Sources/App/Frontend/IncomingURLHandler.swift")
        self.assertIn('components.host?.lowercased() == "aiot.woowtech.io"', incoming)
        self.assertIn('legacy.host = "my.home-assistant.io"', incoming)
        self.assertIn('components.scheme?.lowercased() == "https"', incoming)
        for relative_path in (
            "Configuration/Entitlements/App-ios.entitlements",
            "Configuration/Entitlements/dev/App-ios.entitlements",
            "Configuration/Entitlements/release/App-ios.entitlements",
        ):
            entitlements = plistlib.loads((ROOT / relative_path).read_bytes())
            self.assertEqual(
                entitlements["com.apple.developer.associated-domains"],
                ["applinks:aiot.woowtech.io"],
                relative_path,
            )

        settings = read("Sources/Shared/Settings/SettingsStore.swift")
        self.assertIn("migrateGeocodedLocationDefault(existingInstallation: Bool)", settings)
        self.assertIn("disabledSensorIDs.insert(WebhookSensorId.geocodedLocation.rawValue)", settings)
        self.assertIn("if !existingInstallation", settings)

        crash = read("Sources/Shared/Environment/CrashReporter.swift")
        self.assertNotIn("import FirebaseCrashlytics", crash)
        self.assertIn("// no current crash reporter", crash)
        self.assertIn("// no current analytics logger", crash)

    def test_traditional_chinese_support_label(self):
        path = ROOT / "Sources/App/Resources/zh-Hant.lproj/Localizable.strings"
        strings = json.loads(subprocess.check_output([
            "plutil", "-convert", "json", "-o", "-", str(path)
        ]))
        self.assertEqual(strings.get("support.contact"), "聯絡支援")
        self.assertEqual(strings.get("nfc.detail.tag_value"), "標籤識別")
        self.assertIn("將會於靠近裝置時", strings["nfc.list.description"])
        self.assertNotIn("將會於於", strings["nfc.list.description"])
        self.assertIn('"support.contact" = "Contact support";',
                      read("Sources/App/Resources/en.lproj/Localizable.strings"))
        self.assertIn('Link(L10n.Support.contact, destination: AppConstants.WebURLs.support)',
                      read("Sources/App/Settings/AboutView.swift"))

    def test_all_rendered_phone_widget_brand_logos_are_circular(self):
        expected = {
            "Sources/App/Onboarding/Steps/Welcome/OnboardingWelcomeView.swift",
            "Sources/App/Onboarding/Steps/Welcome/InvitationView.swift",
            "Sources/App/Onboarding/Views/SearchingServersAnimationView.swift",
            "Sources/App/Frontend/WebView/Views/ConnectionErrorDetailsView.swift",
            "Sources/App/Frontend/WebView/Views/WebViewEmptyStateView.swift",
            "Sources/App/Settings/AboutView.swift",
            "Sources/Extensions/Widgets/Lockscreen/Gauge/GaugeArcView.swift",
            "Sources/Extensions/Widgets/TodoList/WidgetTodoListView.swift",
            "Sources/Extensions/Widgets/Common/WidgetCircularView.swift",
        }
        found = set()
        for folder in [ROOT / "Sources/App", ROOT / "Sources/Extensions/Widgets"]:
            for path in folder.rglob("*.swift"):
                text = path.read_text()
                for line in text.splitlines():
                    if "Image(.logo)" in line or ("Image(" in line and "Asset.logo.image" in line):
                        rel = str(path.relative_to(ROOT))
                        found.add(rel)
                        chain = text.split(line, 1)[1]
                        # Only this Image's modifier chain, not another icon or enclosing container.
                        modifier_lines = []
                        for next_line in chain.splitlines()[1:]:
                            if next_line.lstrip().startswith(("Text(", "Image(", "}", "),")):
                                break
                            modifier_lines.append(next_line)
                        self.assertIn(".clipShape(Circle())", "\n".join(modifier_lines), rel)
        self.assertEqual(found, expected, "New brand-logo consumers require review")

    def test_connection_error_brand_copy(self):
        keys = ["camera_player.errors.unable_to_connect_to_server",
                "connection.error.failed_connect.title", "web_view.no_url_available.title",
                "widgets.custom.server_unreachable.title"]
        for locale in ["en", "zh-Hant"]:
            path = ROOT / f"Sources/App/Resources/{locale}.lproj/Localizable.strings"
            strings = json.loads(subprocess.check_output(
                ["plutil", "-convert", "json", "-o", "-", str(path)]))
            for key in keys:
                self.assertIn("woowtech aiot", strings[key], (locale, key))
                self.assertNotIn("woowtech Home", strings[key])
                self.assertNotIn("Home Assistant", strings[key])

    def test_audited_product_display_localizations_use_current_brand(self):
        audited = {
            "ja": ("onboarding.welcome.header", "web_view.no_url_available.title"),
            "et": ("connection.error.failed_connect.title",),
            "ml": ("onboarding.welcome.title",),
            "cs": ("widgets.custom.server_unreachable.title",),
            "tr": ("onboarding.manual_url_entry.title", "onboarding.welcome.header",
                   "onboarding.welcome.primary_button", "onboarding.welcome.updated.body"),
            "id": ("onboarding.network_input.primary_description",),
        }
        english_path = ROOT / "Sources/App/Resources/en.lproj/Localizable.strings"
        english = json.loads(subprocess.check_output(
            ["plutil", "-convert", "json", "-o", "-", str(english_path)]))
        self.assertEqual(sum(len(keys) for keys in audited.values()), 10)
        for locale, keys in audited.items():
            path = ROOT / f"Sources/App/Resources/{locale}.lproj/Localizable.strings"
            strings = json.loads(subprocess.check_output(
                ["plutil", "-convert", "json", "-o", "-", str(path)]))
            for key in keys:
                with self.subTest(locale=locale, key=key):
                    self.assertIn("woowtech aiot", strings[key])
                    self.assertEqual(re.findall(r"%(?:\d+\$)?[@a-zA-Z]", strings[key]),
                                     re.findall(r"%(?:\d+\$)?[@a-zA-Z]", english[key]))

    def test_welcome_body_never_claims_woowtech_aiot_is_open_source(self):
        # Upstream says Home Assistant is open source; the rebrand turned that into a claim about our
        # product in 32 locales. Locales we cannot proofread drop the key and fall back to en.
        claim = re.compile(r"open.?source|開源|开源|オープンソース|açık kaynak|ανοι[κχ]τού κώδικα", re.I)
        for path in sorted((ROOT / "Sources/App/Resources").glob("*.lproj/Localizable.strings")):
            strings = json.loads(subprocess.check_output(["plutil", "-convert", "json", "-o", "-", str(path)]))
            body = strings.get("onboarding.welcome.updated.body")
            if body is None:
                continue
            with self.subTest(locale=path.parent.name):
                self.assertIn("woowtech aiot", body)
                self.assertIsNone(claim.search(body), body)

    def test_owner_approved_manual_url_copy(self):
        for locale, title in (
                ("zh-Hant", "woowtech aiot 網址是什麼"),
                ("en", "What is your woowtech aiot address?")):
            with self.subTest(locale=locale):
                path = ROOT / f"Sources/App/Resources/{locale}.lproj/Localizable.strings"
                strings = json.loads(subprocess.check_output(
                    ["plutil", "-convert", "json", "-o", "-", str(path)]))
                self.assertEqual(strings["onboarding.manual_url_entry.title"], title)
                self.assertEqual(strings["onboarding.manual_setup.text_field.placeholder"],
                                 "http://<your woowtech aiot ip>:8123")

    def test_search_loader_matches_welcome_circle(self):
        view = read("Sources/App/Onboarding/Views/SearchingServersAnimationView.swift")
        logo = view.split("private var logo: some View {", 1)[1].split("private var dots:", 1)[0]
        self.assertIn("Image(.logo)", logo)
        self.assertIn(".clipShape(Circle())", logo)
        self.assertLess(logo.index(".frame("), logo.index(".clipShape(Circle())"))
        self.assertLess(logo.index(".clipShape(Circle())"), logo.index(".scaleEffect("))
        self.assertIn("static let logoSize: CGFloat = 80", view)
        self.assertIn("Image(.searchingServersDots)", view)

    def test_english_welcome_matches_owner_brand_copy(self):
        path = ROOT / "Sources/App/Resources/en.lproj/Localizable.strings"
        strings = json.loads(subprocess.check_output(
            ["plutil", "-convert", "json", "-o", "-", str(path)]))
        self.assertEqual(strings["onboarding.welcome.header"], "woowtech aiot app")
        self.assertEqual(strings["onboarding.welcome.primary_button"], "Connect to my woowtech aiot")
        self.assertEqual(strings["onboarding.welcome.updated.body"],
                         "Access your woowtech aiot server on the go.\n\n"
                         "woowtech aiot advocates for privacy and information security "
                         "and runs locally in your home.")

    def test_welcome_logo_uses_circular_clipping(self):
        view = read("Sources/App/Onboarding/Steps/Welcome/OnboardingWelcomeView.swift")
        logo = view.split("Image(.logo)", 1)[1].split("Text(verbatim:", 1)[0]
        self.assertIn(".clipShape(Circle())", logo)
        self.assertLess(logo.index(".frame("), logo.index(".clipShape(Circle())"))
        self.assertIn("static let logoWidth: CGFloat = 120", view)
        self.assertIn("static let logoHeight: CGFloat = 120", view)

    def test_owner_approved_traditional_chinese_welcome_copy(self):
        path = ROOT / "Sources/App/Resources/zh-Hant.lproj/Localizable.strings"
        strings = json.loads(subprocess.check_output(
            ["plutil", "-convert", "json", "-o", "-", str(path)]))
        self.assertEqual(strings["onboarding.welcome.header"], "woowtech aiot app")
        self.assertEqual(strings["onboarding.welcome.primary_button"], "連線至我的 woowtech aiot")
        self.assertEqual(strings["onboarding.welcome.updated.body"],
                         "隨時隨地存取您的 woowtech aiot 伺服器。\n\n"
                         "woowtech aiot 倡導隱私資安保護並於您的家中進行本地端運行。")

    def test_brand_and_bundle_configuration(self):
        brand = read("Configuration/Brand.xcconfig")
        for setting in ("BRAND_APP_NAME = woowtech aiot", "BRAND_URL_SCHEME = woowtech",
                        "BRAND_BUNDLE_BASE = aiot"):
            self.assertIn(setting, brand)
        config = read("Configuration/HomeAssistant.xcconfig")
        self.assertIn("BUNDLE_ID_PREFIX = com.woowtech", config)
        self.assertIn("${BUNDLE_ID_PREFIX}.$(BRAND_BUNDLE_BASE)${BUNDLE_ID_SUFFIX}${PROVISIONING_SUFFIX}", config)
        self.assertIn('APP_NAME="woowtech aiot"', read("Tools/brand/woowtech-ios.conf"))
        self.assertIn('BUNDLE_ID_BASE="aiot"', read("Tools/brand/woowtech-ios.conf"))

    def test_project_targets_and_scheme(self):
        project = read("HomeAssistant.xcodeproj/project.pbxproj")
        self.assertEqual(project.count('ENV_URL_HANDLER = "$(BRAND_URL_SCHEME)";'), 2)
        self.assertNotIn("woowtech Home", project)
        self.assertNotIn("woowhome", project)
        suffixes = set(re.findall(r"PROVISIONING_SUFFIX = ([.\w]+);", project))
        self.assertEqual(suffixes, {
            ".ShareExtension", ".MacBridge", ".Widgets", ".PushProvider",
            ".Launcher", ".SharedTesting", ".NotificationContentExtension", ".HomeAssistantTests",
            ".HomeAssistantUITests", ".Intents", ".Shared", ".APNSAttachmentService",
            ".watchkitapp", ".watchkitapp.watchkitextension", ".SharedTests",
        })
        self.assertIn('PRODUCT_NAME = "$(BRAND_APP_NAME)";', project)
        self.assertIn('TEST_HOST = "$(BUILT_PRODUCTS_DIR)/$(BRAND_APP_NAME).app/$(BRAND_APP_NAME)";', project)

    def test_phone_release_graph_preserves_independent_watch_and_local_push(self):
        data = json.loads(subprocess.check_output([
            "plutil", "-convert", "json", "-o", "-", str(ROOT / "HomeAssistant.xcodeproj/project.pbxproj")
        ]))
        objects = data["objects"]
        targets = {obj["name"]: key for key, obj in objects.items() if obj["isa"] == "PBXNativeTarget"}

        def closure(target_id):
            seen = set()
            pending = [target_id]
            while pending:
                current = pending.pop()
                if current in seen:
                    continue
                seen.add(current)
                target = objects[current]
                pending.extend(objects[dep]["target"] for dep in target.get("dependencies", []))
                # Copy/framework product references can introduce implicit dependencies too.
                for phase_id in target.get("buildPhases", []):
                    for file_id in objects[phase_id].get("files", []):
                        product = objects[file_id].get("fileRef")
                        pending.extend(key for key in targets.values()
                                       if objects[key]["productReference"] == product)
            return seen

        phone = closure(targets["App"])
        for name in ("WatchApp", "WatchExtension-Watch", "Shared-watchOS"):
            self.assertNotIn(targets[name], phone, name)
        for name in ("Extensions-Widgets", "Extensions-Intents", "Extensions-Share", "Extensions-PushProvider",
                     "Extensions-NotificationContent", "Extensions-NotificationService"):
            self.assertIn(targets[name], phone, name)
        watch = closure(targets["WatchApp"])
        self.assertIn(targets["WatchExtension-Watch"], watch)
        self.assertIn(targets["Shared-watchOS"], watch)
        watch_embeds = {
            objects[file_id]["fileRef"]
            for phase_id in objects[targets["WatchApp"]]["buildPhases"]
            if objects[phase_id]["isa"] == "PBXCopyFilesBuildPhase"
            for file_id in objects[phase_id]["files"]
        }
        self.assertIn(objects[targets["WatchExtension-Watch"]]["productReference"], watch_embeds)
        for scheme_name in ("App-Debug", "App-Release", "WatchApp"):
            scheme = ET.parse(ROOT / f"HomeAssistant.xcodeproj/xcshareddata/xcschemes/{scheme_name}.xcscheme")
            if scheme_name == "App-Release":
                self.assertEqual(scheme.find("ArchiveAction").get("buildConfiguration"), "Release")
            for entry in scheme.findall("./BuildAction/BuildActionEntries/BuildActionEntry"):
                target_id = entry.find("BuildableReference").get("BlueprintIdentifier")
                if scheme_name.startswith("App-"):
                    self.assertFalse(closure(target_id) & {targets["WatchApp"], targets["WatchExtension-Watch"]})
            if scheme_name == "WatchApp":
                self.assertIn(targets["WatchApp"], {
                    ref.get("BlueprintIdentifier") for ref in scheme.findall(".//BuildableReference")
                })

    def test_release_version_matches_asc_without_changing_development_version(self):
        release = read("Configuration/HomeAssistant.release.xcconfig")
        self.assertRegex(release, r"(?m)^MARKETING_VERSION\s*=\s*1\.0\s*$")
        self.assertLess(release.index('#include "HomeAssistant.xcconfig"'), release.index("MARKETING_VERSION"))
        self.assertNotIn("CURRENT_PROJECT_VERSION", release)
        self.assertEqual(read("Configuration/Version.xcconfig"),
                         "MARKETING_VERSION=2026.7.3\nCURRENT_PROJECT_VERSION=2026\n")
        debug = read("Configuration/HomeAssistant.debug.xcconfig")
        self.assertIn('#include "HomeAssistant.xcconfig"', debug)
        self.assertNotIn("MARKETING_VERSION", debug)
        self.assertIn("BUNDLE_ID_SUFFIX = .dev", debug)
        data = json.loads(subprocess.check_output([
            "plutil", "-convert", "json", "-o", "-", str(ROOT / "HomeAssistant.xcodeproj/project.pbxproj")
        ]))
        objects = data["objects"]
        project = objects[data["rootObject"]]
        for config_id in objects[project["buildConfigurationList"]]["buildConfigurations"]:
            config = objects[config_id]
            self.assertEqual(objects[config["baseConfigurationReference"]]["path"],
                             f'HomeAssistant.{config["name"].lower()}.xcconfig')
        for obj in objects.values():
            if obj["isa"] == "XCBuildConfiguration":
                self.assertFalse({"MARKETING_VERSION", "CURRENT_PROJECT_VERSION"} & obj["buildSettings"].keys())
            if obj["isa"] != "PBXNativeTarget" or not (obj["name"] == "App" or obj["name"].startswith("Extensions-")):
                continue
            for config_id in objects[obj["buildConfigurationList"]]["buildConfigurations"]:
                config = objects[config_id]
                info = plistlib.loads((ROOT / config["buildSettings"]["INFOPLIST_FILE"]).read_bytes())
                self.assertEqual(info["CFBundleShortVersionString"], "$(MARKETING_VERSION)", obj["name"])
                self.assertEqual(info["CFBundleVersion"], "$(CURRENT_PROJECT_VERSION)", obj["name"])

    def test_all_app_group_and_keychain_templates(self):
        count = 0
        for path in (ROOT / "Configuration/Entitlements").rglob("*.entitlements"):
            data = plistlib.loads(path.read_bytes())
            if "com.apple.security.application-groups" in data:
                count += 1
                self.assertEqual(data["com.apple.security.application-groups"], ["group." + BASE], str(path))
                self.assertEqual(data["keychain-access-groups"], ["$(AppIdentifierPrefix)" + BASE], str(path))
        self.assertEqual(count, 12)
        constants = read("Sources/Shared/Environment/AppConstants.swift")
        for suffix in ("Widgets", "PushProvider", "Intents", "APNSAttachmentService",
                       "NotificationContentExtension", "ShareExtension", "watchkitapp.watchkitextension"):
            self.assertIn('of: ".' + suffix + '"', constants)
        self.assertIn('"group." + BundleID.lowercased()', constants)
        self.assertIn("KeychainAccess.Keychain(service: BundleID)", constants)

    def test_log_bootstrap_does_not_reenter_current_when_app_group_is_missing(self):
        constants = read("Sources/Shared/Environment/AppConstants.swift")
        container = constants.split("public static var AppGroupContainer: URL {", 1)[1].split(
            "public static var appGRDBFile: URL {", 1)[0]
        self.assertNotIn("Current.", container)
        self.assertIn("NSTemporaryDirectory()", container)
        environment = read("Sources/Shared/Environment/Environment.swift")
        logger = environment.split("public var Log: XCGLogger = {", 1)[1].split(
            "/// Wrapper around CMMotionActivityManager", 1)[0]
        self.assertIn('log.error("App Group unavailable; using temporary storage without extension sharing")', logger)
        self.assertNotIn("Current.", logger)

    def test_watch_pairing_identifiers(self):
        app = plistlib.loads((ROOT / "Sources/WatchApp/Info.plist").read_bytes())
        extension = plistlib.loads((ROOT / "Sources/Extensions/Watch/Resources/Info.plist").read_bytes())
        self.assertEqual(app["WKCompanionAppBundleIdentifier"], BASE)
        self.assertEqual(extension["NSExtension"]["NSExtensionAttributes"]["WKAppBundleIdentifier"], BASE + ".watchkitapp")
        self.assertEqual(app["CFBundleDisplayName"], "$(BRAND_APP_NAME)")

    def test_both_auth_paths_share_identity(self):
        constants = read("Sources/Shared/Environment/AppConstants.swift")
        self.assertIn('public static let urlScheme = "woowtech"', constants)
        self.assertIn('public static let redirectURI = "\\(urlScheme)://auth-callback"', constants)
        self.assertIn('clientID = "https://aiot.woowtech.io/ios"', constants)
        runtime_client = re.search(r'clientID = "([^"]+)"', constants).group(1)
        configured_client = re.search(r'^OAUTH_CLIENT_ID="([^"]+)"',
                                      read("Tools/brand/woowtech-ios.conf"), re.MULTILINE).group(1)
        self.assertEqual(configured_client, runtime_client)
        self.assertIn("AppConstants.OAuth.clientID", read("Sources/App/Onboarding/API/OnboardingAuthDetails.swift"))
        self.assertIn("AppConstants.OAuth.redirectURI", read("Sources/App/Onboarding/API/OnboardingAuthDetails.swift"))
        routes = read("Sources/Shared/API/Authentication/AuthenticationRoutes.swift")
        self.assertEqual(routes.count('"client_id": AppConstants.OAuth.clientID'), 2)
        login = read("Sources/App/Onboarding/API/OnboardingAuthLoginViewController.swift")
        self.assertIn('url.scheme == AppConstants.urlScheme, url.host == "auth-callback"', login)
        self.assertNotIn('hasPrefix("woow', login)

    def test_customer_support_destinations(self):
        constants = read("Sources/Shared/Environment/AppConstants.swift")
        for post in (364, 365, 366):
            self.assertIn(f"https://aiot.woowtech.io/en/blog/help-center-7/woowtech-aiot-app-{post}", constants)
        error = read("Sources/App/Frontend/WebView/Views/ConnectionErrorDetailsView.swift")
        about = read("Sources/App/Settings/AboutView.swift")
        for source in (error, about):
            self.assertIn("L10n.Support.contact", source)
            self.assertIn("AppConstants.WebURLs.support", source)
            self.assertNotIn("discord", source.lower())
            self.assertNotIn("github", source.lower())
        self.assertIn("AcknowledgementsView()", about)
        self.assertIn("AppConstants.WebURLs.companionAppDocsTroubleshooting", error)
        self.assertNotIn("aiot.woowtech.io/search", read("Sources/Shared/ExternalLink.swift"))

    def test_published_topic_destinations(self):
        constants = read("Sources/Shared/Environment/AppConstants.swift")
        for slug in ("367", "local-pushwebsocket-368", "live-activities-369",
                     "iosandroid-widgets-371#ios-widgets", "nfcapp-373#nfc"):
            self.assertIn("https://aiot.woowtech.io/en/blog/help-center-7/woowtech-aiot-app-" + slug, constants)
        for anchor in ("connection-security-level", "actionable-notifications", "notifications-sounds", "live-activities"):
            self.assertIn("#" + anchor, constants)
        consumers = {
            "Sources/App/AppDelegate.swift": "actionableNotificationsDocs",
            "Sources/App/Settings/Notifications/NotificationCategoryEditorView.swift": "actionableNotificationsDocs",
            "Sources/App/Settings/Notifications/NotificationCategoryListView.swift": "actionableNotificationsDocs",
            "Sources/App/Settings/Notifications/NotificationSettingsView.swift": "notificationsDocs",
            "Sources/App/Settings/Notifications/NotificationSoundsView.swift": "notificationSoundsDocs",
            "Sources/App/Settings/Settings/SettingsView.swift": "companionAppDocs",
            "Sources/App/MainWindowGroupCommands.swift": "companionAppDocs",
            "Sources/Shared/ExternalLink.swift": "widgetsDocs",
        }
        for source, constant in consumers.items():
            self.assertIn("AppConstants.WebURLs." + constant, read(source))
            self.assertNotIn("https://aiot.woowtech.io/app/ios/", read(source))

    def test_push_and_retained_capabilities(self):
        self.assertIn('"app_id": AppConstants.BundleID', read("Sources/Shared/Notifications/LocalPush/LocalPushEvent.swift"))
        self.assertIn('Environment.get("APNS_TOPIC") ?? "com.woowtech.aiot"', read("Sources/PushServer/Sources/App/routes.swift"))
        constants = read("Sources/Shared/Environment/AppConstants.swift")
        self.assertIn('public static let pushURLString = "https://aiot.woowtech.io/api/sendPushNotification"', constants)
        self.assertNotIn("https://mobile-apps.home-assistant.io/api/sendPushNotification", constants)
        swift_test = (ROOT / "Tests/App/AppConstants.test.swift").read_text()
        self.assertIn('AppConstants.Firebase.pushURLString == "https://aiot.woowtech.io/api/sendPushNotification"', swift_test)
        self.assertNotIn("https://mobile-apps.home-assistant.io/api/sendPushNotification", swift_test)
        self.assertIn("stun:stun.home-assistant.io:3478", constants)
        entitlements = plistlib.loads((ROOT / "Configuration/Entitlements/release/App-ios.entitlements").read_bytes())
        for key in ("aps-environment", "com.apple.developer.siri", "com.apple.developer.nfc.readersession.formats",
                    "com.apple.developer.networking.wifi-info", "com.apple.developer.associated-domains"):
            self.assertIn(key, entitlements)
        app = plistlib.loads((ROOT / "Sources/App/Resources/Info.plist").read_bytes())
        self.assertIn("location", app["UIBackgroundModes"])
        self.assertIn("remote-notification", app["UIBackgroundModes"])

    def test_all_localized_identity_and_backend_terminology(self):
        # This checked-in manifest records every locale/key pair changed by the all-locale correction wave.
        # Assert the positive semantic token, rather than merely excluding one known-wrong replacement.
        expectations = json.loads(SEMANTIC_EXPECTATIONS.read_text())
        self.assertEqual(set(expectations), {"Home Assistant", "homeassistant", "woowtech aiot"})
        self.assertEqual(
            {token: sum(len(keys) for keys in files.values()) for token, files in expectations.items()},
            {"Home Assistant": 2861, "homeassistant": 6, "woowtech aiot": 781}
        )

        parsed = {}
        keys_by_table = {"InfoPlist.strings": set(), "Intents.strings": set(), "Core.strings": set()}
        for token, files in expectations.items():
            for relative_path, keys in files.items():
                path = ROOT / relative_path
                if path not in parsed:
                    parsed[path] = json.loads(subprocess.check_output(
                        ["plutil", "-convert", "json", "-o", "-", str(path)]
                    ))
                strings = parsed[path]
                table = path.name
                if table in keys_by_table:
                    keys_by_table[table].update(keys)
                for key in keys:
                    with self.subTest(path=relative_path, key=key, expected_token=token):
                        self.assertIn(key, strings)
                        self.assertIn(token, strings[key])

        self.assertEqual(keys_by_table["InfoPlist.strings"], PRIVACY_KEYS)
        self.assertEqual(keys_by_table["Intents.strings"], INTENTS_KEYS)
        self.assertEqual(keys_by_table["Core.strings"], CORE_KEYS)

    def test_no_old_visible_brand_and_all_localized_vocabulary_is_current(self):
        visible = []
        resources = ROOT / "Sources/App/Resources"
        for table in ("Localizable.strings", "InfoPlist.strings", "Intents.strings", "Core.strings"):
            visible.extend(resources.glob(f"*.lproj/{table}"))
        vocabularies = sorted(
            (ROOT / "Sources/Extensions/Intents/Resources").glob("*.lproj/AppIntentVocabulary.plist")
        )
        visible.extend(vocabularies)
        self.assertEqual(len(vocabularies), 35)
        for path in visible:
            self.assertNotIn("woowtech home", path.read_text().lower(), str(path))
        for path in vocabularies:
            vocabulary = plistlib.loads(path.read_bytes())
            phrase = vocabulary["IntentPhrases"][0]["IntentExamples"][0]
            self.assertEqual(phrase, "Share focus in woowtech aiot", str(path))

    def test_english_identity_and_fastlane_destination(self):
        self.assertIn('"about.logo.app_title" = "woowtech aiot";',
                      read("Sources/App/Resources/en.lproj/Localizable.strings"))
        self.assertIn("com.woowtech.aiot", read("fastlane/Deliverfile"))
        self.assertIn("com.woowtech.aiot", read("fastlane/lanes/testing.rb"))
        self.assertEqual(read("fastlane/metadata/en-US/name.txt").strip(), "woowtech aiot")
        self.assertEqual(read("fastlane/metadata/en-US/marketing_url.txt").strip(), "https://aiot.woowtech.io/en")
        self.assertEqual(
            read("fastlane/metadata/en-US/support_url.txt").strip(),
            "https://aiot.woowtech.io/en/blog/help-center-7/woowtech-aiot-app-366"
        )

    def test_watch_help_uses_proven_topic_specific_upstream_page(self):
        constants = read("Sources/Shared/Environment/AppConstants.swift")
        self.assertIn(
            'appleWatchDocs = URL(string: "https://companion.home-assistant.io/docs/apple-watch/")!',
            constants
        )
        for source in (
                "Sources/App/Settings/AppleWatch/Complications/ComplicationListView.swift",
                "Sources/App/Settings/AppleWatch/Complications/ComplicationEditView.swift"):
            text = read(source)
            self.assertIn("AppConstants.WebURLs.appleWatchDocs", text)
            self.assertNotIn("aiot.woowtech.io/app/ios/apple-watch", text)

    def test_cloud_terminology_does_not_remove_ha_cloud_routing(self):
        for path in (ROOT / "Sources/App/Resources").glob("*.lproj/Localizable.strings"):
            text = path.read_text()
            self.assertNotIn("woowtech Home Cloud", text, str(path))
            cloud_error = next(line for line in text.splitlines()
                               if line.startswith('"connection.error.failed_connect.cloud_inactive.title"'))
            cloud_name = "Home Assistant Bulut" if path.parent.name == "tr.lproj" else "Home Assistant Cloud"
            self.assertIn(cloud_name, cloud_error, str(path))
        connection = read("Sources/Shared/API/ConnectionInfo.swift")
        for token in ("remoteUIURL", "cloudhookURL", "useCloud", "externalURL", "internalURL"):
            self.assertIn(token, connection)
        self.assertIn("useCloud", read("Sources/App/Settings/Connection/ConnectionURLView.swift"))

    def test_native_commissioning_is_unavailable_but_bridge_controls_remain(self):
        config = read("Sources/App/Frontend/ExternalMessageBus/WebViewExternalBusMessage.swift")
        for key in ("canCommissionMatter", "hasMatterStatusReport", "canImportThreadCredentials",
                    "canTransferThreadCredentialsToKeychain"):
            self.assertIn('"' + key + '": false', config)
        handler = read("Sources/App/Frontend/ExternalMessageBus/WebViewExternalMessageHandler.swift")
        self.assertIn("rejectNativeCommissioning(incomingMessage)", handler)
        self.assertIn('result: ["success": false, "error": "unsupported"]', handler)
        self.assertIn('payload: ["success": false]', handler)
        for entry in (".tagRead:", ".tagWrite:", ".barCodeScanner:", ".cameraPlayerShow:",
                      ".assistShow:", ".scanForImprov:", ".connectionStatus:"):
            self.assertIn(entry, handler)
        for path in (ROOT / "Sources").rglob("*.swift"):
            if "PushServer" in path.parts:
                continue
            for token in ("Current.matter", "MatterWrapper", "ThreadClientService", "ThreadCredentialsManagementView",
                          "import MatterSupport", "import ThreadNetwork", "matterLastPreferredNetWork"):
                self.assertNotIn(token, path.read_text(), str(path))
        self.assertFalse(any((ROOT / "Sources/Thread").rglob("*.swift")))
        self.assertFalse(any((ROOT / "Sources/Extensions/Matter").rglob("*.swift")))
        self.assertFalse(any((ROOT / "Tests/App/Thread").rglob("*.swift")))
        self.assertNotIn("ThreadNetwork", read("Configuration/HomeAssistant.xcconfig"))
        self.assertNotIn("ENABLE_THREAD_NETWORK_CREDENTIALS", read("Configuration/HomeAssistant.xcconfig"))
        script = read("Configuration/Entitlements/activate_special_entitlements.sh")
        self.assertNotIn("manage-thread-network-credentials", script)
        for retained in ("critical-alerts", "app-push-provider", "carplay-driving-task", "carplay-voice-based-conversation"):
            self.assertIn(retained, script)
        app = plistlib.loads((ROOT / "Sources/App/Resources/Info.plist").read_bytes())
        self.assertEqual(app["NSBonjourServices"], ["_hass-mobile-app._tcp", "_home-assistant._tcp"])
        for key in ("NSCameraUsageDescription", "NSMicrophoneUsageDescription", "NFCReaderUsageDescription"):
            self.assertIn(key, app)

    def test_project_graph_has_no_native_commissioning_target_or_dangling_references(self):
        project = read("HomeAssistant.xcodeproj/project.pbxproj")
        for removed in ("Matter", "Thread", "PayloadConstants"):
            self.assertNotIn(removed, project)
        self.assertNotIn("Extensions-Matter", read("Podfile"))
        self.assertFalse((ROOT / "HomeAssistant.xcodeproj/xcshareddata/xcschemes/Extensions-Matter.xcscheme").exists())
        data = json.loads(subprocess.check_output([
            "plutil", "-convert", "json", "-o", "-", str(ROOT / "HomeAssistant.xcodeproj/project.pbxproj")
        ]))
        objects = data["objects"]

        def references(value):
            if isinstance(value, dict):
                for item in value.values():
                    yield from references(item)
            elif isinstance(value, list):
                for item in value:
                    yield from references(item)
            elif isinstance(value, str) and re.fullmatch(r"[A-F0-9]{24}", value):
                yield value

        self.assertEqual(set(references(data)) - objects.keys(), set())
        targets = {obj["name"]: obj for obj in objects.values() if obj["isa"] == "PBXNativeTarget"}
        self.assertEqual(set(targets), {
            "App", "Shared-iOS", "Shared-watchOS", "SharedTesting", "Tests-App", "Tests-Shared", "Tests-UI",
            "WatchApp", "WatchExtension-Watch", "Extensions-Widgets", "Extensions-Intents", "Extensions-Share",
            "Extensions-PushProvider", "Extensions-NotificationContent", "Extensions-NotificationService",
            "MacBridge", "Launcher",
        })
        embedded_products = set()
        for phase_id in targets["App"]["buildPhases"]:
            phase = objects[phase_id]
            if phase["isa"] == "PBXCopyFilesBuildPhase":
                embedded_products.update(objects[file_id]["fileRef"] for file_id in phase["files"])
        self.assertNotIn(targets["WatchApp"]["productReference"], embedded_products, "WatchApp")
        for name in ("Extensions-Widgets", "Extensions-Intents", "Extensions-Share", "Extensions-PushProvider",
                     "Extensions-NotificationContent", "Extensions-NotificationService"):
            self.assertIn(targets[name]["productReference"], embedded_products, name)

        app_dependencies = {objects[dependency]["target"] for dependency in targets["App"]["dependencies"]}
        watch_target_id = next(key for key, value in objects.items() if value is targets["WatchApp"])
        self.assertNotIn(watch_target_id, app_dependencies)
        self.assertIn("guard AppConstants.includesWatchAppInPhonePackage else { return false }",
                      read("Sources/App/Settings/Settings/SettingsView.swift"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
