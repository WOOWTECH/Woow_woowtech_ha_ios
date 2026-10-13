import CoreLocation
import Foundation
@testable import HomeAssistant
import Shared
import Testing
import UIKit

// MARK: - Test Fixtures

@Suite("OnboardingPermissionsNavigationViewModel Tests")
struct OnboardingPermissionsNavigationViewModelTests {
    // MARK: - Initialization Tests

    @Test("Initialization with default steps")
    func initializationWithDefaultSteps() async throws {
        ServerFixture.reset()
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)

        #expect(viewModel.steps == OnboardingPermissionsNavigationViewModel.StepID.default)
        #expect(viewModel.currentStepIndex == 0)
        #expect(viewModel.locationPermissionContext == .notRequested)
        #expect(viewModel.currentStep == .disclaimer)
    }

    @Test("Initialization with remote connection setup")
    func initializationWithRemoteConnectionSetup() async throws {
        let server = ServerFixture.withRemoteConnection
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)

        #expect(viewModel.steps == OnboardingPermissionsNavigationViewModel.StepID.remoteConnectionCompatible)
        #expect(viewModel.currentStep == .location)
    }

    @Test("Initialization with HTTPS-only URLs skips local access step")
    func initializationWithHTTPSOnlyURLsSkipsLocalAccessStep() async throws {
        var info = ServerInfo(
            name: "HTTPS Only Server",
            connection: .init(
                externalURL: URL(string: "https://external.example.com")!,
                internalURL: URL(string: "https://internal.example.com")!,
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: nil,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(exceptions: []),
                connectionAccessSecurityLevel: .undefined
            ),
            token: .init(
                accessToken: "access-token",
                refreshToken: "refresh-token",
                expiration: Date()
            ),
            version: "2026.1.0"
        )
        let server = Server(identifier: "https-only", getter: {
            info
        }, setter: { newInfo in
            info = newInfo
            return true
        })
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)

        #expect(viewModel.steps == [.location, .homeNetwork, .completion])
        #expect(viewModel.steps.contains(.localAccess) == false)
        #expect(viewModel.currentStep == .location)
    }

    @Test("Initialization with custom steps")
    func initializationWithCustomSteps() async throws {
        let server = ServerFixture.standard
        let customSteps: [OnboardingPermissionsNavigationViewModel.StepID] = [.location, .completion]
        let viewModel = OnboardingPermissionsNavigationViewModel(
            onboardingServer: server,
            steps: customSteps
        )

        #expect(viewModel.steps == customSteps)
        #expect(viewModel.currentStep == .location)
    }

    // MARK: - Step Management Tests

    @Test("Current step returns correct step")
    func currentStepReturnsCorrectStep() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)

        #expect(viewModel.currentStep == .disclaimer)

        viewModel.navigateToStep(at: 1)
        #expect(viewModel.currentStep == .location)

        viewModel.navigateToStep(at: 2)
        #expect(viewModel.currentStep == .localAccess)
    }

    @Test("Current step handles out of bounds index")
    func currentStepHandlesOutOfBoundsIndex() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)

        // Test the computed property behavior when currentStepIndex is out of bounds
        // We need to manually set currentStepIndex since navigateToStep has bounds checking
        viewModel.currentStepIndex = 999 // Directly set out of bounds index
        #expect(viewModel.currentStep == .completion)

        // Also test that navigateToStep prevents out of bounds navigation
        let originalIndex = 0
        viewModel.currentStepIndex = originalIndex
        viewModel.navigateToStep(at: 999) // Should not change currentStepIndex
        #expect(viewModel.currentStepIndex == originalIndex)
    }

    @Test("Is advancing detection")
    func isAdvancingDetection() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)

        // Initially advancing (0 >= 0)
        #expect(viewModel.isAdvancing == true)

        // Move forward
        viewModel.navigateToStep(at: 2)
        #expect(viewModel.isAdvancing == true)

        // Move backward
        viewModel.navigateToStep(at: 1)
        #expect(viewModel.isAdvancing == false)
    }

    // MARK: - Navigation Tests

    @Test("Navigate to step by index")
    func navigateToStepByIndex() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)

        viewModel.navigateToStep(at: 2)
        #expect(viewModel.currentStepIndex == 2)
        #expect(viewModel.currentStep == .localAccess)
    }

    @Test("Navigate to step by index with bounds checking")
    func navigateToStepByIndexWithBoundsChecking() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        let initialIndex = viewModel.currentStepIndex

        // Test negative index
        viewModel.navigateToStep(at: -1)
        #expect(viewModel.currentStepIndex == initialIndex) // Should not change

        // Test index too high
        viewModel.navigateToStep(at: 999)
        #expect(viewModel.currentStepIndex == initialIndex) // Should not change
    }

    @Test("Navigate to step by identifier")
    func navigateToStepByIdentifier() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)

        viewModel.navigateToStep(.location)
        #expect(viewModel.currentStep == .location)
        #expect(viewModel.currentStepIndex == 1)

        viewModel.navigateToStep(.completion)
        #expect(viewModel.currentStep == .completion)
        #expect(viewModel.currentStepIndex == 4)
    }

    @Test("Navigate to step by non-existent identifier")
    func navigateToStepByNonExistentIdentifier() async throws {
        let server = ServerFixture.standard
        let customSteps: [OnboardingPermissionsNavigationViewModel.StepID] = [.location, .completion]
        let viewModel = OnboardingPermissionsNavigationViewModel(
            onboardingServer: server,
            steps: customSteps
        )
        let initialIndex = viewModel.currentStepIndex

        viewModel.navigateToStep(.disclaimer) // Not in custom steps
        #expect(viewModel.currentStepIndex == initialIndex) // Should not change
    }

    @Test("Next step navigation")
    func nextStepNavigation() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)

        #expect(viewModel.currentStepIndex == 0)

        viewModel.nextStep()
        #expect(viewModel.currentStepIndex == 1)
        #expect(viewModel.currentStep == .location)

        viewModel.nextStep()
        #expect(viewModel.currentStepIndex == 2)
        #expect(viewModel.currentStep == .localAccess)
    }

    // MARK: - Network SSID Tests

    @Test("Save Home Network")
    func saveHomeNetwork() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)

        let testSSID = "TestNetwork"
        viewModel.saveHomeNetwork(.init(networkName: testSSID, hardwareAddress: nil))

        #expect(server.info.connection.internalSSIDs == [testSSID])
    }

    // MARK: - Location Permission Context Tests

    @Test("Request location permission for Home Assistant sharing")
    func requestLocationPermissionForHomeAssistantSharing() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)

        viewModel.requestLocationPermissionToShareWithHomeAssistant()
        #expect(viewModel.locationPermissionContext == .shareWithHomeAssistant)
    }

    @Test("Request location permission for secure local connection")
    func requestLocationPermissionForSecureLocalConnection() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)

        viewModel.requestLocationPermissionForSecureLocalConnection()
        #expect(viewModel.locationPermissionContext == .secureLocalConnection)
    }

    @Test("Choosing most secure when location is already denied asks the user instead of opening Settings")
    func choosingMostSecureWhenAlreadyDeniedAsksTheUser() async throws {
        // 這正是 Apple 2026-09-23 退件的路徑:位置頁已拒絕 → 本地連線頁預設「最安全」→ 按 Next
        // → 舊版直接跳設定 App,完全沒有顯示權限請求(5.1.1(iv))。
        let server = ServerFixture.standard
        let urlOpener = MockURLOpener()
        let viewModel = OnboardingPermissionsNavigationViewModel(
            onboardingServer: server,
            permissionStatus: { .denied },
            urlOpener: urlOpener
        )
        viewModel.navigateToStep(.localAccess)

        viewModel.requestLocationPermissionForSecureLocalConnection()

        #expect(urlOpener.openedURLs.isEmpty)
        #expect(viewModel.isShowingLocationRequiredForMostSecure)
        #expect(viewModel.currentStep == .localAccess)
    }

    @Test("Sharing location when it is already denied moves on without opening Settings")
    func sharingLocationWhenAlreadyDeniedMovesOn() async throws {
        // 裝置整體關閉定位服務時,第一次按「Share my location」狀態就已是 .denied。
        // 等同使用者拒絕:關閉位置感測器並前進,不能自己跳設定 App。
        let server = ServerFixture.standard
        let urlOpener = MockURLOpener()
        let viewModel = OnboardingPermissionsNavigationViewModel(
            onboardingServer: server,
            permissionStatus: { .denied },
            urlOpener: urlOpener
        )
        viewModel.navigateToStep(.location)
        let locationIndex = viewModel.currentStepIndex

        viewModel.requestLocationPermissionToShareWithHomeAssistant()

        #expect(urlOpener.openedURLs.isEmpty)
        #expect(server.info.setting(for: .locationPrivacy) == .never)
        #expect(viewModel.currentStepIndex == locationIndex + 1)
    }

    @Test("Opening Settings from the most-secure dialog is the user's own choice")
    func openingSettingsFromMostSecureDialog() async throws {
        // Apple 退件信建議的做法:說明原因並「提供」設定 App 的連結,由使用者自己按。
        let server = ServerFixture.standard
        let urlOpener = MockURLOpener()
        let viewModel = OnboardingPermissionsNavigationViewModel(
            onboardingServer: server,
            permissionStatus: { .denied },
            urlOpener: urlOpener
        )
        viewModel.navigateToStep(.localAccess)
        viewModel.requestLocationPermissionForSecureLocalConnection()

        viewModel.openSettingsForMostSecure()

        #expect(urlOpener.openedURLs.map(\.url.absoluteString) == [UIApplication.openSettingsURLString])
        #expect(viewModel.isShowingLocationRequiredForMostSecure == false)
    }

    @Test("Choosing less secure from the most-secure dialog applies it and moves past local access")
    func choosingLessSecureFromMostSecureDialog() async throws {
        let server = ServerFixture.standard
        let urlOpener = MockURLOpener()
        let viewModel = OnboardingPermissionsNavigationViewModel(
            onboardingServer: server,
            permissionStatus: { .denied },
            urlOpener: urlOpener
        )
        viewModel.navigateToStep(.localAccess)
        viewModel.requestLocationPermissionForSecureLocalConnection()

        viewModel.useLessSecureInsteadOfMostSecure()

        #expect(server.info.connection.connectionAccessSecurityLevel == .lessSecure)
        #expect(viewModel.currentStep == .completion)
        #expect(viewModel.isShowingLocationRequiredForMostSecure == false)
        #expect(urlOpener.openedURLs.isEmpty)
    }

    @Test("Set less secure local connection")
    func setLessSecureLocalConnection() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)

        viewModel.setLessSecureLocalConnection()
        #expect(server.info.connection.connectionAccessSecurityLevel == .lessSecure)
    }

    @Test("Request location permission for less secure local connection")
    func requestLocationPermissionForLessSecureLocalConnection() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)

        viewModel.requestLocationPermissionForLessSecureLocalConnection()
        #expect(viewModel.locationPermissionContext == .lessSecureLocalConnection)
    }

    @Test("Disable location sensor")
    func disableLocationSensor() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)

        viewModel.disableLocationSensor()

        let locationPrivacy = server.info.setting(for: .locationPrivacy)
        #expect(locationPrivacy == .never)
    }

    // MARK: - StepID Tests

    @Test("StepID identifiable conformance")
    func stepIDIdentifiableConformance() async throws {
        let step = OnboardingPermissionsNavigationViewModel.StepID.disclaimer
        #expect(step.id == "disclaimer")
        #expect(step.id == step.rawValue)
    }

    @Test("StepID case iteration")
    func stepIDCaseIteration() async throws {
        let allCases = OnboardingPermissionsNavigationViewModel.StepID.allCases
        #expect(allCases.contains(.disclaimer))
        #expect(allCases.contains(.location))
        #expect(allCases.contains(.localAccess))
        #expect(allCases.contains(.homeNetwork))
        #expect(allCases.contains(.completion))
        #expect(allCases.contains(.updatePreferencesSuccess))
    }

    @Test("StepID static flow configurations")
    func stepIDStaticFlowConfigurations() async throws {
        let defaultFlow = OnboardingPermissionsNavigationViewModel.StepID.default
        #expect(defaultFlow == [.disclaimer, .location, .localAccess, .homeNetwork, .completion])

        let remoteCompatibleFlow = OnboardingPermissionsNavigationViewModel.StepID.remoteConnectionCompatible
        #expect(remoteCompatibleFlow == [.location, .localAccess, .homeNetwork, .completion])

        let updateLocalAccessFlow = OnboardingPermissionsNavigationViewModel.StepID
            .updateLocalAccessSecurityLevelPreference
        #expect(updateLocalAccessFlow == [.localAccess, .homeNetwork, .updatePreferencesSuccess])

        let updateLocationFlow = OnboardingPermissionsNavigationViewModel.StepID.updateLocationPermission
        #expect(updateLocationFlow == [.location, .localAccess, .homeNetwork, .updatePreferencesSuccess])
    }

    // MARK: - LocationPermissionContext Tests

    @Test("LocationPermissionContext enum cases")
    func locationPermissionContextEnumCases() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)

        // Test initial state
        #expect(viewModel.locationPermissionContext == .notRequested)

        // Test setting different contexts
        viewModel.locationPermissionContext = .shareWithHomeAssistant
        #expect(viewModel.locationPermissionContext == .shareWithHomeAssistant)

        viewModel.locationPermissionContext = .secureLocalConnection
        #expect(viewModel.locationPermissionContext == .secureLocalConnection)

        viewModel.locationPermissionContext = .lessSecureLocalConnection
        #expect(viewModel.locationPermissionContext == .lessSecureLocalConnection)

        viewModel.locationPermissionContext = .notRequested
        #expect(viewModel.locationPermissionContext == .notRequested)
    }
}

