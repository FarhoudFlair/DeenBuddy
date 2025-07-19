import Foundation
import Combine
import BackgroundTasks

// MARK: - Dependency Container

public class DependencyContainer: ObservableObject {
    // MARK: - Services

    @Published public private(set) var locationService: any LocationServiceProtocol
    @Published public private(set) var apiClient: any APIClientProtocol
    @Published public private(set) var notificationService: any NotificationServiceProtocol
    @Published public private(set) var prayerTimeService: any PrayerTimeServiceProtocol
    @Published public private(set) var settingsService: any SettingsServiceProtocol
    @Published public private(set) var prayerTrackingService: any PrayerTrackingServiceProtocol
    @Published public private(set) var prayerAnalyticsService: PrayerAnalyticsService
    @Published public private(set) var prayerTrackingCoordinator: PrayerTrackingCoordinator
    @Published public private(set) var tasbihService: any TasbihServiceProtocol
    @Published public private(set) var islamicCalendarService: any IslamicCalendarServiceProtocol
    @Published public private(set) var backgroundTaskManager: BackgroundTaskManager
    @Published public private(set) var backgroundPrayerRefreshService: BackgroundPrayerRefreshService
    @Published public private(set) var islamicCacheManager: IslamicCacheManager
    
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
        prayerTrackingService: any PrayerTrackingServiceProtocol,
        prayerAnalyticsService: PrayerAnalyticsService,
        prayerTrackingCoordinator: PrayerTrackingCoordinator,
        tasbihService: any TasbihServiceProtocol,
        islamicCalendarService: any IslamicCalendarServiceProtocol,
        backgroundTaskManager: BackgroundTaskManager,
        backgroundPrayerRefreshService: BackgroundPrayerRefreshService,
        islamicCacheManager: IslamicCacheManager,
        apiConfiguration: APIConfiguration = .default,
        isTestEnvironment: Bool = true
    ) {
        self.locationService = locationService
        self.apiClient = apiClient
        self.notificationService = notificationService
        self.prayerTimeService = prayerTimeService
        self.settingsService = settingsService
        self.prayerTrackingService = prayerTrackingService
        self.prayerAnalyticsService = prayerAnalyticsService
        self.prayerTrackingCoordinator = prayerTrackingCoordinator
        self.tasbihService = tasbihService
        self.islamicCalendarService = islamicCalendarService
        self.backgroundTaskManager = backgroundTaskManager
        self.backgroundPrayerRefreshService = backgroundPrayerRefreshService
        self.islamicCacheManager = islamicCacheManager
        self.apiConfiguration = apiConfiguration
        self.isTestEnvironment = isTestEnvironment
    }

    public static func createAsync(
        locationService: (any LocationServiceProtocol)? = nil,
        apiClient: (any APIClientProtocol)? = nil,
        notificationService: (any NotificationServiceProtocol)? = nil,
        prayerTimeService: (any PrayerTimeServiceProtocol)? = nil,
        settingsService: (any SettingsServiceProtocol)? = nil,
        islamicCacheManager: IslamicCacheManager? = nil,
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
        
        let resolvedIslamicCacheManager: IslamicCacheManager
        if let islamicCacheManager = islamicCacheManager {
            resolvedIslamicCacheManager = islamicCacheManager
        } else {
            resolvedIslamicCacheManager = await MainActor.run { IslamicCacheManager() }
        }
        
        let resolvedPrayerTimeService: any PrayerTimeServiceProtocol
        if let prayerTimeService = prayerTimeService {
            resolvedPrayerTimeService = prayerTimeService
        } else {
            resolvedPrayerTimeService = await MainActor.run { PrayerTimeService(
                locationService: resolvedLocationService,
                settingsService: resolvedSettingsService,
                apiClient: resolvedApiClient,
                errorHandler: resolvedErrorHandler,
                retryMechanism: resolvedRetryMechanism,
                networkMonitor: NetworkMonitor.shared,
                islamicCacheManager: resolvedIslamicCacheManager
            ) }
        }

        // Create background services with proper dependencies
        let resolvedBackgroundTaskManager = await MainActor.run { BackgroundTaskManager(
            prayerTimeService: resolvedPrayerTimeService,
            notificationService: resolvedNotificationService,
            locationService: resolvedLocationService
        ) }

        let resolvedBackgroundPrayerRefreshService = await MainActor.run { BackgroundPrayerRefreshService(
            prayerTimeService: resolvedPrayerTimeService,
            locationService: resolvedLocationService
        ) }

        // Create additional services
        let resolvedPrayerTrackingService = await MainActor.run { PrayerTrackingService(
            prayerTimeService: resolvedPrayerTimeService,
            settingsService: resolvedSettingsService,
            locationService: resolvedLocationService
        ) }

        let resolvedPrayerAnalyticsService = await MainActor.run { PrayerAnalyticsService(
            prayerTrackingService: resolvedPrayerTrackingService
        ) }

        let resolvedPrayerTrackingCoordinator = await MainActor.run { PrayerTrackingCoordinator(
            prayerTimeService: resolvedPrayerTimeService,
            prayerTrackingService: resolvedPrayerTrackingService,
            notificationService: resolvedNotificationService,
            settingsService: resolvedSettingsService
        ) }

        let resolvedTasbihService = await MainActor.run { TasbihService() }

        let resolvedIslamicCalendarService = await MainActor.run { IslamicCalendarService() }

        let container = DependencyContainer(
            locationService: resolvedLocationService,
            apiClient: resolvedApiClient,
            notificationService: resolvedNotificationService,
            prayerTimeService: resolvedPrayerTimeService,
            settingsService: resolvedSettingsService,
            prayerTrackingService: resolvedPrayerTrackingService,
            prayerAnalyticsService: resolvedPrayerAnalyticsService,
            prayerTrackingCoordinator: resolvedPrayerTrackingCoordinator,
            tasbihService: resolvedTasbihService,
            islamicCalendarService: resolvedIslamicCalendarService,
            backgroundTaskManager: resolvedBackgroundTaskManager,
            backgroundPrayerRefreshService: resolvedBackgroundPrayerRefreshService,
            islamicCacheManager: resolvedIslamicCacheManager,
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
        case is any PrayerTrackingServiceProtocol.Type:
            if let prayerTrackingService = service as? any PrayerTrackingServiceProtocol {
                self.prayerTrackingService = prayerTrackingService
            }
        case is any TasbihServiceProtocol.Type:
            if let tasbihService = service as? any TasbihServiceProtocol {
                self.tasbihService = tasbihService
            }
        case is any IslamicCalendarServiceProtocol.Type:
            if let islamicCalendarService = service as? any IslamicCalendarServiceProtocol {
                self.islamicCalendarService = islamicCalendarService
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
        case is any PrayerTrackingServiceProtocol.Type:
            return prayerTrackingService as? T
        case is any TasbihServiceProtocol.Type:
            return tasbihService as? T
        case is any IslamicCalendarServiceProtocol.Type:
            return islamicCalendarService as? T
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

            // Register and start background services
            await backgroundTaskManager.registerBackgroundTasks()
            await backgroundPrayerRefreshService.startBackgroundRefresh()

            print("🔄 Background services initialized and started")
        }
    }
    
    @MainActor
    public func tearDown() async {
        // Clean up services
        locationService.stopUpdatingLocation()
        await notificationService.cancelAllNotifications()

        // Stop background services
        backgroundPrayerRefreshService.stopBackgroundRefresh()

        print("🔄 Background services stopped and cleaned up")
    }
}

