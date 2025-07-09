import Foundation
import Swinject
import DeenAssistCore
import DeenAssistProtocols

class DependencyContainer: ObservableObject {
    static let shared = DependencyContainer()
    let container = Container()
    
    private init() {
        registerServices()
    }
    
    private func registerServices() {
        // Foundational Services (no dependencies)
        container.register(LocationService.self) { _ in LocationService() }.inObjectScope(.container)
        container.register(LocationServiceProtocol.self) { r in
            guard let svc = r.resolve(LocationService.self) else {
                print("[DependencyContainer] Warning: LocationService not registered.")
                return nil
            }
            return svc
        }

        container.register(NetworkMonitor.self) { _ in NetworkMonitor() }.inObjectScope(.container)
        container.register(CrashReporter.self) { _ in CrashReporter() }.inObjectScope(.container)

        // Services with Dependencies
        container.register(ErrorHandler.self) { r in
            guard let crashReporter = r.resolve(CrashReporter.self) else {
                print("[DependencyContainer] Warning: CrashReporter not registered.")
                return ErrorHandler(crashReporter: DummyCrashReporter())
            }
            return ErrorHandler(crashReporter: crashReporter)
        }.inObjectScope(.container)

        container.register(RetryMechanism.self) { r in
            guard let networkMonitor = r.resolve(NetworkMonitor.self) else {
                print("[DependencyContainer] Warning: NetworkMonitor not registered.")
                return RetryMechanism(networkMonitor: DummyNetworkMonitor())
            }
            return RetryMechanism(networkMonitor: networkMonitor)
        }.inObjectScope(.container)
        
        container.register(OfflineManager.self) { r in
            guard let networkMonitor = r.resolve(NetworkMonitor.self) else {
                print("[DependencyContainer] Warning: NetworkMonitor not registered for OfflineManager.")
                return OfflineManager(networkMonitor: DummyNetworkMonitor())
            }
            return OfflineManager(networkMonitor: networkMonitor)
        }.inObjectScope(.container)

        container.register(PrayerTimeService.self) { r in
            guard let locationService = r.resolve(LocationServiceProtocol.self) else {
                print("[DependencyContainer] Warning: LocationServiceProtocol not registered for PrayerTimeService.")
                return DummyPrayerTimeService()
            }
            guard let errorHandler = r.resolve(ErrorHandler.self) else {
                print("[DependencyContainer] Warning: ErrorHandler not registered for PrayerTimeService.")
                return DummyPrayerTimeService()
            }
            guard let retryMechanism = r.resolve(RetryMechanism.self) else {
                print("[DependencyContainer] Warning: RetryMechanism not registered for PrayerTimeService.")
                return DummyPrayerTimeService()
            }
            guard let networkMonitor = r.resolve(NetworkMonitor.self) else {
                print("[DependencyContainer] Warning: NetworkMonitor not registered for PrayerTimeService.")
                return DummyPrayerTimeService()
            }
            return PrayerTimeService(
                locationService: locationService,
                errorHandler: errorHandler,
                retryMechanism: retryMechanism,
                networkMonitor: networkMonitor
            )
        }.inObjectScope(.container)
        container.register(PrayerTimeServiceProtocol.self) { r in
            r.resolve(PrayerTimeService.self)
        }
    }
    
    func resolve<Service>(_ serviceType: Service.Type) -> Service? {
        return container.resolve(serviceType)
    }
}

// MARK: - Dummy Fallbacks for DependencyContainer

private class DummyCrashReporter: CrashReporter {
    override func report(_ error: Error) {}
}

private class DummyNetworkMonitor: NetworkMonitor {
    override var isConnected: Bool { false }
}
