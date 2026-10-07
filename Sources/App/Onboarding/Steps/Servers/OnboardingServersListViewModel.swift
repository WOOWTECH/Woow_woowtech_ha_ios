import Combine
import Foundation
import PromiseKit
import Shared
import SwiftUI

final class OnboardingServersListViewModel: ObservableObject {
    enum Destination {
        case error(Error)
        case next(Server)
    }

    @Published var discoveredInstances: [DiscoveredHomeAssistant] = []
    @Published var currentlyInstanceLoading: DiscoveredHomeAssistant?

    @Published var showError = false
    @Published var error: Error?

    @Published var showPermissionsFlow = false
    @Published var shouldDismiss = false
    @Published var onboardingServer: Server?
    var permissionsFlowCompleted = false

    @Published var manualInputLoading = false
    @Published var invitationLoading = false
    @Published var showCenterLoader = true

    private var webhookSensors: [WebhookSensor] = []
    private var discovery = Current.bonjour()
    private var cancellables = Set<AnyCancellable>()
    private let shouldDismissOnSuccess: Bool

    init(shouldDismissOnSuccess: Bool) {
        self.shouldDismissOnSuccess = shouldDismissOnSuccess
        discovery.observer = self
        Current.sensors.register(observer: self)
        Current.onboardingObservation.register(observer: self)
    }

    func startDiscovery() {
        discoveredInstances = []
        // Only Bonjour discoveries belong here, including in development builds.
        // Public HTTP/TLS test sites must not be offered as Home Assistant servers.
        discovery.start()
    }

    func stopDiscovery() {
        discovery.stop()
    }

    func selectInstance(_ instance: DiscoveredHomeAssistant, presentingController: UIViewController) {
        Current.Log.verbose("Selected instance \(instance)")

        currentlyInstanceLoading = instance

        let authentication = OnboardingAuth()

        authentication.authenticate(to: instance, sender: presentingController).pipe { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case let .fulfilled(server):
                    Current.Log.verbose("Onboarding authentication succeeded")
                    self?.authenticationSucceeded(server: server)
                case let .rejected(error):
                    if let pmkError = error as? PMKError, pmkError.isCancelled {
                        /* No action needed, user cancelled flow */
                        self?.resetFlow()
                    } else {
                        self?.error = error
                        self?.showError = true
                    }
                }
                self?.resetSpecificLoaders()
            }
        }
    }

    private func resetSpecificLoaders() {
        manualInputLoading = false
        invitationLoading = false
    }

    func resetFlow() {
        currentlyInstanceLoading = nil
        resetSpecificLoaders()
    }

    @MainActor
    private func authenticationSucceeded(server: Server) {
        discovery.stop()
        onboardingServer = server
        disableNonEssentialSensors(server)
        showPermissionsFlow = true
    }

    private func disableNonEssentialSensors(_ server: Server) {
        guard Current.servers.all.count == 1 else {
            Current.Log.verbose("Avoid overriding sensors if user has already servers setup in place.")
            return
        }
        let sensorsToKeepEnabled: [WebhookSensorId] = [
            .appVersion,
            .locationPermission,
        ]
        for sensor in webhookSensors {
            if let uniqueId = sensor.UniqueID,
               uniqueId.contains("battery") || sensorsToKeepEnabled.map(\.rawValue).contains(uniqueId) {
                Current.sensors.setEnabled(true, for: sensor)
            } else {
                Current.sensors.setEnabled(false, for: sensor)
            }
        }
    }
}

extension OnboardingServersListViewModel: BonjourObserver {
    func bonjour(_ bonjour: Bonjour, didAdd instance: DiscoveredHomeAssistant) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Prevent duplicates by checking if instance already exists
            if !discoveredInstances.contains(instance) {
                discoveredInstances.append(instance)
            }
        }
    }

    func bonjour(_ bonjour: Bonjour, didRemoveInstanceWithName name: String) {
        DispatchQueue.main.async { [weak self] in
            self?.discoveredInstances.removeAll { $0.bonjourName == name }
        }
    }
}

extension OnboardingServersListViewModel: SensorObserver {
    func sensorContainer(
        _ container: SensorContainer,
        didSignalForUpdateBecause reason: SensorContainerUpdateReason,
        lastUpdate: SensorObserverUpdate?
    ) {
        /* no-op */
    }

    func sensorContainer(_ container: SensorContainer, didUpdate update: SensorObserverUpdate) {
        update.sensors.done { [weak self] sensors in
            self?.webhookSensors = sensors
        }
    }
}

extension OnboardingServersListViewModel: OnboardingStateObserver {
    func onboardingStateDidChange(to state: OnboardingState) {
        if state == .complete, shouldDismissOnSuccess {
            shouldDismiss = true
        }
    }
}
