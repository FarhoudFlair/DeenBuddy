//
//  PrayerTimeSynchronizationIntegrationTests.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-11.
//

import XCTest
import Combine
import CoreLocation
import BackgroundTasks
@testable import DeenBuddy

/// Integration tests for the complete prayer time synchronization system
/// Tests the interaction between SettingsService, PrayerTimeService, cache systems, and background services
class PrayerTimeSynchronizationIntegrationTests: XCTestCase {

    // MARK: - Properties

    private var dependencyContainer: DependencyContainer!
    private var settingsService: PrayerTimeSyncMockSettingsService!
    private var locationService: PrayerTimeSyncTestMockLocationService!
    private var apiClient: MockAPIClient!
    private var notificationService: PrayerTimeSyncMockNotificationService!
    private var prayerTimeService: PrayerTimeService!
    private var backgroundTaskManager: BackgroundTaskManager!
    private var backgroundPrayerRefreshService: BackgroundPrayerRefreshService!
    private var apiCache: APICache!
    private var islamicCacheManager: IslamicCacheManager!
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Setup & Teardown

    @MainActor
    override func setUp() {
        super.setUp()

        // Create mock services
        settingsService = PrayerTimeSyncMockSettingsService()
        locationService = PrayerTimeSyncTestMockLocationService()
        apiClient = MockAPIClient()
        notificationService = PrayerTimeSyncMockNotificationService()
        
        // Create cache systems
        apiCache = APICache()
        islamicCacheManager = IslamicCacheManager()
        
        // Create prayer time service
        prayerTimeService = PrayerTimeService(
            locationService: locationService as LocationServiceProtocol,
            settingsService: settingsService,
            apiClient: apiClient,
            errorHandler: ErrorHandler(crashReporter: CrashReporter()),
            retryMechanism: RetryMechanism(networkMonitor: NetworkMonitor.shared),
            networkMonitor: NetworkMonitor.shared,
            islamicCacheManager: islamicCacheManager
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

        // Create additional required services for DependencyContainer
        let prayerTrackingService = PrayerTrackingService(
            prayerTimeService: prayerTimeService,
            settingsService: settingsService,
            locationService: locationService as LocationServiceProtocol
        )

        let prayerAnalyticsService = PrayerAnalyticsService(
            prayerTrackingService: prayerTrackingService
        )

        let prayerTrackingCoordinator = PrayerTrackingCoordinator(
            prayerTimeService: prayerTimeService,
            prayerTrackingService: prayerTrackingService,
            notificationService: notificationService,
            settingsService: settingsService
        )

        let tasbihService = TasbihService()
        let islamicCalendarService = IslamicCalendarService()

        // Create dependency container for integration testing
        dependencyContainer = DependencyContainer(
            locationService: locationService as LocationServiceProtocol,
            apiClient: apiClient,
            notificationService: notificationService,
            prayerTimeService: prayerTimeService,
            settingsService: settingsService,
            prayerTrackingService: prayerTrackingService,
            prayerAnalyticsService: prayerAnalyticsService,
            prayerTrackingCoordinator: prayerTrackingCoordinator,
            tasbihService: tasbihService,
            islamicCalendarService: islamicCalendarService,
            backgroundTaskManager: backgroundTaskManager,
            backgroundPrayerRefreshService: backgroundPrayerRefreshService,
            islamicCacheManager: islamicCacheManager,
            isTestEnvironment: true
        )
        
        // Set up test location
        locationService.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
    }
    
    @MainActor
    override func tearDown() {
        cancellables.removeAll()
        apiCache.clearAllCache()
        islamicCacheManager.clearAllCache()
        
        dependencyContainer = nil
        settingsService = nil
        locationService = nil
        apiClient = nil
        notificationService = nil
        prayerTimeService = nil
        backgroundTaskManager = nil
        backgroundPrayerRefreshService = nil
        apiCache = nil
        islamicCacheManager = nil
        
        super.tearDown()
    }
    
    // MARK: - End-to-End Integration Tests
    
    func testCompleteSettingsChangeSynchronization() async throws {
        let expectation = XCTestExpectation(description: "Complete settings change synchronization")
        expectation.expectedFulfillmentCount = 2 // Initial + after settings change

        var prayerTimeUpdates: [[PrayerTime]] = []

        // Given: Observer for prayer time changes
        await MainActor.run {
            prayerTimeService.$todaysPrayerTimes
                .dropFirst() // Skip initial empty value
                .sink { prayerTimes in
                    print("🕌 Test: Received prayer times update with \(prayerTimes.count) times")
                    if !prayerTimes.isEmpty {
                        prayerTimeUpdates.append(prayerTimes)
                        print("🕌 Test: Fulfilling expectation (\(prayerTimeUpdates.count)/2)")
                        expectation.fulfill()
                    }
                }
                .store(in: &cancellables)
        }

        // Add notification observer for debugging
        await MainActor.run {
            NotificationCenter.default.publisher(for: .settingsDidChange)
                .sink { _ in
                    print("🔔 Test: Settings change notification received")
                }
                .store(in: &cancellables)
        }

        // When: Complete workflow
        // 1. Initial prayer time calculation
        await prayerTimeService.refreshPrayerTimes()

        // Wait for initial calculation (account for debouncing + async operations)
        try await Task.sleep(nanoseconds: 1_200_000_000) // 1.2 seconds

        // 2. Change settings (should trigger cache invalidation and recalculation)
        await MainActor.run {
            settingsService.calculationMethod = CalculationMethod.egyptian
            settingsService.madhab = Madhab.hanafi
        }

        // Wait for settings change propagation (account for 300ms debounce + async operations)
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2.0 seconds

        // Then: Verify complete synchronization
        await fulfillment(of: [expectation], timeout: 25.0) // Increased timeout for CI

        XCTAssertEqual(prayerTimeUpdates.count, 2, "Should have initial and updated prayer times")

        let currentMethod = await MainActor.run { prayerTimeService.calculationMethod }
        let currentMadhab = await MainActor.run { prayerTimeService.madhab }
        XCTAssertEqual(currentMethod, CalculationMethod.egyptian)
        XCTAssertEqual(currentMadhab, Madhab.hanafi)
    }
    
    func testCacheSystemsIntegrationWithSettingsChanges() async throws {
        // Given: Initial settings and cached data
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let clLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        // Cache data in all systems with initial settings
        let prayerTimes = createMockPrayerTimes(for: date, location: location, method: "muslim_world_league")
        let schedule = createMockPrayerSchedule(for: date)
        
        apiCache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
        await islamicCacheManager.cachePrayerSchedule(schedule, for: date, location: clLocation, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)

        // Verify initial cache exists
        XCTAssertNotNil(apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi))
        let cachedSchedule = await islamicCacheManager.getCachedPrayerSchedule(for: date, location: clLocation, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
        XCTAssertNotNil(cachedSchedule.schedule)

        // When: Settings change
        await MainActor.run {
            settingsService.calculationMethod = CalculationMethod.egyptian
        }
        
        // Wait for cache invalidation
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Then: Old cache should be cleared, new cache should be separate
        let oldAPICache = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
        let oldIslamicCache = await islamicCacheManager.getCachedPrayerSchedule(for: date, location: clLocation, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)

        // Old cache should still exist (cache keys are method-specific now)
        XCTAssertNotNil(oldAPICache, "Old cache should exist with method-specific keys")
        XCTAssertNotNil(oldIslamicCache.schedule, "Old Islamic cache should exist with method-specific keys")

        // New settings should have no cache initially
        let newAPICache = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: CalculationMethod.egyptian, madhab: Madhab.shafi)
        let newIslamicCache = await islamicCacheManager.getCachedPrayerSchedule(for: date, location: clLocation, calculationMethod: CalculationMethod.egyptian, madhab: Madhab.shafi)
        
        XCTAssertNil(newAPICache, "New settings should have no cache initially")
        XCTAssertNil(newIslamicCache.schedule, "New Islamic cache should be empty initially")
    }
    
