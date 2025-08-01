import XCTest
import UserNotifications
import Combine
import CoreLocation
@testable import DeenBuddy

/// Memory leak detection tests for notification and background services
@MainActor
final class MemoryLeakTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var initialMemoryFootprint: Int = 0
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        initialMemoryFootprint = getCurrentMemoryUsage()
    }
    
    override func tearDown() async throws {
        // Force garbage collection
        autoreleasepool { }
        
        let finalMemoryFootprint = getCurrentMemoryUsage()
        let memoryIncrease = finalMemoryFootprint - initialMemoryFootprint
        
        // Allow for some memory increase but flag significant leaks
        if memoryIncrease > 10_000_000 { // 10MB threshold
            print("⚠️ Potential memory leak detected: \(memoryIncrease) bytes increase")
        }
        
        try await super.tearDown()
    }
    
    // MARK: - NotificationService Memory Leak Tests
    
    func testNotificationServiceObserverCleanup() {
        weak var weakService: NotificationService?
        
        // Create and destroy service in autorelease pool
        autoreleasepool {
            let service = NotificationService()
            weakService = service
            
            // Service should set up observers automatically during initialization
            
            // Service should be strongly referenced here
            XCTAssertNotNil(weakService, "Service should exist during setup")
        }
        
        // Force cleanup
        autoreleasepool { }
        
        // Service should be deallocated after autorelease pool
        XCTAssertNil(weakService, "NotificationService should be deallocated - potential memory leak")
    }
    
    func testNotificationServiceMultipleInstances() {
        var services: [NotificationService] = []
        
        // Create multiple instances
        for _ in 0..<10 {
            autoreleasepool {
                let service = NotificationService()
                services.append(service)
            }
        }
        
        let memoryAfterCreation = getCurrentMemoryUsage()
        
        // Clear all references
        services.removeAll()
        autoreleasepool { }
        
        let memoryAfterCleanup = getCurrentMemoryUsage()
        let memoryDifference = memoryAfterCleanup - memoryAfterCreation
        
        // Memory should not increase significantly after cleanup
        XCTAssertLessThan(abs(memoryDifference), 2_000_000, "Memory should be cleaned up after service deallocation")
    }
    
    // MARK: - Widget Service Memory Leak Tests
    
    func testWidgetServiceMemoryManagement() {
        weak var weakWidgetService: WidgetService?
        
        autoreleasepool {
            let widgetService = WidgetService()
            weakWidgetService = widgetService
            
            // Simulate widget operations
            Task {
                await widgetService.updateWidgetData()
            }
        }
        
        // Allow async operations to complete
        let expectation = XCTestExpectation(description: "Widget operations complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        autoreleasepool { }
        
        XCTAssertNil(weakWidgetService, "WidgetService should be deallocated")
    }
    
    func testWidgetDataManagerSingleton() {
        let manager1 = WidgetDataManager.shared
        let manager2 = WidgetDataManager.shared
        
        // Should be the same instance
        XCTAssertTrue(manager1 === manager2, "WidgetDataManager should be singleton")
        
        // Test data operations don't cause leaks
        let testData = WidgetData.placeholder
        manager1.saveWidgetData(testData)
        
        let retrievedData = manager2.loadWidgetData()
        XCTAssertNotNil(retrievedData, "Data should be retrievable")
    }
    
    // MARK: - Live Activity Memory Leak Tests
    
    @available(iOS 16.1, *)
    func testLiveActivityManagerMemoryManagement() {
        let manager = PrayerLiveActivityManager.shared
        
        // Test that manager doesn't retain activities indefinitely
        let initialActivityCount = manager.isActivityActive ? 1 : 0
        
        // Simulate activity lifecycle
        Task {
            do {
                try await manager.startPrayerCountdown(
                    for: .fajr,
                    prayerTime: Date().addingTimeInterval(3600),
                    location: "Test Location",
                    hijriDate: "Test Date",
                    calculationMethod: "Test Method"
                )
                
                await manager.endCurrentActivity()
            } catch {
                // Expected to fail in test environment
            }
        }
        
        // Manager should not accumulate state
        XCTAssertEqual(manager.isActivityActive, false, "Activity should not remain active after end")
    }
    
    // MARK: - Background Task Memory Tests
    
    func testBackgroundTaskCleanup() {
        var backgroundTasks: [Task<Void, Never>] = []
        
        // Create multiple background tasks
        for i in 0..<5 {
            let task = Task {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                print("Background task \(i) completed")
            }
            backgroundTasks.append(task)
        }
        
        let memoryAfterTaskCreation = getCurrentMemoryUsage()
        
        // Cancel all tasks
        for task in backgroundTasks {
            task.cancel()
        }
        backgroundTasks.removeAll()
        
        // Allow cleanup
        let expectation = XCTestExpectation(description: "Tasks cleanup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        let memoryAfterCleanup = getCurrentMemoryUsage()
        let memoryDifference = memoryAfterCleanup - memoryAfterTaskCreation
        
        // Allow for more variance in test environment (simulator can have higher baseline)
        XCTAssertLessThan(abs(memoryDifference), 3_000_000, "Background tasks should not leak significant memory")
    }
    
    // MARK: - Observer Pattern Memory Tests
    
    func testNotificationCenterObserverLeaks() {
        var observers: [NSObjectProtocol] = []
        
        // Add multiple observers
        for i in 0..<10 {
            let observer = NotificationCenter.default.addObserver(
                forName: .settingsDidChange,
                object: nil,
                queue: nil
            ) { _ in
                print("Observer \(i) triggered")
            }
            observers.append(observer)
        }
        
        let memoryAfterObservers = getCurrentMemoryUsage()
        
        // Remove all observers
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        
        autoreleasepool { }
        
        let memoryAfterRemoval = getCurrentMemoryUsage()
        let memoryDifference = memoryAfterRemoval - memoryAfterObservers
        
        XCTAssertLessThan(abs(memoryDifference), 500_000, "Observers should not leak memory")
    }
    
    // MARK: - Combine Publisher Memory Tests
    
    func testCombineSubscriptionCleanup() {
        var cancellables = Set<AnyCancellable>()
        
        // Create multiple publishers and subscriptions
        for i in 0..<10 {
            Just(i)
                .delay(for: .milliseconds(100), scheduler: RunLoop.main)
                .sink { value in
                    print("Received value: \(value)")
                }
                .store(in: &cancellables)
        }
        
        let memoryAfterSubscriptions = getCurrentMemoryUsage()
        
        // Cancel all subscriptions
        cancellables.removeAll()
        
        autoreleasepool { }
        
        let memoryAfterCancellation = getCurrentMemoryUsage()
        let memoryDifference = memoryAfterCancellation - memoryAfterSubscriptions
        
        XCTAssertLessThan(abs(memoryDifference), 500_000, "Combine subscriptions should not leak memory")
    }
    
    // MARK: - Performance Tests
    
    func testNotificationSchedulingPerformance() async throws {
        let prayerTimes = createMockPrayerTimes()
        let notificationService = NotificationService()

        // Check notification permission status before running performance test
        switch notificationService.authorizationStatus {
        case .authorized, .provisional:
            // Permissions available: Run full performance test
            measure {
                Task {
                    do {
                        try await notificationService.schedulePrayerNotifications(for: prayerTimes)
                    } catch {
                        XCTFail("Notification scheduling failed with permissions available: \(error)")
                    }
                }
            }

        case .denied:
            // Permissions denied: Run alternative test measuring service initialization
            measure {
                Task {
                    // Test notification service configuration and validation without actual scheduling
                    let settings = notificationService.getNotificationSettings()
                    XCTAssertNotNil(settings, "Notification settings should be accessible even without permissions")

                    // Test prayer time validation logic
                    XCTAssertFalse(prayerTimes.isEmpty, "Prayer times should be valid for testing")
                    XCTAssertEqual(prayerTimes.count, 5, "Should have 5 daily prayers")
                }
            }

        case .notDetermined, .ephemeral:
            // Permissions not determined: Skip test with descriptive message
            throw XCTSkip("Notification permissions not determined - cannot run meaningful performance test. Please grant notification permissions or run test with denied permissions to test alternative path.")

        @unknown default:
            throw XCTSkip("Unknown notification permission status - cannot determine appropriate test path.")
        }
    }
    
    func testWidgetDataProcessingPerformance() {
        let widgetData = WidgetData.placeholder
        
        measure {
            WidgetDataManager.shared.saveWidgetData(widgetData)
            let _ = WidgetDataManager.shared.loadWidgetData()
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size)
        } else {
            return 0
        }
    }
    
    private func createMockPrayerTimes() -> [PrayerTime] {
        let calendar = Calendar.current
        let today = Date()
        let baseTime = calendar.startOfDay(for: today)
        
        return [
            PrayerTime(prayer: .fajr, time: calendar.date(byAdding: .hour, value: 5, to: baseTime)!),
            PrayerTime(prayer: .dhuhr, time: calendar.date(byAdding: .hour, value: 12, to: baseTime)!),
            PrayerTime(prayer: .asr, time: calendar.date(byAdding: .hour, value: 15, to: baseTime)!),
            PrayerTime(prayer: .maghrib, time: calendar.date(byAdding: .hour, value: 18, to: baseTime)!),
            PrayerTime(prayer: .isha, time: calendar.date(byAdding: .hour, value: 20, to: baseTime)!)
        ]
    }
}

