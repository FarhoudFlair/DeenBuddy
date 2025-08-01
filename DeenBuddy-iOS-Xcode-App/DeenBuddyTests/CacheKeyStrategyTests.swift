//
//  CacheKeyStrategyTests.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-11.
//

import XCTest
import CoreLocation
@testable import DeenBuddy

/// Tests for enhanced cache key strategy that includes calculation method and madhab
class CacheKeyStrategyTests: XCTestCase {

    // MARK: - Properties

    private var apiCache: APICache!
    private var islamicCacheManager: IslamicCacheManager!
    private var mockAPIClient: MockAPIClient!
    
    // MARK: - Setup & Teardown
    
    @MainActor
    override func setUp() {
        super.setUp()

        apiCache = APICache()
        islamicCacheManager = IslamicCacheManager()
        mockAPIClient = MockAPIClient()
    }

    @MainActor
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
        let prayerTimes1 = createMockPrayerTimes(for: date, location: location, method: CalculationMethod.muslimWorldLeague.rawValue)
        let prayerTimes2 = createMockPrayerTimes(for: date, location: location, method: CalculationMethod.egyptian.rawValue)
        
        // When: Caching with different calculation methods
        apiCache.cachePrayerTimes(prayerTimes1, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        apiCache.cachePrayerTimes(prayerTimes2, for: date, location: location, calculationMethod: .egyptian, madhab: .shafi)
        apiCache.waitForPendingOperations() // Wait for cache operations to complete
        
        // Then: Both cache entries should exist independently
        let cachedMWL = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        let cachedEgyptian = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .egyptian, madhab: .shafi)
        
