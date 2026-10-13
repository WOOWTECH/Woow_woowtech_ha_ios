import Alamofire
import HAKit
@testable import Shared
import XCTest

class HAAPITokenFetchFailureTests: XCTestCase {
    private func drainMainQueue(cycles: Int = 2) {
        let expectation = expectation(description: "drain main queue")

        func schedule(_ remaining: Int) {
            DispatchQueue.main.async {
                if remaining == 0 {
                    expectation.fulfill()
                } else {
                    schedule(remaining - 1)
                }
            }
        }

        schedule(cycles)
        wait(for: [expectation], timeout: 10.0)
    }

    func testTokenFetchFailureMarksRevokedCredentialsAsPermanent() {
        let error = AFError.responseValidationFailed(reason: .customValidationFailed(
            error: AuthenticationAPI.AuthenticationError.serverError(
                statusCode: 400,
                errorCode: "invalid_grant",
                error: nil
            )
        ))

        let failure = HomeAssistantAPI.tokenFetchFailure(from: error)

        XCTAssertTrue(failure.shouldDisconnectPermanently)
        XCTAssertTrue(failure.errorDescription?.contains("invalid_grant") == true)
    }

    func testTokenFetchFailureLeavesTransientErrorsRetryable() {
        let failure = HomeAssistantAPI.tokenFetchFailure(from: URLError(.notConnectedToInternet))

        XCTAssertFalse(failure.shouldDisconnectPermanently)
    }

    func testConnectionDelegateStopsReconnectLoopForPermanentTokenFetchFailure() {
        let api = HomeAssistantAPI(server: .fake())
        let connection = HAMockConnection()
        connection.delegate = api
        api.connection = connection

        connection.setState(.disconnected(reason: .waitingToReconnect(
            lastError: HomeAssistantAPI.TokenFetchFailure(
                underlyingType: "fatal",
                shouldDisconnectPermanently: true
            ),
            atLatest: Date(),
            retryCount: 1
        )), waitForQueue: false)

        drainMainQueue()

        XCTAssertEqual(connection.state, .disconnected(reason: .disconnected))
    }

    func testConnectionDelegateKeepsRetryingForNonPermanentTokenFetchFailure() {
        let api = HomeAssistantAPI(server: .fake())
        let connection = HAMockConnection()
        connection.delegate = api
        api.connection = connection

        let expectedState = HAConnectionState.disconnected(reason: .waitingToReconnect(
            lastError: HomeAssistantAPI.TokenFetchFailure(
                underlyingType: "transient",
                shouldDisconnectPermanently: false
            ),
            atLatest: Date(),
            retryCount: 1
        ))

        connection.setState(expectedState, waitForQueue: false)

        drainMainQueue()

        XCTAssertEqual(connection.state, expectedState)
    }

    func testConnectionDelegateRecoversFromRejectedStateWhenReconnectSucceeds() {
        let priorDelays = HomeAssistantAPI.rejectedReconnectDelays
        HomeAssistantAPI.rejectedReconnectDelays = [0, 0, 0]
        defer { HomeAssistantAPI.rejectedReconnectDelays = priorDelays }

        let api = HomeAssistantAPI(server: .fake())
        let connection = HAMockConnection()
        connection.delegate = api
        api.connection = connection

        connection.setState(.disconnected(reason: .rejected), waitForQueue: false)
        drainMainQueue(cycles: 10)

        // HAKit won't auto-reconnect a rejected connection, but our delegate explicitly retries; the
        // mock's connect() succeeds, so the rejection is recovered instead of dead-ending the socket.
        XCTAssertEqual(connection.state, .ready(version: "1.0-mock"))
    }

    func testConnectionDelegateGivesUpAfterExhaustingRejectedReconnectBudget() {
        let priorDelays = HomeAssistantAPI.rejectedReconnectDelays
        HomeAssistantAPI.rejectedReconnectDelays = [0, 0, 0]
        defer { HomeAssistantAPI.rejectedReconnectDelays = priorDelays }

        let api = HomeAssistantAPI(server: .fake())
        let connection = ScriptedConnectMockConnection(stateAfterConnect: .disconnected(reason: .rejected))
        connection.delegate = api
        api.connection = connection

        connection.setState(.disconnected(reason: .rejected))
        drainMainQueue(cycles: 20)

        // One reconnect per backoff entry, then we stop — a genuinely-invalid token must not loop forever
        // (which would keep tripping HA's auth-ban endpoint).
        XCTAssertEqual(connection.connectCount, 3)
        XCTAssertEqual(connection.state, .disconnected(reason: .rejected))
    }

