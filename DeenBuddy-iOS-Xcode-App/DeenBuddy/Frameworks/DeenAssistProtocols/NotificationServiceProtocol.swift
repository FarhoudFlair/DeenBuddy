import Foundation
import UserNotifications

/// Protocol for notification services
@MainActor
public protocol NotificationServiceProtocol: ObservableObject {
    /// Current notification authorization status
    var authorizationStatus: UNAuthorizationStatus { get }
    
    /// Whether notifications are enabled
    var notificationsEnabled: Bool { get }
    
    /// Request notification permission from user
    func requestNotificationPermission() async throws -> Bool
    
    /// Schedule prayer notifications
    func schedulePrayerNotifications(for prayerTimes: [PrayerTime]) async throws
    
    /// Cancel all scheduled notifications
    func cancelAllNotifications() async
    
    /// Cancel specific prayer notifications
    func cancelNotifications(for prayer: Prayer) async
}

/// Prayer time data structure for notifications
public struct PrayerTime: Codable {
    public let prayer: Prayer
    public let time: Date
    public let location: String?
    
    public init(prayer: Prayer, time: Date, location: String? = nil) {
        self.prayer = prayer
        self.time = time
        self.location = location
    }
}
