import CoreLocation
import Foundation
import Shared
import UIKit

final class OnboardingPermissionsNavigationViewModel: NSObject, ObservableObject {
    /// Defines the different steps in the onboarding permissions flow
    enum StepID: String, CaseIterable, Identifiable {
        /// Initial disclaimer step explaining local access functionality
        case disclaimer
        /// Location permission request step for sharing location with Home Assistant
        case location
        /// Local access permission step for secure local connections
        case localAccess
        /// Home network SSID input step for trusted network configuration
        case homeNetwork
        /// Final completion step that triggers onboarding completion
        case completion
        /// Step indicating preferences were updated successfully
        case updatePreferencesSuccess

        var id: String { rawValue }

        /// Default onboarding flow steps
        static var `default`: [StepID] = [.disclaimer, .location, .localAccess, .homeNetwork, .completion]
        /// Flow when user already has remote connection setup, skipping local access disclaimer
        static var remoteConnectionCompatible: [StepID] = [.location, .localAccess, .homeNetwork, .completion]
        /// Flow for updating local access security level preference
        static var updateLocalAccessSecurityLevelPreference: [StepID] = [
            .localAccess,
            .homeNetwork,
            .updatePreferencesSuccess,
        ]
        /// Flow for updating location permission preference
        static var updateLocationPermission: [StepID] = [
            .location,
            .localAccess,
            .homeNetwork,
            .updatePreferencesSuccess,
        ]
    }

    /// Tracks the context in which location permission is being requested
    enum LocationPermissionContext {
        /// Location permission has not been requested yet
        case notRequested
        /// Location permission is being requested to share location data with Home Assistant
        case shareWithHomeAssistant
        /// Location permission is being requested for secure local network connections
        case secureLocalConnection
        /// Location permission is being requested so iOS records the user's less secure local connection decision
        case lessSecureLocalConnection
    }

    // MARK: - Published Properties

    /// Current step index in the onboarding flow (0-based)
    @Published var currentStepIndex: Int = 0

    /// The context in which location permission is being requested
    @Published var locationPermissionContext: LocationPermissionContext = .notRequested

    /// SSID Stored into server settings
    @Published var storedSSIDSuccessfully: Bool = false

    /// 使用者選了「最安全」但位置權限被拒時,顯示說明視窗讓使用者自己決定下一步。
    @Published var isShowingLocationRequiredForMostSecure: Bool = false

    // MARK: - Private Properties

    /// Tracks the previous step index for determining animation direction
    private var lastStepIndex: Int = 0

    private let locationManager = CLLocationManager()
    private let onboardingServer: Server
    /// 注入點,讓測試能模擬「權限早已被拒」;正式執行讀 CLLocationManager。
    private let permissionStatus: () -> CLAuthorizationStatus
    private let urlOpener: URLOpening

    // MARK: - Step Management

    /// Returns all available steps in the onboarding flow
    let steps: [StepID]

    /// Determines if the user is advancing forward through the steps (for animation purposes)
    var isAdvancing: Bool {
        currentStepIndex >= lastStepIndex
    }

    /// Returns the current step based on the current step index
    var currentStep: StepID {
        guard currentStepIndex < steps.count else { return .completion }
        return steps[currentStepIndex]
    }

    init(
        onboardingServer: Server,
        steps: [StepID]? = nil,
        permissionStatus: @escaping () -> CLAuthorizationStatus = { Current.location.permissionStatus },
        urlOpener: URLOpening = URLOpener.shared
    ) {
        self.onboardingServer = onboardingServer
        self.permissionStatus = permissionStatus
        self.urlOpener = urlOpener

        if let customSteps = steps {
            // Use externally provided steps
            self.steps = customSteps
        } else {
            // Use default logic to determine steps
            let connection = onboardingServer.info.connection
            var defaultSteps = StepID.default

            // No need to display local access only disclaimer when user already has remote connection setup
            if connection.hasRemoteConnectionSetup {
                defaultSteps = StepID.remoteConnectionCompatible
            }

            if connection.hasOnlyHTTPSURLOptions {
                defaultSteps.removeAll { $0 == .localAccess }
            }
            self.steps = defaultSteps
        }

        super.init()
    }

    // MARK: - Navigation Methods

