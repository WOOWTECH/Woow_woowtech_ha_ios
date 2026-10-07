import Shared
import Testing

struct BackgroundTaskTests {
    @Test func testAllCasesRawValues() async throws {
        #expect(BackgroundTask.backgroundFetch.rawValue == "background-fetch")
        #expect(BackgroundTask.lifecycleManagerDidFinishLaunching.rawValue == "lifecycle-manager-didFinishLaunching")
        #expect(BackgroundTask.lifecycleManagerDidEnterBackground.rawValue == "lifecycle-manager-didEnterBackground")
        #expect(BackgroundTask.lifecycleManagerDidBecomeActive.rawValue == "lifecycle-manager-didBecomeActive")
        #expect(BackgroundTask.shortcutItem.rawValue == "shortcut-item")
        #expect(BackgroundTask.handlePushAction.rawValue == "handle-push-action")
        #expect(
            BackgroundTask.notificationManagerDidReceiveRegistrationToken
                .rawValue == "notificationManager-didReceiveRegistrationToken"
        )
        #expect(BackgroundTask.zoneManagerPerformEvent.rawValue == "zone-manager-perform-event")
        #expect(BackgroundTask.watchPushAction.rawValue == "watch-push-action")
        #expect(BackgroundTask.webhookSendEphemeral.rawValue == "webhook-send-ephemeral")
        #expect(BackgroundTask.webhookSend.rawValue == "webhook-send")
        #expect(BackgroundTask.webhookInvoke.rawValue == "webhook-invoke")
        #expect(BackgroundTask.manualLocationUpdate.rawValue == "manual-location-update")
        #expect(BackgroundTask.signaledUpdateSensors.rawValue == "signaled-update-sensors")
        #expect(BackgroundTask.connectApi.rawValue == "connect-api")
        #expect(BackgroundTask.realmWrite.rawValue == "realm-write")
        #expect(BackgroundTask.pushLocationRequest.rawValue == "push-location-request")
    }
}
