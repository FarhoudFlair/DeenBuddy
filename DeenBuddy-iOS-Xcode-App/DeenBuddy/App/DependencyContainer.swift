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
        container.register(LocationServiceProtocol.self) { r in r.resolve(LocationService.self)! }

        container.register(NetworkMonitor.self) { _ in NetworkMonitor() }.inObjectScope(.container)
        container.register(CrashReporter.self) { _ in CrashReporter() }.inObjectScope(.container)

        // Services with Dependencies
        container.register(ErrorHandler.self) { r in
            ErrorHandler(crashReporter: r.resolve(CrashReporter.self)!)
        }.inObjectScope(.container)

        container.register(RetryMechanism.self) { r in
            RetryMechanism(networkMonitor: r.resolve(NetworkMonitor.self)!)
        }.inObjectScope(.container)
        
        container.register(OfflineManager.self) { r in
            OfflineManager(networkMonitor: r.resolve(NetworkMonitor.self)!)
        }.inObjectScope(.container)

        container.register(PrayerTimeService.self) { r in
            PrayerTimeService(
                locationService: r.resolve(LocationServiceProtocol.self)!,
                errorHandler: r.resolve(ErrorHandler.self)!,
                retryMechanism: r.resolve(RetryMechanism.self)!,
                networkMonitor: r.resolve(NetworkMonitor.self)!
            )
        }.inObjectScope(.container)
        container.register(PrayerTimeServiceProtocol.self) { r in r.resolve(PrayerTimeService.self)! }
    }
    
    func resolve<Service>(_ serviceType: Service.Type) -> Service? {
        return container.resolve(serviceType)
    }
}
