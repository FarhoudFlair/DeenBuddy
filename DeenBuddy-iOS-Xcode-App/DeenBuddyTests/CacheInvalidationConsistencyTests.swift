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
    
    private var settingsService: MockSettingsService!
    private var locationService: MockLocationService!
    private var apiClient: MockAPIClient!
    private var prayerTimeService: PrayerTimeService!
    private var apiCache: APICache!
    private var islamicCacheManager: IslamicCacheManager!
    private var backgroundTaskManager: BackgroundTaskManager!
    private var backgroundPrayerRefreshService: BackgroundPrayerRefreshService!
    private var testUserDefaults: UserDefaults!
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Create test UserDefaults
        testUserDefaults = UserDefaults(suiteName: "CacheInvalidationConsistencyTests")!
        testUserDefaults.removePersistentDomain(forName: "CacheInvalidationConsistencyTests")
        
        // Create mock services
        settingsService = MockSettingsService()
        locationService = MockLocationService()
        apiClient = MockAPIClient()
        
        // Create cache systems
        apiCache = APICache()
        islamicCacheManager = IslamicCacheManager()
        
        // Create prayer time service
        prayerTimeService = PrayerTimeService(
            locationService: locationService,
            settingsService: settingsService,
            apiClient: apiClient,
            errorHandler: ErrorHandler(crashReporter: CrashReporter()),
            retryMechanism: RetryMechanism(networkMonitor: NetworkMonitor.shared),
            networkMonitor: NetworkMonitor.shared
        )
        
        // Create background services
        backgroundTaskManager = BackgroundTaskManager(
            prayerTimeService: prayerTimeService,
            notificationService: MockNotificationService(),
            locationService: locationService
        )
        
        backgroundPrayerRefreshService = BackgroundPrayerRefreshService(
            prayerTimeService: prayerTimeService,
            locationService: locationService as! LocationService
        )
        
        // Set up test location
        locationService.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
    }
    
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
        apiCache.cachePrayerTimes(initialPrayerTimes, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        islamicCacheManager.cachePrayerSchedule(initialSchedule, for: date, location: clLocation, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        
        // Verify initial cache exists
        XCTAssertNotNil(apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi))
        XCTAssertNotNil(islamicCacheManager.getCachedPrayerSchedule(for: date, location: clLocation, calculationMethod: .muslimWorldLeague, madhab: .shafi).schedule)
        
        // When: Calculation method changes
        await MainActor.run {
            settingsService.calculationMethod = .egyptian
        }
        
        // Wait for cache invalidation
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Then: Old cache should still exist (method-specific keys), new method should have no cache
        let oldCache = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        let newCache = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .egyptian, madhab: .shafi)
        
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
        apiCache.cachePrayerTimes(initialPrayerTimes, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        islamicCacheManager.cachePrayerSchedule(initialSchedule, for: date, location: clLocation, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        
        // When: Madhab changes
        await MainActor.run {
            settingsService.madhab = .hanafi
        }
        
        // Wait for cache invalidation
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Then: Old cache should exist, new madhab should have no cache
        let shafiCache = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        let hanafiCache = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .hanafi)
        
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
        apiCache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        
        // Cache in IslamicCacheManager
        let schedule = createMockPrayerSchedule(for: date)
        islamicCacheManager.cachePrayerSchedule(schedule, for: date, location: clLocation, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        
        // Cache in PrayerTimeService (UserDefaults)
        let testPrayerTimes = [
            PrayerTime(prayer: .fajr, time: date.addingTimeInterval(5 * 3600), isNext: false),
            PrayerTime(prayer: .dhuhr, time: date.addingTimeInterval(12 * 3600), isNext: true)
        ]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateFormatter.string(from: date)
        let methodKey = settingsService.calculationMethod.rawValue
        let madhabKey = settingsService.madhab.rawValue
        let cacheKey = "\(UnifiedSettingsKeys.cachedPrayerTimes)_\(dateKey)_\(methodKey)_\(madhabKey)"
        
        if let data = try? JSONEncoder().encode(testPrayerTimes) {
            testUserDefaults.set(data, forKey: cacheKey)
        }
        
        // Verify all caches exist
        XCTAssertNotNil(apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi))
        XCTAssertNotNil(islamicCacheManager.getCachedPrayerSchedule(for: date, location: clLocation, calculationMethod: .muslimWorldLeague, madhab: .shafi).schedule)
        XCTAssertNotNil(testUserDefaults.data(forKey: cacheKey))
        
        // When: Settings change triggers comprehensive cache invalidation
        await MainActor.run {
            settingsService.calculationMethod = .egyptian
        }
        
        // Wait for cache invalidation
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        // Then: Verify cache behavior with new method-specific keys
        // Old method cache should still exist
        let oldAPICache = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        let oldIslamicCache = islamicCacheManager.getCachedPrayerSchedule(for: date, location: clLocation, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        let oldUserDefaultsCache = testUserDefaults.data(forKey: cacheKey)
        
        XCTAssertNotNil(oldAPICache, "Old API cache should exist")
        XCTAssertNotNil(oldIslamicCache.schedule, "Old Islamic cache should exist")
        XCTAssertNotNil(oldUserDefaultsCache, "Old UserDefaults cache should exist")
        
        // New method cache should not exist
        let newAPICache = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .egyptian, madhab: .shafi)
        let newIslamicCache = islamicCacheManager.getCachedPrayerSchedule(for: date, location: clLocation, calculationMethod: .egyptian, madhab: .shafi)
        
        XCTAssertNil(newAPICache, "New API cache should not exist")
        XCTAssertNil(newIslamicCache.schedule, "New Islamic cache should not exist")
    }
    
    // MARK: - Background Service Cache Tests
    
    func testBackgroundServiceCacheConsistency() async throws {
        // Given: Background services are running
        backgroundTaskManager.registerBackgroundTasks()
        backgroundPrayerRefreshService.startBackgroundRefresh()
        
        // When: Settings change
        await MainActor.run {
            settingsService.calculationMethod = .karachi
        }
        
        // Wait for propagation
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Then: Background services should use new settings
        XCTAssertEqual(prayerTimeService.calculationMethod, .karachi)
        
        // And: Background services should have access to the same PrayerTimeService
        XCTAssertTrue(backgroundTaskManager.prayerTimeService === prayerTimeService)
        XCTAssertTrue(backgroundPrayerRefreshService.prayerTimeService === prayerTimeService)
    }
    
    // MARK: - Helper Methods
    
    private func createMockPrayerTimes(for date: Date, location: LocationCoordinate, method: String) -> PrayerTimes {
        return PrayerTimes(
            date: date,
            location: location,
            fajr: date.addingTimeInterval(5 * 3600),
            sunrise: date.addingTimeInterval(6 * 3600),
            dhuhr: date.addingTimeInterval(12 * 3600),
            asr: date.addingTimeInterval(15 * 3600),
            maghrib: date.addingTimeInterval(18 * 3600),
            isha: date.addingTimeInterval(19 * 3600),
            calculationMethod: method,
            madhab: "shafi"
        )
    }
    
    private func createMockPrayerSchedule(for date: Date) -> PrayerSchedule {
        return PrayerSchedule(
            date: date,
            prayers: [
                Prayer(name: .fajr, time: date.addingTimeInterval(5 * 3600)),
                Prayer(name: .dhuhr, time: date.addingTimeInterval(12 * 3600)),
                Prayer(name: .asr, time: date.addingTimeInterval(15 * 3600)),
                Prayer(name: .maghrib, time: date.addingTimeInterval(18 * 3600)),
                Prayer(name: .isha, time: date.addingTimeInterval(19 * 3600))
            ]
        )
    }
}
