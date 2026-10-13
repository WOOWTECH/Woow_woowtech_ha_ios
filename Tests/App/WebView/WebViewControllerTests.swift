@testable import HomeAssistant
@testable import Shared
import UIKit
import WebKit
import XCTest

@MainActor
final class WebViewControllerTests: XCTestCase {
    func testMakeWebViewConfigurationRequiresUserActionForAudioPlayback() {
        let config = WebViewController.makeWebViewConfiguration()

        XCTAssertTrue(config.allowsInlineMediaPlayback)
        XCTAssertEqual(config.mediaTypesRequiringUserActionForPlayback, .audio)
    }

    func testEmptyStateStyleUsesUnauthenticatedVariantForAuthInvalidConnectionState() {
        let sut = makeSUT()

        let style = sut.emptyStateStyle(for: .authInvalid)

        XCTAssertEqual(style, .unauthenticated)
    }

    func testEmptyStateStyleUsesDisconnectedVariantForDisconnectedConnectionState() {
        let sut = makeSUT()

        let style = sut.emptyStateStyle(for: .disconnected)

        XCTAssertEqual(style, .disconnected)
    }

    func testUpdateFrontendConnectionStateDoesNotDowngradeAuthInvalidToDisconnected() {
        let sut = makeSUT()
        sut.connectionState = .authInvalid

        sut.updateFrontendConnectionState(state: FrontEndConnectionState.disconnected.rawValue)

        XCTAssertEqual(sut.connectionState, .authInvalid)
        XCTAssertNil(sut.emptyStateTimer)
    }

    func testUpdateFrontendConnectionStateSchedulesTimerForDisconnectedState() {
        let sut = makeSUT()

        sut.updateFrontendConnectionState(state: FrontEndConnectionState.disconnected.rawValue)

        XCTAssertEqual(sut.connectionState, .disconnected)
        XCTAssertNotNil(sut.emptyStateTimer)
    }

    func testShowEmptyStatePublishesContentWithErrorDetailsButtonWhenLatestLoadErrorExists() {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState
        sut.connectionState = .disconnected
        sut.latestLoadError = URLError(.notConnectedToInternet)

        sut.showEmptyState()

        XCTAssertEqual(overlayState.emptyState?.style, .disconnected)
        XCTAssertEqual(overlayState.emptyState?.showsErrorDetailsButton, true)
    }

    func testHideEmptyStateClearsPublishedContent() {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        sut.overlayState = overlayState
        sut.showEmptyState()
        XCTAssertNotNil(overlayState.emptyState)

        sut.hideEmptyState()

        XCTAssertNil(overlayState.emptyState)
    }

    func testUpdateFrontendConnectionStateClearsLatestLoadError() {
        let sut = makeSUT()
        sut.latestLoadError = URLError(.timedOut)

        sut.updateFrontendConnectionState(state: FrontEndConnectionState.connected.rawValue)

        XCTAssertNil(sut.latestLoadError)
    }

    func testDisconnectedRetryUsesResetFrontendAction() {
        let sut = makeSUT()
        let overlayState = WebFrontendOverlayState()
        var resetCalled = false
        sut.overlayState = overlayState
        sut.connectionState = .disconnected
        sut.resetFrontendAction = { [weak sut] in
            resetCalled = true
            sut?.overlayState?.emptyState = nil
        }

        sut.showEmptyState()
        overlayState.emptyState?.retryAction()

        XCTAssertTrue(resetCalled)
        XCTAssertNil(overlayState.emptyState)
    }

    func testMarkDisconnectedForHardReloadArmsTimer() {
        let sut = makeSUT()
        sut.overlayState = WebFrontendOverlayState()
        sut.updateFrontendConnectionState(state: FrontEndConnectionState.connected.rawValue)
        XCTAssertEqual(sut.connectionState, .connected)

        sut.markDisconnectedForHardReload()

        XCTAssertEqual(sut.connectionState, .disconnected)
        XCTAssertNotNil(sut.emptyStateTimer)
    }

    func testMarkDisconnectedForHardReloadKeepsAuthInvalid() {
        let sut = makeSUT()
        sut.connectionState = .authInvalid

        sut.markDisconnectedForHardReload()

        XCTAssertEqual(sut.connectionState, .authInvalid)
    }

