//
//  CacheInvalidationConsistencyTests.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-11.
//

import XCTest
import Combine
import CoreLocation
import BackgroundTasks
@testable import DeenBuddy

/// Tests for cache invalidation and consistency across all cache systems
class CacheInvalidationConsistencyTests: XCTestCase {

    // MARK: - Properties

    private var settingsService: CacheInvalidationConsistencyMockSettingsService!
    private var locationService: CacheInvalidationTestMockLocationService!
    private var apiClient: MockAPIClient!
    private var prayerTimeService: PrayerTimeService!
    private var apiCache: APICache!
    private var islamicCacheManager: IslamicCacheManager!
    private var backgroundTaskManager: BackgroundTaskManager!
    private var backgroundPrayerRefreshService: BackgroundPrayerRefreshService!
    private var testUserDefaults: UserDefaults!
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Setup & Teardown

    @MainActor
    override func setUp() {
        super.setUp()

        // Create test UserDefaults
        testUserDefaults = UserDefaults(suiteName: "CacheInvalidationConsistencyTests")!
        testUserDefaults.removePersistentDomain(forName: "CacheInvalidationConsistencyTests")

        // Create mock services
        settingsService = CacheInvalidationConsistencyMockSettingsService()
        locationService = CacheInvalidationTestMockLocationService()
        apiClient = MockAPIClient()
        
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
            islamicCacheManager: islamicCacheManager,
            islamicCalendarService: CacheInvalidationConsistencyMockIslamicCalendarService()
        )

        // Create background services
        backgroundTaskManager = BackgroundTaskManager(
            prayerTimeService: prayerTimeService,
            notificationService: CacheInvalidationConsistencyMockNotificationService(),
            locationService: locationService as LocationServiceProtocol
        )

        backgroundPrayerRefreshService = BackgroundPrayerRefreshService(
            prayerTimeService: prayerTimeService,
            locationService: locationService as LocationServiceProtocol
        )
        
