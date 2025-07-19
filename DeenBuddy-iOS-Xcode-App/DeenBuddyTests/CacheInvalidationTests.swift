//
//  CacheInvalidationTests.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-11.
//

import XCTest
import Combine
import CoreLocation

/// Comprehensive tests for cache invalidation across all cache systems
class CacheInvalidationTests: XCTestCase {
    
    // MARK: - Properties
    
    private var settingsService: MockSettingsService!
    private var locationService: MockLocationService!
    private var apiClient: MockAPIClient!
    private var prayerTimeService: PrayerTimeService!
    private var apiCache: APICache!
    private var islamicCacheManager: IslamicCacheManager!
    private var testUserDefaults: UserDefaults!
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Create test UserDefaults
        testUserDefaults = UserDefaults(suiteName: "CacheInvalidationTests")!
        testUserDefaults.removePersistentDomain(forName: "CacheInvalidationTests")
        
        // Create mock services
        settingsService = MockSettingsService()
        locationService = MockLocationService()
        apiClient = MockAPIClient()
        
        // Create cache systems
        apiCache = APICache()
        islamicCacheManager = IslamicCacheManager()
        
        // Create prayer time service with dependencies
        prayerTimeService = PrayerTimeService(
            locationService: locationService,
            settingsService: settingsService,
            apiClient: apiClient,
            errorHandler: ErrorHandler(crashReporter: CrashReporter()),
            retryMechanism: RetryMechanism(networkMonitor: NetworkMonitor.shared),
            networkMonitor: NetworkMonitor.shared
        )
        
        // Set up test location
        locationService.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
    }
    
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
    
    func testIslamicCacheManagerUsesMethodSpecificKeys() {
        // Given: Different calculation settings
        let date = Date()
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let schedule = createMockPrayerSchedule(for: date)
        
        // When: Caching with different settings
        islamicCacheManager.cachePrayerSchedule(schedule, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        islamicCacheManager.cachePrayerSchedule(schedule, for: date, location: location, calculationMethod: .egyptian, madhab: .hanafi)
        
        // Then: Different cache entries should exist
        let cachedMWLShafi = islamicCacheManager.getCachedPrayerSchedule(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        let cachedEgyptianHanafi = islamicCacheManager.getCachedPrayerSchedule(for: date, location: location, calculationMethod: .egyptian, madhab: .hanafi)
        
        XCTAssertNotNil(cachedMWLShafi.schedule, "MWL+Shafi cache should exist")
        XCTAssertNotNil(cachedEgyptianHanafi.schedule, "Egyptian+Hanafi cache should exist")
    }
    
    // MARK: - Comprehensive Cache Invalidation Tests
    
    func testComprehensiveCacheInvalidationOnSettingsChange() {
        let expectation = XCTestExpectation(description: "Comprehensive cache invalidation")
        
        // Given: Cached data in all cache systems (old method/madhab)
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let clLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let prayerTimes = createMockPrayerTimes(for: date, location: location)
        let schedule = createMockPrayerSchedule(for: date)
        
        // Cache in APICache (old method/madhab)
        apiCache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        
        // Cache in IslamicCacheManager (old method/madhab)
        islamicCacheManager.cachePrayerSchedule(schedule, for: date, location: clLocation, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        
        // Verify caches exist for old method/madhab
        XCTAssertNotNil(apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi))
        XCTAssertNotNil(islamicCacheManager.getCachedPrayerSchedule(for: date, location: clLocation, calculationMethod: .muslimWorldLeague, madhab: .shafi).schedule)
        
        // When: Settings change to new method/madhab
        settingsService.calculationMethod = .egyptian
        let newMethod: CalculationMethod = .egyptian
        let newMadhab: Madhab = .hanafi
        
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
        let qiblaDirection = QiblaDirection(bearing: 45.0, distance: 1000.0)
        
        // Cache both types
        apiCache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
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
            location: location,
            fajr: date.addingTimeInterval(5 * 3600), // 5 AM
            sunrise: date.addingTimeInterval(6 * 3600), // 6 AM
            dhuhr: date.addingTimeInterval(12 * 3600), // 12 PM
            asr: date.addingTimeInterval(15 * 3600), // 3 PM
            maghrib: date.addingTimeInterval(18 * 3600), // 6 PM
            isha: date.addingTimeInterval(19 * 3600), // 7 PM
            calculationMethod: "muslim_world_league",
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