    func testConnectionDelegateRestartsAConnectAttemptThatNeverLeavesConnecting() {
        let priorDelays = HomeAssistantAPI.staleConnectingDelays
        HomeAssistantAPI.staleConnectingDelays = [0, 3600]
        defer { HomeAssistantAPI.staleConnectingDelays = priorDelays }

        let api = HomeAssistantAPI(server: .fake())
        let connection = ScriptedConnectMockConnection(stateAfterConnect: .connecting)
        connection.delegate = api
        api.connection = connection

        // Starscream ignores NWConnection's `.waiting` and has no timeout on the upgrade response, so a
        // socket opened while the server is unreachable, or one whose handshake stalls across a
        // suspension, stays `.connecting` forever; `connectWebSocketIfNeeded` deliberately leaves it alone.
        connection.connect()
        drainMainQueue(cycles: 10)

        XCTAssertEqual(connection.disconnectCount, 1)
        XCTAssertEqual(connection.connectCount, 2)
    }

    func testConnectionDelegateLeavesAConnectAttemptThatCompletesInTime() {
        let priorDelays = HomeAssistantAPI.staleConnectingDelays
        HomeAssistantAPI.staleConnectingDelays = [0]
        defer { HomeAssistantAPI.staleConnectingDelays = priorDelays }

        let api = HomeAssistantAPI(server: .fake())
        let connection = ScriptedConnectMockConnection(stateAfterConnect: .connecting)
        connection.delegate = api
        api.connection = connection

        connection.setState(.connecting)
        connection.setState(.ready(version: "1.0-mock"))
        drainMainQueue(cycles: 10)

        XCTAssertEqual(connection.disconnectCount, 0)
        XCTAssertEqual(connection.connectCount, 0)
        XCTAssertEqual(connection.state, .ready(version: "1.0-mock"))
    }
}

/// A minimal `HAConnection` whose `connect()` always lands in one scripted state: rejected, to exercise
/// the reconnect-budget cap, or connecting, to mimic a socket whose upgrade never completes.
/// `HAMockConnection` is `public` (not `open`), so it can't be subclassed here.
private final class ScriptedConnectMockConnection: HAConnection {
    weak var delegate: HAConnectionDelegate?
    var configuration: HAConnectionConfiguration = .fake
    var callbackQueue: DispatchQueue = .main
    private(set) var connectCount = 0
    private(set) var disconnectCount = 0
    let stateAfterConnect: HAConnectionState

    init(stateAfterConnect: HAConnectionState) {
        self.stateAfterConnect = stateAfterConnect
    }

    lazy var caches: HACachesContainer = .init(connection: self)

    private(set) var state: HAConnectionState = .disconnected(reason: .disconnected) {
        didSet {
            callbackQueue.async { [self, state] in
                delegate?.connection(self, didTransitionTo: state)
            }
        }
    }

    func setState(_ state: HAConnectionState) {
        self.state = state
    }

    func connect() {
        connectCount += 1
        state = stateAfterConnect
    }

    func disconnect() {
        disconnectCount += 1
        state = .disconnected(reason: .disconnected)
    }

    private func noopCancellable() -> HACancellable { HAMockCancellable {} }

    func send(_ request: HARequest, completion: @escaping (Result<HAData, HAError>) -> Void) -> HACancellable {
        noopCancellable()
    }

    func send<T>(
        _ request: HATypedRequest<T>,
        completion: @escaping (Result<T, HAError>) -> Void
    ) -> HACancellable {
        noopCancellable()
    }

    func subscribe(
        to request: HARequest,
        handler: @escaping (HACancellable, HAData) -> Void
    ) -> HACancellable {
        noopCancellable()
    }

