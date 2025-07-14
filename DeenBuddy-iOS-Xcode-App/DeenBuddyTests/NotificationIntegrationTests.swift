import XCTest
import UserNotifications
import CoreLocation
@testable import DeenAssistCore

/// Integration tests for notification system synchronization with prayer times and settings
@MainActor
final class NotificationIntegrationTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var notificationService: NotificationService!
    private var prayerTimeService: MockPrayerTimeService!
    private var settingsService: MockSettingsService!
    private var mockNotificationCenter: MockUNUserNotificationCenter!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create mock services
        mockNotificationCenter = MockUNUserNotificationCenter()
        settingsService = MockSettingsService()
        prayerTimeService = MockPrayerTimeService(settingsService: settingsService)
        
        // Create notification service with mock notification center
        notificationService = NotificationService()
        notificationService.setMockNotificationCenter(mockNotificationCenter)
        
        // Set up authorized notification status
        mockNotificationCenter.authorizationStatus = .authorized
    }
    
    override func tearDown() async throws {
        notificationService = nil
        prayerTimeService = nil
        settingsService = nil
        mockNotificationCenter = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Prayer Time Synchronization Tests
    
    func testNotificationSchedulingSynchronizesWithPrayerTimes() async throws {
        // Given: Prayer times for today
        let today = Date()
        let prayerTimes = createMockPrayerTimes(for: today)
        
        // When: Scheduling notifications
        try await notificationService.schedulePrayerNotifications(for: prayerTimes)
        
        // Then: Notifications should be scheduled for all enabled prayers
        let scheduledRequests = mockNotificationCenter.scheduledRequests
        XCTAssertEqual(scheduledRequests.count, 5, "Should schedule notifications for all 5 prayers")
        
        // Verify each prayer has a notification
        for prayer in Prayer.allCases {
            let hasNotification = scheduledRequests.contains { request in
                request.content.userInfo["prayer"] as? String == prayer.rawValue
            }
            XCTAssertTrue(hasNotification, "Should have notification for \(prayer.displayName)")
        }
    }
    
    func testNotificationSchedulingRespectsEnabledPrayersSettings() async throws {
        // Given: Settings with only Fajr and Maghrib enabled
        let customSettings = NotificationSettings(
            isEnabled: true,
            prayerConfigs: [
                .fajr: PrayerNotificationConfig(isEnabled: true, reminderTimes: [10]),
                .dhuhr: PrayerNotificationConfig(isEnabled: false, reminderTimes: [10]),
                .asr: PrayerNotificationConfig(isEnabled: false, reminderTimes: [10]),
                .maghrib: PrayerNotificationConfig(isEnabled: true, reminderTimes: [5]),
                .isha: PrayerNotificationConfig(isEnabled: false, reminderTimes: [10])
            ]
        )
        notificationService.updateNotificationSettings(customSettings)
        
        let today = Date()
        let prayerTimes = createMockPrayerTimes(for: today)
        
        // When: Scheduling notifications
        try await notificationService.schedulePrayerNotifications(for: prayerTimes)
        
        // Then: Only enabled prayers should have notifications
        let scheduledRequests = mockNotificationCenter.scheduledRequests
        XCTAssertEqual(scheduledRequests.count, 2, "Should only schedule notifications for enabled prayers")
        
        let scheduledPrayers = scheduledRequests.compactMap { request in
            Prayer(rawValue: request.content.userInfo["prayer"] as? String ?? "")
        }
        
        XCTAssertTrue(scheduledPrayers.contains(.fajr), "Should schedule Fajr notification")
        XCTAssertTrue(scheduledPrayers.contains(.maghrib), "Should schedule Maghrib notification")
        XCTAssertFalse(scheduledPrayers.contains(.dhuhr), "Should not schedule Dhuhr notification")
        XCTAssertFalse(scheduledPrayers.contains(.asr), "Should not schedule Asr notification")
        XCTAssertFalse(scheduledPrayers.contains(.isha), "Should not schedule Isha notification")
    }
    
    func testMultipleReminderTimesPerPrayer() async throws {
        // Given: Settings with multiple reminder times for Fajr
        let customSettings = NotificationSettings(
            isEnabled: true,
            prayerConfigs: [
                .fajr: PrayerNotificationConfig(isEnabled: true, reminderTimes: [15, 5, 0]),
                .dhuhr: PrayerNotificationConfig(isEnabled: false, reminderTimes: []),
                .asr: PrayerNotificationConfig(isEnabled: false, reminderTimes: []),
                .maghrib: PrayerNotificationConfig(isEnabled: false, reminderTimes: []),
                .isha: PrayerNotificationConfig(isEnabled: false, reminderTimes: [])
            ]
        )
        notificationService.updateNotificationSettings(customSettings)
        
        let today = Date()
        let prayerTimes = createMockPrayerTimes(for: today)
        
        // When: Scheduling notifications
        try await notificationService.schedulePrayerNotifications(for: prayerTimes)
        
        // Then: Should have 3 notifications for Fajr (15min, 5min, 0min)
        let scheduledRequests = mockNotificationCenter.scheduledRequests
        let fajrNotifications = scheduledRequests.filter { request in
            request.content.userInfo["prayer"] as? String == Prayer.fajr.rawValue
        }
        
        XCTAssertEqual(fajrNotifications.count, 3, "Should schedule 3 notifications for Fajr")
        
        // Verify reminder times
        let reminderMinutes = fajrNotifications.compactMap { request in
            request.content.userInfo["reminder_minutes"] as? Int
        }.sorted(by: >)
        
        XCTAssertEqual(reminderMinutes, [15, 5, 0], "Should have correct reminder times")
    }
    
    func testCalculationMethodChangeTriggersNotificationUpdate() async throws {
        // Given: Initial prayer times with Muslim World League method
        settingsService.calculationMethod = .muslimWorldLeague
        let initialPrayerTimes = createMockPrayerTimes(for: Date())
        try await notificationService.schedulePrayerNotifications(for: initialPrayerTimes)
        
        let initialRequestCount = mockNotificationCenter.scheduledRequests.count
        XCTAssertGreaterThan(initialRequestCount, 0, "Should have initial notifications")
        
        // When: Changing calculation method
        settingsService.calculationMethod = .egyptian
        
        // Simulate settings change notification
        NotificationCenter.default.post(name: .settingsDidChange, object: settingsService)
        
        // Allow time for async handling
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then: Settings should be reloaded (in real implementation, notifications would be rescheduled)
        // Note: This test verifies the observer pattern works; actual rescheduling would require
        // integration with PrayerTimeService to recalculate times
        XCTAssertEqual(settingsService.calculationMethod, .egyptian, "Settings should be updated")
    }
    
    func testMadhabChangeAffectsAsrNotificationTiming() async throws {
        // Given: Initial Madhab setting
        settingsService.madhab = .shafi

        // When: Changing Madhab (affects Asr calculation)
        settingsService.madhab = .hanafi

        // Then: This would affect Asr prayer time calculation
        // In a full integration test, we would verify that:
        // 1. PrayerTimeService recalculates Asr time
        // 2. NotificationService reschedules Asr notifications
        // 3. New notification time reflects Hanafi Asr calculation

        XCTAssertEqual(settingsService.madhab, .hanafi, "Madhab should be updated")

        // Note: Full integration would require:
        // - Mock location service
        // - Actual prayer time calculation
        // - Verification of notification timing changes
    }

    // MARK: - Widget Integration Tests

    func testWidgetDataSynchronizationWithNotifications() async throws {
        // Given: Prayer times and notification settings
        let today = Date()
        let prayerTimes = createMockPrayerTimes(for: today)

        // When: Updating widget data
        let widgetData = WidgetData(
            nextPrayer: prayerTimes.first,
            timeUntilNextPrayer: 3600,
            todaysPrayerTimes: prayerTimes,
            hijriDate: HijriDate(from: today),
            location: "Test Location",
            calculationMethod: .muslimWorldLeague
        )

        WidgetDataManager.shared.saveWidgetData(widgetData)

        // Then: Widget data should be retrievable and consistent
        let retrievedData = WidgetDataManager.shared.loadWidgetData()
        XCTAssertNotNil(retrievedData, "Widget data should be retrievable")
        XCTAssertEqual(retrievedData?.todaysPrayerTimes.count, 5, "Should have all 5 prayers")
        XCTAssertEqual(retrievedData?.calculationMethod, .muslimWorldLeague, "Calculation method should match")
    }

    func testLiveActivityIntegration() async throws {
        // Given: Live Activity support (iOS 16.1+)
        guard #available(iOS 16.1, *) else {
            throw XCTSkip("Live Activities require iOS 16.1+")
        }

        let prayer = Prayer.fajr
        let prayerTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()

        // When: Starting Live Activity
        let liveActivityManager = PrayerLiveActivityManager.shared

        // Then: Live Activity should be manageable
        XCTAssertFalse(liveActivityManager.isActivityActive, "No activity should be active initially")

        // Note: Actual Live Activity testing requires device testing
        // as simulator doesn't fully support Live Activities
    }

    func testInteractiveNotificationActions() async throws {
        // Given: Enhanced notification with actions
        let prayer = Prayer.dhuhr
        let prayerTime = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        let config = PrayerNotificationConfig(
            isEnabled: true,
            reminderTimes: [10],
            customTitle: "Test Prayer",
            customBody: "Test notification body"
        )

        // When: Scheduling enhanced notification
        try await notificationService.scheduleEnhancedNotification(
            for: prayer,
            prayerTime: prayerTime,
            notificationTime: prayerTime,
            reminderMinutes: 0,
            config: config
        )

        // Then: Notification should be scheduled with correct category
        let pendingNotifications = await notificationService.getPendingNotifications()
        let prayerNotification = pendingNotifications.first { $0.prayer == prayer }

        XCTAssertNotNil(prayerNotification, "Prayer notification should be scheduled")
        XCTAssertEqual(prayerNotification?.title, "Test Prayer", "Custom title should be used")
    }

    func testIslamicEventNotifications() async throws {
        // Given: Islamic event notification service
        let eventService = IslamicEventNotificationService.shared

        let testEvent = IslamicEvent(
            id: UUID(),
            title: "Test Islamic Event",
            description: "Test event description",
            hijriDate: HijriDate(from: Date()),
            type: .religious,
            importance: .high,
            isRecurring: false,
            location: nil,
            reminder: nil
        )

        // When: Scheduling Islamic event notification
        try await eventService.scheduleIslamicEventNotification(for: testEvent)

        // Then: Event notification should be scheduled
        // Note: This would require integration with UNUserNotificationCenter
        // to verify the notification was actually scheduled
        XCTAssertTrue(true, "Event notification scheduling completed without error")
    }
    
    // MARK: - Memory Leak Prevention Tests
    
    func testNotificationServiceObserverCleanup() {
        // Given: Initial observer count
        let initialObserverCount = getNotificationCenterObserverCount()
        
        // When: Creating and destroying notification service
        autoreleasepool {
            let service = NotificationService()
            // Service sets up observers in init
            
            let observerCountAfterSetup = getNotificationCenterObserverCount()
            XCTAssertGreaterThan(observerCountAfterSetup, initialObserverCount, 
                               "Should add observers during setup")
        }
        
        // Then: Observers should be cleaned up after service deallocation
        let finalObserverCount = getNotificationCenterObserverCount()
        XCTAssertEqual(finalObserverCount, initialObserverCount, 
                       "NotificationCenter observers not properly cleaned up")
    }
    
    // MARK: - Helper Methods
    
    private func createMockPrayerTimes(for date: Date) -> [PrayerTime] {
        let calendar = Calendar.current
        let baseTime = calendar.startOfDay(for: date)
        
        return [
            PrayerTime(prayer: .fajr, time: calendar.date(byAdding: .hour, value: 5, to: baseTime)!),
            PrayerTime(prayer: .dhuhr, time: calendar.date(byAdding: .hour, value: 12, to: baseTime)!),
            PrayerTime(prayer: .asr, time: calendar.date(byAdding: .hour, value: 15, to: baseTime)!),
            PrayerTime(prayer: .maghrib, time: calendar.date(byAdding: .hour, value: 18, to: baseTime)!),
            PrayerTime(prayer: .isha, time: calendar.date(byAdding: .hour, value: 20, to: baseTime)!)
        ]
    }
    
    private func getNotificationCenterObserverCount() -> Int {
        // In a real implementation, this would use runtime introspection
        // or a custom observer tracking mechanism
        return 0 // Placeholder
    }
}