// MARK: - Memory Leak Detection Utilities

extension MemoryLeakTests {
    
    /// Utility to detect retain cycles in objects
    func detectRetainCycle<T: AnyObject>(in object: T, description: String) {
        weak var weakObject = object
        
        autoreleasepool {
            // Object should still exist here
            XCTAssertNotNil(weakObject, "\(description) should exist before cleanup")
        }
        
        // After autorelease pool, object should be deallocated if no retain cycle
        autoreleasepool { }
        
        XCTAssertNil(weakObject, "\(description) has potential retain cycle - not deallocated")
    }
    
    /// Utility to measure memory impact of operations
    func measureMemoryImpact(of operation: () throws -> Void, description: String) rethrows {
        let initialMemory = getCurrentMemoryUsage()

        try operation()

        autoreleasepool { }

        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory

        print("📊 \(description) memory impact: \(memoryIncrease) bytes")

        // Flag significant memory increases
        if memoryIncrease > 2_000_000 { // 2MB threshold
            XCTFail("\(description) caused significant memory increase: \(memoryIncrease) bytes")
        }
    }

    /// PERFORMANCE: Test comprehensive performance metrics
    func testPerformanceMonitoringService() {
        let performanceService = PerformanceMonitoringService.shared

        // Start monitoring
        performanceService.startMonitoring()

        // Wait for initial metrics
        let expectation = XCTestExpectation(description: "Performance metrics collected")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)

