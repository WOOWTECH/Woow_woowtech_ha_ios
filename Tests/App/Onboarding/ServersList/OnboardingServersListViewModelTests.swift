import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

@Suite(.serialized)
struct OnboardingServersListViewModelTests {
    @Test func testInitAddsSelfAsObserver() async throws {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let sut = OnboardingServersListViewModel(shouldDismissOnSuccess: false)
        assert(sut.discoveredInstances.isEmpty)
        assert((mockBonjour.observer as? OnboardingServersListViewModel) != nil)
    }

    @Test func testStartDiscovery() async throws {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let sut = OnboardingServersListViewModel(shouldDismissOnSuccess: false)

        sut.startDiscovery()
        assert(sut.discoveredInstances.isEmpty)
        assert(mockBonjour.startCalled)
    }

    @Test @MainActor
    func testDiscoveryDoesNotInjectDelayedTestServers() async throws {
        let originalBonjour = Current.bonjour
        let mockBonjour = MockBonjour()
        Current.bonjour = { mockBonjour }
        let sut = OnboardingServersListViewModel(shouldDismissOnSuccess: false)
        defer {
            sut.stopDiscovery()
            mockBonjour.observer = nil
            Current.bonjour = originalBonjour
        }

        sut.startDiscovery()
        #expect(mockBonjour.startCalled)
        #expect(sut.discoveredInstances.isEmpty)

        // The removed debug fixture first appeared after 1.5 seconds.
        try await Task.sleep(nanoseconds: 2_000_000_000)
        await drainDiscoveryCallbacks()
        #expect(sut.discoveredInstances.isEmpty)
    }

    @Test @MainActor
    func testRestartDiscoveryDoesNotLeaveDelayedTestServers() async throws {
        let originalBonjour = Current.bonjour
        let mockBonjour = MockBonjour()
        Current.bonjour = { mockBonjour }
        let sut = OnboardingServersListViewModel(shouldDismissOnSuccess: false)
        defer {
            sut.stopDiscovery()
            mockBonjour.observer = nil
            Current.bonjour = originalBonjour
        }

        sut.startDiscovery()
        sut.stopDiscovery()
        sut.startDiscovery()
        try await Task.sleep(nanoseconds: 2_000_000_000)
        await drainDiscoveryCallbacks()
        #expect(mockBonjour.stopCalled)
        #expect(sut.discoveredInstances.isEmpty)
    }

    @Test @MainActor
    func testBonjourInstancesRemainDiscoverableAndDeduplicated() async {
        let originalBonjour = Current.bonjour
        let mockBonjour = MockBonjour()
        Current.bonjour = { mockBonjour }
        let sut = OnboardingServersListViewModel(shouldDismissOnSuccess: false)
        defer {
            sut.stopDiscovery()
            mockBonjour.observer = nil
            Current.bonjour = originalBonjour
        }

        // Construct callback data only: this Bonjour instance never starts browsing.
        let bonjour = Bonjour()
        var first = DiscoveredHomeAssistant(manualURL: URL(string: "http://192.168.1.10:8123")!, name: "Home")
        first.bonjourName = "fixture-home"
        var second = DiscoveredHomeAssistant(manualURL: URL(string: "http://192.168.1.11:8123")!, name: "Home-2")
        second.bonjourName = "fixture-home-2"
        sut.startDiscovery()
        sut.bonjour(bonjour, didAdd: first)
        sut.bonjour(bonjour, didAdd: second)
        sut.bonjour(bonjour, didAdd: first)
        await drainDiscoveryCallbacks()
        #expect(sut.discoveredInstances == [first, second])

        sut.bonjour(bonjour, didRemoveInstanceWithName: "fixture-home")
        await drainDiscoveryCallbacks()
        #expect(sut.discoveredInstances == [second])
    }

    @MainActor
    private func drainDiscoveryCallbacks() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }

    @Test func testStopDiscovery() async throws {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let sut = OnboardingServersListViewModel(shouldDismissOnSuccess: false)

        sut.stopDiscovery()
        assert(mockBonjour.stopCalled)
    }

    @Test func testResetFlow() async throws {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let sut = OnboardingServersListViewModel(shouldDismissOnSuccess: false)

        sut.resetFlow()
        assert(sut.currentlyInstanceLoading == nil)
        assert(sut.manualInputLoading == false)
        assert(sut.invitationLoading == false)
    }
}