// MARK: - Location Manager Delegate Tests

@Suite("OnboardingPermissionsNavigationViewModel Location Delegate Tests")
struct OnboardingPermissionsNavigationViewModelLocationDelegateTests {
    init() {
        // Reset fixtures before each test suite
        ServerFixture.reset()
    }

    @Test("Location manager authorization change - when in use granted")
    func locationManagerAuthorizationChangeWhenInUse() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        viewModel.locationPermissionContext = .shareWithHomeAssistant

        // Create a mock location manager
        let mockLocationManager = MockCLLocationManager()
        mockLocationManager.authorizationStatus = .authorizedWhenInUse

        // Simulate authorization change
        viewModel.locationManagerDidChangeAuthorization(mockLocationManager)

        // Should advance to next step
        #expect(viewModel.currentStepIndex == 1)
    }

    @Test("Location manager authorization change - denied")
    func locationManagerAuthorizationChangeDenied() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)

        let mockLocationManager = MockCLLocationManager()
        mockLocationManager.authorizationStatus = .denied

        viewModel.locationManagerDidChangeAuthorization(mockLocationManager)

        // Should disable location sensor
        let locationPrivacy = server.info.setting(for: .locationPrivacy)
        #expect(locationPrivacy == .never)
    }

    @Test("Location manager authorization change - denied while sharing with Home Assistant advances")
    func locationManagerAuthorizationChangeDeniedWhileSharingAdvances() async throws {
        // App Store 審查指南 5.1.1(iv):上線流程的位置頁不得提供繞過系統對話框的出口,
        // 因此「Do not share my location」那顆次要按鈕已移除,系統對話框的「不允許」
        // 成為唯一的拒絕入口。
        //
        // ⚠️ 這裡若不推進流程,使用者按下「不允許」就會卡在位置頁:此時授權狀態已是
        //    .denied,僅存的主按鈕會走 requestLocationPermission() 的 .denied 分支
        //    去開啟 iOS 設定 App,永遠回不到上線流程。
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        viewModel.locationPermissionContext = .shareWithHomeAssistant

        let mockLocationManager = MockCLLocationManager()
        mockLocationManager.authorizationStatus = .denied

        viewModel.locationManagerDidChangeAuthorization(mockLocationManager)

        // 拒絕時仍然關閉位置感測器——這一點不能因為推進流程而失效。
        #expect(server.info.setting(for: .locationPrivacy) == .never)
        // 而且流程必須往前走。
        #expect(viewModel.currentStepIndex == 1)
    }

    @Test("Location manager authorization change - denied while choosing most secure asks the user")
    func locationManagerAuthorizationChangeDeniedWhileChoosingMostSecureAsksTheUser() async throws {
        // App Store 審查指南 5.1.1(iv),Apple 2026-09-23 退件:
        // "The user is redirected to the Settings app to grant access before showing the permission request."
        // 「最安全」需要位置權限。使用者拒絕後,App 不得自己跳設定 App,也不能讓流程卡住;
        // 要改成跳出說明視窗,由使用者決定開啟設定、改用較不安全,或取消。
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        viewModel.navigateToStep(.localAccess)
        viewModel.locationPermissionContext = .secureLocalConnection

        let mockLocationManager = MockCLLocationManager()
        mockLocationManager.authorizationStatus = .denied

        viewModel.locationManagerDidChangeAuthorization(mockLocationManager)

        #expect(viewModel.isShowingLocationRequiredForMostSecure)
        #expect(viewModel.currentStep == .localAccess)
    }

    @Test("Location manager authorization change - denied after less secure selection advances")
    func locationManagerAuthorizationChangeDeniedAfterLessSecureSelectionAdvances() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        viewModel.navigateToStep(.localAccess)
        viewModel.locationPermissionContext = .lessSecureLocalConnection

        let mockLocationManager = MockCLLocationManager()
        mockLocationManager.authorizationStatus = .denied

        viewModel.locationManagerDidChangeAuthorization(mockLocationManager)

        #expect(server.info.setting(for: .locationPrivacy) == .never)
        #expect(server.info.connection.connectionAccessSecurityLevel == .lessSecure)
        #expect(viewModel.currentStep == .completion)
    }

    @Test("Location manager authorization change - when in use after less secure selection advances")
    func locationManagerAuthorizationChangeWhenInUseAfterLessSecureSelectionAdvances() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        viewModel.navigateToStep(.localAccess)
        viewModel.locationPermissionContext = .lessSecureLocalConnection

        let mockLocationManager = MockCLLocationManager()
        mockLocationManager.authorizationStatus = .authorizedWhenInUse

        viewModel.locationManagerDidChangeAuthorization(mockLocationManager)

        #expect(server.info.connection.connectionAccessSecurityLevel == .lessSecure)
        #expect(viewModel.currentStep == .completion)
    }

    @Test("Location manager authorization change - not determined")
    func locationManagerAuthorizationChangeNotDetermined() async throws {
        let server = ServerFixture.standard
        let viewModel = OnboardingPermissionsNavigationViewModel(onboardingServer: server)
        let initialStepIndex = viewModel.currentStepIndex

        let mockLocationManager = MockCLLocationManager()
        mockLocationManager.authorizationStatus = .notDetermined

        viewModel.locationManagerDidChangeAuthorization(mockLocationManager)

        // Should not advance step
        #expect(viewModel.currentStepIndex == initialStepIndex)
    }
}

// MARK: - Mock Classes

/// Mock CLLocationManager for testing
class MockCLLocationManager: CLLocationManager {
    private var _authorizationStatus: CLAuthorizationStatus = .notDetermined

    override var authorizationStatus: CLAuthorizationStatus {
        get { _authorizationStatus }
        set { _authorizationStatus = newValue }
    }
}
