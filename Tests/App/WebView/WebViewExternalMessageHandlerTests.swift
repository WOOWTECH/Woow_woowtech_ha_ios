@testable import HomeAssistant
import Improv_iOS
import PromiseKit
@testable import Shared
import SwiftUI
import XCTest

final class WebViewExternalMessageHandlerTests: XCTestCase {
    private var sut: WebViewExternalMessageHandler!
    private var mockWebViewController: MockWebViewController!

    override func setUp() async throws {
        mockWebViewController = MockWebViewController()
        sut = WebViewExternalMessageHandler(
            improvManager: ImprovManager.shared
        )
        sut.webViewController = mockWebViewController
    }

    override func tearDown() async throws {
        sut = nil
        mockWebViewController = nil
    }

    @MainActor func testHandleExternalMessageConfigScreenShowShowSettings() {
        let coordinator = MockAppCoordinator()
        let settingsShown = expectation(description: "showSettings called")
        coordinator.onShowSettings = { settingsShown.fulfill() }
        Current.sceneManager.registerAppCoordinator(coordinator)

        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "config_screen/show",
        ]
        sut.handleExternalMessage(dictionary)

        wait(for: [settingsShown], timeout: 1)
        XCTAssertTrue(coordinator.showSettingsCalled)
    }

    @MainActor func testHandleExternalMessageThemeUpdateNotifyThemeColors() {
        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "theme-update",
        ]
        sut.handleExternalMessage(dictionary)

        XCTAssertEqual(mockWebViewController.lastEvaluatedJavaScriptScript, "notifyThemeColors()")
    }

    @MainActor func testHandleExternalMessageBarCodeScanPresentsScanner() {
        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "bar_code/scan",
            "payload": [
                "title": "abc",
                "description": "abc2",
            ],
        ]
        sut.handleExternalMessage(dictionary)

        XCTAssertTrue(mockWebViewController.overlayedController is BarcodeScannerHostingController)
    }

    @MainActor func testHandleExternalMessageBarCodeCloseClosesScanner() {
        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "bar_code/scan",
            "payload": [
                "title": "abc",
                "description": "abc2",
            ],
        ]
        // Open scanner
        sut.handleExternalMessage(dictionary)

        let dictionary2: [String: Any] = [
            "id": 2,
            "message": "",
            "command": "",
            "type": "bar_code/close",
        ]
        // Close scanner
        sut.handleExternalMessage(dictionary2)

        XCTAssertTrue(mockWebViewController.dismissOverlayControllerCalled)
        XCTAssertTrue(mockWebViewController.dismissControllerAboveOverlayControllerCalled)
    }

    @MainActor func testHandleExternalMessageBarCodeNotifyNotifies() {
        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "bar_code/scan",
            "payload": [
                "title": "abc",
                "description": "abc2",
            ],
        ]
        // Open scanner
        sut.handleExternalMessage(dictionary)

        let dictionary2: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "bar_code/notify",
            "payload": [
                "message": "abc",
            ],
        ]

        sut.handleExternalMessage(dictionary2)
        XCTAssertEqual(mockWebViewController.shownBannerRequests.last?.id, "BarcodeScannerMessage")
        XCTAssertEqual(mockWebViewController.shownBannerRequests.last?.message, "abc")
    }

    @MainActor func testNativeCommissioningRequestsAreUnsupportedWithoutPresentingUI() throws {
        for (index, type) in [
            "matter/commission",
            "thread/import_credentials",
            "thread/store_in_platform_keychain",
        ].enumerated() {
            let sent = expectation(description: "Unsupported response for \(type)")
            sent.expectedFulfillmentCount = type == "matter/commission" ? 2 : 1
            mockWebViewController.evaluateJavaScriptExpectation = sent
            mockWebViewController.evaluatedJavaScriptScripts = []

            sut.handleExternalMessage([
                "id": index,
                "type": type,
                "payload": [
                    "mac_extended_address": "unused-address",
                    "active_operational_dataset": "unused-dataset",
                    "extended_pan_id": "unused-pan-id",
                ],
            ])

            wait(for: [sent], timeout: 1)
            let messages = try mockWebViewController.evaluatedJavaScriptScripts.map(externalBusMessage(from:))
            let result = try XCTUnwrap(messages.first { $0["type"] as? String == "result" })
            XCTAssertEqual(result["id"] as? Int, index)
            XCTAssertEqual(result["success"] as? Bool, false)
            XCTAssertEqual((result["result"] as? [String: Any])?["error"] as? String, "unsupported")
            if type == "matter/commission" {
                let finish = try XCTUnwrap(messages.first { $0["type"] as? String == "command" })
                XCTAssertEqual(finish["command"] as? String, "matter/commission/finish")
                XCTAssertEqual((finish["payload"] as? [String: Any])?["success"] as? Bool, false)
            }
            XCTAssertNil(mockWebViewController.overlayedController)
        }
    }

    @MainActor func testMatterCommissionWithoutIDOrPayloadStillSendsFailureFinish() throws {
        let sent = expectation(description: "Failure finish for old fire-and-forget frontend")
        mockWebViewController.evaluateJavaScriptExpectation = sent
        sut.handleExternalMessage(["type": "matter/commission"])

        wait(for: [sent], timeout: 1)
        let message = try externalBusMessage(from: XCTUnwrap(mockWebViewController.lastEvaluatedJavaScriptScript))
        XCTAssertEqual(message["command"] as? String, "matter/commission/finish")
        XCTAssertEqual((message["payload"] as? [String: Any])?["success"] as? Bool, false)
        XCTAssertEqual(mockWebViewController.evaluateJavaScriptCallCount, 1)
        XCTAssertNil(mockWebViewController.overlayedController)
    }

    @MainActor func testThreadCredentialRequestWithoutPayloadIsRejected() throws {
        let sent = expectation(description: "Missing credentials cannot leave a request pending")
        mockWebViewController.evaluateJavaScriptExpectation = sent
        sut.handleExternalMessage(["id": 42, "type": "thread/store_in_platform_keychain"])

        wait(for: [sent], timeout: 1)
        let message = try externalBusMessage(from: XCTUnwrap(mockWebViewController.lastEvaluatedJavaScriptScript))
        XCTAssertEqual(message["id"] as? Int, 42)
        XCTAssertEqual(message["success"] as? Bool, false)
        XCTAssertNil(mockWebViewController.overlayedController)
    }

    @MainActor func testHandleExternalMessageShowAssistShowsAssist() {
        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "assist/show",
        ]

        sut.handleExternalMessage(dictionary)

        XCTAssertTrue(mockWebViewController.overlayedController is UIHostingController<AssistView>)
    }

    @MainActor func testHandleExternalMessageOpenVoiceDeviceSettingsShowsSettings() {
        let coordinator = MockAppCoordinator()
        let assistSettingsShown = expectation(description: "showAssistSettings called")
        coordinator.onShowAssistSettings = { assistSettingsShown.fulfill() }
        Current.sceneManager.registerAppCoordinator(coordinator)

        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "assist/settings",
        ]

        sut.handleExternalMessage(dictionary)

        wait(for: [assistSettingsShown], timeout: 1)
        XCTAssertTrue(coordinator.showAssistSettingsCalled)
    }

    private func externalBusMessage(from script: String) throws -> [String: Any] {
        let prefix = "window.externalBus("
        XCTAssertTrue(script.hasPrefix(prefix))
        XCTAssertTrue(script.hasSuffix(")"))

        let jsonString = String(script.dropFirst(prefix.count).dropLast())
        let jsonObject = try JSONSerialization.jsonObject(with: Data(jsonString.utf8))
        return try XCTUnwrap(jsonObject as? [String: Any])
    }

    @MainActor func testHandleExternalMessageCameraPlayerShowPresentsCameraPlayer() {
        let dictionary: [String: Any] = [
            "id": 1,
            "message": "",
            "command": "",
            "type": "camera/show",
            "payload": [
                "entity_id": "camera.front_door",
                "camera_name": "Front Door",
            ],
        ]

        sut.handleExternalMessage(dictionary)

        XCTAssertNotNil(mockWebViewController.overlayedController)
        XCTAssertEqual(mockWebViewController.overlayedController?.modalPresentationStyle, .overFullScreen)
    }

    @MainActor func testSendExternalBusCommandWithRetrySendsCommandWithCorrelatableID() throws {
        let firstSend = expectation(description: "command sent")
        mockWebViewController.evaluateJavaScriptExpectation = firstSend

        sut.sendExternalBusCommandWithRetry(
            command: .kioskModeSet,
            payload: ["enable": true],
            maxAttempts: 3,
            retryDelay: .milliseconds(10),
            acknowledgementTimeout: .seconds(5)
        )

        wait(for: [firstSend], timeout: 1)
        let message = try externalBusMessage(from: XCTUnwrap(mockWebViewController.lastEvaluatedJavaScriptScript))
        XCTAssertEqual(message["type"] as? String, "command")
        XCTAssertEqual(message["command"] as? String, WebViewExternalBusOutgoingMessage.kioskModeSet.rawValue)
        XCTAssertEqual((message["payload"] as? [String: Any])?["enable"] as? Bool, true)
        XCTAssertNotNil(message["id"] as? Int)
    }

    @MainActor func testSendExternalBusCommandWithRetryRetriesWhenFrontendRejects() throws {
        let firstSend = expectation(description: "first send")
        mockWebViewController.evaluateJavaScriptExpectation = firstSend

        sut.sendExternalBusCommandWithRetry(
            command: .kioskModeSet,
            payload: ["enable": true],
            maxAttempts: 3,
            retryDelay: .milliseconds(10),
            acknowledgementTimeout: .seconds(5)
        )

        wait(for: [firstSend], timeout: 1)
        let firstMessage = try externalBusMessage(from: XCTUnwrap(mockWebViewController.lastEvaluatedJavaScriptScript))
        let firstID = try XCTUnwrap(firstMessage["id"] as? Int)

        // Frontend reports it couldn't handle the command yet; expect a retry with a fresh id.
        let retrySend = expectation(description: "retry send")
        mockWebViewController.evaluateJavaScriptExpectation = retrySend
        sut.handleExternalMessage([
            "type": "result",
            "id": firstID,
            "success": false,
            "error": ["code": "not_ready", "message": "Command handler not ready"],
        ])

        wait(for: [retrySend], timeout: 1)
        let retryMessage = try externalBusMessage(from: XCTUnwrap(mockWebViewController.lastEvaluatedJavaScriptScript))
        let retryID = try XCTUnwrap(retryMessage["id"] as? Int)
        XCTAssertNotEqual(retryID, firstID)
        XCTAssertEqual(retryMessage["command"] as? String, WebViewExternalBusOutgoingMessage.kioskModeSet.rawValue)
        XCTAssertEqual((retryMessage["payload"] as? [String: Any])?["enable"] as? Bool, true)
    }

    @MainActor func testSendExternalBusCommandWithRetryGivesUpAfterMaxAttempts() throws {
        let firstSend = expectation(description: "first send")
        mockWebViewController.evaluateJavaScriptExpectation = firstSend

        sut.sendExternalBusCommandWithRetry(
            command: .kioskModeSet,
            payload: ["enable": true],
            maxAttempts: 1,
            retryDelay: .milliseconds(10),
            acknowledgementTimeout: .seconds(5)
        )

        wait(for: [firstSend], timeout: 1)
        XCTAssertEqual(mockWebViewController.evaluateJavaScriptCallCount, 1)
        let firstMessage = try externalBusMessage(from: XCTUnwrap(mockWebViewController.lastEvaluatedJavaScriptScript))
        let firstID = try XCTUnwrap(firstMessage["id"] as? Int)

        // The single allowed attempt was rejected, so the handler must give up rather than send again.
        let noFurtherSend = expectation(description: "no further send")
        noFurtherSend.isInverted = true
        mockWebViewController.evaluateJavaScriptExpectation = noFurtherSend
        sut.handleExternalMessage([
            "type": "result",
            "id": firstID,
            "success": false,
            "error": ["code": "not_ready", "message": "Command handler not ready"],
        ])

        wait(for: [noFurtherSend], timeout: 0.5)
        XCTAssertEqual(mockWebViewController.evaluateJavaScriptCallCount, 1)
    }
}
