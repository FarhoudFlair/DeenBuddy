import Foundation
import Combine

// MARK: - Dependency Container

public class DependencyContainer: ObservableObject {
    // MARK: - Services

    @Published public private(set) var locationService: any LocationServiceProtocol
    @Published public private(set) var apiClient: any APIClientProtocol
    @Published public private(set) var notificationService: any NotificationServiceProtocol
    @Published public private(set) var prayerTimeService: any PrayerTimeServiceProtocol
    @Published public private(set) var settingsService: any SettingsServiceProtocol
    
    // MARK: - Configuration
    
    public let apiConfiguration: APIConfiguration
    public let isTestEnvironment: Bool
    
    // MARK: - Initialization
    
    // Public initializer for testing and preview purposes
    public init(
        locationService: any LocationServiceProtocol,
        apiClient: any APIClientProtocol,
        notificationService: any NotificationServiceProtocol,
        prayerTimeService: any PrayerTimeServiceProtocol,
        settingsService: any SettingsServiceProtocol,
        apiConfiguration: APIConfiguration = .default,
        isTestEnvironment: Bool = true
    ) {
        self.locationService = locationService
        self.apiClient = apiClient
        self.notificationService = notificationService
        self.prayerTimeService = prayerTimeService
        self.settingsService = settingsService
        self.apiConfiguration = apiConfiguration
        self.isTestEnvironment = isTestEnvironment
    }

    public static func createAsync(
        locationService: (any LocationServiceProtocol)? = nil,
        apiClient: (any APIClientProtocol)? = nil,
        notificationService: (any NotificationServiceProtocol)? = nil,
        prayerTimeService: (any PrayerTimeServiceProtocol)? = nil,
        settingsService: (any SettingsServiceProtocol)? = nil,
        apiConfiguration: APIConfiguration = .default,
        isTestEnvironment: Bool = false
    ) async -> DependencyContainer {
        let resolvedLocationService: any LocationServiceProtocol
        if let locationService = locationService {
            resolvedLocationService = locationService
        } else {
            resolvedLocationService = await MainActor.run { LocationService() }
        }
        
        let resolvedApiClient = apiClient ?? APIClient(configuration: apiConfiguration)
        
        let resolvedNotificationService: any NotificationServiceProtocol
        if let notificationService = notificationService {
            resolvedNotificationService = notificationService
        } else {
            resolvedNotificationService = await MainActor.run { NotificationService() }
        }
        
        let resolvedSettingsService: any SettingsServiceProtocol
        if let settingsService = settingsService {
            resolvedSettingsService = settingsService
        } else {
            resolvedSettingsService = await MainActor.run { SettingsService() }
        }
        
        let resolvedErrorHandler: ErrorHandler = await MainActor.run { ErrorHandler(crashReporter: CrashReporter()) }
        let resolvedRetryMechanism: RetryMechanism = await MainActor.run { RetryMechanism(networkMonitor: NetworkMonitor.shared) }
        
        let resolvedPrayerTimeService: any PrayerTimeServiceProtocol
        if let prayerTimeService = prayerTimeService {
            resolvedPrayerTimeService = prayerTimeService
        } else {
            resolvedPrayerTimeService = await MainActor.run { PrayerTimeService(
                locationService: resolvedLocationService,
                errorHandler: resolvedErrorHandler,
                retryMechanism: resolvedRetryMechanism,
                networkMonitor: NetworkMonitor.shared
            ) }
        }
        let container = DependencyContainer(
            locationService: resolvedLocationService,
            apiClient: resolvedApiClient,
            notificationService: resolvedNotificationService,
            prayerTimeService: resolvedPrayerTimeService,
            settingsService: resolvedSettingsService,
            apiConfiguration: apiConfiguration,
            isTestEnvironment: isTestEnvironment
        )
        await container.setupServices()
        return container
    }
    
    // MARK: - Service Registration
    
    public func register<T>(service: T, for type: T.Type) {
        switch type {
        case is any LocationServiceProtocol.Type:
            if let locationService = service as? any LocationServiceProtocol {
                self.locationService = locationService
            }
        case is any APIClientProtocol.Type:
            if let apiClient = service as? any APIClientProtocol {
                self.apiClient = apiClient
            }
        case is any NotificationServiceProtocol.Type:
            if let notificationService = service as? any NotificationServiceProtocol {
                self.notificationService = notificationService
            }
        case is any PrayerTimeServiceProtocol.Type:
            if let prayerTimeService = service as? any PrayerTimeServiceProtocol {
                self.prayerTimeService = prayerTimeService
            }
        case is any SettingsServiceProtocol.Type:
            if let settingsService = service as? any SettingsServiceProtocol {
                self.settingsService = settingsService
            }
        default:
            break
        }
    }
    
    // MARK: - Service Resolution
    
