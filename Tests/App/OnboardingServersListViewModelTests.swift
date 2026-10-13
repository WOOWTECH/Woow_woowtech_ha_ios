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
        let sut = OnboardingServersListViewModel()
        #expect(sut.discoveredInstances.isEmpty)
        #expect((mockBonjour.observer as? OnboardingServersListViewModel) != nil)
    }

    @Test func testStartDiscovery() async throws {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let sut = OnboardingServersListViewModel()

        sut.startDiscovery()
        #expect(sut.discoveredInstances.isEmpty)
        #expect(mockBonjour.startCalled)
    }

    @Test func testStopDiscovery() async throws {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let sut = OnboardingServersListViewModel()

        sut.stopDiscovery()
        #expect(mockBonjour.stopCalled)
    }

    @Test func testSelectInstance() async throws {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let sut = OnboardingServersListViewModel()
        let instance = DiscoveredHomeAssistant(
            manualURL: URL(string: "http://192.168.0.1:8123")!,
            name: "Home"
        )
        let dummyController = await UIViewController()
        sut.selectInstance(instance, controller: dummyController)

        #expect(sut.currentlyInstanceLoading == instance)
    }

    @Test func testResetFlow() async throws {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let sut = OnboardingServersListViewModel()

        sut.resetFlow()
        #expect(sut.currentlyInstanceLoading == nil)
        #expect(sut.isLoading == false)
    }
}