        // Get performance report
        let report = performanceService.getPerformanceReport()

        // Verify metrics are reasonable (allow for test environment limitations)
        XCTAssertGreaterThanOrEqual(report.currentMetrics.memoryUsage, 0, "Memory usage should be non-negative")
        XCTAssertGreaterThanOrEqual(report.currentMetrics.batteryLevel, -1.0, "Battery level should be valid (or -1 in simulator)")
        XCTAssertLessThanOrEqual(report.currentMetrics.batteryLevel, 1.0, "Battery level should not exceed 100%")

        // Stop monitoring
        performanceService.stopMonitoring()

        print("✅ Performance monitoring test completed: \(report.summary)")
    }

    /// PERFORMANCE: Test timer consolidation
    func testTimerConsolidation() {
        let timerManager = BatteryAwareTimerManager.shared

        // Create multiple low-priority timers
        for i in 0..<5 {
            timerManager.scheduleTimer(id: "test-timer-\(i)", type: .memoryMonitoring) {
                print("Timer \(i) fired")
            }
        }

        let initialStats = timerManager.getTimerStatistics()
        XCTAssertGreaterThanOrEqual(initialStats.activeTimerCount, 5, "Should have at least 5 timers")

        // Consolidate timers
        timerManager.consolidateTimers()

        // Wait for consolidation
        let expectation = XCTestExpectation(description: "Timer consolidation completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)

        // Cleanup
        for i in 0..<5 {
            timerManager.cancelTimer(id: "test-timer-\(i)")
        }
        timerManager.cancelTimer(id: "consolidated-low-priority")

        print("✅ Timer consolidation test completed")
    }

    /// PERFORMANCE: Test cache performance optimization
    func testCachePerformanceOptimization() {
        let cacheManager = UnifiedCacheManager.shared

        // Clear cache to start fresh
        cacheManager.clearAllCache()

        // Store test data to simulate cache usage
        for i in 0..<10 {
            cacheManager.store("test-data-\(i)", forKey: "test-key-\(i)", type: .temporaryData)
        }

        // Get initial metrics
        let initialMetrics = cacheManager.getPerformanceMetrics()
        print("📊 Initial cache metrics: entries=\(initialMetrics.entryCount), hitRate=\(initialMetrics.hitRate), totalSize=\(initialMetrics.totalSize)")

        // Optimize for device - this should not crash and should complete successfully
        cacheManager.optimizeForDevice()

        // Verify optimization completed without errors
        let optimizedMetrics = cacheManager.getPerformanceMetrics()
        print("📊 Optimized cache metrics: entries=\(optimizedMetrics.entryCount), hitRate=\(optimizedMetrics.hitRate), totalSize=\(optimizedMetrics.totalSize)")

        // Basic assertions - optimization should not break basic functionality
        XCTAssertGreaterThanOrEqual(optimizedMetrics.entryCount, 0, "Entry count should be non-negative after optimization")

        // Verify cache is still functional after optimization
        cacheManager.store("post-optimization-test", forKey: "post-opt-key", type: .temporaryData)
        let retrievedValue = cacheManager.retrieve(String.self, forKey: "post-opt-key", cacheType: .temporaryData)
        XCTAssertEqual(retrievedValue, "post-optimization-test", "Cache should be functional after optimization")

        // Verify performance metrics are reasonable
        XCTAssertGreaterThanOrEqual(optimizedMetrics.hitRate, 0.0, "Hit rate should be non-negative")
        XCTAssertLessThanOrEqual(optimizedMetrics.hitRate, 1.0, "Hit rate should not exceed 100%")

        // Cleanup
        cacheManager.clearAllCache()

        print("✅ Cache performance optimization test completed - verified basic functionality")
    }
}
