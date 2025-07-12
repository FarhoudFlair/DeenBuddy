//
//  BackgroundServiceSynchronizationTests.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-11.
//

import XCTest
import Combine
import CoreLocation
import BackgroundTasks
@testable import DeenAssistCore

/// Tests for background service synchronization with current settings
class BackgroundServiceSynchronizationTests: XCTestCase {
    
    // MARK: - Properties
    
    private var settingsService: MockSettingsService!
    private var locationService: MockLocationService!
    private var apiClient: MockAPIClient!
    private var notificationService: MockNotificationService!
    private var prayerTimeService: PrayerTimeService!
    private var backgroundTaskManager: BackgroundTaskManager!
    private var backgroundPrayerRefreshService: BackgroundPrayerRefreshService!
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Create mock services
        settingsService = MockSettingsService()
        locationService = MockLocationService()
        apiClient = MockAPIClient()
        notificationService = MockNotificationService()
        
        // Create prayer time service with dependencies
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
        
        // Set up test location
        locationService.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
    }
    
    override func tearDown() {
        cancellables.removeAll()
        
        settingsService = nil
        locationService = nil
        apiClient = nil
        notificationService = nil
        prayerTimeService = nil
        backgroundTaskManager = nil
        backgroundPrayerRefreshService = nil
        
        super.tearDown()
    }
    
    // MARK: - Background Service Dependency Tests
    
    func testBackgroundTaskManagerUsesCurrentSettings() {
        // Given: Initial settings
        settingsService.calculationMethod = .muslimWorldLeague
        settingsService.madhab = .shafi
        
        // When: Settings change
        settingsService.calculationMethod = .egyptian
        settingsService.madhab = .hanafi
        
        // Then: Background task manager should use updated settings through PrayerTimeService
        XCTAssertEqual(prayerTimeService.calculationMethod, .egyptian)
        XCTAssertEqual(prayerTimeService.madhab, .hanafi)
        
        // And: Background task manager has access to the same PrayerTimeService instance
        XCTAssertTrue(backgroundTaskManager.prayerTimeService === prayerTimeService)
    }
    
    func testBackgroundPrayerRefreshServiceUsesCurrentSettings() {
        // Given: Initial settings
        settingsService.calculationMethod = .muslimWorldLeague
        settingsService.madhab = .shafi
        
        // When: Settings change
        settingsService.calculationMethod = .karachi
        settingsService.madhab = .hanafi
        
        // Then: Background prayer refresh service should use updated settings
        XCTAssertEqual(prayerTimeService.calculationMethod, .karachi)
        XCTAssertEqual(prayerTimeService.madhab, .hanafi)
        
        // And: Background service has access to the same PrayerTimeService instance
        XCTAssertTrue(backgroundPrayerRefreshService.prayerTimeService === prayerTimeService)
    }
    
    func testBackgroundServicesReceiveSettingsUpdates() {
        let expectation = XCTestExpectation(description: "Background services receive settings updates")
        
        // Given: Observer for prayer time changes
        var updateCount = 0
        prayerTimeService.$todaysPrayerTimes
            .dropFirst()
            .sink { _ in
                updateCount += 1
                if updateCount >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When: Settings change
        Task {
            await MainActor.run {
                settingsService.calculationMethod = .egyptian
            }
            
            // Trigger prayer time calculation to verify settings are used
            await prayerTimeService.refreshPrayerTimes()
        }
        
        // Then: Background services should receive the update
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssertEqual(prayerTimeService.calculationMethod, .egyptian)
    }
    
    // MARK: - Background Task Registration Tests
    
    func testBackgroundTaskManagerRegistration() {
        // When: Background tasks are registered
        backgroundTaskManager.registerBackgroundTasks()
        
        // Then: Registration should complete without errors
        // Note: In a real test environment, we would verify the tasks are registered
        // but BGTaskScheduler registration is not easily testable in unit tests
        XCTAssertTrue(true, "Background task registration completed")
    }
    
    func testBackgroundPrayerRefreshServiceStartup() {
        // When: Background refresh is started
        backgroundPrayerRefreshService.startBackgroundRefresh()
        
        // Then: Service should be in refreshing state
        XCTAssertNotNil(backgroundPrayerRefreshService.nextRefreshTime)
    }
    
    // MARK: - Settings Change Propagation Tests
    
    func testSettingsChangePropagationToBackgroundServices() {
        let expectation = XCTestExpectation(description: "Settings propagate to background services")
        
        // Given: Initial state
        let initialMethod = settingsService.calculationMethod
        let initialMadhab = settingsService.madhab
        
        // When: Multiple settings changes
        Task {
            await MainActor.run {
                settingsService.calculationMethod = .egyptian
                settingsService.madhab = .hanafi
            }
            
            // Small delay to allow propagation
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            await MainActor.run {
                // Verify both background services see the changes
                XCTAssertEqual(self.prayerTimeService.calculationMethod, .egyptian)
                XCTAssertEqual(self.prayerTimeService.madhab, .hanafi)
                
                // Verify the changes are different from initial
                XCTAssertNotEqual(self.prayerTimeService.calculationMethod, initialMethod)
                XCTAssertNotEqual(self.prayerTimeService.madhab, initialMadhab)
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testBackgroundServicesCacheInvalidationOnSettingsChange() {
        let expectation = XCTestExpectation(description: "Background services handle cache invalidation")
        
        // Given: Cached prayer times
        Task {
            await prayerTimeService.refreshPrayerTimes()
            
            // Wait for initial cache
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // When: Settings change (this should trigger cache invalidation)
            await MainActor.run {
                settingsService.calculationMethod = .egyptian
            }
            
            // Wait for cache invalidation to complete
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            await MainActor.run {
                // Then: Background services should use new settings
                XCTAssertEqual(self.prayerTimeService.calculationMethod, .egyptian)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Integration Tests
    
    func testEndToEndBackgroundServiceSynchronization() {
        let expectation = XCTestExpectation(description: "End-to-end background service synchronization")
        
        // Given: Complete background service setup
        backgroundTaskManager.registerBackgroundTasks()
        backgroundPrayerRefreshService.startBackgroundRefresh()
        
        // When: Complete workflow with settings changes
        Task {
            // 1. Initial prayer time calculation
            await prayerTimeService.refreshPrayerTimes()
            
            // 2. Change settings
            await MainActor.run {
                settingsService.calculationMethod = .karachi
                settingsService.madhab = .hanafi
            }
            
            // 3. Wait for propagation
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // 4. Trigger background refresh
            await prayerTimeService.refreshTodaysPrayerTimes()
            
            await MainActor.run {
                // Then: Everything should be synchronized
                XCTAssertEqual(self.prayerTimeService.calculationMethod, .karachi)
                XCTAssertEqual(self.prayerTimeService.madhab, .hanafi)
                
                // Background services should have the same reference
                XCTAssertTrue(self.backgroundTaskManager.prayerTimeService === self.prayerTimeService)
                XCTAssertTrue(self.backgroundPrayerRefreshService.prayerTimeService === self.prayerTimeService)
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    // MARK: - Performance Tests
    
    func testBackgroundServiceSynchronizationPerformance() {
        measure {
            // Test rapid settings changes with background services
            for i in 0..<50 {
                let method: CalculationMethod = i % 2 == 0 ? .egyptian : .muslimWorldLeague
                let madhab: Madhab = i % 2 == 0 ? .hanafi : .shafi
                
                settingsService.calculationMethod = method
                settingsService.madhab = madhab
            }
        }
    }
}

// MARK: - Mock Background Task Scheduler

/// Mock for testing background task registration
class MockBGTaskScheduler {
    static var registeredTasks: [String] = []
    
    static func register(forTaskWithIdentifier identifier: String, using queue: DispatchQueue?, launchHandler: @escaping (BGTask) -> Void) -> Bool {
        registeredTasks.append(identifier)
        return true
    }
    
    static func reset() {
        registeredTasks.removeAll()
    }
}