    public func resolve<T>(_ type: T.Type) -> T? {
        switch type {
        case is any LocationServiceProtocol.Type:
            return locationService as? T
        case is any APIClientProtocol.Type:
            return apiClient as? T
        case is any NotificationServiceProtocol.Type:
            return notificationService as? T
        case is any PrayerTimeServiceProtocol.Type:
            return prayerTimeService as? T
        case is any SettingsServiceProtocol.Type:
            return settingsService as? T
        default:
            return nil
        }
    }
    
    // MARK: - Convenience Methods
    
    public func setupServices() async {
        // Initialize services that need async setup
        if !isTestEnvironment {
            // Request permissions if needed
            await locationService.requestLocationPermission()
            _ = try? await notificationService.requestNotificationPermission()
        }
    }
    
    @MainActor
    public func tearDown() async {
        // Clean up services
        locationService.stopUpdatingLocation()
        await notificationService.cancelAllNotifications()
    }
}

// MARK: - Service Factory

public class ServiceFactory {
    @MainActor
    public static func createLocationService() -> any LocationServiceProtocol {
        return LocationService()
    }

    public static func createAPIClient(
        configuration: APIConfiguration = .default
    ) -> any APIClientProtocol {
        return APIClient(configuration: configuration)
    }

    @MainActor
    public static func createNotificationService() -> any NotificationServiceProtocol {
        return NotificationService()
    }

    @MainActor
    public static func createPrayerTimeService(
        locationService: any LocationServiceProtocol,
        errorHandler: ErrorHandler,
        retryMechanism: RetryMechanism,
        networkMonitor: NetworkMonitor
    ) -> any PrayerTimeServiceProtocol {
        return PrayerTimeService(
            locationService: locationService,
            errorHandler: errorHandler,
            retryMechanism: retryMechanism,
            networkMonitor: networkMonitor
        )
    }

    @MainActor 
    public static func createSettingsService() -> any SettingsServiceProtocol {
        return SettingsService()
    }
}

// MARK: - Environment Detection

public extension DependencyContainer {
    @MainActor
    static var shared: DependencyContainer = {
        let resolvedLocationService = LocationService()
        let resolvedApiClient = APIClient(configuration: .default)
        let resolvedNotificationService: any NotificationServiceProtocol = NotificationService()
        let resolvedSettingsService: any SettingsServiceProtocol = SettingsService()
        let resolvedErrorHandler: ErrorHandler = ErrorHandler(crashReporter: CrashReporter())
        let resolvedRetryMechanism: RetryMechanism = RetryMechanism(networkMonitor: NetworkMonitor.shared)
        let resolvedPrayerTimeService: any PrayerTimeServiceProtocol = PrayerTimeService(
            locationService: resolvedLocationService,
            errorHandler: resolvedErrorHandler,
            retryMechanism: resolvedRetryMechanism,
            networkMonitor: NetworkMonitor.shared
        )
        return DependencyContainer(
            locationService: resolvedLocationService,
            apiClient: resolvedApiClient,
            notificationService: resolvedNotificationService,
            prayerTimeService: resolvedPrayerTimeService,
            settingsService: resolvedSettingsService,
            apiConfiguration: .default,
            isTestEnvironment: ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        )
    }()

    @MainActor
    static func createForTesting(
        locationService: (any LocationServiceProtocol)? = nil,
        apiClient: (any APIClientProtocol)? = nil,
        notificationService: (any NotificationServiceProtocol)? = nil,
        prayerTimeService: (any PrayerTimeServiceProtocol)? = nil,
        settingsService: (any SettingsServiceProtocol)? = nil
    ) -> DependencyContainer {
        let resolvedLocationService = locationService ?? LocationService()
        let resolvedApiClient = apiClient ?? APIClient(configuration: .default)
        let resolvedNotificationService: any NotificationServiceProtocol = notificationService ?? NotificationService()
        let resolvedSettingsService: any SettingsServiceProtocol = settingsService ?? SettingsService()
        let resolvedErrorHandler: ErrorHandler = ErrorHandler(crashReporter: CrashReporter())
        let resolvedRetryMechanism: RetryMechanism = RetryMechanism(networkMonitor: NetworkMonitor.shared)
        let resolvedPrayerTimeService: any PrayerTimeServiceProtocol = prayerTimeService ?? PrayerTimeService(
            locationService: resolvedLocationService,
            errorHandler: resolvedErrorHandler,
            retryMechanism: resolvedRetryMechanism,
            networkMonitor: NetworkMonitor.shared
        )
        return DependencyContainer(
            locationService: resolvedLocationService,
            apiClient: resolvedApiClient,
            notificationService: resolvedNotificationService,
            prayerTimeService: resolvedPrayerTimeService,
            settingsService: resolvedSettingsService,
            apiConfiguration: .default,
            isTestEnvironment: true
        )
    }
}
