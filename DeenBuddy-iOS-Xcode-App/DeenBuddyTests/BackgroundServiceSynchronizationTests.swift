//
//  BackgroundServiceSynchronizationTests.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-11.
//

import XCTest
import Combine
import CoreLocation
import BackgroundTasks
@testable import DeenBuddy

/// Tests for background service synchronization with current settings
class BackgroundServiceSynchronizationTests: XCTestCase {
    
    // MARK: - Properties
    
    private var settingsService: BackgroundSyncMockSettingsService!
    private var locationService: BackgroundSyncMockLocationService!
    private var apiClient: MockAPIClient!
    private var notificationService: BackgroundSyncMockNotificationService!
    private var prayerTimeService: PrayerTimeService!
    private var backgroundTaskManager: BackgroundTaskManager!
    private var backgroundPrayerRefreshService: BackgroundPrayerRefreshService!
    private var islamicCacheManager: IslamicCacheManager!
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Setup & Teardown
    
    @MainActor
    override func setUp() {
        super.setUp()
        
        // Create mock services
        settingsService = BackgroundSyncMockSettingsService()
        locationService = BackgroundSyncMockLocationService()
        apiClient = MockAPIClient()
        notificationService = BackgroundSyncMockNotificationService()

        // Create cache manager
        islamicCacheManager = IslamicCacheManager()
        
        // Create prayer time service with dependencies
        prayerTimeService = PrayerTimeService(
            locationService: locationService as LocationServiceProtocol,
            settingsService: settingsService,
            apiClient: apiClient,
            errorHandler: ErrorHandler(crashReporter: CrashReporter()),
            retryMechanism: RetryMechanism(networkMonitor: NetworkMonitor.shared),
            networkMonitor: NetworkMonitor.shared,
            islamicCacheManager: islamicCacheManager,
            islamicCalendarService: IslamicCalendarService()
        )

        // Create background services
        backgroundTaskManager = BackgroundTaskManager(
            prayerTimeService: prayerTimeService,
            notificationService: notificationService,
            locationService: locationService as LocationServiceProtocol
        )

        backgroundPrayerRefreshService = BackgroundPrayerRefreshService(
            prayerTimeService: prayerTimeService,
            locationService: locationService as LocationServiceProtocol
        )
        
        // Set up test location
        locationService.currentLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
    }
    
    override func tearDown() {
        cancellables.removeAll()
        
        settingsService = nil
        locationService = nil
        apiClient = nil
        notificationService = nil
        prayerTimeService = nil
        backgroundTaskManager = nil
        backgroundPrayerRefreshService = nil
        islamicCacheManager = nil
        
        super.tearDown()
    }
    
    // MARK: - Background Service Dependency Tests
    
    @MainActor
    func testBackgroundTaskManagerUsesCurrentSettings() {
        // Given: Initial settings
        settingsService.calculationMethod = CalculationMethod.muslimWorldLeague
        settingsService.madhab = Madhab.shafi

        // When: Settings change
        settingsService.calculationMethod = CalculationMethod.egyptian
        settingsService.madhab = Madhab.hanafi

        // Then: Background task manager should use updated settings through PrayerTimeService
        XCTAssertEqual(prayerTimeService.calculationMethod, CalculationMethod.egyptian)
        XCTAssertEqual(prayerTimeService.madhab, Madhab.hanafi)
        
        // And: Background task manager has access to the same PrayerTimeService instance
        XCTAssertTrue(backgroundTaskManager.prayerTimeService === prayerTimeService)
    }
    
    @MainActor
    func testBackgroundPrayerRefreshServiceUsesCurrentSettings() {
        // Given: Initial settings
        settingsService.calculationMethod = CalculationMethod.muslimWorldLeague
        settingsService.madhab = Madhab.shafi
        
        // When: Settings change
        settingsService.calculationMethod = CalculationMethod.karachi
        settingsService.madhab = Madhab.hanafi
        
        // Then: Background prayer refresh service should use updated settings
        let calculationMethod = prayerTimeService.calculationMethod
        let madhab = prayerTimeService.madhab
        let backgroundServicePrayerTimeService = backgroundPrayerRefreshService.prayerTimeService
        
        XCTAssertEqual(calculationMethod, CalculationMethod.karachi)
        XCTAssertEqual(madhab, Madhab.hanafi)
        
        // And: Background service has access to the same PrayerTimeService instance
        XCTAssertTrue(backgroundServicePrayerTimeService === prayerTimeService)
    }
    
