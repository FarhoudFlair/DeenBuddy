import Foundation
import Combine

// MARK: - Notification Service Protocol

public protocol NotificationServiceProtocol: ObservableObject {
    /// Current notification permission status
    var permissionStatus: NotificationPermissionStatus { get }
    
    /// Whether notifications are globally enabled
    var isNotificationsEnabled: Bool { get set }
    
    /// Publisher for permission status changes
    var permissionPublisher: AnyPublisher<NotificationPermissionStatus, Never> { get }
    
    /// Request notification permission from user
    func requestNotificationPermission() async -> NotificationPermissionStatus
    
    /// Schedule prayer time notifications
    func schedulePrayerNotifications(for prayerTimes: PrayerTimes) async throws
    
    /// Schedule notification for a specific prayer
    func scheduleNotification(
        for prayer: Prayer,
        at time: Date,
        title: String?,
        body: String?
    ) async throws
    
    /// Cancel all scheduled prayer notifications
    func cancelAllPrayerNotifications()
    
    /// Cancel notification for specific prayer
    func cancelNotification(for prayer: Prayer, date: Date)
    
    /// Get all pending notifications
    func getPendingNotifications() async -> [PendingNotification]
    
    /// Check if notification is scheduled for specific prayer
    func isNotificationScheduled(for prayer: Prayer, date: Date) async -> Bool
    
    /// Update notification settings
    func updateNotificationSettings(_ settings: NotificationSettings)
    
    /// Get current notification settings
    func getNotificationSettings() -> NotificationSettings
}

// MARK: - Notification Models

public enum NotificationPermissionStatus {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
    
    public var isAuthorized: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }
}

public struct PendingNotification: Identifiable, Codable {
    public let id: String
    public let prayer: Prayer
    public let scheduledTime: Date
    public let title: String
    public let body: String
    public let isActive: Bool
    
    public init(
        id: String,
        prayer: Prayer,
        scheduledTime: Date,
        title: String,
        body: String,
        isActive: Bool = true
    ) {
        self.id = id
        self.prayer = prayer
        self.scheduledTime = scheduledTime
        self.title = title
        self.body = body
        self.isActive = isActive
    }
}

public struct NotificationSettings: Codable {
    public let isEnabled: Bool
    public let reminderMinutes: Int // Minutes before prayer time
    public let enabledPrayers: Set<Prayer>
    public let soundEnabled: Bool
    public let badgeEnabled: Bool
    public let customMessage: String?
    
    public init(
        isEnabled: Bool = true,
        reminderMinutes: Int = 10,
        enabledPrayers: Set<Prayer> = Set(Prayer.allCases),
        soundEnabled: Bool = true,
        badgeEnabled: Bool = true,
        customMessage: String? = nil
    ) {
        self.isEnabled = isEnabled
        self.reminderMinutes = reminderMinutes
        self.enabledPrayers = enabledPrayers
        self.soundEnabled = soundEnabled
        self.badgeEnabled = badgeEnabled
        self.customMessage = customMessage
    }
    
    public static let `default` = NotificationSettings()
}

// MARK: - Notification Content

public struct NotificationContent {
    public let title: String
    public let body: String
    public let sound: NotificationSound
    public let badge: Int?
    public let userInfo: [String: Any]
    
    public init(
        title: String,
        body: String,
        sound: NotificationSound = .default,
        badge: Int? = nil,
        userInfo: [String: Any] = [:]
    ) {
        self.title = title
        self.body = body
        self.sound = sound
        self.badge = badge
        self.userInfo = userInfo
    }
    
    public static func prayerReminder(
        for prayer: Prayer,
        minutesBefore: Int,
        customMessage: String? = nil
    ) -> NotificationContent {
        let title = "\(prayer.displayName) Prayer Reminder"
        let body = customMessage ?? "It's time for \(prayer.displayName) prayer in \(minutesBefore) minutes"
        
        return NotificationContent(
            title: title,
            body: body,
            userInfo: [
                "prayer": prayer.rawValue,
                "type": "prayer_reminder",
                "minutes_before": minutesBefore
            ]
        )
    }
}

public enum NotificationSound {
    case `default`
    case none
    case custom(String)
    
    public var identifier: String? {
        switch self {
        case .default:
            return "default"
        case .none:
            return nil
        case .custom(let name):
            return name
        }
    }
}

// MARK: - Notification Errors

public enum NotificationError: Error, LocalizedError {
    case permissionDenied
    case schedulingFailed
    case invalidDate
    case notificationNotFound
    case systemError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission denied. Please enable notifications in Settings."
        case .schedulingFailed:
            return "Failed to schedule notification. Please try again."
        case .invalidDate:
            return "Invalid notification date provided."
        case .notificationNotFound:
            return "Notification not found."
        case .systemError(let error):
            return "System error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Default Implementation Helpers

public extension NotificationServiceProtocol {
    /// Check if notifications can be scheduled
    var canScheduleNotifications: Bool {
        return permissionStatus.isAuthorized && isNotificationsEnabled
    }
    
    /// Get notification identifier for prayer
    func notificationIdentifier(for prayer: Prayer, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "prayer_\(prayer.rawValue.lowercased())_\(formatter.string(from: date))"
    }
    
    /// Calculate notification time based on prayer time and reminder minutes
    func notificationTime(for prayerTime: Date, reminderMinutes: Int) -> Date {
        return prayerTime.addingTimeInterval(-TimeInterval(reminderMinutes * 60))
    }
}
