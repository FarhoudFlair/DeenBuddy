//
//  CachePerformanceTests.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-11.
//

import XCTest
import Combine
import CoreLocation
@testable import DeenBuddy

/// Performance tests for cache operations and prayer time synchronization
class CachePerformanceTests: XCTestCase {

    // MARK: - Properties

    private var settingsService: CachePerformanceMockSettingsService!
    private var locationService: CachePerformanceTestMockLocationService!
    private var apiClient: MockAPIClient!
    private var prayerTimeService: PrayerTimeService!
    private var apiCache: APICache!
    private var islamicCacheManager: IslamicCacheManager!
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Setup & Teardown

    @MainActor
    override func setUp() {
        super.setUp()

        // Create mock services
        settingsService = CachePerformanceMockSettingsService()
        locationService = CachePerformanceTestMockLocationService()
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
            islamicCalendarService: CachePerformanceMockIslamicCalendarService()
        )

        // Set up test location
        locationService.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
    }
    
    @MainActor
    override func tearDown() {
        cancellables.removeAll()
        apiCache.clearAllCache()
        islamicCacheManager.clearAllCache()

        settingsService = nil
        locationService = nil
        apiClient = nil
        prayerTimeService = nil
        apiCache = nil
        islamicCacheManager = nil

        super.tearDown()
    }
    
    // MARK: - Cache Operation Performance Tests
    
    func testAPICachePerformance() {
        let iterations = 1000
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        
        measure {
            for i in 0..<iterations {
                let prayerTimes = createMockPrayerTimes(for: date.addingTimeInterval(TimeInterval(i * 86400)), location: location, method: "muslim_world_league")
                
                // Test caching performance
                apiCache.cachePrayerTimes(prayerTimes, for: date.addingTimeInterval(TimeInterval(i * 86400)), location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
                
                // Test retrieval performance
                _ = apiCache.getCachedPrayerTimes(for: date.addingTimeInterval(TimeInterval(i * 86400)), location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
            }
        }
    }
    
    func testIslamicCacheManagerPerformance() {
        let iterations = 1000
        let date = Date()
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        measure {
            for i in 0..<iterations {
                let schedule = createMockPrayerSchedule(for: date.addingTimeInterval(TimeInterval(i * 86400)))
                
                // Test caching performance
                islamicCacheManager.cachePrayerSchedule(schedule, for: date.addingTimeInterval(TimeInterval(i * 86400)), location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
                
                // Test retrieval performance
                _ = islamicCacheManager.getCachedPrayerSchedule(for: date.addingTimeInterval(TimeInterval(i * 86400)), location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
            }
        }
    }
    
    @MainActor
    func testCacheInvalidationPerformance() {
        // Pre-populate cache with data
        let iterations = 100
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let clLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        for i in 0..<iterations {
            let prayerTimes = createMockPrayerTimes(for: date.addingTimeInterval(TimeInterval(i * 86400)), location: location, method: "muslim_world_league")
            let schedule = createMockPrayerSchedule(for: date.addingTimeInterval(TimeInterval(i * 86400)))
            
            apiCache.cachePrayerTimes(prayerTimes, for: date.addingTimeInterval(TimeInterval(i * 86400)), location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
            islamicCacheManager.cachePrayerSchedule(schedule, for: date.addingTimeInterval(TimeInterval(i * 86400)), location: clLocation, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
        }
        
        // Test cache invalidation performance
        measure {
            apiCache.clearPrayerTimeCache()
            islamicCacheManager.clearPrayerTimeCache()
        }
    }
    
    // MARK: - Settings Synchronization Performance Tests
    
    func testSettingsSynchronizationPerformance() {
        let iterations = 100
        let methods: [CalculationMethod] = [CalculationMethod.muslimWorldLeague, CalculationMethod.egyptian, CalculationMethod.karachi, CalculationMethod.ummAlQura]
        let madhabs: [Madhab] = [Madhab.shafi, Madhab.hanafi]
        
        measure {
            for i in 0..<iterations {
                let method = methods[i % methods.count]
                let madhab = madhabs[i % madhabs.count]
                
                settingsService.calculationMethod = method
                settingsService.madhab = madhab
            }
        }
    }
    
    func testRapidSettingsChangesPerformance() {
        let iterations = 500
        
        measure {
            for i in 0..<iterations {
                let method: CalculationMethod = i % 2 == 0 ? CalculationMethod.egyptian : CalculationMethod.muslimWorldLeague
                let madhab: Madhab = i % 2 == 0 ? Madhab.hanafi : Madhab.shafi
                
                settingsService.calculationMethod = method
                settingsService.madhab = madhab
            }
        }
    }
    
    // MARK: - Prayer Time Calculation Performance Tests
    
    func testPrayerTimeCalculationPerformance() async {
        let iterations = 50

        // Measure async operations by timing them manually
        measure {
            let expectation = XCTestExpectation(description: "Prayer time calculation performance")

            Task {
                await withTaskGroup(of: Void.self) { group in
                    for i in 0..<iterations {
                        group.addTask {
                            let method: CalculationMethod = i % 2 == 0 ? CalculationMethod.egyptian : CalculationMethod.muslimWorldLeague
                            await MainActor.run {
                                self.settingsService.calculationMethod = method
                            }

                            await self.prayerTimeService.refreshPrayerTimes()
                        }
                    }
                }
                expectation.fulfill()
            }

            // Wait for async operations to complete within the measure block
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    func testConcurrentSettingsChangesPerformance() async {
        let iterations = 20

        // Measure async operations by timing them manually
        measure {
            let expectation = XCTestExpectation(description: "Concurrent settings changes performance")

            Task {
                await withTaskGroup(of: Void.self) { group in
                    for i in 0..<iterations {
                        group.addTask {
                            let method: CalculationMethod = i % 2 == 0 ? CalculationMethod.egyptian : CalculationMethod.muslimWorldLeague
                            await MainActor.run {
                                self.settingsService.calculationMethod = method
                            }
                        }
                    }
                }
                expectation.fulfill()
            }

            // Wait for async operations to complete within the measure block
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Memory Usage Tests
    
    func testMemoryUsageUnderLoad() {
        let iterations = 1000
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        
        // Measure memory usage during heavy cache operations
        measure(metrics: [XCTMemoryMetric()]) {
            for i in 0..<iterations {
                let prayerTimes = createMockPrayerTimes(for: date.addingTimeInterval(TimeInterval(i * 86400)), location: location, method: "muslim_world_league")
                
                apiCache.cachePrayerTimes(prayerTimes, for: date.addingTimeInterval(TimeInterval(i * 86400)), location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
                
                // Periodically clear cache to prevent excessive memory usage
                if i % 100 == 0 {
                    apiCache.clearExpiredCache()
                }
            }
        }
    }
    
    func testCacheKeyGenerationPerformance() {
        let iterations = 10000
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        
        measure {
            for i in 0..<iterations {
                let method: CalculationMethod = i % 2 == 0 ? CalculationMethod.egyptian : CalculationMethod.muslimWorldLeague
                let madhab: Madhab = i % 2 == 0 ? Madhab.hanafi : Madhab.shafi
                
                // This tests the performance of cache key generation with method and madhab
                let prayerTimes = createMockPrayerTimes(for: date, location: location, method: method.rawValue)
                apiCache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: method, madhab: madhab)
            }
        }
    }
    
    // MARK: - Background Performance Tests
    
    @MainActor
    func testBackgroundServicePerformance() {
        let iterations = 100

        let backgroundTaskManager = BackgroundTaskManager(
            prayerTimeService: prayerTimeService,
            notificationService: MockNotificationService(),
            locationService: locationService
        )
        
        measure {
            for i in 0..<iterations {
                let method: CalculationMethod = i % 2 == 0 ? CalculationMethod.egyptian : CalculationMethod.muslimWorldLeague
                settingsService.calculationMethod = method
                
                // Simulate background task execution
                backgroundTaskManager.registerBackgroundTasks()
            }
        }
    }
    
    // MARK: - Stress Tests
    
    func testStressTestRapidSettingsChanges() {
        let iterations = 1000
        let methods: [CalculationMethod] = [CalculationMethod.muslimWorldLeague, CalculationMethod.egyptian, CalculationMethod.karachi, CalculationMethod.ummAlQura]
        let madhabs: [Madhab] = [Madhab.shafi, Madhab.hanafi]
        
        // This test ensures the system can handle rapid settings changes without performance degradation
        measure {
            for i in 0..<iterations {
                let method = methods[i % methods.count]
                let madhab = madhabs[i % madhabs.count]
                
                settingsService.calculationMethod = method
                settingsService.madhab = madhab
                
                // Simulate some processing time
                Thread.sleep(forTimeInterval: 0.001) // 1ms
            }
        }
    }
    
    func testCacheConsistencyUnderLoad() {
        let iterations = 500
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        
        measure {
            for i in 0..<iterations {
                let method: CalculationMethod = i % 2 == 0 ? CalculationMethod.egyptian : CalculationMethod.muslimWorldLeague
                let madhab: Madhab = i % 2 == 0 ? Madhab.hanafi : Madhab.shafi
                
                let prayerTimes = createMockPrayerTimes(for: date, location: location, method: method.rawValue)
                
                // Cache with different method/madhab combinations
                apiCache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: method, madhab: madhab)
                
                // Retrieve to ensure consistency
                let cached = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: method, madhab: madhab)
                XCTAssertNotNil(cached, "Cache should be consistent under load")
            }
        }
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

// MARK: - Test Mock Extensions

/// Extended MockLocationService with mockLocation property for testing
@MainActor
class CachePerformanceTestMockLocationService: LocationServiceProtocol, ObservableObject {
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

    var mockLocation: CLLocation? {
        get { currentLocation }
        set { currentLocation = newValue }
    }

    func requestLocationPermission() {}
    func requestLocationPermissionAsync() async -> CLAuthorizationStatus { return .authorizedWhenInUse }
    func requestLocation() async throws -> CLLocation {
        return currentLocation ?? CLLocation(latitude: 37.7749, longitude: -122.4194)
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

@MainActor
class CachePerformanceMockSettingsService: SettingsServiceProtocol, ObservableObject {
    @Published var calculationMethod: CalculationMethod = .muslimWorldLeague
    @Published var madhab: Madhab = .shafi
    @Published var notificationsEnabled: Bool = true
    @Published var useAstronomicalMaghrib: Bool = false
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

    func saveSettings() async throws {}
    func loadSettings() async throws {}
    func resetToDefaults() async throws {}
    func saveImmediately() async throws {}
    func saveOnboardingSettings() async throws {}
}

// MARK: - Mock Islamic Calendar Service

@MainActor
class CachePerformanceMockIslamicCalendarService: IslamicCalendarServiceProtocol {
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
    func getMostActiveMonth() async -> HijriMonth? { return nil }
    func clearCache() async {}
    func updateFromExternalSources() async {}
}