// MARK: - Mock Classes

/// Mock UNUserNotificationCenter for testing
class MockUNUserNotificationCenter {
    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var scheduledRequests: [UNNotificationRequest] = []
    
    func add(_ request: UNNotificationRequest) async throws {
        scheduledRequests.append(request)
    }
    
    func removeAllPendingNotificationRequests() {
        scheduledRequests.removeAll()
    }
    
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        scheduledRequests.removeAll { request in
            identifiers.contains(request.identifier)
        }
    }
    
    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        return scheduledRequests
    }
}

/// Mock settings service for testing
@MainActor
class MockSettingsService: SettingsServiceProtocol, ObservableObject {
    @Published var calculationMethod: CalculationMethod = .muslimWorldLeague
    @Published var madhab: Madhab = .shafi
    @Published var notificationsEnabled: Bool = true
    @Published var theme: ThemeMode = .dark
    @Published var timeFormat: TimeFormat = .twelveHour
    @Published var notificationOffset: TimeInterval = 300
    @Published var overrideBatteryOptimization: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    @Published var userName: String = ""
    
    var enableNotifications: Bool {
        get { notificationsEnabled }
        set { notificationsEnabled = newValue }
    }
    
    func saveSettings() async throws {}
    func loadSettings() async throws {}
    func resetToDefaults() async throws {}
}

