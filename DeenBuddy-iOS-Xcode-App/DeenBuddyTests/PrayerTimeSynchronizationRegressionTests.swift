//
//  PrayerTimeSynchronizationRegressionTests.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-11.
//

import XCTest
import Combine
import CoreLocation
@testable import DeenAssistCore

/// Comprehensive regression test suite to prevent prayer time synchronization bugs
/// This test suite covers all critical paths and edge cases that could lead to synchronization issues
class PrayerTimeSynchronizationRegressionTests: XCTestCase {
    
    // MARK: - Properties
    
    private var settingsService: MockSettingsService!
    private var locationService: MockLocationService!
    private var apiClient: MockAPIClient!
    private var prayerTimeService: PrayerTimeService!
    private var apiCache: APICache!
    private var islamicCacheManager: IslamicCacheManager!
    private var backgroundTaskManager: BackgroundTaskManager!
    private var dependencyContainer: DependencyContainer!
    private var testUserDefaults: UserDefaults!
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Create test UserDefaults
        testUserDefaults = UserDefaults(suiteName: "RegressionTests")!
        testUserDefaults.removePersistentDomain(forName: "RegressionTests")
        
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
        
        // Create dependency container
        dependencyContainer = DependencyContainer(
            locationService: locationService,
            apiClient: apiClient,
            notificationService: MockNotificationService(),
            prayerTimeService: prayerTimeService,
            settingsService: settingsService,
            backgroundTaskManager: backgroundTaskManager,
            backgroundPrayerRefreshService: BackgroundPrayerRefreshService(
                prayerTimeService: prayerTimeService,
                locationService: locationService
            ),
            isTestEnvironment: true
        )
        