    func testBackgroundServicesIntegrationWithSettingsChanges() async throws {
        let expectation = XCTestExpectation(description: "Background services integration")
        
        // Given: Background services are started
        await backgroundTaskManager.registerBackgroundTasks()
        await backgroundPrayerRefreshService.startBackgroundRefresh()
        
        // When: Settings change
        await MainActor.run {
            settingsService.calculationMethod = CalculationMethod.karachi
            settingsService.madhab = Madhab.hanafi
        }

        // Wait for propagation
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Then: Background services should use new settings
        let currentMethod = await MainActor.run { prayerTimeService.calculationMethod }
        let currentMadhab = await MainActor.run { prayerTimeService.madhab }
        XCTAssertEqual(currentMethod, CalculationMethod.karachi)
        XCTAssertEqual(currentMadhab, Madhab.hanafi)

        // And: Background services should have access to the same PrayerTimeService
        let bgTaskPrayerService = await MainActor.run { backgroundTaskManager.prayerTimeService }
        let bgRefreshPrayerService = await MainActor.run { backgroundPrayerRefreshService.prayerTimeService }
        XCTAssertTrue(bgTaskPrayerService === prayerTimeService)
        XCTAssertTrue(bgRefreshPrayerService === prayerTimeService)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testDependencyContainerIntegration() async throws {
        // Given: Dependency container setup
        await dependencyContainer.setupServices()
        
        // When: Settings change through the container's settings service
        await MainActor.run {
            dependencyContainer.settingsService.calculationMethod = CalculationMethod.ummAlQura
            dependencyContainer.settingsService.madhab = Madhab.hanafi
        }

        // Wait for propagation
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Then: All services should be synchronized
        await MainActor.run {
            XCTAssertEqual(dependencyContainer.prayerTimeService.calculationMethod, CalculationMethod.ummAlQura)
            XCTAssertEqual(dependencyContainer.prayerTimeService.madhab, Madhab.hanafi)
            XCTAssertEqual(dependencyContainer.settingsService.calculationMethod, CalculationMethod.ummAlQura)
            XCTAssertEqual(dependencyContainer.settingsService.madhab, Madhab.hanafi)

            // And: Background services should use the same settings
            XCTAssertTrue(dependencyContainer.backgroundTaskManager.prayerTimeService === dependencyContainer.prayerTimeService)
            XCTAssertTrue(dependencyContainer.backgroundPrayerRefreshService.prayerTimeService === dependencyContainer.prayerTimeService)
        }
    }
    
    // MARK: - Real-World Scenario Tests
    
    func testUserChangesCalculationMethodScenario() async throws {
        let expectation = XCTestExpectation(description: "User changes calculation method scenario")
        expectation.expectedFulfillmentCount = 3 // Initial + 2 changes

        var calculationMethods: [CalculationMethod] = []

        // Given: Observer for calculation method changes
        await MainActor.run {
            prayerTimeService.$todaysPrayerTimes
                .dropFirst()
                .sink { prayerTimes in
                    Task { @MainActor in
                        let currentMethod = self.prayerTimeService.calculationMethod
                        calculationMethods.append(currentMethod)
                        print("🕌 Test: Prayer times updated, method: \(currentMethod.displayName), count: \(calculationMethods.count)")
                        expectation.fulfill()
                    }
                }
                .store(in: &cancellables)
        }

        // Add notification observer for debugging
        await MainActor.run {
            NotificationCenter.default.publisher(for: .settingsDidChange)
                .sink { _ in
                    print("🔔 Test: Settings change notification received")
                }
                .store(in: &cancellables)
        }

        // When: User workflow - initial load, then changes method twice
        await prayerTimeService.refreshPrayerTimes()
        try await Task.sleep(nanoseconds: 1_200_000_000) // Account for debouncing + async operations

        await MainActor.run {
            settingsService.calculationMethod = CalculationMethod.egyptian
        }
        try await Task.sleep(nanoseconds: 2_000_000_000) // Account for 300ms debounce + async operations

        await MainActor.run {
            settingsService.calculationMethod = CalculationMethod.karachi
        }
        try await Task.sleep(nanoseconds: 2_000_000_000) // Account for 300ms debounce + async operations

        // Then: All changes should be reflected
        await fulfillment(of: [expectation], timeout: 30.0) // Increased timeout for CI

        // Defensive check for array bounds
        XCTAssertGreaterThanOrEqual(calculationMethods.count, 3, "Should have at least 3 calculation method changes recorded")

        if calculationMethods.count >= 3 {
            XCTAssertEqual(calculationMethods[0], CalculationMethod.muslimWorldLeague) // Initial
            XCTAssertEqual(calculationMethods[1], CalculationMethod.egyptian) // First change
            XCTAssertEqual(calculationMethods[2], CalculationMethod.karachi) // Second change
        } else {
            XCTFail("Expected 3 calculation method changes but got \(calculationMethods.count): \(calculationMethods)")
        }

        await MainActor.run {
            XCTAssertEqual(prayerTimeService.calculationMethod, CalculationMethod.karachi) // Final state
        }
    }
    
    func testAppBackgroundingWithSettingsChangeScenario() async throws {
        // Given: App is running with initial settings
        await prayerTimeService.refreshPrayerTimes()
        try await Task.sleep(nanoseconds: 500_000_000)
        
        let initialMethod = await prayerTimeService.calculationMethod
        
        // When: App goes to background and settings change
        await backgroundTaskManager.registerBackgroundTasks()
        await backgroundPrayerRefreshService.startBackgroundRefresh()
        
        await MainActor.run {
            settingsService.calculationMethod = CalculationMethod.egyptian
        }

        // Simulate background refresh
        await prayerTimeService.refreshTodaysPrayerTimes()
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Then: Background services should use new settings
        await MainActor.run {
            XCTAssertNotEqual(prayerTimeService.calculationMethod, initialMethod)
            XCTAssertEqual(prayerTimeService.calculationMethod, CalculationMethod.egyptian)
        }
    }
    
    func testMultipleRapidSettingsChangesIntegration() async throws {
        // Note: Due to debouncing in PrayerTimeService (300ms), rapid changes will be consolidated
        // This test validates the debouncing behavior rather than expecting all individual updates
        let expectation = XCTestExpectation(description: "Multiple rapid settings changes")
        expectation.expectedFulfillmentCount = 2 // Initial + final debounced update

        var settingsHistory: [(CalculationMethod, Madhab)] = []

        // Given: Observer for all changes
        await MainActor.run {
            prayerTimeService.$todaysPrayerTimes
                .dropFirst()
                .sink { _ in
                    Task { @MainActor in
                        let current = (self.prayerTimeService.calculationMethod, self.prayerTimeService.madhab)
                        settingsHistory.append(current)
                        expectation.fulfill()
                    }
                }
                .store(in: &cancellables)
        }

        // When: Rapid settings changes (these will be debounced)
        await prayerTimeService.refreshPrayerTimes()
        try await Task.sleep(nanoseconds: 800_000_000) // Wait for initial

        // Rapid fire changes - these will be debounced to only the final change
        await MainActor.run {
            settingsService.calculationMethod = CalculationMethod.egyptian
        }
        try await Task.sleep(nanoseconds: 100_000_000) // Short delay

        await MainActor.run {
            settingsService.madhab = Madhab.hanafi
        }
        try await Task.sleep(nanoseconds: 100_000_000) // Short delay

        await MainActor.run {
            settingsService.calculationMethod = CalculationMethod.karachi
        }
        try await Task.sleep(nanoseconds: 100_000_000) // Short delay

        await MainActor.run {
            settingsService.madhab = Madhab.shafi
        }

        // Wait for debouncing to complete
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds for debouncing + async

        // Then: Should handle rapid changes gracefully with debouncing
        await fulfillment(of: [expectation], timeout: 15.0)

        XCTAssertEqual(settingsHistory.count, 2, "Should have 2 updates: initial + final debounced")
        XCTAssertEqual(settingsHistory.last?.0, CalculationMethod.karachi, "Final method should be the last one set")
        XCTAssertEqual(settingsHistory.last?.1, Madhab.shafi, "Final madhab should be the last one set")
    }

    func testConcurrentAccessIntegration() async throws {
        // Given: Multiple concurrent operations
        let expectation = XCTestExpectation(description: "Concurrent access integration")
        expectation.expectedFulfillmentCount = 3

        // When: Concurrent settings changes and prayer time requests
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await MainActor.run {
                    self.settingsService.calculationMethod = CalculationMethod.egyptian
                }
                expectation.fulfill()
            }

            group.addTask {
                await self.prayerTimeService.refreshPrayerTimes()
                expectation.fulfill()
            }

            group.addTask {
                await MainActor.run {
                    self.settingsService.madhab = Madhab.hanafi
                }
                expectation.fulfill()
            }
        }