    /// Navigates to a specific step in the onboarding flow
    /// - Parameter index: The target step index (0-based)
    /// - Note: Provides haptic feedback for forward navigation and validates bounds
    func navigateToStep(at index: Int) {
        guard index >= 0, index < steps.count else { return }

        // Add haptic feedback for forward navigation
        if index > currentStepIndex {
            Current.impactFeedback.impactOccurred()
        }

        // Update the last step after deciding transition direction
        lastStepIndex = currentStepIndex
        currentStepIndex = index
    }

    /// Navigates to a specific step by its identifier
    func navigateToStep(_ stepId: StepID) {
        if let index = steps.firstIndex(of: stepId) {
            navigateToStep(at: index)
        }
    }

    /// Advances to the next step in the onboarding flow
    /// - Note: Uses navigateToStep internally to handle bounds checking and feedback
    func nextStep() {
        navigateToStep(at: currentStepIndex + 1)
    }

    // MARK: - Step-Specific Actions

    /// Saves the home network SSID to the onboarding server configuration
    /// - Parameter ssid: The network SSID to save for trusted local connections
    /// - Note: This is used in the homeNetwork step to configure secure local access
    func saveHomeNetwork(_ context: HomeNetworkInputView.SubmitContext) {
        onboardingServer.update { [weak self] info in
            if let ssid = context.networkName {
                info.connection.internalSSIDs = [ssid]
            }
            if let hardwareAddress = context.hardwareAddress {
                info.connection.internalHardwareAddresses = [hardwareAddress]
            }
            DispatchQueue.main.async {
                self?.storedSSIDSuccessfully = true
            }
        }
    }

    // MARK: - Location Permission Management

    /// Requests location permission specifically for sharing location data with Home Assistant
    /// - Note: Sets context to shareWithHomeAssistant before requesting permission
    func requestLocationPermissionToShareWithHomeAssistant() {
        locationPermissionContext = .shareWithHomeAssistant
        requestLocationPermission()
    }

    /// Requests location permission specifically for secure local network connections
    /// - Note: Sets context to secureLocalConnection before requesting permission
    func requestLocationPermissionForSecureLocalConnection() {
        locationPermissionContext = .secureLocalConnection
        requestLocationPermission()
    }

    /// Requests location permission specifically for less secure local network connections
    /// - Note: Sets context to lessSecureLocalConnection before requesting permission
    func requestLocationPermissionForLessSecureLocalConnection() {
        locationPermissionContext = .lessSecureLocalConnection
        requestLocationPermission()
    }

    /// 說明視窗「開啟設定」:使用者自己選擇前往設定 App 開啟位置權限。
    func openSettingsForMostSecure() {
        isShowingLocationRequiredForMostSecure = false
        // 只有這裡、而且是使用者自己按下之後,才開啟設定 App(5.1.1(iv))。
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            urlOpener.open(settingsUrl, options: [:], completionHandler: nil)
        }
    }

    /// 說明視窗「改用較不安全」:套用較不安全的連線方式並略過本地連線設定。
    func useLessSecureInsteadOfMostSecure() {
        isShowingLocationRequiredForMostSecure = false
        setLessSecureLocalConnection()
        navigatePastLocalAccessConfiguration()
    }

    /// Configures the server for less secure local connections (when location permission is denied)
    /// - Note: Sets security level to .lessSecure as fallback option
    func setLessSecureLocalConnection() {
        onboardingServer.update { info in
            info.connection.connectionAccessSecurityLevel = .lessSecure
        }
    }

    /// Disables location-related sensors when permission is denied or not wanted
    /// - Note: Affects geocoded location, WiFi BSSID, and SSID sensors
    func disableLocationSensor() {
        onboardingServer.info.setSetting(value: ServerLocationPrivacy.never, for: .locationPrivacy)
    }

    // MARK: - Private Location Methods

    /// Enables location-related sensors when permission is granted
    /// - Note: Affects geocoded location, WiFi BSSID, and SSID sensors
    private func enableLocationSensor() {
        onboardingServer.info.setSetting(value: ServerLocationPrivacy.exact, for: .locationPrivacy)
    }

    /// Handles the actual location permission request based on current authorization status
    /// - Note: Follows the existing decision if denied/restricted (never opens Settings on its own),
    ///         grants immediately if already authorized, or requests permission if not determined
    private func requestLocationPermission() {
        switch permissionStatus() {
        case .denied, .restricted:
            // ⚠️ 這裡絕對不能自己開設定 App。Apple 2026-09-23 以 5.1.1(iv) 退件:
            //    "The user is redirected to the Settings app to grant access before showing
            //     the permission request." 權限早已被拒(或定位服務整體關閉)時,
            //    系統對話框不會再出現,只能照使用者既有的決定處理。
            switch locationPermissionContext {
            case .lessSecureLocalConnection:
                applyLocationPermissionNeeds()
            case .shareWithHomeAssistant:
                // 等同使用者拒絕:關閉位置感測器並前進。
                disableLocationSensor()
                nextStep()
            case .secureLocalConnection:
                // 「最安全」需要位置;交給說明視窗,由使用者決定開設定、改較不安全或取消。
                isShowingLocationRequiredForMostSecure = true
            case .notRequested:
                break
            }
        case .authorizedWhenInUse, .authorizedAlways:
            // Permission already granted, apply the context-specific needs
            applyLocationPermissionNeeds()
        default:
            // Permission not determined, request it from the system
            locationManager.delegate = self
            locationManager.requestWhenInUseAuthorization()
        }
    }

    /// Applies the appropriate configuration based on the location permission context
    /// - Note: Enables sensors for Home Assistant sharing or sets security level for local connections
    private func applyLocationPermissionNeeds() {
        if locationPermissionContext == .shareWithHomeAssistant {
            // Enable location sensors for sharing with Home Assistant
            enableLocationSensor()
        }

        if locationPermissionContext == .secureLocalConnection {
            // Configure most secure local connection using location data
            onboardingServer.update { info in
                info.connection.connectionAccessSecurityLevel = .mostSecure
            }
        }

        if locationPermissionContext == .lessSecureLocalConnection {
            setLessSecureLocalConnection()
            navigatePastLocalAccessConfiguration()
            return
        }

        nextStep()
    }

    private func navigatePastLocalAccessConfiguration() {
        if steps.contains(.completion) {
            navigateToStep(.completion)
        } else if steps.contains(.updatePreferencesSuccess) {
            navigateToStep(.updatePreferencesSuccess)
        } else {
            nextStep()
        }
    }
}