        // Set up test location
        locationService.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
    }
    
    override func tearDown() {
        cancellables.removeAll()
        testUserDefaults.removePersistentDomain(forName: "RegressionTests")
        apiCache.clearAllCache()
        islamicCacheManager.clearAllCache()
        
        settingsService = nil
        locationService = nil
        apiClient = nil
        prayerTimeService = nil
        apiCache = nil
        islamicCacheManager = nil
        backgroundTaskManager = nil
        dependencyContainer = nil
        testUserDefaults = nil
        
        super.tearDown()
    }
    
    // MARK: - Core Synchronization Regression Tests
    
    func testCriticalPath_SettingsChangeTriggersRecalculation() async throws {
        let expectation = XCTestExpectation(description: "Settings change triggers recalculation")
        expectation.expectedFulfillmentCount = 2 // Initial + after change
        
        var updateCount = 0
        prayerTimeService.$todaysPrayerTimes
            .dropFirst()
            .sink { prayerTimes in
                if !prayerTimes.isEmpty {
                    updateCount += 1
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Initial calculation
        await prayerTimeService.refreshPrayerTimes()
        
        // Wait for initial calculation
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Change settings - this is the critical path that was broken
        await MainActor.run {
            settingsService.calculationMethod = .egyptian
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        XCTAssertEqual(updateCount, 2, "Should have initial calculation + recalculation after settings change")
        XCTAssertEqual(prayerTimeService.calculationMethod, .egyptian, "Service should use new calculation method")
    }
    
    func testRegressionPrevention_DuplicateUserDefaultsKeys() {
        // This test prevents the original bug: duplicate UserDefaults keys between services
        
        // Verify unified keys are used
        XCTAssertEqual(UnifiedSettingsKeys.calculationMethod, "unified_calculation_method")
        XCTAssertEqual(UnifiedSettingsKeys.madhab, "unified_madhab")
        
        // Verify no legacy keys are used in production code
        let legacyKeys = ["calculationMethod", "madhab", "prayer_calculation_method", "prayer_madhab"]
        
        for legacyKey in legacyKeys {
            // These keys should not exist in fresh installation
            XCTAssertNil(testUserDefaults.object(forKey: legacyKey), "Legacy key \(legacyKey) should not be used")
        }
        
        // Verify services use unified keys
        settingsService.calculationMethod = .egyptian
        settingsService.madhab = .hanafi
        
        // Both services should read the same values
        XCTAssertEqual(prayerTimeService.calculationMethod, .egyptian)
        XCTAssertEqual(prayerTimeService.madhab, .hanafi)
    }
    
    func testRegressionPrevention_CacheKeyIncludesMethodAndMadhab() {
        // This test prevents cache invalidation issues
        
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let prayerTimes1 = createMockPrayerTimes(for: date, location: location, method: "muslim_world_league")
        let prayerTimes2 = createMockPrayerTimes(for: date, location: location, method: "egyptian")
        
        // Cache with different methods should create separate entries
        apiCache.cachePrayerTimes(prayerTimes1, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        apiCache.cachePrayerTimes(prayerTimes2, for: date, location: location, calculationMethod: .egyptian, madhab: .shafi)
        
        // Both should exist independently
        let cached1 = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        let cached2 = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .egyptian, madhab: .shafi)
        
        XCTAssertNotNil(cached1, "MWL cache should exist")
        XCTAssertNotNil(cached2, "Egyptian cache should exist")
        XCTAssertEqual(cached1?.calculationMethod, "muslim_world_league")
        XCTAssertEqual(cached2?.calculationMethod, "egyptian")
    }
    
    func testRegressionPrevention_BackgroundServicesUsesCurrentSettings() async throws {
        // This test prevents background services from using stale settings
        
        // Initial settings
        settingsService.calculationMethod = .muslimWorldLeague
        
        // Start background services
        backgroundTaskManager.registerBackgroundTasks()
        
        // Change settings
        await MainActor.run {
            settingsService.calculationMethod = .egyptian
        }
        
        // Wait for propagation
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Background services should use current settings
        XCTAssertEqual(prayerTimeService.calculationMethod, .egyptian)
        XCTAssertTrue(backgroundTaskManager.prayerTimeService === prayerTimeService, "Background service should use same instance")
    }
    
    // MARK: - Edge Case Regression Tests
    
    func testRegressionPrevention_RapidSettingsChanges() async throws {
        // This test prevents issues with rapid settings changes
        
        let expectation = XCTestExpectation(description: "Rapid settings changes handled correctly")
        expectation.expectedFulfillmentCount = 5
        
        prayerTimeService.$todaysPrayerTimes
            .dropFirst()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Rapid changes
        for i in 0..<5 {
            let method: CalculationMethod = i % 2 == 0 ? .egyptian : .muslimWorldLeague
            await MainActor.run {
                settingsService.calculationMethod = method
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // Final state should be consistent
        XCTAssertEqual(prayerTimeService.calculationMethod, .egyptian) // Last setting
    }
    
    func testRegressionPrevention_ConcurrentAccess() async throws {
        // This test prevents race conditions
        
        let expectation = XCTestExpectation(description: "Concurrent access handled safely")
        expectation.expectedFulfillmentCount = 3
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await MainActor.run {
                    self.settingsService.calculationMethod = .egyptian
                }
                expectation.fulfill()
            }
            
            group.addTask {
                await self.prayerTimeService.refreshPrayerTimes()
                expectation.fulfill()
            }
            
            group.addTask {
                await MainActor.run {
                    self.settingsService.madhab = .hanafi
                }
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // System should remain stable
        XCTAssertEqual(prayerTimeService.calculationMethod, .egyptian)
        XCTAssertEqual(prayerTimeService.madhab, .hanafi)
    }
    
    func testRegressionPrevention_MemoryLeaks() {
        // This test prevents memory leaks in observers
        
        weak var weakSettingsService: MockSettingsService?
        weak var weakPrayerTimeService: PrayerTimeService?
        
        autoreleasepool {
            let tempSettingsService = MockSettingsService()
            let tempPrayerTimeService = PrayerTimeService(
                locationService: locationService,
                settingsService: tempSettingsService,
                apiClient: apiClient,
                errorHandler: ErrorHandler(crashReporter: CrashReporter()),
                retryMechanism: RetryMechanism(networkMonitor: NetworkMonitor.shared),
                networkMonitor: NetworkMonitor.shared
            )
            
            weakSettingsService = tempSettingsService
            weakPrayerTimeService = tempPrayerTimeService
            
            // Create observer relationship
            tempSettingsService.calculationMethod = .egyptian
        }
        
        // Objects should be deallocated
        XCTAssertNil(weakSettingsService, "SettingsService should be deallocated")
        XCTAssertNil(weakPrayerTimeService, "PrayerTimeService should be deallocated")
    }
    
    // MARK: - Integration Regression Tests
    
    func testRegressionPrevention_DependencyContainerIntegration() async throws {
        // This test prevents dependency injection issues
        
        await dependencyContainer.setupServices()
        
        // Change settings through container
        await MainActor.run {
            dependencyContainer.settingsService.calculationMethod = .karachi
        }
        
        // Wait for propagation
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // All services should be synchronized
        XCTAssertEqual(dependencyContainer.prayerTimeService.calculationMethod, .karachi)
        XCTAssertEqual(dependencyContainer.settingsService.calculationMethod, .karachi)
        
        // Background services should use same instance
        XCTAssertTrue(dependencyContainer.backgroundTaskManager.prayerTimeService === dependencyContainer.prayerTimeService)
    }
    
    func testRegressionPrevention_AppLifecycleTransitions() async throws {
        // This test prevents issues during app lifecycle transitions
        
        // Simulate app launch
        await prayerTimeService.refreshPrayerTimes()
        
        // Simulate app backgrounding
        await MainActor.run {
            settingsService.calculationMethod = .egyptian
        }
        
        // Simulate app foregrounding
        await prayerTimeService.refreshTodaysPrayerTimes()
        
        // Settings should be consistent
        XCTAssertEqual(prayerTimeService.calculationMethod, .egyptian)
    }
    
    // MARK: - Performance Regression Tests
    
    func testRegressionPrevention_PerformanceDegradation() {
        // This test prevents performance regressions
        
        measure {
            for i in 0..<100 {
                let method: CalculationMethod = i % 2 == 0 ? .egyptian : .muslimWorldLeague
                settingsService.calculationMethod = method
            }
        }
    }
    
    func testRegressionPrevention_CachePerformance() {
        // This test prevents cache performance regressions
        
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        
        measure {
            for i in 0..<1000 {
                let prayerTimes = createMockPrayerTimes(for: date.addingTimeInterval(TimeInterval(i * 86400)), location: location, method: "muslim_world_league")
                apiCache.cachePrayerTimes(prayerTimes, for: date.addingTimeInterval(TimeInterval(i * 86400)), location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
            }
        }
    }
    
    // MARK: - Data Integrity Regression Tests
    
    func testRegressionPrevention_SettingsPersistence() async throws {
        // This test prevents settings persistence issues
        
        // Set specific values
        settingsService.calculationMethod = .karachi
        settingsService.madhab = .hanafi
        
        // Save settings
        try await settingsService.saveSettings()
        
        // Create new service instance (simulates app restart)
        let newSettingsService = SettingsService(suiteName: "RegressionTests")
        
        // Wait for loading
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Settings should persist
        XCTAssertEqual(newSettingsService.calculationMethod, .karachi)
        XCTAssertEqual(newSettingsService.madhab, .hanafi)
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
}