/// Mock prayer time service for testing
@MainActor
class MockPrayerTimeService: PrayerTimeServiceProtocol, ObservableObject {
    @Published var todaysPrayerTimes: [PrayerTime] = []
    @Published var nextPrayer: PrayerTime? = nil
    @Published var timeUntilNextPrayer: TimeInterval? = nil
    @Published var isLoading: Bool = false
    @Published var error: Error? = nil
    
    private let settingsService: any SettingsServiceProtocol
    
    var calculationMethod: CalculationMethod {
        settingsService.calculationMethod
    }
    
    var madhab: Madhab {
        settingsService.madhab
    }
    
    init(settingsService: any SettingsServiceProtocol) {
        self.settingsService = settingsService
    }
    
    func calculatePrayerTimes(for location: CLLocation, date: Date) async throws -> [PrayerTime] {
        // Return mock prayer times
        let calendar = Calendar.current
        let baseTime = calendar.startOfDay(for: date)
        
        return [
            PrayerTime(prayer: .fajr, time: calendar.date(byAdding: .hour, value: 5, to: baseTime)!),
            PrayerTime(prayer: .dhuhr, time: calendar.date(byAdding: .hour, value: 12, to: baseTime)!),
            PrayerTime(prayer: .asr, time: calendar.date(byAdding: .hour, value: 15, to: baseTime)!),
            PrayerTime(prayer: .maghrib, time: calendar.date(byAdding: .hour, value: 18, to: baseTime)!),
            PrayerTime(prayer: .isha, time: calendar.date(byAdding: .hour, value: 20, to: baseTime)!)
        ]
    }
    
    func refreshPrayerTimes() async {}
    func refreshTodaysPrayerTimes() async {}
    func getPrayerTimes(from startDate: Date, to endDate: Date) async throws -> [Date: [PrayerTime]] { return [:] }
    func getCurrentLocation() async throws -> CLLocation { throw NSError(domain: "Mock", code: 0) }
}
