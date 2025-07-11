import Foundation
import UserNotifications

// MARK: - Notification Models

/// Represents a pending notification
public struct PendingNotification: Codable, Equatable {
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
        isActive: Bool
    ) {
        self.id = id
        self.prayer = prayer
        self.scheduledTime = scheduledTime
        self.title = title
        self.body = body
        self.isActive = isActive
    }
}

/// Notification settings
public struct NotificationSettings: Codable, Equatable, Sendable {
    public let isEnabled: Bool
    public let reminderMinutes: Int
    public let soundEnabled: Bool
    public let badgeEnabled: Bool
    public let customMessage: String?
    public let enabledPrayers: Set<Prayer>
    
    public init(
        isEnabled: Bool = true,
        reminderMinutes: Int = 10,
        soundEnabled: Bool = true,
        badgeEnabled: Bool = true,
        customMessage: String? = nil,
        enabledPrayers: Set<Prayer> = Set(Prayer.allCases)
    ) {
        self.isEnabled = isEnabled
        self.reminderMinutes = reminderMinutes
        self.soundEnabled = soundEnabled
        self.badgeEnabled = badgeEnabled
        self.customMessage = customMessage
        self.enabledPrayers = enabledPrayers
    }
    
    public static let `default` = NotificationSettings()
}

/// Notification permission status
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

/// Notification errors
public enum NotificationError: Error, LocalizedError {
    case permissionDenied
    case schedulingFailed
    case invalidDate
    case invalidParameters
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission denied"
        case .schedulingFailed:
            return "Failed to schedule notification"
        case .invalidDate:
            return "Invalid notification date"
        case .invalidParameters:
            return "Invalid parameters: prayerTimes is empty and date is nil."
        }
    }
}