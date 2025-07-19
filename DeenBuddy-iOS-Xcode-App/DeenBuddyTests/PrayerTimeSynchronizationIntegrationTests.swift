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

/// Integration tests for the complete prayer time synchronization system
/// Tests the interaction between SettingsService, PrayerTimeService, cache systems, and background services
class PrayerTimeSynchronizationIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    private var dependencyContainer: DependencyContainer!
    private var settingsService: MockSettingsService!
    private var locationService: MockLocationService!
    private var apiClient: MockAPIClient!
    private var notificationService: MockNotificationService!
    private var prayerTimeService: PrayerTimeService!
    private var backgroundTaskManager: BackgroundTaskManager!
    private var backgroundPrayerRefreshService: BackgroundPrayerRefreshService!
    private var apiCache: APICache!
    private var islamicCacheManager: IslamicCacheManager!
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Create mock services
        settingsService = MockSettingsService()
        locationService = MockLocationService()
        apiClient = MockAPIClient()
        notificationService = MockNotificationService()
        
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
            notificationService: notificationService,
            locationService: locationService
        )
        
        backgroundPrayerRefreshService = BackgroundPrayerRefreshService(
            prayerTimeService: prayerTimeService,
            locationService: locationService
        )
        
        // Create dependency container for integration testing
        dependencyContainer = DependencyContainer(
            locationService: locationService,
            apiClient: apiClient,
            notificationService: notificationService,
            prayerTimeService: prayerTimeService,
            settingsService: settingsService,
            backgroundTaskManager: backgroundTaskManager,
            backgroundPrayerRefreshService: backgroundPrayerRefreshService,
            isTestEnvironment: true
        )
        
        // Set up test location
        locationService.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
    }
    
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
        prayerTimeService.$todaysPrayerTimes
            .dropFirst() // Skip initial empty value
            .sink { prayerTimes in
                if !prayerTimes.isEmpty {
                    prayerTimeUpdates.append(prayerTimes)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When: Complete workflow
        // 1. Initial prayer time calculation
        await prayerTimeService.refreshPrayerTimes()
        
        // Wait for initial calculation
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // 2. Change settings (should trigger cache invalidation and recalculation)
        await MainActor.run {
            settingsService.calculationMethod = .egyptian
            settingsService.madhab = .hanafi
        }
        
        // Wait for settings change propagation
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Then: Verify complete synchronization
        await fulfillment(of: [expectation], timeout: 10.0)
        
        XCTAssertEqual(prayerTimeUpdates.count, 2, "Should have initial and updated prayer times")
        XCTAssertEqual(prayerTimeService.calculationMethod, .egyptian)
        XCTAssertEqual(prayerTimeService.madhab, .hanafi)
    }
    
    func testCacheSystemsIntegrationWithSettingsChanges() async throws {
        // Given: Initial settings and cached data
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let clLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        // Cache data in all systems with initial settings
        let prayerTimes = createMockPrayerTimes(for: date, location: location, method: "muslim_world_league")
        let schedule = createMockPrayerSchedule(for: date)
        
        apiCache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        islamicCacheManager.cachePrayerSchedule(schedule, for: date, location: clLocation, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        
        // Verify initial cache exists
        XCTAssertNotNil(apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi))
        XCTAssertNotNil(islamicCacheManager.getCachedPrayerSchedule(for: date, location: clLocation, calculationMethod: .muslimWorldLeague, madhab: .shafi).schedule)
        
        // When: Settings change
        await MainActor.run {
            settingsService.calculationMethod = .egyptian
        }
        
        // Wait for cache invalidation
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Then: Old cache should be cleared, new cache should be separate
        let oldAPICache = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        let oldIslamicCache = islamicCacheManager.getCachedPrayerSchedule(for: date, location: clLocation, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        
        // Old cache should still exist (cache keys are method-specific now)
        XCTAssertNotNil(oldAPICache, "Old cache should exist with method-specific keys")
        XCTAssertNotNil(oldIslamicCache.schedule, "Old Islamic cache should exist with method-specific keys")
        
        // New settings should have no cache initially
        let newAPICache = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .egyptian, madhab: .shafi)
        let newIslamicCache = islamicCacheManager.getCachedPrayerSchedule(for: date, location: clLocation, calculationMethod: .egyptian, madhab: .shafi)
        
        XCTAssertNil(newAPICache, "New settings should have no cache initially")
        XCTAssertNil(newIslamicCache.schedule, "New Islamic cache should be empty initially")
    }
    
    func testBackgroundServicesIntegrationWithSettingsChanges() async throws {
        let expectation = XCTestExpectation(description: "Background services integration")
        
        // Given: Background services are started
        backgroundTaskManager.registerBackgroundTasks()
        backgroundPrayerRefreshService.startBackgroundRefresh()
        
        // When: Settings change
        await MainActor.run {
            settingsService.calculationMethod = .karachi
            settingsService.madhab = .hanafi
        }
        
        // Wait for propagation
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Then: Background services should use new settings
        XCTAssertEqual(prayerTimeService.calculationMethod, .karachi)
        XCTAssertEqual(prayerTimeService.madhab, .hanafi)
        
        // And: Background services should have access to the same PrayerTimeService
        XCTAssertTrue(backgroundTaskManager.prayerTimeService === prayerTimeService)
        XCTAssertTrue(backgroundPrayerRefreshService.prayerTimeService === prayerTimeService)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testDependencyContainerIntegration() async throws {
        // Given: Dependency container setup
        await dependencyContainer.setupServices()
        
        // When: Settings change through the container's settings service
        await MainActor.run {
            dependencyContainer.settingsService.calculationMethod = .ummAlQura
            dependencyContainer.settingsService.madhab = .hanafi
        }
        
        // Wait for propagation
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Then: All services should be synchronized
        XCTAssertEqual(dependencyContainer.prayerTimeService.calculationMethod, .ummAlQura)
        XCTAssertEqual(dependencyContainer.prayerTimeService.madhab, .hanafi)
        XCTAssertEqual(dependencyContainer.settingsService.calculationMethod, .ummAlQura)
        XCTAssertEqual(dependencyContainer.settingsService.madhab, .hanafi)
        
        // And: Background services should use the same settings
        XCTAssertTrue(dependencyContainer.backgroundTaskManager.prayerTimeService === dependencyContainer.prayerTimeService)
        XCTAssertTrue(dependencyContainer.backgroundPrayerRefreshService.prayerTimeService === dependencyContainer.prayerTimeService)
    }
    
    // MARK: - Real-World Scenario Tests
    
    func testUserChangesCalculationMethodScenario() async throws {
        let expectation = XCTestExpectation(description: "User changes calculation method scenario")
        expectation.expectedFulfillmentCount = 3 // Initial + 2 changes
        
        var calculationMethods: [CalculationMethod] = []
        
        // Given: Observer for calculation method changes
        prayerTimeService.$todaysPrayerTimes
            .dropFirst()
            .sink { _ in
                calculationMethods.append(self.prayerTimeService.calculationMethod)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When: User workflow - initial load, then changes method twice
        await prayerTimeService.refreshPrayerTimes()
        try await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            settingsService.calculationMethod = .egyptian
        }
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            settingsService.calculationMethod = .karachi
        }
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Then: All changes should be reflected
        await fulfillment(of: [expectation], timeout: 15.0)
        
        XCTAssertEqual(calculationMethods.count, 3)
        XCTAssertEqual(calculationMethods[0], .muslimWorldLeague) // Initial
        XCTAssertEqual(calculationMethods[1], .egyptian) // First change
        XCTAssertEqual(calculationMethods[2], .karachi) // Second change
        XCTAssertEqual(prayerTimeService.calculationMethod, .karachi) // Final state
    }
    
    func testAppBackgroundingWithSettingsChangeScenario() async throws {
        // Given: App is running with initial settings
        await prayerTimeService.refreshPrayerTimes()
        try await Task.sleep(nanoseconds: 500_000_000)
        
        let initialMethod = prayerTimeService.calculationMethod
        
        // When: App goes to background and settings change
        backgroundTaskManager.registerBackgroundTasks()
        backgroundPrayerRefreshService.startBackgroundRefresh()
        
        await MainActor.run {
            settingsService.calculationMethod = .egyptian
        }
        
        // Simulate background refresh
        await prayerTimeService.refreshTodaysPrayerTimes()
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Then: Background services should use new settings
        XCTAssertNotEqual(prayerTimeService.calculationMethod, initialMethod)
        XCTAssertEqual(prayerTimeService.calculationMethod, .egyptian)
    }
    
    func testMultipleRapidSettingsChangesIntegration() async throws {
        let expectation = XCTestExpectation(description: "Multiple rapid settings changes")
        expectation.expectedFulfillmentCount = 5 // Initial + 4 changes

        var settingsHistory: [(CalculationMethod, Madhab)] = []

        // Given: Observer for all changes
        prayerTimeService.$todaysPrayerTimes
            .dropFirst()
            .sink { _ in
                let current = (self.prayerTimeService.calculationMethod, self.prayerTimeService.madhab)
                settingsHistory.append(current)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When: Rapid settings changes (simulating user quickly changing preferences)
        await prayerTimeService.refreshPrayerTimes()
        try await Task.sleep(nanoseconds: 200_000_000)

        await MainActor.run {
            settingsService.calculationMethod = .egyptian
        }
        try await Task.sleep(nanoseconds: 200_000_000)

        await MainActor.run {
            settingsService.madhab = .hanafi
        }
        try await Task.sleep(nanoseconds: 200_000_000)

        await MainActor.run {
            settingsService.calculationMethod = .karachi
        }
        try await Task.sleep(nanoseconds: 200_000_000)

        await MainActor.run {
            settingsService.madhab = .shafi
        }
        try await Task.sleep(nanoseconds: 500_000_000)

        // Then: All changes should be handled correctly
        await fulfillment(of: [expectation], timeout: 10.0)

        XCTAssertEqual(settingsHistory.count, 5)
        XCTAssertEqual(settingsHistory.last?.0, .karachi)
        XCTAssertEqual(settingsHistory.last?.1, .shafi)
    }

    func testConcurrentAccessIntegration() async throws {
        // Given: Multiple concurrent operations
        let expectation = XCTestExpectation(description: "Concurrent access integration")
        expectation.expectedFulfillmentCount = 3

        // When: Concurrent settings changes and prayer time requests
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

        // Then: System should remain stable
        await fulfillment(of: [expectation], timeout: 10.0)

        XCTAssertEqual(prayerTimeService.calculationMethod, .egyptian)
        XCTAssertEqual(prayerTimeService.madhab, .hanafi)
    }

    func testNetworkFailureWithCacheIntegration() async throws {
        // Given: Network failure scenario
        apiClient.shouldFailRequests = true
        apiClient.isNetworkAvailable = false

        // Cache some data first
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let cachedPrayerTimes = createMockPrayerTimes(for: date, location: location, method: "muslim_world_league")

        apiCache.cachePrayerTimes(cachedPrayerTimes, for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)

        // When: Settings change during network failure
        await MainActor.run {
            settingsService.calculationMethod = .egyptian
        }

        // Then: System should handle gracefully
        // Old cache should still exist for old settings
        let oldCache = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        XCTAssertNotNil(oldCache, "Old cache should still exist")

        // New settings should have no cache
        let newCache = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: .egyptian, madhab: .shafi)
        XCTAssertNil(newCache, "New settings should have no cache")
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