        // Then: System should remain stable
        await fulfillment(of: [expectation], timeout: 10.0)

        await MainActor.run {
            XCTAssertEqual(prayerTimeService.calculationMethod, CalculationMethod.egyptian)
            XCTAssertEqual(prayerTimeService.madhab, Madhab.hanafi)
        }
    }

    func testNetworkFailureWithCacheIntegration() async throws {
        // Given: Network failure scenario
        apiClient.shouldFailRequests = true
        apiClient.isNetworkAvailable = false

        // Cache some data first
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let cachedPrayerTimes = createMockPrayerTimes(for: date, location: location, method: "muslim_world_league")

        apiCache.cachePrayerTimes(cachedPrayerTimes, for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)

        // When: Settings change during network failure
        await MainActor.run {
            settingsService.calculationMethod = CalculationMethod.egyptian
        }

        // Then: System should handle gracefully
        // Old cache should still exist for old settings
        let oldCache = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
        XCTAssertNotNil(oldCache, "Old cache should still exist")

        // New settings should have no cache
        let newCache = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: CalculationMethod.egyptian, madhab: Madhab.shafi)
        XCTAssertNil(newCache, "New settings should have no cache")
    }

    // MARK: - Helper Methods

    private func createMockPrayerTimes(for date: Date, location: LocationCoordinate, method: String) -> PrayerTimes {
        return PrayerTimes(
            date: date,
            fajr: date.addingTimeInterval(5 * 3600),
            dhuhr: date.addingTimeInterval(12 * 3600),
            asr: date.addingTimeInterval(15 * 3600),
            maghrib: date.addingTimeInterval(18 * 3600),
            isha: date.addingTimeInterval(19 * 3600),
            calculationMethod: method,
            location: location
        )
    }

    private func createMockPrayerSchedule(for date: Date) -> PrayerSchedule {
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let dailySchedule = DailyPrayerSchedule(
            date: date,
            fajr: date.addingTimeInterval(5 * 3600),
            dhuhr: date.addingTimeInterval(12 * 3600),
            asr: date.addingTimeInterval(15 * 3600),
            maghrib: date.addingTimeInterval(18 * 3600),
            isha: date.addingTimeInterval(19 * 3600)
        )

        return PrayerSchedule(
            startDate: date,
            endDate: date,
            location: location,
            calculationMethod: CalculationMethod.muslimWorldLeague,
            madhab: Madhab.shafi,
            dailySchedules: [dailySchedule]
        )
    }
}

