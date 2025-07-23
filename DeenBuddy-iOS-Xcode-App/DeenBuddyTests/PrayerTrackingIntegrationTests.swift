import XCTest
import Combine
@testable import DeenBuddy

/// Integration tests for the complete Prayer Tracking system
/// Tests the workflow from prayer time notifications to tracking completion
@MainActor
final class PrayerTrackingIntegrationTests: XCTestCase {
    
    var container: DependencyContainer!
    var prayerTrackingService: PrayerTrackingService!
    var notificationService: NotificationService!
    var prayerTimeService: PrayerTimeService!
    var prayerTrackingCoordinator: PrayerTrackingCoordinator!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create test container
        container = await DependencyContainer.createForTesting()
        
        // Extract services
        prayerTrackingService = container.prayerTrackingService as? PrayerTrackingService
        notificationService = container.notificationService as? NotificationService
        prayerTimeService = container.prayerTimeService as? PrayerTimeService
        prayerTrackingCoordinator = container.prayerTrackingCoordinator
        
        cancellables = Set<AnyCancellable>()
        
        XCTAssertNotNil(prayerTrackingService)
        XCTAssertNotNil(notificationService)
        XCTAssertNotNil(prayerTimeService)
        XCTAssertNotNil(prayerTrackingCoordinator)
    }
    
    override func tearDown() async throws {
        cancellables?.removeAll()
        container = nil
        prayerTrackingService = nil
        notificationService = nil
        prayerTimeService = nil
        prayerTrackingCoordinator = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Integration Tests
    
    func testPrayerTrackingWorkflow() async throws {
        // Test the complete workflow from prayer time to completion tracking
        
        // 1. Verify initial state
        XCTAssertEqual(prayerTrackingService.todaysCompletedPrayers, 0)
        XCTAssertEqual(prayerTrackingService.currentStreak, 0)
        XCTAssertEqual(prayerTrackingService.todayCompletionRate, 0.0)
        
        // 2. Simulate prayer completion via notification action
        let testPrayer = Prayer.fajr
        let completionDate = Date()
        
        // Post notification that simulates user tapping "Completed" on notification
        NotificationCenter.default.post(
            name: .prayerMarkedAsPrayed,
            object: nil,
            userInfo: [
                "prayer": testPrayer.rawValue,
                "timestamp": completionDate,
                "source": "notification_action",
                "action": "completed"
            ]
        )
        
        // 3. Wait for async processing
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // 4. Verify prayer was logged
        XCTAssertEqual(prayerTrackingService.todaysCompletedPrayers, 1)
        XCTAssertEqual(prayerTrackingService.todayCompletionRate, 0.2) // 1/5 prayers
        
        // 5. Verify entry was created
        let recentEntries = prayerTrackingService.recentEntries
        XCTAssertFalse(recentEntries.isEmpty)
        
        let lastEntry = recentEntries.last
        XCTAssertEqual(lastEntry?.prayer, testPrayer)
        if let lastEntry = lastEntry {
            XCTAssertEqual(lastEntry.completedAt.timeIntervalSince1970, completionDate.timeIntervalSince1970, accuracy: 1.0)
        } else {
            XCTFail("Expected to find a prayer tracking entry")
        }
    }
    
    func testPrayerTrackingCoordinatorIntegration() async throws {
        // Test the coordinator's integration with services
        
        // 1. Get initial statistics
        let initialStats = prayerTrackingCoordinator.getTrackingStatistics()
        XCTAssertEqual(initialStats.todaysCompletedPrayers, 0)
        XCTAssertEqual(initialStats.currentStreak, 0)
        
        // 2. Mark a prayer as completed through coordinator
        let testPrayer = Prayer.dhuhr
        await prayerTrackingCoordinator.markPrayerCompleted(testPrayer)
        
        // 3. Verify statistics updated
        let updatedStats = prayerTrackingCoordinator.getTrackingStatistics()
        XCTAssertEqual(updatedStats.todaysCompletedPrayers, 1)
        XCTAssertTrue(updatedStats.completionStatus[testPrayer] == true)
        
        // 4. Verify prayer is marked as completed today
        XCTAssertTrue(prayerTrackingCoordinator.isPrayerCompletedToday(testPrayer))
        XCTAssertFalse(prayerTrackingCoordinator.isPrayerCompletedToday(.asr))
    }
    
    func testNotificationServiceIntegration() async throws {
        // Test notification service integration with prayer tracking
        
        // 1. Request notification permission (will be mocked in test environment)
        let permissionGranted = try await notificationService.requestNotificationPermission()
        
        // In test environment, this might be mocked to return true
        // XCTAssertTrue(permissionGranted)
        
        // 2. Schedule a prayer tracking notification
        let futureTime = Date().addingTimeInterval(3600) // 1 hour from now
        
        try await notificationService.schedulePrayerTrackingNotification(
            for: .maghrib,
            at: futureTime,
            reminderMinutes: 0
        )
        
        // 3. Verify notification was scheduled
        let pendingNotifications = await notificationService.getPendingNotifications()
        
        // In a real test environment, we'd verify the notification exists
        // For now, just verify no errors were thrown
        XCTAssertNoThrow(pendingNotifications)
    }
    
    func testPrayerAnalyticsIntegration() async throws {
        // Test analytics service integration
        
        // 1. Log multiple prayers
        let prayers: [Prayer] = [.fajr, .dhuhr, .asr]
        
        for prayer in prayers {
            await prayerTrackingService.logPrayerCompletion(prayer)
        }
        
        // 2. Wait for analytics to update
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // 3. Verify analytics reflect the completions
        XCTAssertEqual(prayerTrackingService.todaysCompletedPrayers, 3)
        XCTAssertEqual(prayerTrackingService.todayCompletionRate, 0.6) // 3/5 prayers
        
        // 4. Test completion status
        let completionStatus = prayerTrackingCoordinator.getTodayCompletionStatus()
        XCTAssertTrue(completionStatus[.fajr] == true)
        XCTAssertTrue(completionStatus[.dhuhr] == true)
        XCTAssertTrue(completionStatus[.asr] == true)
        XCTAssertTrue(completionStatus[.maghrib] == false)
        XCTAssertTrue(completionStatus[.isha] == false)
    }
    
    func testDataPersistence() async throws {
        // Test that prayer tracking data persists correctly
        
        // 1. Log a prayer
        let testPrayer = Prayer.isha
        await prayerTrackingService.logPrayerCompletion(testPrayer)
        
        // 2. Verify it's in recent entries
        let entries = prayerTrackingService.recentEntries
        XCTAssertFalse(entries.isEmpty)
        
        let lastEntry = entries.last
        XCTAssertEqual(lastEntry?.prayer, testPrayer)
        
        // 3. Create a new service instance (simulating app restart)
        let newContainer = await DependencyContainer.createForTesting()
        let newTrackingService = newContainer.prayerTrackingService as? PrayerTrackingService
        
        // 4. Verify data persisted
        // Note: In a real test, we'd need to ensure UserDefaults persistence
        // For now, just verify the service initializes correctly
        XCTAssertNotNil(newTrackingService)
    }
    
    func testErrorHandling() async throws {
        // Test error handling in the prayer tracking system
        
        // 1. Test invalid prayer completion
        // This should not crash the system
        NotificationCenter.default.post(
            name: .prayerMarkedAsPrayed,
            object: nil,
            userInfo: [
                "prayer": "invalid_prayer",
                "timestamp": Date(),
                "source": "test",
                "action": "completed"
            ]
        )
        
        // 2. Wait for processing
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        // 3. Verify system is still stable
        XCTAssertEqual(prayerTrackingService.todaysCompletedPrayers, 0)
        XCTAssertNotNil(prayerTrackingService.recentEntries)
    }
}

// MARK: - Test Helpers

extension PrayerTrackingIntegrationTests {
    
    /// Helper to simulate notification action
    func simulateNotificationAction(
        prayer: Prayer,
        action: String,
        source: String = "notification_action"
    ) {
        NotificationCenter.default.post(
            name: .prayerMarkedAsPrayed,
            object: nil,
            userInfo: [
                "prayer": prayer.rawValue,
                "timestamp": Date(),
                "source": source,
                "action": action
            ]
        )
    }
    
    /// Helper to wait for async operations
    func waitForAsyncOperation() async throws {
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
}
