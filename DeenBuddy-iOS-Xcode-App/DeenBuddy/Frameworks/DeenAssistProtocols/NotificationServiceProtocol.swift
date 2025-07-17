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
    func schedulePrayerNotifications(for prayerTimes: [PrayerTime], date: Date?) async throws
    
    /// Cancel all scheduled notifications
    func cancelAllNotifications() async
    
    /// Cancel specific prayer notifications
    func cancelNotifications(for prayer: Prayer) async

    /// Get current notification settings
    func getNotificationSettings() -> NotificationSettings

    /// Update notification settings
    func updateNotificationSettings(_ settings: NotificationSettings)
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

// MARK: - Notification Settings Types

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
