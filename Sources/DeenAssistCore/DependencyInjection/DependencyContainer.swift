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
        
        // Use provided services or create defaults based on environment
        if isTestEnvironment {
            self.locationService = locationService ?? MockLocationService()
            self.apiClient = apiClient ?? MockAPIClient()
            self.notificationService = notificationService ?? MockNotificationService()
            self.settingsService = settingsService ?? MockSettingsService()
            self.prayerTimeService = prayerTimeService ?? MockPrayerTimeService()
        } else {
            self.locationService = locationService ?? LocationService()
            self.apiClient = apiClient ?? APIClient(configuration: apiConfiguration)
            self.notificationService = notificationService ?? NotificationService()
            self.settingsService = settingsService ?? SettingsService()
            self.prayerTimeService = prayerTimeService ?? PrayerTimeService(locationService: self.locationService)
        }
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
            _ = await locationService.requestLocationPermission()
            _ = await notificationService.requestNotificationPermission()
        }
    }
    
    public func tearDown() {
        // Clean up services
        locationService.stopLocationUpdates()
        notificationService.cancelAllPrayerNotifications()
    }
}

// MARK: - Service Factory

public class ServiceFactory {
    public static func createLocationService(isTest: Bool = false) -> any LocationServiceProtocol {
        return isTest ? MockLocationService() : LocationService()
    }

    public static func createAPIClient(
        configuration: APIConfiguration = .default,
        isTest: Bool = false
    ) -> any APIClientProtocol {
        return isTest ? MockAPIClient() : APIClient(configuration: configuration)
    }

    public static func createNotificationService(isTest: Bool = false) -> any NotificationServiceProtocol {
        return isTest ? MockNotificationService() : NotificationService()
    }

    public static func createPrayerTimeService(
        locationService: any LocationServiceProtocol,
        isTest: Bool = false
    ) -> any PrayerTimeServiceProtocol {
        return isTest ? MockPrayerTimeService() : PrayerTimeService(locationService: locationService)
    }

    public static func createSettingsService(isTest: Bool = false) -> any SettingsServiceProtocol {
        return isTest ? MockSettingsService() : SettingsService()
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