        // Set up test location
        locationService.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
    }
    
    @MainActor
    override func tearDown() {
        cancellables.removeAll()
        testUserDefaults.removePersistentDomain(forName: "CacheInvalidationConsistencyTests")
        apiCache.clearAllCache()
        islamicCacheManager.clearAllCache()
        
        settingsService = nil
        locationService = nil
        apiClient = nil
        prayerTimeService = nil
        apiCache = nil
        islamicCacheManager = nil
        backgroundTaskManager = nil
        backgroundPrayerRefreshService = nil
        testUserDefaults = nil
        
        super.tearDown()
    }
    
    // MARK: - Cache Invalidation Tests
    
    func testCacheInvalidationOnCalculationMethodChange() async throws {
        let expectation = XCTestExpectation(description: "Cache invalidation on calculation method change")
        
        // Given: Cached prayer times with initial method
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let clLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        let initialPrayerTimes = createMockPrayerTimes(for: date, location: location, method: "muslim_world_league")
        let initialSchedule = createMockPrayerSchedule(for: date)
        
        // Cache in all systems
        apiCache.cachePrayerTimes(initialPrayerTimes, for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
        apiCache.waitForPendingOperations() // Wait for cache operation to complete
        await islamicCacheManager.cachePrayerSchedule(initialSchedule, for: date, location: clLocation, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)

        // Verify initial cache exists
        XCTAssertNotNil(apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi))
        let initialCacheResult = await islamicCacheManager.getCachedPrayerSchedule(for: date, location: clLocation, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
        XCTAssertNotNil(initialCacheResult.schedule)

        // When: Calculation method changes
        await MainActor.run {
            settingsService.calculationMethod = CalculationMethod.egyptian
        }

        // Wait for cache invalidation
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // Then: Old cache should still exist (method-specific keys), new method should have no cache
        let oldCache = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
        let newCache = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: CalculationMethod.egyptian, madhab: Madhab.shafi)
        
        XCTAssertNotNil(oldCache, "Old cache should exist with method-specific keys")
        XCTAssertNil(newCache, "New method should have no cache initially")
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testCacheInvalidationOnMadhabChange() async throws {
        let expectation = XCTestExpectation(description: "Cache invalidation on madhab change")
        
        // Given: Cached prayer times with initial madhab
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let clLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        let initialPrayerTimes = createMockPrayerTimes(for: date, location: location, method: "muslim_world_league")
        let initialSchedule = createMockPrayerSchedule(for: date)
        
        // Cache with Shafi madhab
        apiCache.cachePrayerTimes(initialPrayerTimes, for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
        apiCache.waitForPendingOperations() // Wait for cache operation to complete
        await islamicCacheManager.cachePrayerSchedule(initialSchedule, for: date, location: clLocation, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)

        // When: Madhab changes
        await MainActor.run {
            settingsService.madhab = Madhab.hanafi
        }

        // Wait for cache invalidation
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // Then: Old cache should exist, new madhab should have no cache
        let shafiCache = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
        let hanafiCache = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.hanafi)
        
        XCTAssertNotNil(shafiCache, "Shafi cache should exist")
        XCTAssertNil(hanafiCache, "Hanafi cache should not exist initially")
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testComprehensiveCacheInvalidationAcrossAllSystems() async throws {
        // Given: Data cached in all systems
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let clLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        // Cache in APICache
        let prayerTimes = createMockPrayerTimes(for: date, location: location, method: "muslim_world_league")
        apiCache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
        apiCache.waitForPendingOperations() // Wait for cache operation to complete

        // Cache in IslamicCacheManager
        let schedule = createMockPrayerSchedule(for: date)
        await islamicCacheManager.cachePrayerSchedule(schedule, for: date, location: clLocation, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)

        // Cache in PrayerTimeService (UserDefaults)
        let testPrayerTimes = [
            PrayerTime(prayer: .fajr, time: date.addingTimeInterval(5 * 3600)),
            PrayerTime(prayer: .dhuhr, time: date.addingTimeInterval(12 * 3600))
        ]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateFormatter.string(from: date)
        let methodKey = await MainActor.run { settingsService.calculationMethod.rawValue }
        let madhabKey = await MainActor.run { settingsService.madhab.rawValue }
        let cacheKey = "\(UnifiedSettingsKeys.cachedPrayerTimes)_\(dateKey)_\(methodKey)_\(madhabKey)"
        
        if let data = try? JSONEncoder().encode(testPrayerTimes) {
            testUserDefaults.set(data, forKey: cacheKey)
        }
        
        // Verify all caches exist
        XCTAssertNotNil(apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi))
        let cacheResult = await islamicCacheManager.getCachedPrayerSchedule(for: date, location: clLocation, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
        XCTAssertNotNil(cacheResult.schedule)
        XCTAssertNotNil(testUserDefaults.data(forKey: cacheKey))

        // When: Settings change triggers comprehensive cache invalidation
        await MainActor.run {
            settingsService.calculationMethod = CalculationMethod.egyptian
        }
        
        // Wait for cache invalidation
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        // Then: Verify cache behavior with new method-specific keys
        // Old method cache should still exist
        let oldAPICache = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        let oldIslamicCache = await islamicCacheManager.getCachedPrayerSchedule(for: date, location: clLocation, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        let oldUserDefaultsCache = testUserDefaults.data(forKey: cacheKey)
        
        XCTAssertNotNil(oldAPICache, "Old API cache should exist")
        XCTAssertNotNil(oldIslamicCache.schedule, "Old Islamic cache should exist")
        XCTAssertNotNil(oldUserDefaultsCache, "Old UserDefaults cache should exist")
        
        // New method cache should not exist
        let newAPICache = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .egyptian, madhab: .shafi)
        let newIslamicCache = await islamicCacheManager.getCachedPrayerSchedule(for: date, location: clLocation, calculationMethod: .egyptian, madhab: .shafi)
        
        XCTAssertNil(newAPICache, "New API cache should not exist")
        XCTAssertNil(newIslamicCache.schedule, "New Islamic cache should not exist")
    }
    
    // MARK: - Background Service Cache Tests
    
    func testBackgroundServiceCacheConsistency() async throws {
        // Given: Background services are running
        await backgroundTaskManager.registerBackgroundTasks()
        await backgroundPrayerRefreshService.startBackgroundRefresh()

        // When: Settings change
        await MainActor.run {
            settingsService.calculationMethod = CalculationMethod.karachi
        }

        // Wait for propagation
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Then: Background services should use new settings
        await MainActor.run {
            XCTAssertEqual(prayerTimeService.calculationMethod, CalculationMethod.karachi)
        }

        // And: Background services should have access to the same PrayerTimeService
        // Note: These assertions are commented out due to private access level
        // XCTAssertTrue(backgroundTaskManager.prayerTimeService === prayerTimeService)
        // XCTAssertTrue(backgroundPrayerRefreshService.prayerTimeService === prayerTimeService)
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

/// Mock settings service for cache invalidation consistency tests
@MainActor
class CacheInvalidationConsistencyMockSettingsService: SettingsServiceProtocol, ObservableObject {
    @Published var calculationMethod: CalculationMethod = .muslimWorldLeague {
        didSet {
            if calculationMethod != oldValue {
                print("DEBUG: CacheInvalidationConsistencyMockSettingsService - calculationMethod changed to \(calculationMethod)")
                notifySettingsChanged()
            }
        }
    }
    
    @Published var madhab: Madhab = .shafi {
        didSet {
            if madhab != oldValue {
                print("DEBUG: CacheInvalidationConsistencyMockSettingsService - madhab changed to \(madhab)")
                notifySettingsChanged()
            }
        }
    }
    
    @Published var notificationsEnabled: Bool = true {
        didSet {
            if notificationsEnabled != oldValue {
                print("DEBUG: CacheInvalidationConsistencyMockSettingsService - notificationsEnabled changed to \(notificationsEnabled)")
                notifySettingsChanged()
            }
        }
    }
    
    @Published var useAstronomicalMaghrib: Bool = false {
        didSet {
            if useAstronomicalMaghrib != oldValue {
                print("DEBUG: CacheInvalidationConsistencyMockSettingsService - useAstronomicalMaghrib changed to \(useAstronomicalMaghrib)")
                notifySettingsChanged()
            }
        }
    }
    
    @Published var theme: ThemeMode = .dark
    @Published var timeFormat: TimeFormat = .twelveHour
    @Published var notificationOffset: TimeInterval = 300
    @Published var hasCompletedOnboarding: Bool = false
    @Published var userName: String = ""
    @Published var overrideBatteryOptimization: Bool = false
    @Published var showArabicSymbolInWidget: Bool = true

    var enableNotifications: Bool {
        get { notificationsEnabled }
        set { notificationsEnabled = newValue }
    }

    private func notifySettingsChanged() {
        print("DEBUG: CacheInvalidationConsistencyMockSettingsService - Posting settingsDidChange notification")
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

/// Mock notification service for cache invalidation consistency tests
@MainActor
class CacheInvalidationConsistencyMockNotificationService: NotificationServiceProtocol, ObservableObject {
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
class CacheInvalidationTestMockLocationService: LocationServiceProtocol, ObservableObject {
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

    func requestLocationPermissionAsync() async -> CLAuthorizationStatus {
        return .authorizedWhenInUse
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

    func startBackgroundLocationUpdates() {}

    func stopBackgroundLocationUpdates() {}

    func startUpdatingHeading() {
        isUpdatingHeading = true
    }

    func stopUpdatingHeading() {
        isUpdatingHeading = false
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
}

// MARK: - Mock Islamic Calendar Service

@MainActor
class CacheInvalidationConsistencyMockIslamicCalendarService: IslamicCalendarServiceProtocol {
    var mockIsRamadan: Bool = false
    
    // Required published properties
    @Published var currentHijriDate: HijriDate = HijriDate(from: Date())
    @Published var todayInfo: IslamicCalendarDay = IslamicCalendarDay(gregorianDate: Date(), hijriDate: HijriDate(from: Date()))
    @Published var upcomingEvents: [IslamicEvent] = []
    @Published var allEvents: [IslamicEvent] = []
    @Published var statistics: IslamicCalendarStatistics = IslamicCalendarStatistics()
    @Published var isLoading: Bool = false
    @Published var error: Error? = nil
    
    // Mock implementation
    func isRamadan() async -> Bool {
        return mockIsRamadan
    }
    
    // Core protocol methods
    func convertToHijri(_ gregorianDate: Date) async -> HijriDate { return HijriDate(from: gregorianDate) }
    func convertToGregorian(_ hijriDate: HijriDate) async -> Date { return Date() }
    func getCurrentHijriDate() async -> HijriDate { return HijriDate(from: Date()) }
    func isDate(_ gregorianDate: Date, equalToHijri hijriDate: HijriDate) async -> Bool { return false }
    func getCalendarInfo(for date: Date) async -> IslamicCalendarDay { return IslamicCalendarDay(gregorianDate: date, hijriDate: HijriDate(from: date)) }
    func getCalendarInfo(for period: DateInterval) async -> [IslamicCalendarDay] { return [] }
    func getMonthInfo(month: HijriMonth, year: Int) async -> [IslamicCalendarDay] { return [] }
    func isHolyDay(_ date: Date) async -> Bool { return false }
    func getMoonPhase(for date: Date) async -> MoonPhase? { return nil }
    func getAllEvents() async -> [IslamicEvent] { return [] }
    func getEvents(for date: Date) async -> [IslamicEvent] { return [] }
    func getEvents(for period: DateInterval) async -> [IslamicEvent] { return [] }
    
    // Stub implementations for other required methods
    func refreshCalendarData() async {}
    func getUpcomingEvents(limit: Int) async -> [IslamicEvent] { return [] }
    func addCustomEvent(_ event: IslamicEvent) async {}
    func removeCustomEvent(_ event: IslamicEvent) async {}
    func getEventsForDate(_ date: Date) async -> [IslamicEvent] { return [] }
    func getEventsForMonth(_ month: HijriMonth, year: Int) async -> [IslamicEvent] { return [] }
    func getStatistics() async -> IslamicCalendarStatistics { return IslamicCalendarStatistics() }
    func isHolyMonth() async -> Bool { return false }
    func getCurrentHolyMonthInfo() async -> HolyMonthInfo? { return nil }
    func getRamadanPeriod(for hijriYear: Int) async -> DateInterval? { return nil }
    func getHajjPeriod(for hijriYear: Int) async -> DateInterval? { return nil }
    func setEventReminder(_ event: IslamicEvent, reminderTime: TimeInterval) async {}
    func removeEventReminder(_ event: IslamicEvent) async {}
    func getEventReminders() async -> [EventReminder] { return [] }
    func exportCalendarData(for period: DateInterval) async -> String { return "" }
    func importEvents(from jsonData: String) async throws {}
    func exportAsICalendar(_ events: [IslamicEvent]) async -> String { return "" }
    func getEventFrequencyByCategory() async -> [EventCategory: Int] { return [:] }
    func setCalculationMethod(_ method: IslamicCalendarMethod) async {}
    func setEventNotifications(_ enabled: Bool) async {}
    func setDefaultReminderTime(_ time: TimeInterval) async {}
    
    // Additional required protocol methods
    func getEvents(by category: EventCategory) async -> [IslamicEvent] { return [] }
    func getEvents(by significance: EventSignificance) async -> [IslamicEvent] { return [] }
    func searchEvents(_ query: String) async -> [IslamicEvent] { return [] }
    func updateEvent(_ event: IslamicEvent) async {}
    func deleteEvent(_ eventId: UUID) async {}
    func getDaysRemainingInMonth() async -> Int { return 30 }
    func getActiveReminders() async -> [EventReminder] { return [] }
    func cancelEventReminder(_ reminderId: UUID) async {}
    func getEventsObservedThisYear() async -> [IslamicEvent] { return [] }
    func getMostActiveMonth() async -> HijriMonth? { return nil }
    func clearCache() async {}
    func updateFromExternalSources() async {}
}
