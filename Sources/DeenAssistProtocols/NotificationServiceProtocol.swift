import Foundation
import UserNotifications

/// Protocol for notification services
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
    func cancelAllNotifications()
    
    /// Cancel specific prayer notifications
    func cancelNotifications(for prayer: PrayerType)
}

/// Prayer time data structure for notifications
public struct PrayerTime {
    public let prayer: PrayerType
    public let time: Date
    public let location: String?
    
    public init(prayer: PrayerType, time: Date, location: String? = nil) {
        self.prayer = prayer
        self.time = time
        self.location = location
    }
}

/// Types of prayers
public enum PrayerType: String, CaseIterable {
    case fajr = "Fajr"
    case dhuhr = "Dhuhr"
    case asr = "Asr"
    case maghrib = "Maghrib"
    case isha = "Isha"
    
    public var displayName: String {
        return rawValue
    }
    
    public var notificationTitle: String {
        return "\(rawValue) Prayer Time"
    }
    
    public var notificationBody: String {
        return "\(rawValue) prayer time is in 10 minutes"
    }
}
