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
    @Published public private(set) var userAccountService: any UserAccountServiceProtocol
    @Published public private(set) var notificationScheduler: NotificationScheduler
    
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
        userAccountService: any UserAccountServiceProtocol,
        notificationScheduler: NotificationScheduler,
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
        self.userAccountService = userAccountService
        self.notificationScheduler = notificationScheduler
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
            resolvedLocationService = await MainActor.run { ServiceFactory.createLocationService() }
        }
        
        let resolvedApiClient = apiClient ?? APIClient(configuration: apiConfiguration)
        
        let resolvedNotificationService: any NotificationServiceProtocol
        if let notificationService = notificationService {
            resolvedNotificationService = notificationService
        } else {
            resolvedNotificationService = await MainActor.run { ServiceFactory.createNotificationService() }
        }
        
        let resolvedSettingsService: any SettingsServiceProtocol
        if let settingsService = settingsService {
            resolvedSettingsService = settingsService
        } else {
            resolvedSettingsService = await MainActor.run { ServiceFactory.createSettingsService() }
        }
        
        let resolvedErrorHandler: ErrorHandler = await MainActor.run { ErrorHandler(crashReporter: CrashReporter()) }
        let resolvedRetryMechanism: RetryMechanism = await MainActor.run { RetryMechanism(networkMonitor: NetworkMonitor.shared) }
        
        let resolvedIslamicCacheManager: IslamicCacheManager
        if let islamicCacheManager = islamicCacheManager {
            resolvedIslamicCacheManager = islamicCacheManager
        } else {
            resolvedIslamicCacheManager = await MainActor.run { ServiceFactory.createIslamicCacheManager() }
        }

        let resolvedIslamicCalendarService = await MainActor.run { ServiceFactory.createIslamicCalendarService() }

        let resolvedPrayerTimeService: any PrayerTimeServiceProtocol
        if let prayerTimeService = prayerTimeService {
            resolvedPrayerTimeService = prayerTimeService
        } else {
            resolvedPrayerTimeService = await MainActor.run { ServiceFactory.createPrayerTimeService(
                locationService: resolvedLocationService,
                settingsService: resolvedSettingsService,
                apiClient: resolvedApiClient,
                errorHandler: resolvedErrorHandler,
                retryMechanism: resolvedRetryMechanism,
                networkMonitor: NetworkMonitor.shared,
                islamicCacheManager: resolvedIslamicCacheManager,
                islamicCalendarService: resolvedIslamicCalendarService
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
        
        let resolvedUserAccountService = await MainActor.run { ServiceFactory.createUserAccountService() }

        let resolvedNotificationScheduler = await MainActor.run { ServiceFactory.createNotificationScheduler(
            notificationService: resolvedNotificationService,
            prayerTimeService: resolvedPrayerTimeService,
            settingsService: resolvedSettingsService
        ) }

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
            userAccountService: resolvedUserAccountService,
            notificationScheduler: resolvedNotificationScheduler,
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
        case is IslamicCacheManager.Type:
            if let islamicCacheManager = service as? IslamicCacheManager {
                self.islamicCacheManager = islamicCacheManager
            }
        case is any UserAccountServiceProtocol.Type:
            if let userAccountService = service as? any UserAccountServiceProtocol {
                self.userAccountService = userAccountService
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
        case is IslamicCacheManager.Type:
            return islamicCacheManager as? T
        case is any UserAccountServiceProtocol.Type:
            return userAccountService as? T
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
    // CRITICAL FIX: Singleton instances for ALL services to prevent service multiplication
    @MainActor
    private static var _locationServiceInstance: LocationService?
    
    @MainActor
    private static var _notificationServiceInstance: NotificationService?
    
    @MainActor
    private static var _settingsServiceInstance: SettingsService?
    
    @MainActor
    private static var _prayerTimeServiceInstance: PrayerTimeService?
    
    @MainActor
    private static var _islamicCacheManagerInstance: IslamicCacheManager?
    
    @MainActor
    private static var _islamicCalendarServiceInstance: IslamicCalendarService?
    
    @MainActor
    private static var _userAccountServiceInstance: FirebaseUserAccountService?

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
    
    @MainActor
    public static func createNotificationService() -> any NotificationServiceProtocol {
        if let existingInstance = _notificationServiceInstance {
            print("🔄 Reusing existing NotificationService instance")
            return existingInstance
        }
        
        let newInstance = NotificationService()
        _notificationServiceInstance = newInstance
        print("🏗️ Created new NotificationService singleton instance")
        return newInstance
    }
    
    @MainActor
    public static func createSettingsService() -> any SettingsServiceProtocol {
        if let existingInstance = _settingsServiceInstance {
            print("🔄 Reusing existing SettingsService instance")
            return existingInstance
        }
        
        let newInstance = SettingsService()
        _settingsServiceInstance = newInstance
        print("🏗️ Created new SettingsService singleton instance")
        return newInstance
    }
    
    @MainActor
    public static func createIslamicCacheManager() -> IslamicCacheManager {
        if let existingInstance = _islamicCacheManagerInstance {
            print("🔄 Reusing existing IslamicCacheManager instance")
            return existingInstance
        }
        
        let newInstance = IslamicCacheManager()
        _islamicCacheManagerInstance = newInstance
        print("🏗️ Created new IslamicCacheManager singleton instance")
        return newInstance
    }
    
    @MainActor
    public static func createIslamicCalendarService() -> any IslamicCalendarServiceProtocol {
        if let existingInstance = _islamicCalendarServiceInstance {
            print("🔄 Reusing existing IslamicCalendarService instance")
            return existingInstance
        }
        
        let newInstance = IslamicCalendarService()
        _islamicCalendarServiceInstance = newInstance
        print("🏗️ Created new IslamicCalendarService singleton instance")
        return newInstance
    }
    
    @MainActor
    public static func createPrayerTimeService(
        locationService: any LocationServiceProtocol,
        settingsService: any SettingsServiceProtocol,
        apiClient: any APIClientProtocol,
        errorHandler: ErrorHandler,
        retryMechanism: RetryMechanism,
        networkMonitor: NetworkMonitor,
        islamicCacheManager: IslamicCacheManager,
        islamicCalendarService: any IslamicCalendarServiceProtocol
    ) -> any PrayerTimeServiceProtocol {
        // Only create singleton if services match existing instances
        if let existingInstance = _prayerTimeServiceInstance,
           existingInstance.locationService === locationService,
           existingInstance.settingsService === settingsService {
            print("🔄 Reusing existing PrayerTimeService instance")
            return existingInstance
        }
        
        let newInstance = PrayerTimeService(
            locationService: locationService,
            settingsService: settingsService,
            apiClient: apiClient,
            errorHandler: errorHandler,
            retryMechanism: retryMechanism,
            networkMonitor: networkMonitor,
            islamicCacheManager: islamicCacheManager,
            islamicCalendarService: islamicCalendarService
        )
        _prayerTimeServiceInstance = newInstance
        print("🏗️ Created new PrayerTimeService singleton instance")
        return newInstance
    }

    public static func createAPIClient(
        configuration: APIConfiguration = .default
    ) -> any APIClientProtocol {
        return APIClient(configuration: configuration)
    }
    
    @MainActor
    public static func createUserAccountService() -> any UserAccountServiceProtocol {
        if let existingInstance = _userAccountServiceInstance {
            print("🔄 Reusing existing UserAccountService instance")
            return existingInstance
        }
        
        let newInstance = FirebaseUserAccountService()
        _userAccountServiceInstance = newInstance
        print("🏗️ Created new UserAccountService singleton instance")
        return newInstance
    }
    
    @MainActor
    private static var _notificationSchedulerInstance: NotificationScheduler?
    
    @MainActor
    public static func createNotificationScheduler(
        notificationService: any NotificationServiceProtocol,
        prayerTimeService: any PrayerTimeServiceProtocol,
        settingsService: any SettingsServiceProtocol
    ) -> NotificationScheduler {
        // Only create singleton if services match existing instances
        // We use identity comparison (===) to check if the dependencies are the same instances
        if let existingInstance = _notificationSchedulerInstance,
           // Note: We can't easily compare protocol types with === unless we cast to AnyObject or they are class-bound and we know the underlying types are classes.
           // However, NotificationScheduler stores them as existentials.
           // A safer check for now might be just checking if the instance exists, assuming dependencies don't change for the singleton container.
           // But the requirement was "compare by identity".
           // Let's try to cast to AnyObject for comparison if possible, or just rely on the singleton nature if we assume the container is stable.
           // Given the prompt explicitly asked for "compare by identity", I should try to respect that.
           // Swift protocols are not classes, so === might not work directly on the existential unless it's a class-bound protocol.
           // NotificationServiceProtocol, PrayerTimeServiceProtocol, SettingsServiceProtocol ARE class-bound (@MainActor implies class usually, or they inherit from ObservableObject which is class-bound).
           // Let's check the protocols. They inherit from ObservableObject, which is a class protocol (AnyObject).
           (existingInstance.notificationService as AnyObject) === (notificationService as AnyObject),
           (existingInstance.prayerTimeService as AnyObject) === (prayerTimeService as AnyObject),
           (existingInstance.settingsService as AnyObject) === (settingsService as AnyObject) {
            print("🔄 Reusing existing NotificationScheduler instance")
            return existingInstance
        }
        
        let newInstance = NotificationScheduler(
            notificationService: notificationService,
            prayerTimeService: prayerTimeService,
            settingsService: settingsService
        )
        _notificationSchedulerInstance = newInstance
        print("🏗️ Created new NotificationScheduler singleton instance")
        return newInstance
    }
}

// MARK: - Environment Detection

public extension DependencyContainer {
    @MainActor
    static var shared: DependencyContainer = {
        print("🏗️ Creating shared DependencyContainer singleton")
        
        // CRITICAL FIX: Use ServiceFactory singleton methods to prevent multiple service instances
        let resolvedLocationService = ServiceFactory.createLocationService()
        let resolvedApiClient = APIClient(configuration: .default)
        let resolvedNotificationService = ServiceFactory.createNotificationService()
        let resolvedSettingsService = ServiceFactory.createSettingsService()
        let resolvedErrorHandler: ErrorHandler = ErrorHandler(crashReporter: CrashReporter())
        let resolvedRetryMechanism: RetryMechanism = RetryMechanism(networkMonitor: NetworkMonitor.shared)
        let resolvedIslamicCacheManager = ServiceFactory.createIslamicCacheManager()
        let resolvedIslamicCalendarService = ServiceFactory.createIslamicCalendarService()

        let resolvedPrayerTimeService = ServiceFactory.createPrayerTimeService(
            locationService: resolvedLocationService,
            settingsService: resolvedSettingsService,
            apiClient: resolvedApiClient,
            errorHandler: resolvedErrorHandler,
            retryMechanism: resolvedRetryMechanism,
            networkMonitor: NetworkMonitor.shared,
            islamicCacheManager: resolvedIslamicCacheManager,
            islamicCalendarService: resolvedIslamicCalendarService
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
        
        let resolvedUserAccountService = ServiceFactory.createUserAccountService()

        let resolvedNotificationScheduler = ServiceFactory.createNotificationScheduler(
            notificationService: resolvedNotificationService,
            prayerTimeService: resolvedPrayerTimeService,
            settingsService: resolvedSettingsService
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
            userAccountService: resolvedUserAccountService,
            notificationScheduler: resolvedNotificationScheduler,
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
        let resolvedLocationService = locationService ?? ServiceFactory.createLocationService()
        let resolvedApiClient = apiClient ?? APIClient(configuration: .default)
        let resolvedNotificationService: any NotificationServiceProtocol = notificationService ?? NotificationService()
        let resolvedSettingsService: any SettingsServiceProtocol = settingsService ?? SettingsService()
        let resolvedErrorHandler: ErrorHandler = ErrorHandler(crashReporter: CrashReporter())
        let resolvedRetryMechanism: RetryMechanism = RetryMechanism(networkMonitor: NetworkMonitor.shared)
        let resolvedIslamicCacheManager = IslamicCacheManager()
        let resolvedIslamicCalendarService: any IslamicCalendarServiceProtocol = IslamicCalendarService()

        let resolvedPrayerTimeService: any PrayerTimeServiceProtocol = prayerTimeService ?? PrayerTimeService(
            locationService: resolvedLocationService,
            settingsService: resolvedSettingsService,
            apiClient: resolvedApiClient,
            errorHandler: resolvedErrorHandler,
            retryMechanism: resolvedRetryMechanism,
            networkMonitor: NetworkMonitor.shared,
            islamicCacheManager: resolvedIslamicCacheManager,
            islamicCalendarService: resolvedIslamicCalendarService
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
        let resolvedUserAccountService: any UserAccountServiceProtocol = MockUserAccountService()
        
        let resolvedNotificationScheduler = ServiceFactory.createNotificationScheduler(
            notificationService: resolvedNotificationService,
            prayerTimeService: resolvedPrayerTimeService,
            settingsService: resolvedSettingsService
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
            userAccountService: resolvedUserAccountService,
            notificationScheduler: resolvedNotificationScheduler,
            apiConfiguration: .default,
            isTestEnvironment: true
        )
    }
}

// MARK: - Test Doubles

/// Lightweight mock user account service for tests and previews to avoid real Firebase initialization
@MainActor
public final class MockUserAccountService: UserAccountServiceProtocol {
    public var currentUser: AccountUser?

    public func sendSignInLink(to email: String) async throws {}
    public func isSignInWithEmailLink(_ url: URL) -> Bool { false }
    public func signIn(withEmail email: String, linkURL: URL) async throws {}
    public func createUser(email: String, password: String) async throws {}
    public func signIn(email: String, password: String) async throws {}
    public func sendPasswordResetEmail(to email: String) async throws {}
    public func confirmPasswordReset(code: String, newPassword: String) async throws {}
    public func signOut() async throws { currentUser = nil }
    public func deleteAccount() async throws { currentUser = nil }
    public func updateMarketingOptIn(_ enabled: Bool) async throws {}
    public func syncSettingsSnapshot(_ snapshot: SettingsSnapshot) async throws {}
    public func fetchSettingsSnapshot() async throws -> SettingsSnapshot? { nil }
}