// MARK: - CLLocationManagerDelegate Protocol

extension OnboardingPermissionsNavigationViewModel: CLLocationManagerDelegate {
    /// Handles changes in location authorization status during the onboarding flow
    /// - Parameter manager: The location manager that triggered the authorization change
    /// - Note: This is called when the user responds to location permission requests
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined:
            // Initial state - no action needed yet
            break
        case .restricted:
            // Location services restricted by parental controls or device management
            break
        case .denied:
            // User explicitly denied location access - disable related sensors
            disableLocationSensor()
            if locationPermissionContext == .lessSecureLocalConnection {
                applyLocationPermissionNeeds()
            } else if locationPermissionContext == .shareWithHomeAssistant {
                // ⚠️ 必須推進流程。App Store 審查指南 5.1.1(iv) 不允許在系統對話框之前
                //    提供繞過它的出口,所以位置頁的「Do not share my location」已移除,
                //    系統對話框的「不允許」成為唯一的拒絕入口。
                //
                //    此處若不推進,使用者會卡在位置頁:授權狀態已是 .denied,僅存的
                //    主按鈕會走 requestLocationPermission() 的 .denied 分支去開啟
                //    iOS 設定 App,再也回不到上線流程。
                //
                //    這裡刻意不呼叫 applyLocationPermissionNeeds() —— 那會連帶
                //    enableLocationSensor(),與使用者剛表達的拒絕相反。
                nextStep()
            } else if locationPermissionContext == .secureLocalConnection {
                // 「最安全」需要位置權限。使用者剛拒絕,不能卡住,也不能自己跳設定 App
                // (5.1.1(iv),Apple 2026-09-23 退件)—— 交給說明視窗讓使用者決定。
                isShowingLocationRequiredForMostSecure = true
            }
        case .authorizedAlways:
            // Full location access granted - no additional action needed
            break
        case .authorizedWhenInUse:
            // Limited location access - request always authorization for better functionality
            manager.requestAlwaysAuthorization()
        case .authorized:
            // Legacy authorization status - handled below
            break
        @unknown default:
            // Handle future authorization statuses
            break
        }

        // Only proceed if we have some form of location authorization
        // No need to proceed if permission is .authorizedAlways since the code has run before for .authorizedWhenInUse
        guard manager.authorizationStatus == .authorizedWhenInUse else { return }
        applyLocationPermissionNeeds()
    }
}
