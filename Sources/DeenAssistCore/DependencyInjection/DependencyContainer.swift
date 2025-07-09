import Foundation
import Combine
import DeenAssistProtocols

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
    
    public init(
        locationService: (any LocationServiceProtocol)? = nil,
        apiClient: (any APIClientProtocol)? = nil,
        notificationService: (any NotificationServiceProtocol)? = nil,
        prayerTimeService: (any PrayerTimeServiceProtocol)? = nil,
        settingsService: (any SettingsServiceProtocol)? = nil,
        apiConfiguration: APIConfiguration = .default,
        isTestEnvironment: Bool = false
    ) {
        self.apiConfiguration = apiConfiguration
        self.isTestEnvironment = isTestEnvironment
        
        // Use provided services or create defaults
        self.locationService = locationService ?? LocationService()
        self.apiClient = apiClient ?? APIClient(configuration: apiConfiguration)
        self.notificationService = notificationService ?? NotificationService()
        self.settingsService = settingsService ?? SettingsService(userDefaults: UserDefaults.standard)
        self.prayerTimeService = prayerTimeService ?? PrayerTimeService(apiClient: self.apiClient, errorHandler: ErrorHandler(), retryMechanism: RetryMechanism(), networkMonitor: NetworkMonitor())
    }
    
    // MARK: - Service Registration
    
    public func register<T>(service: T, for type: T.Type) {
        switch type {
        case is LocationServiceProtocol.Type:
            if let locationService = service as? any LocationServiceProtocol {
                self.locationService = locationService
            }
        case is APIClientProtocol.Type:
            if let apiClient = service as? any APIClientProtocol {
                self.apiClient = apiClient
            }
        case is NotificationServiceProtocol.Type:
            if let notificationService = service as? any NotificationServiceProtocol {
                self.notificationService = notificationService
            }
        case is PrayerTimeServiceProtocol.Type:
            if let prayerTimeService = service as? any PrayerTimeServiceProtocol {
                self.prayerTimeService = prayerTimeService
            }
        case is SettingsServiceProtocol.Type:
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
        case is LocationServiceProtocol.Type:
            return locationService as? T
        case is APIClientProtocol.Type:
            return apiClient as? T
        case is NotificationServiceProtocol.Type:
            return notificationService as? T
        case is PrayerTimeServiceProtocol.Type:
            return prayerTimeService as? T
        case is SettingsServiceProtocol.Type:
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
            locationService.requestLocationPermission()
            _ = try? await notificationService.requestNotificationPermission()
        }
    }
    
    public func tearDown() {
        // Clean up services
        locationService.stopUpdatingLocation()
        notificationService.cancelAllNotifications()
    }
}

// MARK: - Service Factory

public class ServiceFactory {
    public static func createLocationService() -> any LocationServiceProtocol {
        return LocationService()
    }

    public static func createAPIClient(
        configuration: APIConfiguration = .default
    ) -> any APIClientProtocol {
        return APIClient(configuration: configuration)
    }

    public static func createNotificationService() -> any NotificationServiceProtocol {
        return NotificationService()
    }

    public static func createPrayerTimeService(
        apiClient: any APIClientProtocol,
        errorHandler: ErrorHandler,
        retryMechanism: RetryMechanism,
        networkMonitor: NetworkMonitor
    ) -> any PrayerTimeServiceProtocol {
        return PrayerTimeService(apiClient: apiClient, errorHandler: errorHandler, retryMechanism: retryMechanism, networkMonitor: networkMonitor)
    }

    public static func createSettingsService() -> any SettingsServiceProtocol {
        return SettingsService()
    }
}

// MARK: - Environment Detection

public extension DependencyContainer {
    static var shared: DependencyContainer = {
        let isTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        return DependencyContainer(isTestEnvironment: isTest)
    }()
    
    static func createForTesting(
        locationService: (any LocationServiceProtocol)? = nil,
        apiClient: (any APIClientProtocol)? = nil,
        notificationService: (any NotificationServiceProtocol)? = nil,
        prayerTimeService: (any PrayerTimeServiceProtocol)? = nil,
        settingsService: (any SettingsServiceProtocol)? = nil
    ) -> DependencyContainer {
        return DependencyContainer(
            locationService: locationService,
            apiClient: apiClient,
            notificationService: notificationService,
            prayerTimeService: prayerTimeService,
            settingsService: settingsService,
            isTestEnvironment: true
        )
    }
}
