import Foundation
import Combine
import UserNotifications

/// Mock implementation of NotificationServiceProtocol for UI development
@MainActor
public class MockNotificationService: NotificationServiceProtocol {
    @Published public var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published public var notificationsEnabled: Bool = false
    
    public init() {}
    
    public func requestNotificationPermission() async throws -> Bool {
        // Simulate permission request delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Mock user granting permission
        authorizationStatus = .authorized
        notificationsEnabled = true
        
        return true
    }
    
    public func schedulePrayerNotifications(for prayerTimes: [PrayerTime]) async throws {
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
}
