import Foundation
import Combine

// MARK: - Dependency Container

public class DependencyContainer: ObservableObject {
    // MARK: - Services
    
    @Published public private(set) var locationService: LocationServiceProtocol
    @Published public private(set) var apiClient: APIClientProtocol
    @Published public private(set) var notificationService: NotificationServiceProtocol
    
    // MARK: - Configuration
    
    public let apiConfiguration: APIConfiguration
    public let isTestEnvironment: Bool
    
    // MARK: - Initialization
    
    public init(
        locationService: LocationServiceProtocol? = nil,
        apiClient: APIClientProtocol? = nil,
        notificationService: NotificationServiceProtocol? = nil,
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
        } else {
            self.locationService = locationService ?? LocationService()
            self.apiClient = apiClient ?? APIClient(configuration: apiConfiguration)
            self.notificationService = notificationService ?? NotificationService()
        }
    }
    
    // MARK: - Service Registration
    
    public func register<T>(service: T, for type: T.Type) {
        switch type {
        case is LocationServiceProtocol.Type:
            if let locationService = service as? LocationServiceProtocol {
                self.locationService = locationService
            }
        case is APIClientProtocol.Type:
            if let apiClient = service as? APIClientProtocol {
                self.apiClient = apiClient
            }
        case is NotificationServiceProtocol.Type:
            if let notificationService = service as? NotificationServiceProtocol {
                self.notificationService = notificationService
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
    public static func createLocationService(isTest: Bool = false) -> LocationServiceProtocol {
        return isTest ? MockLocationService() : LocationService()
    }
    
    public static func createAPIClient(
        configuration: APIConfiguration = .default,
        isTest: Bool = false
    ) -> APIClientProtocol {
        return isTest ? MockAPIClient() : APIClient(configuration: configuration)
    }
    
    public static func createNotificationService(isTest: Bool = false) -> NotificationServiceProtocol {
        return isTest ? MockNotificationService() : NotificationService()
    }
}

// MARK: - Environment Detection

public extension DependencyContainer {
    static var shared: DependencyContainer = {
        let isTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        return DependencyContainer(isTestEnvironment: isTest)
    }()
    
    static func createForTesting(
        locationService: LocationServiceProtocol? = nil,
        apiClient: APIClientProtocol? = nil,
        notificationService: NotificationServiceProtocol? = nil
    ) -> DependencyContainer {
        return DependencyContainer(
            locationService: locationService,
            apiClient: apiClient,
            notificationService: notificationService,
            isTestEnvironment: true
        )
    }
}
