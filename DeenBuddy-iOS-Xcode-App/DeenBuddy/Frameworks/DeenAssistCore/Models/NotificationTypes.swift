import Foundation
import UserNotifications

// MARK: - Notification Models

/// Represents a pending notification with enhanced metadata
public struct PendingNotification: Codable, Equatable {
    public let id: String
    public let prayer: Prayer
    public let scheduledTime: Date
    public let prayerTime: Date // Actual prayer time
    public let reminderMinutes: Int // Minutes before prayer
    public let title: String
    public let body: String
    public let isActive: Bool
    public let soundName: String?
    public let soundEnabled: Bool
    public let badgeEnabled: Bool

    public init(
        id: String,
        prayer: Prayer,
        scheduledTime: Date,
        prayerTime: Date,
        reminderMinutes: Int,
        title: String,
        body: String,
        isActive: Bool,
        soundName: String? = nil,
        soundEnabled: Bool = true,
        badgeEnabled: Bool = true
    ) {
        self.id = id
        self.prayer = prayer
        self.scheduledTime = scheduledTime
        self.prayerTime = prayerTime
        self.reminderMinutes = reminderMinutes
        self.title = title
        self.body = body
        self.isActive = isActive
        self.soundName = soundName
        self.soundEnabled = soundEnabled
        self.badgeEnabled = badgeEnabled
    }

    /// Legacy initializer for backward compatibility
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
        self.prayerTime = scheduledTime // Assume scheduled time is prayer time for legacy
        self.reminderMinutes = 0
        self.title = title
        self.body = body
        self.isActive = isActive
        self.soundName = nil
        self.soundEnabled = true
        self.badgeEnabled = true
    }

    /// Check if this is an immediate notification (at prayer time)
    public var isImmediateNotification: Bool {
        return reminderMinutes == 0
    }

    /// Check if this is an advance notification
    public var isAdvanceNotification: Bool {
        return reminderMinutes > 0
    }

    /// Human-readable description of notification timing
    public var timingDescription: String {
        if reminderMinutes == 0 {
            return "At prayer time"
        } else {
            return "\(reminderMinutes) minutes before"
        }
    }
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