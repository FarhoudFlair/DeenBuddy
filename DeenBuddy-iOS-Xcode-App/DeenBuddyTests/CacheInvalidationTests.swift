//
//  CacheInvalidationTests.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-11.
//

import XCTest
import Combine
import CoreLocation
@testable import DeenBuddy

/// Comprehensive tests for cache invalidation across all cache systems
class CacheInvalidationTests: XCTestCase {

    // MARK: - Properties

    private var settingsService: CacheInvalidationBasicMockSettingsService!
    private var locationService: CacheInvalidationBasicTestMockLocationService!
    private var apiClient: MockAPIClient!
    private var prayerTimeService: PrayerTimeService!
    private var apiCache: APICache!
    private var islamicCacheManager: IslamicCacheManager!
    private var testUserDefaults: UserDefaults!
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Setup & Teardown
    
    @MainActor
    override func setUp() {
        super.setUp()

        // Create test UserDefaults
        testUserDefaults = UserDefaults(suiteName: "CacheInvalidationTests")!
        testUserDefaults.removePersistentDomain(forName: "CacheInvalidationTests")

        // Create mock services
        settingsService = CacheInvalidationBasicMockSettingsService()
        locationService = CacheInvalidationBasicTestMockLocationService()
        apiClient = MockAPIClient()

        // Create cache systems
        apiCache = APICache()
        islamicCacheManager = IslamicCacheManager()

        // Create prayer time service with dependencies
        prayerTimeService = PrayerTimeService(
            locationService: locationService as LocationServiceProtocol,
            settingsService: settingsService,
            apiClient: apiClient,
            errorHandler: ErrorHandler(crashReporter: CrashReporter()),
            retryMechanism: RetryMechanism(networkMonitor: NetworkMonitor.shared),
            networkMonitor: NetworkMonitor.shared,
            islamicCacheManager: islamicCacheManager
        )

        // Set up test location
        locationService.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
    }
    
    @MainActor
    override func tearDown() {
        cancellables.removeAll()
        testUserDefaults.removePersistentDomain(forName: "CacheInvalidationTests")
        apiCache.clearAllCache()
        islamicCacheManager.clearAllCache()

        settingsService = nil
        locationService = nil
        apiClient = nil
        prayerTimeService = nil
        apiCache = nil
        islamicCacheManager = nil
        testUserDefaults = nil

        super.tearDown()
    }
    
    // MARK: - Cache Key Strategy Tests
    
    func testCacheKeysIncludeCalculationMethod() {
        // Given: Different calculation methods
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let prayerTimes = createMockPrayerTimes(for: date, location: location)
        
        // When: Caching with different calculation methods
        apiCache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        apiCache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: .egyptian, madhab: .shafi)
        
