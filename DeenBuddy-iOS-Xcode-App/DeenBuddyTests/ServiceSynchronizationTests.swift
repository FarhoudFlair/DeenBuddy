//
//  ServiceSynchronizationTests.swift
//  DeenBuddyTests
//
//  Created by Prayer Time Synchronization Fix
//  Tests for service synchronization between SettingsService and PrayerTimeService
//

import XCTest
import Combine
import CoreLocation
@testable import DeenBuddy

class ServiceSynchronizationTests: XCTestCase {
    
    private var settingsService: SettingsService!
    private var prayerTimeService: PrayerTimeService!
    private var mockLocationService: TestMockLocationService!
    private var testUserDefaults: UserDefaults!
    private var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        
        // Create test UserDefaults with unique suite name
        let suiteName = "test.synchronization.\(UUID().uuidString)"
        testUserDefaults = UserDefaults(suiteName: suiteName)!
        
        // Clear any existing data
        testUserDefaults.removePersistentDomain(forName: suiteName)
        
        // Create services
        settingsService = SettingsService(suiteName: suiteName)
        mockLocationService = TestMockLocationService()
        
        // Set up mock location
        mockLocationService.currentLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
        
        // Create prayer time service with dependencies
        let errorHandler = ErrorHandler(crashReporter: CrashReporter())
        let retryMechanism = RetryMechanism(networkMonitor: NetworkMonitor.shared)
        