    func testServerVersionDidChangeClearsFrontendAssetCacheForMatchingServer() {
        let original = Current.websiteDataStoreHandler
        defer { Current.websiteDataStoreHandler = original }
        let handler = FakeWebsiteDataStoreHandler()
        Current.websiteDataStoreHandler = handler

        let server = Server.fake()
        let sut = makeSUT(server: server)

        sut.serverVersionDidChange(Notification(
            name: HomeAssistantAPI.serverVersionDidChangeNotification,
            object: server
        ))

        XCTAssertEqual(handler.cleanCacheCallCount, 1)
        XCTAssertEqual(handler.lastDataTypes, WebsiteDataStoreHandlerImpl.frontendAssetDataTypes)
    }

    func testServerVersionDidChangeIgnoresChangesForOtherServers() {
        let original = Current.websiteDataStoreHandler
        defer { Current.websiteDataStoreHandler = original }
        let handler = FakeWebsiteDataStoreHandler()
        Current.websiteDataStoreHandler = handler

        let sut = makeSUT(server: .fake())

        sut.serverVersionDidChange(Notification(
            name: HomeAssistantAPI.serverVersionDidChangeNotification,
            object: Server.fake()
        ))

        XCTAssertEqual(handler.cleanCacheCallCount, 0)
    }

    /// 迴歸測試:伺服器拒絕 refresh token 時,必須顯示重新認證畫面,而不是停在白畫面。
    ///
    /// 背景(2026-09-16 於 iPad 實機抓到):
    /// 存在裝置上的 refresh token 與 App 現在送出的 `client_id` 不一致時,
    /// Home Assistant 的 `/auth/token` 會回 `400 {"error":"invalid_request"}`。
    /// `TokenManager` 收到後會送出 `onboardingObservation.needed(.unauthenticated(...))`,
    /// 但當時**沒有任何人在聽這個通知**:
    ///   * `OnboardingStateObservable`(容器層)對 `.unauthenticated` 刻意 `break`,
    ///     註解寫「由 WebViewController 自己處理」;
    ///   * 而 `WebViewController` 既沒有宣告 `OnboardingStateObserver`,
    ///     也沒有在 `viewDidLoad` 註冊 —— 上游 PR #5246 補上的那兩段,本 fork 的
    ///     分支點在它之前,所以從未有過。
    /// 結果:`showReAuthPopup` 永遠不會被呼叫 → `connectionState` 進不了 `.authInvalid`
    /// → 空狀態不顯示 → WebView 一直等 `externalAuthSetToken` → **使用者看到白畫面**。
    func testServerRejectingRefreshTokenSurfacesReAuthenticationInsteadOfBlankWebView() async throws {
        let server = Server.fake(identifier: .init(rawValue: "reauth-test"))
        let sut = makeSUT(server: server)
        // `webView` 是 `WKWebView!`,正式執行時由 `viewDidLoad` 建立;測試沒跑 viewDidLoad,
        // 而 `showReAuthPopup` 會呼叫 `load(request:)` → `webView.load(...)`,不補就會崩潰。
        //
        // ⚠️ 這裡**不能**用 makeSUT 注入 `view` 的那招 `setValue(_:forKey:)`——
        //    KVC 只對 `@objc` 屬性有效,`view` 是 UIViewController 的 @objc 屬性所以可以,
        //    但 `webView` 是純 Swift 屬性,KVC 設不進去(實測:值沒進去,
        //    load(request:) 仍然對 nil 強制解包而崩潰)。
        //    這個測試檔已經 `@testable import HomeAssistant`,internal 屬性可直接指派。
        sut.webView = WKWebView()

        let observer = try XCTUnwrap(
            sut as? OnboardingStateObserver,
            "WebViewController 必須是 OnboardingStateObserver,否則 refresh token 被拒時沒有人會顯示重新認證畫面"
        )

        observer.onboardingStateDidChange(
            to: .needed(.unauthenticated(server.identifier.rawValue, 400))
        )
        // 通知會 hop 到 main actor,等它處理完
        try await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertEqual(
            sut.connectionState,
            .authInvalid,
            "伺服器拒絕 refresh token 後必須進入 authInvalid 並顯示重新認證畫面;停在原狀態就是白畫面"
        )
    }

    private func makeSUT(server: Server = .fake()) -> WebViewController {
        let sut = WebViewController(server: server)
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        sut.setValue(containerView, forKey: "view")
        return sut
    }
}

private final class FakeWebsiteDataStoreHandler: WebsiteDataStoreHandlerProtocol {
    private(set) var cleanCacheCallCount = 0
    private(set) var lastDataTypes: Set<String>?

    func cleanCache(dataTypes: Set<String>, completion: (() -> Void)?) {
        cleanCacheCallCount += 1
        lastDataTypes = dataTypes
    }
}