        // Then: Different cache entries should exist
        let cachedMWL = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        let cachedEgyptian = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .egyptian, madhab: .shafi)
        
        XCTAssertNotNil(cachedMWL, "MWL cache should exist")
        XCTAssertNotNil(cachedEgyptian, "Egyptian cache should exist")
        
        // And: Cache entries should be separate
        XCTAssertEqual(cachedMWL?.calculationMethod, "muslim_world_league")
        XCTAssertEqual(cachedEgyptian?.calculationMethod, "egyptian")
    }
    
    func testCacheKeysIncludeMadhab() {
        // Given: Different madhabs
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let prayerTimes = createMockPrayerTimes(for: date, location: location)
        
        // When: Caching with different madhabs
        apiCache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        apiCache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .hanafi)
        
        // Then: Different cache entries should exist
        let cachedShafi = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        let cachedHanafi = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .hanafi)
        
        XCTAssertNotNil(cachedShafi, "Shafi cache should exist")
        XCTAssertNotNil(cachedHanafi, "Hanafi cache should exist")
    }
    
    func testIslamicCacheManagerUsesMethodSpecificKeys() async {
        // Given: Different calculation settings
        let date = Date()
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let schedule = createMockPrayerSchedule(for: date)

        // When: Caching with different settings
        await islamicCacheManager.cachePrayerSchedule(schedule, for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
        await islamicCacheManager.cachePrayerSchedule(schedule, for: date, location: location, calculationMethod: CalculationMethod.egyptian, madhab: Madhab.hanafi)

        // Then: Different cache entries should exist
        let cachedMWLShafi = await islamicCacheManager.getCachedPrayerSchedule(for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
        let cachedEgyptianHanafi = await islamicCacheManager.getCachedPrayerSchedule(for: date, location: location, calculationMethod: CalculationMethod.egyptian, madhab: Madhab.hanafi)

        XCTAssertNotNil(cachedMWLShafi.schedule, "MWL+Shafi cache should exist")
        XCTAssertNotNil(cachedEgyptianHanafi.schedule, "Egyptian+Hanafi cache should exist")
    }
    
    // MARK: - Comprehensive Cache Invalidation Tests
    
    func testComprehensiveCacheInvalidationOnSettingsChange() async {
        let expectation = XCTestExpectation(description: "Comprehensive cache invalidation")

        // Given: Cached data in all cache systems (old method/madhab)
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let clLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let prayerTimes = createMockPrayerTimes(for: date, location: location)
        let schedule = createMockPrayerSchedule(for: date)

        // Cache in APICache (old method/madhab)
        apiCache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)

        // Cache in IslamicCacheManager (old method/madhab)
        await islamicCacheManager.cachePrayerSchedule(schedule, for: date, location: clLocation, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)

        // Verify caches exist for old method/madhab
        XCTAssertNotNil(apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi))
        let cacheResult = await islamicCacheManager.getCachedPrayerSchedule(for: date, location: clLocation, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
        XCTAssertNotNil(cacheResult.schedule)

        // When: Settings change to new method/madhab
        await MainActor.run {
            settingsService.calculationMethod = CalculationMethod.egyptian
        }
        let newMethod: CalculationMethod = CalculationMethod.egyptian
        let newMadhab: Madhab = Madhab.hanafi
        
        // Then: Old cache entries should still exist, new ones should be absent
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Old cache entries should still exist
            let apiCacheOld = self.apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
            let islamicCacheOld = self.islamicCacheManager.getCachedPrayerSchedule(for: date, location: clLocation, calculationMethod: .muslimWorldLeague, madhab: .shafi)
            XCTAssertNotNil(apiCacheOld, "Old APICache entry should still exist after settings change")
            XCTAssertNotNil(islamicCacheOld.schedule, "Old IslamicCacheManager entry should still exist after settings change")

            // New cache entries should be absent
            let apiCacheNew = self.apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: newMethod, madhab: newMadhab)
            let islamicCacheNew = self.islamicCacheManager.getCachedPrayerSchedule(for: date, location: clLocation, calculationMethod: newMethod, madhab: newMadhab)
            XCTAssertNil(apiCacheNew, "New APICache entry should not exist yet after settings change")
            XCTAssertNil(islamicCacheNew.schedule, "New IslamicCacheManager entry should not exist yet after settings change")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testCacheInvalidationPreservesOtherData() {
        // Given: Mixed cache data (prayer times and qibla direction)
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let prayerTimes = createMockPrayerTimes(for: date, location: location)
        let qiblaDirection = QiblaDirection(direction: 45.0, distance: 1000.0, location: location)

        // Cache both types
        apiCache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
        apiCache.cacheQiblaDirection(qiblaDirection, for: location)
        
        // When: Prayer time cache is cleared
        apiCache.clearPrayerTimeCache()
        
        // Then: Only prayer time cache should be cleared
        let cachedPrayerTimes = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        let cachedQiblaDirection = apiCache.getCachedQiblaDirection(for: location)
        
        XCTAssertNil(cachedPrayerTimes, "Prayer times cache should be cleared")
        XCTAssertNotNil(cachedQiblaDirection, "Qibla direction cache should be preserved")
    }
    
    // MARK: - Helper Methods
    
    private func createMockPrayerTimes(for date: Date, location: LocationCoordinate) -> PrayerTimes {
        return PrayerTimes(
            date: date,
            fajr: date.addingTimeInterval(5 * 3600), // 5 AM
            dhuhr: date.addingTimeInterval(12 * 3600), // 12 PM
            asr: date.addingTimeInterval(15 * 3600), // 3 PM
            maghrib: date.addingTimeInterval(18 * 3600), // 6 PM
            isha: date.addingTimeInterval(19 * 3600), // 7 PM
            calculationMethod: "muslim_world_league",
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

/// Mock settings service for cache invalidation basic tests
@MainActor
class CacheInvalidationBasicMockSettingsService: SettingsServiceProtocol, ObservableObject {
    @Published var calculationMethod: CalculationMethod = .muslimWorldLeague {
        didSet {
            if calculationMethod != oldValue {
                print("DEBUG: CacheInvalidationBasicMockSettingsService - calculationMethod changed to \(calculationMethod)")
                notifySettingsChanged()
            }
        }
    }
    
    @Published var madhab: Madhab = .shafi {
        didSet {
            if madhab != oldValue {
                print("DEBUG: CacheInvalidationBasicMockSettingsService - madhab changed to \(madhab)")
                notifySettingsChanged()
            }
        }
    }
    
    @Published var notificationsEnabled: Bool = true {
        didSet {
            if notificationsEnabled != oldValue {
                print("DEBUG: CacheInvalidationBasicMockSettingsService - notificationsEnabled changed to \(notificationsEnabled)")
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
        print("DEBUG: CacheInvalidationBasicMockSettingsService - Posting settingsDidChange notification")
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

/// Extended MockLocationService with mockLocation property for testing
@MainActor
class CacheInvalidationBasicTestMockLocationService: LocationServiceProtocol, ObservableObject {
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
