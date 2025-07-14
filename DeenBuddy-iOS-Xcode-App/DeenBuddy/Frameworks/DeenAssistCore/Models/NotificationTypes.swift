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

/// Prayer-specific notification configuration
public struct PrayerNotificationConfig: Codable, Equatable, Sendable {
    public let isEnabled: Bool
    public let reminderTimes: [Int] // Minutes before prayer (e.g., [15, 5, 0])
    public let customTitle: String?
    public let customBody: String?
    public let soundName: String?
    public let soundEnabled: Bool
    public let badgeEnabled: Bool

    public init(
        isEnabled: Bool = true,
        reminderTimes: [Int] = [10],
        customTitle: String? = nil,
        customBody: String? = nil,
        soundName: String? = nil,
        soundEnabled: Bool = true,
        badgeEnabled: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.reminderTimes = reminderTimes.sorted(by: >) // Sort descending (15, 10, 5, 0)
        self.customTitle = customTitle
        self.customBody = customBody
        self.soundName = soundName
        self.soundEnabled = soundEnabled
        self.badgeEnabled = badgeEnabled
    }

    /// Default configuration for a prayer
    public static let `default` = PrayerNotificationConfig()

    /// Configuration with multiple reminder times
    public static func multipleReminders(_ times: [Int]) -> PrayerNotificationConfig {
        return PrayerNotificationConfig(reminderTimes: times)
    }

    /// Configuration for immediate notification only (at prayer time)
    public static let immediate = PrayerNotificationConfig(reminderTimes: [0])

    /// Configuration with advance notice
    public static let advance15 = PrayerNotificationConfig(reminderTimes: [15])
    public static let advance10 = PrayerNotificationConfig(reminderTimes: [10])
    public static let advance5 = PrayerNotificationConfig(reminderTimes: [5])

    /// Configuration with multiple reminders (common pattern)
    public static let multipleStandard = PrayerNotificationConfig(reminderTimes: [15, 5, 0])
}

/// Enhanced notification settings with per-prayer configuration
public struct NotificationSettings: Codable, Equatable, Sendable {
    public let isEnabled: Bool
    public let globalSoundEnabled: Bool
    public let globalBadgeEnabled: Bool
    public let prayerConfigs: [Prayer: PrayerNotificationConfig]

    // Legacy support properties (computed from prayer configs)
    public var reminderMinutes: Int {
        // Return the most common reminder time across all prayers
        let allTimes = prayerConfigs.values.flatMap { $0.reminderTimes }
        let timeFrequency = Dictionary(grouping: allTimes, by: { $0 })
        return timeFrequency.max(by: { $0.value.count < $1.value.count })?.key ?? 10
    }

    public var enabledPrayers: Set<Prayer> {
        Set(prayerConfigs.compactMap { prayer, config in
            config.isEnabled ? prayer : nil
        })
    }

    public var soundEnabled: Bool {
        globalSoundEnabled
    }

    public var badgeEnabled: Bool {
        globalBadgeEnabled
    }

    public init(
        isEnabled: Bool = true,
        globalSoundEnabled: Bool = true,
        globalBadgeEnabled: Bool = true,
        prayerConfigs: [Prayer: PrayerNotificationConfig]? = nil
    ) {
        self.isEnabled = isEnabled
        self.globalSoundEnabled = globalSoundEnabled
        self.globalBadgeEnabled = globalBadgeEnabled

        // Initialize with default configs for all prayers if not provided
        if let configs = prayerConfigs {
            self.prayerConfigs = configs
        } else {
            var defaultConfigs: [Prayer: PrayerNotificationConfig] = [:]
            for prayer in Prayer.allCases {
                defaultConfigs[prayer] = PrayerNotificationConfig.default
            }
            self.prayerConfigs = defaultConfigs
        }
    }

    /// Get configuration for a specific prayer
    public func configForPrayer(_ prayer: Prayer) -> PrayerNotificationConfig {
        return prayerConfigs[prayer] ?? PrayerNotificationConfig.default
    }

    /// Update configuration for a specific prayer
    public func updatingConfig(for prayer: Prayer, config: PrayerNotificationConfig) -> NotificationSettings {
        var updatedConfigs = prayerConfigs
        updatedConfigs[prayer] = config

        return NotificationSettings(
            isEnabled: isEnabled,
            globalSoundEnabled: globalSoundEnabled,
            globalBadgeEnabled: globalBadgeEnabled,
            prayerConfigs: updatedConfigs
        )
    }

    /// Toggle prayer notification on/off
    public func togglingPrayer(_ prayer: Prayer, enabled: Bool) -> NotificationSettings {
        let currentConfig = configForPrayer(prayer)
        let updatedConfig = PrayerNotificationConfig(
            isEnabled: enabled,
            reminderTimes: currentConfig.reminderTimes,
            customTitle: currentConfig.customTitle,
            customBody: currentConfig.customBody,
            soundName: currentConfig.soundName,
            soundEnabled: currentConfig.soundEnabled,
            badgeEnabled: currentConfig.badgeEnabled
        )

        return updatingConfig(for: prayer, config: updatedConfig)
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