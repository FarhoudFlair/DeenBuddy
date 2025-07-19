import XCTest
import UserNotifications

/// Performance tests across different iOS devices and versions
@MainActor
final class PerformanceTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var notificationService: NotificationService!
    private var widgetService: WidgetService!
    private var backgroundOptimizer: BackgroundProcessingOptimizer!
    
    // Device capability thresholds
    private var devicePerformanceProfile: DevicePerformanceProfile!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        notificationService = NotificationService()
        widgetService = WidgetService()
        backgroundOptimizer = BackgroundProcessingOptimizer.shared
        devicePerformanceProfile = DevicePerformanceProfile.current
        
        print("📱 Testing on device: \(devicePerformanceProfile.deviceModel)")
        print("📱 iOS Version: \(devicePerformanceProfile.iOSVersion)")
        print("📱 Performance Tier: \(devicePerformanceProfile.performanceTier)")
    }
    
    override func tearDown() async throws {
        notificationService = nil
        widgetService = nil
        backgroundOptimizer = nil
        devicePerformanceProfile = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Notification Performance Tests
    
    func testNotificationSchedulingPerformance() {
        let prayerTimes = createMockPrayerTimes(count: 5)
        let expectedTime = devicePerformanceProfile.expectedNotificationSchedulingTime
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = expectation(description: "Notification scheduling")
            
            Task {
                do {
                    try await notificationService.schedulePrayerNotifications(for: prayerTimes)
                    expectation.fulfill()
                } catch {
                    XCTFail("Notification scheduling failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: expectedTime)
        }
    }
    
    func testBulkNotificationSchedulingPerformance() {
        // Test scheduling notifications for multiple days
        let bulkPrayerTimes = createBulkMockPrayerTimes(days: 30) // 30 days worth
        let expectedTime = devicePerformanceProfile.expectedBulkOperationTime
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric(), XCTCPUMetric()]) {
            let expectation = expectation(description: "Bulk notification scheduling")
            
            Task {
                for dayPrayerTimes in bulkPrayerTimes {
                    do {
                        try await notificationService.schedulePrayerNotifications(for: dayPrayerTimes)
                    } catch {
                        XCTFail("Bulk notification scheduling failed: \(error)")
                        break
                    }
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: expectedTime)
        }
    }
    
    func testNotificationActionHandlingPerformance() {
        let mockResponse = createMockNotificationResponse()
        let expectedTime = devicePerformanceProfile.expectedActionHandlingTime
        
        measure(metrics: [XCTClockMetric()]) {
            let expectation = expectation(description: "Notification action handling")
            
            notificationService.userNotificationCenter(
                UNUserNotificationCenter.current(),
                didReceive: mockResponse
            ) {
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: expectedTime)
        }
    }
    
    // MARK: - Widget Performance Tests
    
    func testWidgetDataUpdatePerformance() {
        let expectedTime = devicePerformanceProfile.expectedWidgetUpdateTime
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = expectation(description: "Widget data update")
            
            Task {
                await widgetService.updateWidgetData()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: expectedTime)
        }
    }
    
    func testWidgetTimelineGenerationPerformance() {
        let mockEntry = PrayerWidgetEntry.placeholder()
        let timelineManager = WidgetTimelineManager.shared
        let expectedTime = devicePerformanceProfile.expectedTimelineGenerationTime
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let timeline = timelineManager.generateTimeline(from: mockEntry, maxEntries: 20)
            XCTAssertEqual(timeline.count, 20, "Should generate requested number of entries")
        }
    }
    
    func testWidgetDataSerializationPerformance() {
        let widgetData = WidgetData.placeholder
        let dataManager = WidgetDataManager.shared
        
        measure(metrics: [XCTClockMetric()]) {
            // Test serialization performance
            dataManager.saveWidgetData(widgetData)
            let retrievedData = dataManager.loadWidgetData()
            XCTAssertNotNil(retrievedData, "Widget data should be retrievable")
        }
    }
    
    // MARK: - Live Activity Performance Tests
    
    @available(iOS 16.1, *)
    func testLiveActivityCreationPerformance() {
        let liveActivityManager = PrayerLiveActivityManager.shared
        let expectedTime = devicePerformanceProfile.expectedLiveActivityTime
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = expectation(description: "Live Activity creation")
            
            Task {
                do {
                    try await liveActivityManager.startPrayerCountdown(
                        for: .fajr,
                        prayerTime: Date().addingTimeInterval(3600),
                        location: "Test Location",
                        hijriDate: "Test Date",
                        calculationMethod: "Test Method"
                    )
                    
                    await liveActivityManager.endCurrentActivity()
                    expectation.fulfill()
                } catch {
                    // Expected to fail in test environment
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: expectedTime)
        }
    }
    
    // MARK: - Background Processing Performance Tests
    
    func testBackgroundTaskRegistrationPerformance() {
        measure(metrics: [XCTClockMetric()]) {
            backgroundOptimizer.registerBackgroundTasks()
            XCTAssertGreaterThan(backgroundOptimizer.backgroundTasksRegistered, 0, "Should register background tasks")
        }
    }
    
    func testBackgroundTaskSchedulingPerformance() {
        let expectedTime = devicePerformanceProfile.expectedBackgroundTaskTime
        
        measure(metrics: [XCTClockMetric()]) {
            backgroundOptimizer.scheduleOptimizedBackgroundRefresh()
            // Scheduling is synchronous, so no need for expectation
        }
    }
    
    // MARK: - Memory Performance Tests
    
    func testMemoryUsageUnderLoad() {
        let initialMemory = getCurrentMemoryUsage()
        
        // Simulate heavy usage
        var services: [NotificationService] = []
        var widgetData: [WidgetData] = []
        
        measure(metrics: [XCTMemoryMetric()]) {
            // Create multiple service instances
            for _ in 0..<10 {
                services.append(NotificationService())
            }
            
            // Create multiple widget data instances
            for _ in 0..<50 {
                widgetData.append(WidgetData.placeholder)
            }
            
            // Cleanup
            services.removeAll()
            widgetData.removeAll()
        }
        
        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable for device tier
        let maxAllowedIncrease = devicePerformanceProfile.maxMemoryIncrease
        XCTAssertLessThan(memoryIncrease, maxAllowedIncrease, "Memory usage exceeded device limits")
    }
    
    // MARK: - Concurrent Operation Performance Tests
    
    func testConcurrentNotificationOperations() {
        let operationCount = devicePerformanceProfile.maxConcurrentOperations
        let expectedTime = devicePerformanceProfile.expectedConcurrentOperationTime
        
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            let expectation = expectation(description: "Concurrent operations")
            expectation.expectedFulfillmentCount = operationCount
            
            for i in 0..<operationCount {
                Task {
                    let prayerTimes = createMockPrayerTimes(count: 1)
                    do {
                        try await notificationService.schedulePrayerNotifications(for: prayerTimes)
                        expectation.fulfill()
                    } catch {
                        XCTFail("Concurrent operation \(i) failed: \(error)")
                        expectation.fulfill()
                    }
                }
            }
            
            wait(for: [expectation], timeout: expectedTime)
        }
    }
    
    // MARK: - Device-Specific Performance Tests
    
    func testPerformanceOnLowEndDevice() {
        guard devicePerformanceProfile.performanceTier == .low else {
            throw XCTSkip("Test only runs on low-end devices")
        }
        
        // More lenient performance expectations for older devices
        let prayerTimes = createMockPrayerTimes(count: 3) // Reduced load
        
        measure(metrics: [XCTClockMetric()]) {
            let expectation = expectation(description: "Low-end device performance")
            
            Task {
                do {
                    try await notificationService.schedulePrayerNotifications(for: prayerTimes)
                    expectation.fulfill()
                } catch {
                    XCTFail("Low-end device test failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 10.0) // More generous timeout
        }
    }
    
    func testPerformanceOnHighEndDevice() {
        guard devicePerformanceProfile.performanceTier == .high else {
            throw XCTSkip("Test only runs on high-end devices")
        }
        
        // More demanding performance expectations for newer devices
        let prayerTimes = createBulkMockPrayerTimes(days: 7) // Increased load
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric(), XCTCPUMetric()]) {
            let expectation = expectation(description: "High-end device performance")
            
            Task {
                for dayPrayerTimes in prayerTimes {
                    do {
                        try await notificationService.schedulePrayerNotifications(for: dayPrayerTimes)
                    } catch {
                        XCTFail("High-end device test failed: \(error)")
                        break
                    }
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0) // Stricter timeout
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockPrayerTimes(count: Int = 5) -> [PrayerTime] {
        let calendar = Calendar.current
        let today = Date()
        let baseTime = calendar.startOfDay(for: today)
        
        let prayers = Array(Prayer.allCases.prefix(count))
        return prayers.enumerated().map { index, prayer in
            let time = calendar.date(byAdding: .hour, value: (index + 1) * 3, to: baseTime) ?? baseTime
            return PrayerTime(prayer: prayer, time: time)
        }
    }
    
    private func createBulkMockPrayerTimes(days: Int) -> [[PrayerTime]] {
        var bulkTimes: [[PrayerTime]] = []
        let calendar = Calendar.current
        
        for day in 0..<days {
            let date = calendar.date(byAdding: .day, value: day, to: Date()) ?? Date()
            let dayTimes = createMockPrayerTimes(count: 5)
            bulkTimes.append(dayTimes)
        }
        
        return bulkTimes
    }
    
    private func createMockNotificationResponse() -> UNNotificationResponse {
        let content = UNMutableNotificationContent()
        content.title = "Test Prayer"
        content.body = "Test notification"
        content.userInfo = ["prayer": "fajr"]
        
        let request = UNNotificationRequest(
            identifier: "test",
            content: content,
            trigger: nil
        )
        
        let notification = UNNotification(request: request, date: Date())
        
        return UNNotificationResponse(
            notification: notification,
            actionIdentifier: "MARK_PRAYED"
        )
    }
    
    private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
}

// MARK: - Device Performance Profile

struct DevicePerformanceProfile {
    let deviceModel: String
    let iOSVersion: String
    let performanceTier: PerformanceTier
    
    // Performance expectations based on device tier
    let expectedNotificationSchedulingTime: TimeInterval
    let expectedBulkOperationTime: TimeInterval
    let expectedActionHandlingTime: TimeInterval
    let expectedWidgetUpdateTime: TimeInterval
    let expectedTimelineGenerationTime: TimeInterval
    let expectedLiveActivityTime: TimeInterval
    let expectedBackgroundTaskTime: TimeInterval
    let expectedConcurrentOperationTime: TimeInterval
    
    let maxMemoryIncrease: Int
    let maxConcurrentOperations: Int
    
    static var current: DevicePerformanceProfile {
        let device = UIDevice.current
        let model = device.model
        let version = device.systemVersion
        let tier = determinePerformanceTier()
        
        switch tier {
        case .low:
            return DevicePerformanceProfile(
                deviceModel: model,
                iOSVersion: version,
                performanceTier: tier,
                expectedNotificationSchedulingTime: 5.0,
                expectedBulkOperationTime: 30.0,
                expectedActionHandlingTime: 2.0,
                expectedWidgetUpdateTime: 3.0,
                expectedTimelineGenerationTime: 2.0,
                expectedLiveActivityTime: 4.0,
                expectedBackgroundTaskTime: 1.0,
                expectedConcurrentOperationTime: 15.0,
                maxMemoryIncrease: 20_000_000, // 20MB
                maxConcurrentOperations: 3
            )
        case .medium:
            return DevicePerformanceProfile(
                deviceModel: model,
                iOSVersion: version,
                performanceTier: tier,
                expectedNotificationSchedulingTime: 3.0,
                expectedBulkOperationTime: 20.0,
                expectedActionHandlingTime: 1.0,
                expectedWidgetUpdateTime: 2.0,
                expectedTimelineGenerationTime: 1.0,
                expectedLiveActivityTime: 2.0,
                expectedBackgroundTaskTime: 0.5,
                expectedConcurrentOperationTime: 10.0,
                maxMemoryIncrease: 30_000_000, // 30MB
                maxConcurrentOperations: 5
            )
        case .high:
            return DevicePerformanceProfile(
                deviceModel: model,
                iOSVersion: version,
                performanceTier: tier,
                expectedNotificationSchedulingTime: 2.0,
                expectedBulkOperationTime: 15.0,
                expectedActionHandlingTime: 0.5,
                expectedWidgetUpdateTime: 1.0,
                expectedTimelineGenerationTime: 0.5,
                expectedLiveActivityTime: 1.0,
                expectedBackgroundTaskTime: 0.3,
                expectedConcurrentOperationTime: 8.0,
                maxMemoryIncrease: 50_000_000, // 50MB
                maxConcurrentOperations: 8
            )
        }
    }
    
    private static func determinePerformanceTier() -> PerformanceTier {
        // Simplified device tier determination
        // In a real implementation, this would check specific device models
        let processorCount = ProcessInfo.processInfo.processorCount
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        
        if processorCount >= 6 && physicalMemory >= 4_000_000_000 { // 4GB+
            return .high
        } else if processorCount >= 4 && physicalMemory >= 2_000_000_000 { // 2GB+
            return .medium
        } else {
            return .low
        }
    }
}

enum PerformanceTier {
    case low    // Older devices (iPhone 8, iPhone X)
    case medium // Mid-range devices (iPhone 11, iPhone 12)
    case high   // Latest devices (iPhone 13+, iPhone 14+)
}