// MARK: - Test Mock Classes

/// Mock settings service for prayer time synchronization tests
@MainActor
class PrayerTimeSyncMockSettingsService: SettingsServiceProtocol, ObservableObject {
    @Published var calculationMethod: CalculationMethod = .muslimWorldLeague {
        didSet { notifySettingsChanged() }
    }
    @Published var madhab: Madhab = .shafi {
        didSet { notifySettingsChanged() }
    }
    @Published var notificationsEnabled: Bool = true {
        didSet { notifySettingsChanged() }
    }
    @Published var theme: ThemeMode = .dark {
        didSet { notifySettingsChanged() }
    }
    @Published var timeFormat: TimeFormat = .twelveHour {
        didSet { notifySettingsChanged() }
    }
    @Published var notificationOffset: TimeInterval = 300 {
        didSet { notifySettingsChanged() }
    }
    @Published var hasCompletedOnboarding: Bool = false {
        didSet { notifySettingsChanged() }
    }
    @Published var userName: String = "" {
        didSet { notifySettingsChanged() }
    }
    @Published var overrideBatteryOptimization: Bool = false {
        didSet { notifySettingsChanged() }
    }
    @Published var showArabicSymbolInWidget: Bool = true {
        didSet { notifySettingsChanged() }
    }

    var enableNotifications: Bool {
        get { notificationsEnabled }
        set { notificationsEnabled = newValue }
    }

