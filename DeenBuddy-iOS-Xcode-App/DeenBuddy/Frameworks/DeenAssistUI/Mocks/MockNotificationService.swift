import Foundation
import Combine
import UserNotifications

/// Mock implementation of NotificationServiceProtocol for UI development
@MainActor
public class MockNotificationService: NotificationServiceProtocol {
    @Published public var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    public var authorizationStatusPublisher: AnyPublisher<UNAuthorizationStatus, Never> {
        $authorizationStatus.eraseToAnyPublisher()
    }
    
    @Published public var notificationsEnabled: Bool = false
    private var criticalAlertsAuthorized = false
    
    public init() {}
    
    public func requestNotificationPermission() async throws -> Bool {
        // Simulate permission request delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Mock user granting permission
        authorizationStatus = .authorized
        notificationsEnabled = true
        
        return true
    }

    public func requestCriticalAlertPermission() async throws -> Bool {
        // Simulate a quick permission request and assume success in mock mode
        try await Task.sleep(nanoseconds: 200_000_000)
        criticalAlertsAuthorized = true
        return true
    }

    public func getCriticalAlertAuthorizationStatus() async -> Bool {
        criticalAlertsAuthorized
    }
    
    public func schedulePrayerNotifications(for prayerTimes: [PrayerTime], date: Date?) async throws {
        // Simulate scheduling delay
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // In a real implementation, this would schedule actual notifications
        print("Mock: Scheduled notifications for \(prayerTimes.count) prayers")
    }
    
    public func cancelAllNotifications() async {
        print("Mock: Cancelled all notifications")
    }
    
    public func cancelNotifications(for prayer: Prayer) async {
        print("Mock: Cancelled notifications for \(prayer.displayName)")
    }

    public func schedulePrayerTrackingNotification(
        for prayer: Prayer,
        at prayerTime: Date,
        reminderMinutes: Int
    ) async throws {
        // Simulate scheduling delay
        try await Task.sleep(nanoseconds: 500_000_000)

        print("Mock: Scheduled prayer tracking notification for \(prayer.displayName) at \(prayerTime) with \(reminderMinutes) minute reminder")
    }

    // MARK: - Missing Protocol Methods
    
    public func getNotificationSettings() -> NotificationSettings {
        // Return mock notification settings
        return NotificationSettings(
            isEnabled: notificationsEnabled,
            globalSoundEnabled: true,
            globalBadgeEnabled: true,
            prayerConfigs: [
                .fajr: PrayerNotificationConfig(
                    isEnabled: true,
                    reminderTimes: [5], // 5 minutes
                    customTitle: nil,
                    customBody: nil,
                    soundName: nil,
                    soundEnabled: true,
                    badgeEnabled: true
                ),
                .dhuhr: PrayerNotificationConfig(
                    isEnabled: true,
                    reminderTimes: [5],
                    customTitle: nil,
                    customBody: nil,
                    soundName: nil,
                    soundEnabled: true,
                    badgeEnabled: true
                ),
                .asr: PrayerNotificationConfig(
                    isEnabled: true,
                    reminderTimes: [5],
                    customTitle: nil,
                    customBody: nil,
                    soundName: nil,
                    soundEnabled: true,
                    badgeEnabled: true
                ),
                .maghrib: PrayerNotificationConfig(
                    isEnabled: true,
                    reminderTimes: [5],
                    customTitle: nil,
                    customBody: nil,
                    soundName: nil,
                    soundEnabled: true,
                    badgeEnabled: true
                ),
                .isha: PrayerNotificationConfig(
                    isEnabled: true,
                    reminderTimes: [5],
                    customTitle: nil,
                    customBody: nil,
                    soundName: nil,
                    soundEnabled: true,
                    badgeEnabled: true
                )
            ]
        )
    }
    
    public func updateNotificationSettings(_ settings: NotificationSettings) {
        // Mock implementation - just update the enabled state
        notificationsEnabled = settings.isEnabled
        print("Mock: Updated notification settings - enabled: \(settings.isEnabled)")
    }
    
    public func updateAppBadge() async {
        print("Mock: Updated app badge count")
    }
    
    public func clearBadge() async {
        print("Mock: Cleared app badge")
    }
    
    public func updateBadgeForCompletedPrayer() async {
        print("Mock: Updated badge for completed prayer")
    }
}