        XCTAssertNotNil(cachedMWL, "MWL cache should exist")
        XCTAssertNotNil(cachedEgyptian, "Egyptian cache should exist")
        XCTAssertEqual(cachedMWL?.calculationMethod, CalculationMethod.muslimWorldLeague.rawValue)
        XCTAssertEqual(cachedEgyptian?.calculationMethod, CalculationMethod.egyptian.rawValue)
    }
    
    func testAPICacheKeyIncludesMadhab() {
        // Given: Same date, location, and method, different madhabs
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let prayerTimes1 = createMockPrayerTimes(for: date, location: location, method: CalculationMethod.muslimWorldLeague.rawValue)
        let prayerTimes2 = createMockPrayerTimes(for: date, location: location, method: CalculationMethod.muslimWorldLeague.rawValue)

        // When: Caching with different madhabs
        apiCache.cachePrayerTimes(prayerTimes1, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        apiCache.cachePrayerTimes(prayerTimes2, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .hanafi)

        // Wait for cache operations to complete
        apiCache.waitForPendingOperations()
        
        // Add additional synchronization to ensure cache writes are complete
        let expectation = XCTestExpectation(description: "Cache operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Then: Both cache entries should exist independently
        let cachedShafi = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        let cachedHanafi = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .hanafi)

        // Debug output
        print("DEBUG: Cached Shafi: \(cachedShafi != nil)")
        print("DEBUG: Cached Hanafi: \(cachedHanafi != nil)")

        XCTAssertNotNil(cachedShafi, "Shafi cache should exist")
        XCTAssertNotNil(cachedHanafi, "Hanafi cache should exist")
    }
    
    func testAPICacheKeyUniqueness() {
        // Given: All possible combinations
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let prayerTimes = createMockPrayerTimes(for: date, location: location, method: CalculationMethod.muslimWorldLeague.rawValue)
        
        let methods: [CalculationMethod] = [.muslimWorldLeague, .egyptian, .karachi]
        let madhabs: [Madhab] = [.shafi, .hanafi]
        
        // When: Caching all combinations
        for method in methods {
            for madhab in madhabs {
                apiCache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: method, madhab: madhab)
            }
        }
        apiCache.waitForPendingOperations() // Wait for all cache operations to complete
        
        // Then: All combinations should be cached independently
        for method in methods {
            for madhab in madhabs {
                let cached = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: method, madhab: madhab)
                XCTAssertNotNil(cached, "Cache should exist for \(method.rawValue) + \(madhab.rawValue)")
            }
        }
    }
    
    // MARK: - IslamicCacheManager Key Strategy Tests
    
    func testIslamicCacheManagerKeyIncludesCalculationMethod() async {
        // Given: Same date and location, different calculation methods
        let date = Date()
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let schedule = createMockPrayerSchedule(for: date)

        // When: Caching with different calculation methods
        await islamicCacheManager.cachePrayerSchedule(schedule, for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
        await islamicCacheManager.cachePrayerSchedule(schedule, for: date, location: location, calculationMethod: CalculationMethod.egyptian, madhab: Madhab.shafi)

        // Then: Both cache entries should exist independently
        let cachedMWL = await islamicCacheManager.getCachedPrayerSchedule(for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
        let cachedEgyptian = await islamicCacheManager.getCachedPrayerSchedule(for: date, location: location, calculationMethod: CalculationMethod.egyptian, madhab: Madhab.shafi)

        XCTAssertNotNil(cachedMWL.schedule, "MWL cache should exist")
        XCTAssertNotNil(cachedEgyptian.schedule, "Egyptian cache should exist")
    }
    
    func testIslamicCacheManagerKeyIncludesMadhab() async {
        // Given: Same date, location, and method, different madhabs
        let date = Date()
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let schedule = createMockPrayerSchedule(for: date)

        // When: Caching with different madhabs
        await islamicCacheManager.cachePrayerSchedule(schedule, for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
        await islamicCacheManager.cachePrayerSchedule(schedule, for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.hanafi)

        // Then: Both cache entries should exist independently
        let cachedShafi = await islamicCacheManager.getCachedPrayerSchedule(for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.shafi)
        let cachedHanafi = await islamicCacheManager.getCachedPrayerSchedule(for: date, location: location, calculationMethod: CalculationMethod.muslimWorldLeague, madhab: Madhab.hanafi)

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
        // Given: Different settings combinations - use fixed date to avoid timing issues
        let calendar = Calendar.current
        let dateComponents = DateComponents(year: 2024, month: 6, day: 15, hour: 0, minute: 0, second: 0)
        let date = calendar.date(from: dateComponents)!
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)

        // Create PrayerTimes with the correct calculationMethod string that matches the enum
        let prayerTimes = createMockPrayerTimes(for: date, location: location, method: CalculationMethod.muslimWorldLeague.rawValue)

        // When: Caching with one setting
        apiCache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)

        // Wait for all pending cache operations to complete
        apiCache.waitForPendingOperations()

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

        // Additional verification: check if the cached data matches what we stored
        if let cached = cachedOriginal {
            XCTAssertEqual(cached.date, prayerTimes.date, "Cached date should match")
            XCTAssertEqual(cached.calculationMethod, prayerTimes.calculationMethod, "Cached method should match")
            XCTAssertEqual(cached.location.latitude, prayerTimes.location.latitude, accuracy: 0.0001, "Cached location should match")
            XCTAssertEqual(cached.location.longitude, prayerTimes.location.longitude, accuracy: 0.0001, "Cached location should match")
        }
    }
    
    func testCacheKeyConsistencyAcrossRestarts() {
        // Given: Cache entry - use fixed date to avoid timing issues
        let calendar = Calendar.current
        let dateComponents = DateComponents(year: 2024, month: 6, day: 15, hour: 0, minute: 0, second: 0)
        let date = calendar.date(from: dateComponents)!
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let prayerTimes = createMockPrayerTimes(for: date, location: location, method: CalculationMethod.muslimWorldLeague.rawValue)

        // When: Caching data
        apiCache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        apiCache.waitForPendingOperations() // Wait for cache operation to complete

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
            fajr: date.addingTimeInterval(5 * 3600), // 5 AM
            dhuhr: date.addingTimeInterval(12 * 3600), // 12 PM
            asr: date.addingTimeInterval(15 * 3600), // 3 PM
            maghrib: date.addingTimeInterval(18 * 3600), // 6 PM
            isha: date.addingTimeInterval(19 * 3600), // 7 PM
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