    /// Send notification when settings change (to match real SettingsService behavior)
    private func notifySettingsChanged() {
        print("🔔 Mock: Settings changed, posting notification")
        NotificationCenter.default.post(name: .settingsDidChange, object: self)
    }

    func saveSettings() async throws {
        // Mock implementation
    }

    func loadSettings() async throws {
        // Mock implementation
    }

    func resetToDefaults() async throws {
        // Mock implementation
    }

    func saveImmediately() async throws {
        // Mock implementation
    }

    func saveOnboardingSettings() async throws {
        // Mock implementation
    }
}

/// Mock notification service for prayer time synchronization tests
@MainActor
class PrayerTimeSyncMockNotificationService: NotificationServiceProtocol, ObservableObject {
    @Published var authorizationStatus: UNAuthorizationStatus = .authorized
    @Published var notificationsEnabled: Bool = true

    func requestNotificationPermission() async throws -> Bool {
        return true
    }

    func schedulePrayerNotifications(for prayerTimes: [PrayerTime], date: Date?) async throws {
        // Mock implementation
    }

    func cancelAllNotifications() async {
        // Mock implementation
    }

    func cancelNotifications(for prayer: Prayer) async {
        // Mock implementation
    }

    func schedulePrayerTrackingNotification(for prayer: Prayer, at prayerTime: Date, reminderMinutes: Int) async throws {
        // Mock implementation
    }