    func subscribe(
        to request: HARequest,
        initiated: @escaping (Result<HAData, HAError>) -> Void,
        handler: @escaping (HACancellable, HAData) -> Void
    ) -> HACancellable {
        noopCancellable()
    }

    func subscribe<T>(
        to request: HATypedSubscription<T>,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        noopCancellable()
    }

    func subscribe<T>(
        to request: HATypedSubscription<T>,
        initiated: @escaping (Result<HAData, HAError>) -> Void,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        noopCancellable()
    }
}

class HAAPIAutomaticWebSocketConnectTests: XCTestCase {
    private func drainMainQueue(cycles: Int = 2) {
        let expectation = expectation(description: "drain main queue")

        func schedule(_ remaining: Int) {
            DispatchQueue.main.async {
                if remaining == 0 {
                    expectation.fulfill()
                } else {
                    schedule(remaining - 1)
                }
            }
        }

        schedule(cycles)
        wait(for: [expectation], timeout: 10.0)
    }

    func testAutomaticConnectStartsDisconnectedConnection() {
        let api = HomeAssistantAPI(server: .fake())
        let connection = HAMockConnection()
        api.connection = connection

        api.connectWebSocketIfNeeded()
        drainMainQueue()

        XCTAssertEqual(connection.state, .ready(version: "1.0-mock"))
    }

    func testAutomaticConnectPreservesWaitingToReconnectState() {
        let api = HomeAssistantAPI(server: .fake())
        let connection = HAMockConnection()
        api.connection = connection

        let expectedState = HAConnectionState.disconnected(reason: .waitingToReconnect(
            lastError: URLError(.cannotConnectToHost),
            atLatest: Date(timeIntervalSinceNow: 30),
            retryCount: 3
        ))
        connection.setState(expectedState)

        api.connectWebSocketIfNeeded()
        drainMainQueue()

        XCTAssertEqual(connection.state, expectedState)
    }

    func testAutomaticConnectPreservesRejectedState() {
        let api = HomeAssistantAPI(server: .fake())
        let connection = HAMockConnection()
        api.connection = connection

        connection.setState(.disconnected(reason: .rejected))

        api.connectWebSocketIfNeeded()
        drainMainQueue()

        XCTAssertEqual(connection.state, .disconnected(reason: .rejected))
    }

    func testRetryAwareConnectionDoesNotReconnectWhileBackoffIsActive() {
        let underlying = HAMockConnection()
        // The mock otherwise flips to `.connecting` on any send; disable that so the test observes only
        // RetryAwareHAConnection's own connect gating, not the mock's behavior.
        underlying.automaticallyTransitionToConnecting = false
        let connection = RetryAwareHAConnection(underlying: underlying)
        let expectedState = HAConnectionState.disconnected(reason: .waitingToReconnect(
            lastError: URLError(.cannotConnectToHost),
            atLatest: Date(timeIntervalSinceNow: 30),
            retryCount: 3
        ))
        underlying.setState(expectedState)

        _ = connection.send(.init(type: .webSocket("ping")), completion: { _ in })
        drainMainQueue()

        XCTAssertEqual(underlying.state, expectedState)
    }

    func testRetryAwareConnectionReconnectsSocketRequestsFromIdleDisconnectedState() {
        let underlying = HAMockConnection()
        let connection = RetryAwareHAConnection(underlying: underlying)

        _ = connection.send(.init(type: .webSocket("ping")), completion: { _ in })
        drainMainQueue()

        XCTAssertEqual(underlying.state, .ready(version: "1.0-mock"))
    }

    func testRetryAwareConnectionDoesNotConnectRestRequests() {
        let underlying = HAMockConnection()
        // The mock otherwise flips to `.connecting` on any send; disable that so the test observes only
        // RetryAwareHAConnection's own connect gating, not the mock's behavior.
        underlying.automaticallyTransitionToConnecting = false
        let connection = RetryAwareHAConnection(underlying: underlying)

        _ = connection.send(.init(type: .rest(.get, "config")), completion: { _ in })
        drainMainQueue()

        XCTAssertEqual(underlying.state, .disconnected(reason: .disconnected))
        XCTAssertEqual(underlying.pendingRequests.count, 1)
    }
}