// MARK: - Service Factory

public class ServiceFactory {
    // Singleton instances to prevent service multiplication
    @MainActor
    private static var _locationServiceInstance: LocationService?

    @MainActor
    public static func createLocationService() -> any LocationServiceProtocol {
        // Use singleton pattern to prevent multiple instances
        if let existingInstance = _locationServiceInstance {
            print("🔄 Reusing existing LocationService instance")
            return existingInstance
        }

        let newInstance = LocationService()
        _locationServiceInstance = newInstance
        print("🏗️ Created new LocationService singleton instance")
        return newInstance
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
        settingsService: any SettingsServiceProtocol,
        apiClient: any APIClientProtocol,
        errorHandler: ErrorHandler,
        retryMechanism: RetryMechanism,
        networkMonitor: NetworkMonitor,
        islamicCacheManager: IslamicCacheManager
    ) -> any PrayerTimeServiceProtocol {
        return PrayerTimeService(
            locationService: locationService,
            settingsService: settingsService,
            apiClient: apiClient,
            errorHandler: errorHandler,
            retryMechanism: retryMechanism,
            networkMonitor: networkMonitor,
            islamicCacheManager: islamicCacheManager
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
        let resolvedIslamicCacheManager = IslamicCacheManager()
        let resolvedPrayerTimeService: any PrayerTimeServiceProtocol = PrayerTimeService(
            locationService: resolvedLocationService,
            settingsService: resolvedSettingsService,
            apiClient: resolvedApiClient,
            errorHandler: resolvedErrorHandler,
            retryMechanism: resolvedRetryMechanism,
            networkMonitor: NetworkMonitor.shared,
            islamicCacheManager: resolvedIslamicCacheManager
        )

        let resolvedPrayerTrackingService: any PrayerTrackingServiceProtocol = PrayerTrackingService(
            prayerTimeService: resolvedPrayerTimeService,
            settingsService: resolvedSettingsService,
            locationService: resolvedLocationService
        )

        let resolvedPrayerAnalyticsService = PrayerAnalyticsService(
            prayerTrackingService: resolvedPrayerTrackingService
        )

        let resolvedPrayerTrackingCoordinator = PrayerTrackingCoordinator(
            prayerTimeService: resolvedPrayerTimeService,
            prayerTrackingService: resolvedPrayerTrackingService,
            notificationService: resolvedNotificationService,
            settingsService: resolvedSettingsService
        )

        let resolvedTasbihService: any TasbihServiceProtocol = TasbihService()

        let resolvedIslamicCalendarService: any IslamicCalendarServiceProtocol = IslamicCalendarService()

        // Create background services with proper dependencies
        let resolvedBackgroundTaskManager = BackgroundTaskManager(
            prayerTimeService: resolvedPrayerTimeService,
            notificationService: resolvedNotificationService,
            locationService: resolvedLocationService
        )

        let resolvedBackgroundPrayerRefreshService = BackgroundPrayerRefreshService(
            prayerTimeService: resolvedPrayerTimeService,
            locationService: resolvedLocationService
        )

        return DependencyContainer(
            locationService: resolvedLocationService,
            apiClient: resolvedApiClient,
            notificationService: resolvedNotificationService,
            prayerTimeService: resolvedPrayerTimeService,
            settingsService: resolvedSettingsService,
            prayerTrackingService: resolvedPrayerTrackingService,
            prayerAnalyticsService: resolvedPrayerAnalyticsService,
            prayerTrackingCoordinator: resolvedPrayerTrackingCoordinator,
            tasbihService: resolvedTasbihService,
            islamicCalendarService: resolvedIslamicCalendarService,
            backgroundTaskManager: resolvedBackgroundTaskManager,
            backgroundPrayerRefreshService: resolvedBackgroundPrayerRefreshService,
            islamicCacheManager: resolvedIslamicCacheManager,
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
        let resolvedIslamicCacheManager = IslamicCacheManager()
        let resolvedPrayerTimeService: any PrayerTimeServiceProtocol = prayerTimeService ?? PrayerTimeService(
            locationService: resolvedLocationService,
            settingsService: resolvedSettingsService,
            apiClient: resolvedApiClient,
            errorHandler: resolvedErrorHandler,
            retryMechanism: resolvedRetryMechanism,
            networkMonitor: NetworkMonitor.shared,
            islamicCacheManager: resolvedIslamicCacheManager
        )

        // Create mock background services for testing
        let resolvedBackgroundTaskManager = BackgroundTaskManager(
            prayerTimeService: resolvedPrayerTimeService,
            notificationService: resolvedNotificationService,
            locationService: resolvedLocationService
        )

        let resolvedBackgroundPrayerRefreshService = BackgroundPrayerRefreshService(
            prayerTimeService: resolvedPrayerTimeService,
            locationService: resolvedLocationService
        )

        // Create additional services for testing
        let resolvedPrayerTrackingService: any PrayerTrackingServiceProtocol = PrayerTrackingService(
            prayerTimeService: resolvedPrayerTimeService,
            settingsService: resolvedSettingsService,
            locationService: resolvedLocationService
        )

        let resolvedPrayerAnalyticsService = PrayerAnalyticsService(
            prayerTrackingService: resolvedPrayerTrackingService
        )

        let resolvedPrayerTrackingCoordinator = PrayerTrackingCoordinator(
            prayerTimeService: resolvedPrayerTimeService,
            prayerTrackingService: resolvedPrayerTrackingService,
            notificationService: resolvedNotificationService,
            settingsService: resolvedSettingsService
        )

        let resolvedTasbihService: any TasbihServiceProtocol = TasbihService()

        let resolvedIslamicCalendarService: any IslamicCalendarServiceProtocol = IslamicCalendarService()

        return DependencyContainer(
            locationService: resolvedLocationService,
            apiClient: resolvedApiClient,
            notificationService: resolvedNotificationService,
            prayerTimeService: resolvedPrayerTimeService,
            settingsService: resolvedSettingsService,
            prayerTrackingService: resolvedPrayerTrackingService,
            prayerAnalyticsService: resolvedPrayerAnalyticsService,
            prayerTrackingCoordinator: resolvedPrayerTrackingCoordinator,
            tasbihService: resolvedTasbihService,
            islamicCalendarService: resolvedIslamicCalendarService,
            backgroundTaskManager: resolvedBackgroundTaskManager,
            backgroundPrayerRefreshService: resolvedBackgroundPrayerRefreshService,
            islamicCacheManager: resolvedIslamicCacheManager,
            apiConfiguration: .default,
            isTestEnvironment: true
        )
    }
}
