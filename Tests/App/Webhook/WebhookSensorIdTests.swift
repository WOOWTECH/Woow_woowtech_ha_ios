@testable import Shared
import Testing

struct WebhookSensorIdTests {
    @Test func testWebhookSensorIdRawValues() async throws {
        #expect(WebhookSensorId.iPhoneAudioOutput.rawValue == "iphone-audio-output")
        #expect(WebhookSensorId.activity.rawValue == "activity")
        #expect(WebhookSensorId.connectivitySSID.rawValue == "connectivity_ssid")
        #expect(WebhookSensorId.connectivityBSID.rawValue == "connectivity_bssid")
        #expect(WebhookSensorId.connectivityConnectionType.rawValue == "connectivity_connection_type")
        #expect(WebhookSensorId.geocodedLocation.rawValue == "geocoded_location")
        #expect(WebhookSensorId.lastUpdateTrigger.rawValue == "last_update_trigger")
        #expect(WebhookSensorId.storage.rawValue == "storage")
        #expect(WebhookSensorId.camera.rawValue == "camera")
        #expect(WebhookSensorId.microphone.rawValue == "microphone")
        #expect(WebhookSensorId.audioOutput.rawValue == "audio_output")
        #expect(WebhookSensorId.active.rawValue == "active")
        #expect(WebhookSensorId.displaysCount.rawValue == "displays_count")
        #expect(WebhookSensorId.primaryDisplayName.rawValue == "primary_display_name")
        #expect(WebhookSensorId.primaryDisplayId.rawValue == "primary_display_id")
        #expect(WebhookSensorId.frontmostApp.rawValue == "frontmost_app")
        #expect(WebhookSensorId.watchBattery.rawValue == "watch-battery")
        #expect(WebhookSensorId.watchBatteryState.rawValue == "watch-battery-state")
        #expect(WebhookSensorId.appVersion.rawValue == "app-version")
        #expect(WebhookSensorId.locationPermission.rawValue == "location-permission")
        #expect(WebhookSensorId.focus.rawValue == "focus")
        #expect(WebhookSensorId.pressure.rawValue == "pressure")
        #expect(WebhookSensorId.kioskMode.rawValue == "kioskMode")
        #expect(WebhookSensorId.kioskBrightness.rawValue == "kioskBrightness")
        #expect(WebhookSensorId.kioskVolume.rawValue == "kioskVolume")
        #expect(
            WebhookSensorId.allCases.count == 25,
            "WebhookSensorId has different number of cases than defined in test, \(WebhookSensorId.allCases.count)"
        )
    }
}