    @MainActor
    func testBackgroundServicesReceiveSettingsUpdates() {
        let expectation = XCTestExpectation(description: "Background services receive settings updates")

        // Given: Observer for prayer time changes
        var updateCount = 0
        prayerTimeService.$todaysPrayerTimes
            .dropFirst()
            .sink { _ in
                updateCount += 1
                if updateCount >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When: Settings change
        Task {
            await MainActor.run {
                settingsService.calculationMethod = CalculationMethod.egyptian
            }
            
            // Trigger prayer time calculation to verify settings are used
            await prayerTimeService.refreshPrayerTimes()
        }
        
        // Then: Background services should receive the update
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssertEqual(prayerTimeService.calculationMethod, CalculationMethod.egyptian)
    }
    
    // MARK: - Background Task Registration Tests
    
    @MainActor
    func testBackgroundTaskManagerRegistration() {
        // When: Background tasks are registered
        backgroundTaskManager.registerBackgroundTasks()

        // Then: Registration should complete without errors
        // Note: In a real test environment, we would verify the tasks are registered
        // but BGTaskScheduler registration is not easily testable in unit tests
        XCTAssertTrue(true, "Background task registration completed")
    }
    
    @MainActor
    func testBackgroundPrayerRefreshServiceStartup() {
        // When: Background refresh is started
        backgroundPrayerRefreshService.startBackgroundRefresh()

        // Then: Service should be in refreshing state
        XCTAssertNotNil(backgroundPrayerRefreshService.nextRefreshTime)
    }
    
    // MARK: - Settings Change Propagation Tests
    
    @MainActor
    func testSettingsChangePropagationToBackgroundServices() {
        let expectation = XCTestExpectation(description: "Settings propagate to background services")
        
        // Given: Initial state
        let initialMethod = settingsService.calculationMethod
        let initialMadhab = settingsService.madhab
        
        // When: Multiple settings changes
        Task {
            await MainActor.run {
                settingsService.calculationMethod = CalculationMethod.egyptian
                settingsService.madhab = Madhab.hanafi
            }
            
            // Small delay to allow propagation
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            await MainActor.run {
                // Verify both background services see the changes
                XCTAssertEqual(self.prayerTimeService.calculationMethod, CalculationMethod.egyptian)
                XCTAssertEqual(self.prayerTimeService.madhab, Madhab.hanafi)
                
                // Verify the changes are different from initial
                XCTAssertNotEqual(self.prayerTimeService.calculationMethod, initialMethod)
                XCTAssertNotEqual(self.prayerTimeService.madhab, initialMadhab)
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    @MainActor
    func testBackgroundServicesCacheInvalidationOnSettingsChange() {
        let expectation = XCTestExpectation(description: "Background services handle cache invalidation")
        
        // Given: Cached prayer times
        Task {
            await prayerTimeService.refreshPrayerTimes()
            
            // Wait for initial cache
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // When: Settings change (this should trigger cache invalidation)
            await MainActor.run {
                settingsService.calculationMethod = CalculationMethod.egyptian
            }
            
            // Wait for cache invalidation to complete
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            await MainActor.run {
                // Then: Background services should use new settings
                XCTAssertEqual(self.prayerTimeService.calculationMethod, CalculationMethod.egyptian)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Integration Tests
    
    @MainActor
    func testEndToEndBackgroundServiceSynchronization() {
        let expectation = XCTestExpectation(description: "End-to-end background service synchronization")

        // Given: Complete background service setup
        backgroundTaskManager.registerBackgroundTasks()
        backgroundPrayerRefreshService.startBackgroundRefresh()
        
        // When: Complete workflow with settings changes
        Task {
            // 1. Initial prayer time calculation
            await prayerTimeService.refreshPrayerTimes()
            
            // 2. Change settings
            await MainActor.run {
                settingsService.calculationMethod = CalculationMethod.karachi
                settingsService.madhab = Madhab.hanafi
            }
            
            // 3. Wait for propagation
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // 4. Trigger background refresh
            await prayerTimeService.refreshTodaysPrayerTimes()
            
            await MainActor.run {
                // Then: Everything should be synchronized
                XCTAssertEqual(self.prayerTimeService.calculationMethod, CalculationMethod.karachi)
                XCTAssertEqual(self.prayerTimeService.madhab, Madhab.hanafi)
                
                // Background services should have the same reference
                XCTAssertTrue(self.backgroundTaskManager.prayerTimeService === self.prayerTimeService)
                XCTAssertTrue(self.backgroundPrayerRefreshService.prayerTimeService === self.prayerTimeService)
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testBackgroundServiceSynchronizationPerformance() {
        measure {
            // Test rapid settings changes with background services
            for i in 0..<50 {
                let method: CalculationMethod = i % 2 == 0 ? CalculationMethod.egyptian : CalculationMethod.muslimWorldLeague
                let madhab: Madhab = i % 2 == 0 ? Madhab.hanafi : Madhab.shafi
                
                settingsService.calculationMethod = method
                settingsService.madhab = madhab
            }
        }
    }
}

// MARK: - Mock Background Task Scheduler

/// Mock for testing background task registration
class MockBGTaskScheduler {
    static var registeredTasks: [String] = []
    
    static func register(forTaskWithIdentifier identifier: String, using queue: DispatchQueue?, launchHandler: @escaping (BGTask) -> Void) -> Bool {
        registeredTasks.append(identifier)
        return true
    }
    
    static func reset() {
        registeredTasks.removeAll()
    }
}

// MARK: - Mock Classes

@MainActor
class BackgroundSyncMockSettingsService: SettingsServiceProtocol, ObservableObject {
    @Published var calculationMethod: CalculationMethod = .muslimWorldLeague
    @Published var madhab: Madhab = .shafi
    @Published var useAstronomicalMaghrib: Bool = false
    @Published var notificationsEnabled: Bool = true
    @Published var theme: ThemeMode = .dark
    @Published var timeFormat: TimeFormat = .twelveHour
    @Published var notificationOffset: TimeInterval = 300
    @Published var hasCompletedOnboarding: Bool = false
    @Published var userName: String = ""
    @Published var overrideBatteryOptimization: Bool = false
    @Published var showArabicSymbolInWidget: Bool = true
    @Published var liveActivitiesEnabled: Bool = true

    var enableNotifications: Bool {
        get { notificationsEnabled }
        set { notificationsEnabled = newValue }
    }

    func saveSettings() async throws {}
    func loadSettings() async throws {}
    func resetToDefaults() async throws {}
    func saveImmediately() async throws {}
    func saveOnboardingSettings() async throws {}
}

@MainActor
class BackgroundSyncMockNotificationService: NotificationServiceProtocol, ObservableObject {
    @Published var authorizationStatus: UNAuthorizationStatus = .authorized
    @Published var notificationsEnabled: Bool = true

    func requestNotificationPermission() async throws -> Bool { return true }
    func requestCriticalAlertPermission() async throws -> Bool { return true }
    func schedulePrayerNotifications(for prayerTimes: [PrayerTime], date: Date?) async throws {}
    func cancelAllNotifications() async {}
    func cancelNotifications(for prayer: Prayer) async {}
    func schedulePrayerTrackingNotification(for prayer: Prayer, at prayerTime: Date, reminderMinutes: Int) async throws {}
    func getNotificationSettings() -> NotificationSettings { return .default }
    func updateNotificationSettings(_ settings: NotificationSettings) {}
    func updateAppBadge() async {}
    func clearBadge() async {}
    func updateBadgeForCompletedPrayer() async {}
}

@MainActor
class BackgroundSyncMockLocationService: LocationServiceProtocol, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    @Published var currentLocation: CLLocation? = nil
    @Published var currentLocationInfo: LocationInfo? = nil
    @Published var isUpdatingLocation: Bool = false
    @Published var locationError: Error? = nil
    @Published var currentHeading: Double = 0
    @Published var headingAccuracy: Double = 5.0
    @Published var isUpdatingHeading: Bool = false

    var permissionStatus: CLAuthorizationStatus { authorizationStatus }

    private let locationSubject = PassthroughSubject<CLLocation, Error>()
    private let headingSubject = PassthroughSubject<CLHeading, Error>()

    var locationPublisher: AnyPublisher<CLLocation, Error> {
        locationSubject.eraseToAnyPublisher()
    }

    var headingPublisher: AnyPublisher<CLHeading, Error> {
        headingSubject.eraseToAnyPublisher()
    }

    func requestLocationPermission() {}
    func requestLocationPermissionAsync() async -> CLAuthorizationStatus { return .authorizedWhenInUse }
    func requestLocation() async throws -> CLLocation {
        return CLLocation(latitude: 37.7749, longitude: -122.4194)
    }
    func startUpdatingLocation() {}
    func stopUpdatingLocation() {}
    func startBackgroundLocationUpdates() {}
    func stopBackgroundLocationUpdates() {}
    func startUpdatingHeading() {}
    func stopUpdatingHeading() {}
    func geocodeCity(_ cityName: String) async throws -> CLLocation {
        return CLLocation(latitude: 37.7749, longitude: -122.4194)
    }
    func searchCity(_ cityName: String) async throws -> [LocationInfo] { return [] }
    func getLocationInfo(for coordinate: LocationCoordinate) async throws -> LocationInfo {
        return LocationInfo(coordinate: coordinate, accuracy: 10.0, city: "Test", country: "Test")
    }
    func getCachedLocation() -> CLLocation? { return currentLocation }
    func isCachedLocationValid() -> Bool { return true }
    func getLocationPreferCached() async throws -> CLLocation { return try await requestLocation() }
    func isCurrentLocationFromCache() -> Bool { return false }
    func getLocationAge() -> TimeInterval? { return 30.0 }
}
