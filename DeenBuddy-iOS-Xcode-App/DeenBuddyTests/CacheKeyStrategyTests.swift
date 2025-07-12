//
//  CacheKeyStrategyTests.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-11.
//

import XCTest
import CoreLocation
@testable import DeenAssistCore

/// Tests for enhanced cache key strategy that includes calculation method and madhab
class CacheKeyStrategyTests: XCTestCase {
    
    // MARK: - Properties
    
    private var apiCache: APICache!
    private var islamicCacheManager: IslamicCacheManager!
    private var mockAPIClient: MockAPIClient!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        apiCache = APICache()
        islamicCacheManager = IslamicCacheManager()
        mockAPIClient = MockAPIClient()
    }
    
    override func tearDown() {
        apiCache.clearAllCache()
        islamicCacheManager.clearAllCache()
        
        apiCache = nil
        islamicCacheManager = nil
        mockAPIClient = nil
        
        super.tearDown()
    }
    
    // MARK: - APICache Key Strategy Tests
    
    func testAPICacheKeyIncludesCalculationMethod() {
        // Given: Same date and location, different calculation methods
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let prayerTimes1 = createMockPrayerTimes(for: date, location: location, method: "muslim_world_league")
        let prayerTimes2 = createMockPrayerTimes(for: date, location: location, method: "egyptian")
        
        // When: Caching with different calculation methods
        apiCache.cachePrayerTimes(prayerTimes1, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        apiCache.cachePrayerTimes(prayerTimes2, for: date, location: location, calculationMethod: .egyptian, madhab: .shafi)
        
        // Then: Both cache entries should exist independently
        let cachedMWL = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        let cachedEgyptian = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .egyptian, madhab: .shafi)
        
        XCTAssertNotNil(cachedMWL, "MWL cache should exist")
        XCTAssertNotNil(cachedEgyptian, "Egyptian cache should exist")
        XCTAssertEqual(cachedMWL?.calculationMethod, "muslim_world_league")
        XCTAssertEqual(cachedEgyptian?.calculationMethod, "egyptian")
    }
    
    func testAPICacheKeyIncludesMadhab() {
        // Given: Same date, location, and method, different madhabs
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let prayerTimes1 = createMockPrayerTimes(for: date, location: location, method: "muslim_world_league")
        let prayerTimes2 = createMockPrayerTimes(for: date, location: location, method: "muslim_world_league")
        
        // When: Caching with different madhabs
        apiCache.cachePrayerTimes(prayerTimes1, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        apiCache.cachePrayerTimes(prayerTimes2, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .hanafi)
        
        // Then: Both cache entries should exist independently
        let cachedShafi = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        let cachedHanafi = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .hanafi)
        
        XCTAssertNotNil(cachedShafi, "Shafi cache should exist")
        XCTAssertNotNil(cachedHanafi, "Hanafi cache should exist")
    }
    
    func testAPICacheKeyUniqueness() {
        // Given: All possible combinations
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let prayerTimes = createMockPrayerTimes(for: date, location: location, method: "muslim_world_league")
        
        let methods: [CalculationMethod] = [.muslimWorldLeague, .egyptian, .karachi]
        let madhabs: [Madhab] = [.shafi, .hanafi]
        
        // When: Caching all combinations
        for method in methods {
            for madhab in madhabs {
                apiCache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: method, madhab: madhab)
            }
        }
        
        // Then: All combinations should be cached independently
        for method in methods {
            for madhab in madhabs {
                let cached = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: method, madhab: madhab)
                XCTAssertNotNil(cached, "Cache should exist for \(method.rawValue) + \(madhab.rawValue)")
            }
        }
    }
    
    // MARK: - IslamicCacheManager Key Strategy Tests
    
    func testIslamicCacheManagerKeyIncludesCalculationMethod() {
        // Given: Same date and location, different calculation methods
        let date = Date()
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let schedule = createMockPrayerSchedule(for: date)
        
        // When: Caching with different calculation methods
        islamicCacheManager.cachePrayerSchedule(schedule, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        islamicCacheManager.cachePrayerSchedule(schedule, for: date, location: location, calculationMethod: .egyptian, madhab: .shafi)
        
        // Then: Both cache entries should exist independently
        let cachedMWL = islamicCacheManager.getCachedPrayerSchedule(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        let cachedEgyptian = islamicCacheManager.getCachedPrayerSchedule(for: date, location: location, calculationMethod: .egyptian, madhab: .shafi)
        
        XCTAssertNotNil(cachedMWL.schedule, "MWL cache should exist")
        XCTAssertNotNil(cachedEgyptian.schedule, "Egyptian cache should exist")
    }
    
    func testIslamicCacheManagerKeyIncludesMadhab() {
        // Given: Same date, location, and method, different madhabs
        let date = Date()
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let schedule = createMockPrayerSchedule(for: date)
        
        // When: Caching with different madhabs
        islamicCacheManager.cachePrayerSchedule(schedule, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        islamicCacheManager.cachePrayerSchedule(schedule, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .hanafi)
        
        // Then: Both cache entries should exist independently
        let cachedShafi = islamicCacheManager.getCachedPrayerSchedule(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        let cachedHanafi = islamicCacheManager.getCachedPrayerSchedule(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .hanafi)
        
        XCTAssertNotNil(cachedShafi.schedule, "Shafi cache should exist")
        XCTAssertNotNil(cachedHanafi.schedule, "Hanafi cache should exist")
    }
    
    // MARK: - MockAPIClient Key Strategy Tests
    
    func testMockAPIClientKeyIncludesMethodAndMadhab() async throws {
        // Given: Same date and location, different settings
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        
        // When: Getting prayer times with different settings
        let prayerTimes1 = try await mockAPIClient.getPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        let prayerTimes2 = try await mockAPIClient.getPrayerTimes(for: date, location: location, calculationMethod: .egyptian, madhab: .hanafi)
        
        // Then: Different prayer times should be returned (cached separately)
        XCTAssertNotNil(prayerTimes1)
        XCTAssertNotNil(prayerTimes2)
        
        // And: Cache keys should be different (verified by getting cached results)
        let cachedTimes1 = try await mockAPIClient.getPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        let cachedTimes2 = try await mockAPIClient.getPrayerTimes(for: date, location: location, calculationMethod: .egyptian, madhab: .hanafi)
        
        XCTAssertEqual(prayerTimes1.calculationMethod, cachedTimes1.calculationMethod)
        XCTAssertEqual(prayerTimes2.calculationMethod, cachedTimes2.calculationMethod)
    }
    
    // MARK: - Cache Isolation Tests
    
    func testCacheIsolationBetweenSettings() {
        // Given: Different settings combinations
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let prayerTimes = createMockPrayerTimes(for: date, location: location, method: "muslim_world_league")
        
        // When: Caching with one setting
        apiCache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        
        // Then: Other settings should not have cached data
        let cachedDifferentMethod = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .egyptian, madhab: .shafi)
        let cachedDifferentMadhab = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .hanafi)
        let cachedBothDifferent = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .egyptian, madhab: .hanafi)
        
        XCTAssertNil(cachedDifferentMethod, "Different method should not have cache")
        XCTAssertNil(cachedDifferentMadhab, "Different madhab should not have cache")
        XCTAssertNil(cachedBothDifferent, "Different method+madhab should not have cache")
        
        // But original setting should still have cache
        let cachedOriginal = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        XCTAssertNotNil(cachedOriginal, "Original setting should have cache")
    }
    
    func testCacheKeyConsistencyAcrossRestarts() {
        // Given: Cache entry
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let prayerTimes = createMockPrayerTimes(for: date, location: location, method: "muslim_world_league")
        
        // When: Caching data
        apiCache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        
        // And: Creating new cache instance (simulating app restart)
        let newApiCache = APICache()
        
        // Then: Cache should still be accessible with same key
        let cached = newApiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        XCTAssertNotNil(cached, "Cache should persist across restarts")
    }
    
    // MARK: - Helper Methods
    
    private func createMockPrayerTimes(for date: Date, location: LocationCoordinate, method: String) -> PrayerTimes {
        return PrayerTimes(
            date: date,
            location: location,
            fajr: date.addingTimeInterval(5 * 3600), // 5 AM
            sunrise: date.addingTimeInterval(6 * 3600), // 6 AM
            dhuhr: date.addingTimeInterval(12 * 3600), // 12 PM
            asr: date.addingTimeInterval(15 * 3600), // 3 PM
            maghrib: date.addingTimeInterval(18 * 3600), // 6 PM
            isha: date.addingTimeInterval(19 * 3600), // 7 PM
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
