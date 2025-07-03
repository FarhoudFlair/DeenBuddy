import XCTest
import Combine
@testable import DeenAssistCore

final class NotificationServiceTests: XCTestCase {
    var mockNotificationService: MockNotificationService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockNotificationService = MockNotificationService()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        mockNotificationService = nil
        super.tearDown()
    }
    
    // MARK: - Permission Tests
    
    func testRequestNotificationPermission_Success() async {
        // Given
        mockNotificationService.setMockPermissionStatus(.authorized)
        
        // When
        let status = await mockNotificationService.requestNotificationPermission()
        
        // Then
        XCTAssertEqual(status, .authorized)
        XCTAssertEqual(mockNotificationService.permissionStatus, .authorized)
    }
    
    func testRequestNotificationPermission_Denied() async {
        // Given
        mockNotificationService.setMockPermissionStatus(.denied)
        
        // When
        let status = await mockNotificationService.requestNotificationPermission()
        
        // Then
        XCTAssertEqual(status, .denied)
        XCTAssertEqual(mockNotificationService.permissionStatus, .denied)
    }
    
    // MARK: - Prayer Notification Scheduling Tests
    
    func testSchedulePrayerNotifications_Success() async throws {
        // Given
        mockNotificationService.setMockPermissionStatus(.authorized)
        let prayerTimes = createMockPrayerTimes()
        
        // When
        try await mockNotificationService.schedulePrayerNotifications(for: prayerTimes)
        
        // Then
        let pendingNotifications = await mockNotificationService.getPendingNotifications()
        XCTAssertFalse(pendingNotifications.isEmpty)
        
        // Verify all prayers are scheduled
        let scheduledPrayers = Set(pendingNotifications.map { $0.prayer })
        XCTAssertEqual(scheduledPrayers.count, Prayer.allCases.count)
    }
    
    func testSchedulePrayerNotifications_PermissionDenied() async {
        // Given
        mockNotificationService.setMockPermissionStatus(.denied)
        let prayerTimes = createMockPrayerTimes()
        
        // When/Then
        do {
            try await mockNotificationService.schedulePrayerNotifications(for: prayerTimes)
            XCTFail("Expected NotificationError.permissionDenied")
        } catch NotificationError.permissionDenied {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSchedulePrayerNotifications_NotificationsDisabled() async throws {
        // Given
        mockNotificationService.setMockPermissionStatus(.authorized)
        mockNotificationService.isNotificationsEnabled = false
        let prayerTimes = createMockPrayerTimes()
        
        // When
        try await mockNotificationService.schedulePrayerNotifications(for: prayerTimes)
        
        // Then
        let pendingNotifications = await mockNotificationService.getPendingNotifications()
        XCTAssertTrue(pendingNotifications.isEmpty)
    }
    
    func testSchedulePrayerNotifications_SchedulingError() async {
        // Given
        mockNotificationService.setMockPermissionStatus(.authorized)
        mockNotificationService.simulateSchedulingError(.schedulingFailed)
        let prayerTimes = createMockPrayerTimes()
        
        // When/Then
        do {
            try await mockNotificationService.schedulePrayerNotifications(for: prayerTimes)
            XCTFail("Expected NotificationError.schedulingFailed")
        } catch NotificationError.schedulingFailed {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Individual Notification Tests
    
    func testScheduleNotification_Success() async throws {
        // Given
        mockNotificationService.setMockPermissionStatus(.authorized)
        let futureTime = Date().addingTimeInterval(3600) // 1 hour from now
        
        // When
        try await mockNotificationService.scheduleNotification(
            for: .fajr,
            at: futureTime,
            title: "Test Title",
            body: "Test Body"
        )
        
        // Then
        let isScheduled = await mockNotificationService.isNotificationScheduled(for: .fajr, date: futureTime)
        XCTAssertTrue(isScheduled)
    }
    
    func testScheduleNotification_InvalidDate() async {
        // Given
        mockNotificationService.setMockPermissionStatus(.authorized)
        let pastTime = Date().addingTimeInterval(-3600) // 1 hour ago
        
        // When/Then
        do {
            try await mockNotificationService.scheduleNotification(
                for: .fajr,
                at: pastTime,
                title: "Test Title",
                body: "Test Body"
            )
            XCTFail("Expected NotificationError.invalidDate")
        } catch NotificationError.invalidDate {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Notification Management Tests
    
    func testCancelAllPrayerNotifications() async throws {
        // Given
        mockNotificationService.setMockPermissionStatus(.authorized)
        let prayerTimes = createMockPrayerTimes()
        try await mockNotificationService.schedulePrayerNotifications(for: prayerTimes)
        
        // When
        mockNotificationService.cancelAllPrayerNotifications()
        
        // Then
        let pendingNotifications = await mockNotificationService.getPendingNotifications()
        XCTAssertTrue(pendingNotifications.isEmpty)
    }
    
    func testCancelNotification() async throws {
        // Given
        mockNotificationService.setMockPermissionStatus(.authorized)
        let futureTime = Date().addingTimeInterval(3600)
        try await mockNotificationService.scheduleNotification(
            for: .fajr,
            at: futureTime,
            title: "Test",
            body: "Test"
        )
        
        // When
        mockNotificationService.cancelNotification(for: .fajr, date: futureTime)
        
        // Then
        let isScheduled = await mockNotificationService.isNotificationScheduled(for: .fajr, date: futureTime)
        XCTAssertFalse(isScheduled)
    }
    
    // MARK: - Notification Settings Tests
    
    func testUpdateNotificationSettings() {
        // Given
        let newSettings = NotificationSettings(
            isEnabled: false,
            reminderMinutes: 15,
            enabledPrayers: [.fajr, .maghrib],
            soundEnabled: false,
            badgeEnabled: false,
            customMessage: "Custom reminder message"
        )
        
        // When
        mockNotificationService.updateNotificationSettings(newSettings)
        
        // Then
        let retrievedSettings = mockNotificationService.getNotificationSettings()
        XCTAssertEqual(retrievedSettings.isEnabled, newSettings.isEnabled)
        XCTAssertEqual(retrievedSettings.reminderMinutes, newSettings.reminderMinutes)
        XCTAssertEqual(retrievedSettings.enabledPrayers, newSettings.enabledPrayers)
        XCTAssertEqual(retrievedSettings.soundEnabled, newSettings.soundEnabled)
        XCTAssertEqual(retrievedSettings.badgeEnabled, newSettings.badgeEnabled)
        XCTAssertEqual(retrievedSettings.customMessage, newSettings.customMessage)
        XCTAssertEqual(mockNotificationService.isNotificationsEnabled, newSettings.isEnabled)
    }
    
    func testDefaultNotificationSettings() {
        // When
        let settings = mockNotificationService.getNotificationSettings()
        
        // Then
        XCTAssertTrue(settings.isEnabled)
        XCTAssertEqual(settings.reminderMinutes, 10)
        XCTAssertEqual(settings.enabledPrayers, Set(Prayer.allCases))
        XCTAssertTrue(settings.soundEnabled)
        XCTAssertTrue(settings.badgeEnabled)
        XCTAssertNil(settings.customMessage)
    }
    
    // MARK: - Pending Notifications Tests
    
    func testGetPendingNotifications() async throws {
        // Given
        mockNotificationService.setMockPermissionStatus(.authorized)
        let prayerTimes = createMockPrayerTimes()
        try await mockNotificationService.schedulePrayerNotifications(for: prayerTimes)
        
        // When
        let pendingNotifications = await mockNotificationService.getPendingNotifications()
        
        // Then
        XCTAssertFalse(pendingNotifications.isEmpty)
        
        // Verify notifications are sorted by time
        for i in 1..<pendingNotifications.count {
            XCTAssertLessThanOrEqual(
                pendingNotifications[i-1].scheduledTime,
                pendingNotifications[i].scheduledTime
            )
        }
    }
    
    func testIsNotificationScheduled() async throws {
        // Given
        mockNotificationService.setMockPermissionStatus(.authorized)
        let futureTime = Date().addingTimeInterval(3600)
        
        // When
        try await mockNotificationService.scheduleNotification(
            for: .dhuhr,
            at: futureTime,
            title: "Test",
            body: "Test"
        )
        
        // Then
        let isScheduled = await mockNotificationService.isNotificationScheduled(for: .dhuhr, date: futureTime)
        let isNotScheduled = await mockNotificationService.isNotificationScheduled(for: .asr, date: futureTime)
        
        XCTAssertTrue(isScheduled)
        XCTAssertFalse(isNotScheduled)
    }
    
    // MARK: - Publisher Tests
    
    func testPermissionPublisher() async {
        // Given
        let expectation = XCTestExpectation(description: "Permission status published")
        
        mockNotificationService.permissionPublisher
            .sink { status in
                XCTAssertEqual(status, .authorized)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        mockNotificationService.setMockPermissionStatus(.authorized)
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    // MARK: - Mock Simulation Tests
    
    func testSimulateNotificationDelivery() async throws {
        // Given
        mockNotificationService.setMockPermissionStatus(.authorized)
        let futureTime = Date().addingTimeInterval(3600)
        try await mockNotificationService.scheduleNotification(
            for: .maghrib,
            at: futureTime,
            title: "Test",
            body: "Test"
        )
        
        // When
        mockNotificationService.simulateNotificationDelivery(for: .maghrib, date: futureTime)
        
        // Then
        let isScheduled = await mockNotificationService.isNotificationScheduled(for: .maghrib, date: futureTime)
        XCTAssertFalse(isScheduled) // Should be removed after delivery
    }
    
    func testSimulateNotificationTap() {
        // Given/When/Then - Should not crash
        mockNotificationService.simulateNotificationTap(for: .isha, date: Date())
    }
    
    // MARK: - Utility Tests
    
    func testCanScheduleNotifications() {
        // Given
        mockNotificationService.setMockPermissionStatus(.authorized)
        mockNotificationService.isNotificationsEnabled = true
        
        // When/Then
        XCTAssertTrue(mockNotificationService.canScheduleNotifications)
        
        // Given
        mockNotificationService.setMockPermissionStatus(.denied)
        
        // When/Then
        XCTAssertFalse(mockNotificationService.canScheduleNotifications)
        
        // Given
        mockNotificationService.setMockPermissionStatus(.authorized)
        mockNotificationService.isNotificationsEnabled = false
        
        // When/Then
        XCTAssertFalse(mockNotificationService.canScheduleNotifications)
    }
    
    func testNotificationIdentifier() {
        // Given
        let date = Date()
        
        // When
        let identifier = mockNotificationService.notificationIdentifier(for: .fajr, date: date)
        
        // Then
        XCTAssertTrue(identifier.contains("fajr"))
        XCTAssertTrue(identifier.contains("prayer"))
    }
    
    func testNotificationTime() {
        // Given
        let prayerTime = Date()
        let reminderMinutes = 10
        
        // When
        let notificationTime = mockNotificationService.notificationTime(
            for: prayerTime,
            reminderMinutes: reminderMinutes
        )
        
        // Then
        let expectedTime = prayerTime.addingTimeInterval(-TimeInterval(reminderMinutes * 60))
        XCTAssertEqual(notificationTime.timeIntervalSince1970, expectedTime.timeIntervalSince1970, accuracy: 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func createMockPrayerTimes() -> PrayerTimes {
        let calendar = Calendar.current
        let today = Date()
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: today)
        
        let fajr = calendar.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: 5,
            minute: 30
        )) ?? today
        
        let dhuhr = calendar.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: 12,
            minute: 30
        )) ?? today
        
        let asr = calendar.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: 15,
            minute: 30
        )) ?? today
        
        let maghrib = calendar.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: 18,
            minute: 30
        )) ?? today
        
        let isha = calendar.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: 20,
            minute: 0
        )) ?? today
        
        return PrayerTimes(
            date: today,
            fajr: fajr.addingTimeInterval(86400), // Tomorrow
            dhuhr: dhuhr.addingTimeInterval(86400),
            asr: asr.addingTimeInterval(86400),
            maghrib: maghrib.addingTimeInterval(86400),
            isha: isha.addingTimeInterval(86400),
            calculationMethod: "MuslimWorldLeague",
            location: LocationCoordinate(latitude: 40.7128, longitude: -74.0060)
        )
    }
}