    func getNotificationSettings() -> NotificationSettings {
        return .default
    }

    func updateNotificationSettings(_ settings: NotificationSettings) {
        // Mock implementation
    }
}

/// Extended MockLocationService with mockLocation property for testing
@MainActor
class PrayerTimeSyncTestMockLocationService: LocationServiceProtocol, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    @Published var currentLocation: CLLocation? = nil
    @Published var currentLocationInfo: LocationInfo? = nil
    @Published var isUpdatingLocation: Bool = false
    @Published var locationError: Error? = nil
    @Published var currentHeading: Double = 0
    @Published var headingAccuracy: Double = 5.0
    @Published var isUpdatingHeading: Bool = false

    var permissionStatus: CLAuthorizationStatus {
        return authorizationStatus
    }

    private let locationSubject = PassthroughSubject<CLLocation, Error>()
    private let headingSubject = PassthroughSubject<CLHeading, Error>()

    var locationPublisher: AnyPublisher<CLLocation, Error> {
        locationSubject.eraseToAnyPublisher()
    }

    var headingPublisher: AnyPublisher<CLHeading, Error> {
        headingSubject.eraseToAnyPublisher()
    }

    var mockLocation: CLLocation? {
        get { currentLocation }
        set { currentLocation = newValue }
    }

    func requestLocationPermission() {
        authorizationStatus = .authorizedWhenInUse
    }

    func requestLocation() async throws -> CLLocation {
        if let location = currentLocation {
            return location
        }
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        currentLocation = location
        return location
    }

    func startUpdatingLocation() {
        isUpdatingLocation = true
    }

    func stopUpdatingLocation() {
        isUpdatingLocation = false
    }

    func startUpdatingHeading() {
        isUpdatingHeading = true
    }

    func stopUpdatingHeading() {
        isUpdatingHeading = false
    }

    func getLocationInfo(for location: CLLocation) async -> LocationInfo {
        return LocationInfo(
            coordinate: LocationCoordinate(from: location.coordinate),
            accuracy: location.horizontalAccuracy,
            city: "Test City",
            country: "Test Country"
        )
    }

    func getCachedLocation() -> CLLocation? {
        return currentLocation
    }

    func isCachedLocationValid() -> Bool {
        return currentLocation != nil
    }

    func getLocationPreferCached() async throws -> CLLocation {
        return try await requestLocation()
    }

    func isCurrentLocationFromCache() -> Bool {
        return false
    }

    func getLocationAge() -> TimeInterval? {
        return 30.0
    }

    func requestLocationPermissionAsync() async -> CLAuthorizationStatus {
        return authorizationStatus
    }

    func startBackgroundLocationUpdates() {
        // Mock implementation
    }

    func stopBackgroundLocationUpdates() {
        // Mock implementation
    }

    func geocodeCity(_ cityName: String) async throws -> CLLocation {
        return CLLocation(latitude: 37.7749, longitude: -122.4194)
    }

    func searchCity(_ cityName: String) async throws -> [LocationInfo] {
        return []
    }

    func getLocationInfo(for coordinate: LocationCoordinate) async throws -> LocationInfo {
        return LocationInfo(
            coordinate: coordinate,
            accuracy: 10.0,
            city: "Test City",
            country: "Test Country"
        )
    }
}