        prayerTimeService = PrayerTimeService(
            locationService: mockLocationService,
            settingsService: settingsService,
            errorHandler: errorHandler,
            retryMechanism: retryMechanism,
            networkMonitor: NetworkMonitor.shared
        )
    }
    
    override func tearDown() {
        // Clean up
        cancellables.removeAll()
        
        if let suiteName = testUserDefaults.suiteName {
            testUserDefaults.removePersistentDomain(forName: suiteName)
        }
        
        testUserDefaults = nil
        settingsService = nil
        prayerTimeService = nil
        mockLocationService = nil
        
        super.tearDown()
    }
    
    // MARK: - Synchronization Tests
    
    func testCalculationMethodSynchronization() {
        // Given: Initial calculation method
        XCTAssertEqual(prayerTimeService.calculationMethod, .muslimWorldLeague)
        
        // When: Settings service calculation method is changed
        settingsService.calculationMethod = .egyptian
        
        // Then: Prayer time service reflects the change immediately
        XCTAssertEqual(prayerTimeService.calculationMethod, .egyptian)
    }
    
    func testMadhabSynchronization() {
        // Given: Initial madhab
        XCTAssertEqual(prayerTimeService.madhab, .shafi)
        
        // When: Settings service madhab is changed
        settingsService.madhab = .hanafi
        
        // Then: Prayer time service reflects the change immediately
        XCTAssertEqual(prayerTimeService.madhab, .hanafi)
    }
    
    func testPrayerTimeRecalculationOnMethodChange() {
        let expectation = XCTestExpectation(description: "Prayer times recalculated")
        
        // Given: Initial prayer times
        var initialPrayerTimes: [PrayerTime] = []
        var updatedPrayerTimes: [PrayerTime] = []
        
        // Observe prayer time changes
        var changeCount = 0
        prayerTimeService.$todaysPrayerTimes
            .dropFirst() // Skip initial empty value
            .sink { prayerTimes in
                changeCount += 1
                if changeCount == 1 {
                    initialPrayerTimes = prayerTimes
                } else if changeCount == 2 {
                    updatedPrayerTimes = prayerTimes
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When: Trigger initial calculation
        Task {
            await prayerTimeService.refreshPrayerTimes()
            
            // Wait a bit for initial calculation
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Change calculation method
            await MainActor.run {
                settingsService.calculationMethod = .egyptian
            }
        }
        
        // Then: Prayer times should be recalculated
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssertFalse(initialPrayerTimes.isEmpty, "Initial prayer times should be calculated")
        XCTAssertFalse(updatedPrayerTimes.isEmpty, "Updated prayer times should be calculated")
        
        // Prayer times should be different for different calculation methods
        if !initialPrayerTimes.isEmpty && !updatedPrayerTimes.isEmpty {
            let initialFajr = initialPrayerTimes.first(where: { $0.prayer == .fajr })?.time
            let updatedFajr = updatedPrayerTimes.first(where: { $0.prayer == .fajr })?.time
            
            // Fajr times should be different between Muslim World League and Egyptian methods
            XCTAssertNotEqual(initialFajr, updatedFajr, "Fajr times should differ between calculation methods")
        }
    }
    
    func testCacheInvalidationOnSettingsChange() {
        let expectation = XCTestExpectation(description: "Cache invalidated")

        // Given: Cached prayer times exist with method-specific keys
        let testPrayerTimes = [
            PrayerTime(prayer: .fajr, time: Date(), isNext: false),
            PrayerTime(prayer: .dhuhr, time: Date().addingTimeInterval(3600), isNext: true)
        ]

        // Cache some prayer times with current settings
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = dateFormatter.string(from: Date())
        let methodKey = settingsService.calculationMethod.rawValue
        let madhabKey = settingsService.madhab.rawValue
        let cacheKey = "\(UnifiedSettingsKeys.cachedPrayerTimes)_\(todayKey)_\(methodKey)_\(madhabKey)"

        if let data = try? JSONEncoder().encode(testPrayerTimes) {
            testUserDefaults.set(data, forKey: cacheKey)
        }

        // Verify cache exists
        XCTAssertNotNil(testUserDefaults.data(forKey: cacheKey))

        // When: Settings change
        settingsService.calculationMethod = .karachi

        // Then: Cache should be cleared (all cache entries with the prefix)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Check that the old cache entry is cleared
            let cachedData = self.testUserDefaults.data(forKey: cacheKey)
            XCTAssertNil(cachedData, "Old cache should be cleared when settings change")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }
    
    func testMultipleSettingsChanges() {
        let expectation = XCTestExpectation(description: "Multiple changes handled")
        expectation.expectedFulfillmentCount = 2
        
        // Given: Observer for prayer time updates
        prayerTimeService.$todaysPrayerTimes
            .dropFirst()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When: Multiple rapid settings changes
        Task {
            await MainActor.run {
                settingsService.calculationMethod = .egyptian
            }
            
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            await MainActor.run {
                settingsService.madhab = .hanafi
            }
        }
        
        // Then: Both changes should trigger updates
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testSettingsServiceAsSourceOfTruth() {
        // Given: Different initial values
        settingsService.calculationMethod = .ummAlQura
        settingsService.madhab = .hanafi
        
        // When: Prayer time service is queried
        let prayerMethod = prayerTimeService.calculationMethod
        let prayerMadhab = prayerTimeService.madhab
        
        // Then: Values should match settings service
        XCTAssertEqual(prayerMethod, .ummAlQura)
        XCTAssertEqual(prayerMadhab, .hanafi)
        
        // And: Settings service should be the source of truth
        XCTAssertEqual(prayerMethod, settingsService.calculationMethod)
        XCTAssertEqual(prayerMadhab, settingsService.madhab)
    }
    
    func testNoMemoryLeaks() {
        weak var weakSettingsService = settingsService
        weak var weakPrayerTimeService = prayerTimeService
        
        // When: Services are deallocated
        settingsService = nil
        prayerTimeService = nil
        
        // Then: No memory leaks should occur
        XCTAssertNil(weakSettingsService, "SettingsService should be deallocated")
        XCTAssertNil(weakPrayerTimeService, "PrayerTimeService should be deallocated")
    }
    
    // MARK: - Performance Tests
    
    func testSynchronizationPerformance() {
        measure {
            // Test rapid settings changes
            for i in 0..<100 {
                let method: CalculationMethod = i % 2 == 0 ? .egyptian : .muslimWorldLeague
                settingsService.calculationMethod = method
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testEndToEndSynchronization() {
        let expectation = XCTestExpectation(description: "End-to-end synchronization")

        // Given: Complete setup
        var finalPrayerTimes: [PrayerTime] = []

        prayerTimeService.$todaysPrayerTimes
            .dropFirst()
            .sink { prayerTimes in
                if !prayerTimes.isEmpty {
                    finalPrayerTimes = prayerTimes
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When: Complete workflow
        Task {
            // 1. Change settings
            await MainActor.run {
                settingsService.calculationMethod = .karachi
                settingsService.madhab = .hanafi
            }

            // 2. Trigger prayer time calculation
            await prayerTimeService.refreshPrayerTimes()
        }

        // Then: Everything should work together
        wait(for: [expectation], timeout: 15.0)

        XCTAssertFalse(finalPrayerTimes.isEmpty, "Prayer times should be calculated")
        XCTAssertEqual(prayerTimeService.calculationMethod, .karachi)
        XCTAssertEqual(prayerTimeService.madhab, .hanafi)
    }

    func testComprehensiveCacheInvalidationAcrossAllSystems() {
        let expectation = XCTestExpectation(description: "Comprehensive cache invalidation")

        // Given: Cached data exists in multiple systems
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = dateFormatter.string(from: Date())
        let methodKey = settingsService.calculationMethod.rawValue
        let madhabKey = settingsService.madhab.rawValue
        let cacheKey = "\(UnifiedSettingsKeys.cachedPrayerTimes)_\(todayKey)_\(methodKey)_\(madhabKey)"

        // Cache some test data
        let testPrayerTimes = [
            PrayerTime(prayer: .fajr, time: Date(), isNext: false),
            PrayerTime(prayer: .dhuhr, time: Date().addingTimeInterval(3600), isNext: true)
        ]

        if let data = try? JSONEncoder().encode(testPrayerTimes) {
            testUserDefaults.set(data, forKey: cacheKey)
        }

        // Verify cache exists
        XCTAssertNotNil(testUserDefaults.data(forKey: cacheKey))

        // When: Settings change (should trigger comprehensive cache invalidation)
        settingsService.calculationMethod = .egyptian

        // Then: All cache systems should be invalidated
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Check that local cache is cleared
            let cachedData = self.testUserDefaults.data(forKey: cacheKey)
            XCTAssertNil(cachedData, "Local cache should be cleared")

            // Note: APICache and IslamicCacheManager clearing is tested in dedicated test files
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testCacheKeyStrategyWithMethodAndMadhab() {
        // Given: Different calculation settings
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = dateFormatter.string(from: Date())

        let testPrayerTimes = [
            PrayerTime(prayer: .fajr, time: Date(), isNext: false)
        ]

        // When: Caching with different settings
        settingsService.calculationMethod = .muslimWorldLeague
        settingsService.madhab = .shafi

        let key1 = "\(UnifiedSettingsKeys.cachedPrayerTimes)_\(todayKey)_\(settingsService.calculationMethod.rawValue)_\(settingsService.madhab.rawValue)"

        if let data = try? JSONEncoder().encode(testPrayerTimes) {
            testUserDefaults.set(data, forKey: key1)
        }

        settingsService.calculationMethod = .egyptian
        settingsService.madhab = .hanafi

        let key2 = "\(UnifiedSettingsKeys.cachedPrayerTimes)_\(todayKey)_\(settingsService.calculationMethod.rawValue)_\(settingsService.madhab.rawValue)"

        if let data = try? JSONEncoder().encode(testPrayerTimes) {
            testUserDefaults.set(data, forKey: key2)
        }

        // Then: Both cache entries should exist independently
        XCTAssertNotNil(testUserDefaults.data(forKey: key1), "First cache entry should exist")
        XCTAssertNotNil(testUserDefaults.data(forKey: key2), "Second cache entry should exist")
        XCTAssertNotEqual(key1, key2, "Cache keys should be different")
    }
}

// MARK: - Test Mock Location Service

@MainActor
class TestMockLocationService: LocationServiceProtocol {
    var currentLocation: CLLocation?
    var isUpdatingLocation: Bool = false
    var locationError: Error?
    var currentHeading: Double = 0
    var headingAccuracy: Double = 5.0
    var isUpdatingHeading: Bool = false
    var locationPublisher: AnyPublisher<CLLocation, Error> {
        locationSubject.eraseToAnyPublisher()
    }
    var headingPublisher: AnyPublisher<CLHeading, Error> {
        Empty().eraseToAnyPublisher()
    }
    var permissionStatus: CLAuthorizationStatus = .authorizedWhenInUse

    private let locationSubject = PassthroughSubject<CLLocation, Error>()

    func requestLocationPermission() {
        // Mock implementation
    }

    func requestLocationPermissionAsync() async -> CLAuthorizationStatus {
        return permissionStatus
    }

    func requestLocation() async throws -> CLLocation {
        guard let location = currentLocation else {
            throw NSError(domain: "TestMockLocationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No mock location set"])
        }
        return location
    }

    func startUpdatingLocation() {
        isUpdatingLocation = true
        if let location = currentLocation {
            locationSubject.send(location)
        }
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

    func startBackgroundLocationUpdates() {
        isUpdatingLocation = true
    }

    func stopBackgroundLocationUpdates() {
        isUpdatingLocation = false
    }

    func geocodeCity(_ cityName: String) async throws -> CLLocation {
        // Mock implementation - return San Francisco for any city
        return CLLocation(latitude: 37.7749, longitude: -122.4194)
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
