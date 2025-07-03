import Foundation
import CoreLocation

/// iOS user preferences and settings model
public struct User: Codable {
    public let id: UUID
    public var preferredMadhab: Madhab
    public var enabledNotifications: Bool
    public var locationPermissionGranted: Bool
    public var bookmarkedGuides: Set<String>
    public var offlineGuides: Set<String>
    public var completedGuides: Set<String>
    public var readingProgress: [String: Double] // guideId -> progress
    public var lastReadDates: [String: Date] // guideId -> lastReadDate
    public var notificationSettings: NotificationSettings
    public var displaySettings: DisplaySettings
    public var privacySettings: PrivacySettings
    public var createdAt: Date
    public var lastActiveAt: Date
    
    public init(
        id: UUID = UUID(),
        preferredMadhab: Madhab = .sunni,
        enabledNotifications: Bool = true,
        locationPermissionGranted: Bool = false,
        bookmarkedGuides: Set<String> = [],
        offlineGuides: Set<String> = [],
        completedGuides: Set<String> = [],
        readingProgress: [String: Double] = [:],
        lastReadDates: [String: Date] = [:],
        notificationSettings: NotificationSettings = NotificationSettings(),
        displaySettings: DisplaySettings = DisplaySettings(),
        privacySettings: PrivacySettings = PrivacySettings(),
        createdAt: Date = Date(),
        lastActiveAt: Date = Date()
    ) {
        self.id = id
        self.preferredMadhab = preferredMadhab
        self.enabledNotifications = enabledNotifications
        self.locationPermissionGranted = locationPermissionGranted
        self.bookmarkedGuides = bookmarkedGuides
        self.offlineGuides = offlineGuides
        self.completedGuides = completedGuides
        self.readingProgress = readingProgress
        self.lastReadDates = lastReadDates
        self.notificationSettings = notificationSettings
        self.displaySettings = displaySettings
        self.privacySettings = privacySettings
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
    }
    
    // MARK: - Computed Properties
    
    /// Total number of bookmarked guides
    public var bookmarkCount: Int {
        return bookmarkedGuides.count
    }
    
    /// Total number of offline guides
    public var offlineGuideCount: Int {
        return offlineGuides.count
    }
    
    /// Total number of completed guides
    public var completedGuideCount: Int {
        return completedGuides.count
    }
    
    /// Average reading progress across all guides
    public var averageProgress: Double {
        guard !readingProgress.isEmpty else { return 0.0 }
        let total = readingProgress.values.reduce(0, +)
        return total / Double(readingProgress.count)
    }
    
    /// Number of days since account creation
    public var daysSinceCreation: Int {
        return Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
    }
    
    /// Whether user is active (used app in last 7 days)
    public var isActiveUser: Bool {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return lastActiveAt > sevenDaysAgo
    }
    
    // MARK: - Guide Management
    
    /// Checks if a guide is bookmarked
    public func isBookmarked(_ guideId: String) -> Bool {
        return bookmarkedGuides.contains(guideId)
    }
    
    /// Checks if a guide is available offline
    public func isOffline(_ guideId: String) -> Bool {
        return offlineGuides.contains(guideId)
    }
    
    /// Checks if a guide is completed
    public func isCompleted(_ guideId: String) -> Bool {
        return completedGuides.contains(guideId)
    }
    
    /// Gets reading progress for a guide
    public func getProgress(for guideId: String) -> Double {
        return readingProgress[guideId] ?? 0.0
    }
    
    /// Gets last read date for a guide
    public func getLastReadDate(for guideId: String) -> Date? {
        return lastReadDates[guideId]
    }
    
    // MARK: - Mutating Methods
    
    /// Bookmarks a guide
    public mutating func bookmark(_ guideId: String) {
        bookmarkedGuides.insert(guideId)
        updateLastActive()
    }
    
    /// Removes bookmark from a guide
    public mutating func removeBookmark(_ guideId: String) {
        bookmarkedGuides.remove(guideId)
        updateLastActive()
    }
    
    /// Toggles bookmark status for a guide
    public mutating func toggleBookmark(_ guideId: String) {
        if isBookmarked(guideId) {
            removeBookmark(guideId)
        } else {
            bookmark(guideId)
        }
    }
    
    /// Marks a guide as available offline
    public mutating func markOffline(_ guideId: String) {
        offlineGuides.insert(guideId)
        updateLastActive()
    }
    
    /// Removes offline availability for a guide
    public mutating func removeOffline(_ guideId: String) {
        offlineGuides.remove(guideId)
        updateLastActive()
    }
    
    /// Updates reading progress for a guide
    public mutating func updateProgress(for guideId: String, progress: Double) {
        let clampedProgress = max(0.0, min(1.0, progress))
        readingProgress[guideId] = clampedProgress
        lastReadDates[guideId] = Date()
        
        // Mark as completed if progress is 100%
        if clampedProgress >= 1.0 {
            completedGuides.insert(guideId)
        } else {
            completedGuides.remove(guideId)
        }
        
        updateLastActive()
    }
    
    /// Marks a guide as completed
    public mutating func markCompleted(_ guideId: String) {
        completedGuides.insert(guideId)
        readingProgress[guideId] = 1.0
        lastReadDates[guideId] = Date()
        updateLastActive()
    }
    
    /// Updates last active timestamp
    public mutating func updateLastActive() {
        lastActiveAt = Date()
    }
    
    /// Resets all progress and bookmarks
    public mutating func resetAllData() {
        bookmarkedGuides.removeAll()
        offlineGuides.removeAll()
        completedGuides.removeAll()
        readingProgress.removeAll()
        lastReadDates.removeAll()
        updateLastActive()
    }
}

// MARK: - Notification Settings

public struct NotificationSettings: Codable {
    public var prayerReminders: Bool
    public var dailyReminders: Bool
    public var weeklyProgress: Bool
    public var newContentAlerts: Bool
    public var reminderTime: Date // Time of day for daily reminders
    public var soundEnabled: Bool
    public var vibrationEnabled: Bool
    
    public init(
        prayerReminders: Bool = true,
        dailyReminders: Bool = true,
        weeklyProgress: Bool = true,
        newContentAlerts: Bool = true,
        reminderTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date(),
        soundEnabled: Bool = true,
        vibrationEnabled: Bool = true
    ) {
        self.prayerReminders = prayerReminders
        self.dailyReminders = dailyReminders
        self.weeklyProgress = weeklyProgress
        self.newContentAlerts = newContentAlerts
        self.reminderTime = reminderTime
        self.soundEnabled = soundEnabled
        self.vibrationEnabled = vibrationEnabled
    }
}

// MARK: - Display Settings

public struct DisplaySettings: Codable {
    public var fontSize: FontSize
    public var arabicFontSize: FontSize
    public var showArabicText: Bool
    public var showTransliteration: Bool
    public var showTranslation: Bool
    public var darkModePreference: DarkModePreference
    public var animationsEnabled: Bool
    public var hapticFeedbackEnabled: Bool
    
    public init(
        fontSize: FontSize = .medium,
        arabicFontSize: FontSize = .large,
        showArabicText: Bool = true,
        showTransliteration: Bool = true,
        showTranslation: Bool = true,
        darkModePreference: DarkModePreference = .system,
        animationsEnabled: Bool = true,
        hapticFeedbackEnabled: Bool = true
    ) {
        self.fontSize = fontSize
        self.arabicFontSize = arabicFontSize
        self.showArabicText = showArabicText
        self.showTransliteration = showTransliteration
        self.showTranslation = showTranslation
        self.darkModePreference = darkModePreference
        self.animationsEnabled = animationsEnabled
        self.hapticFeedbackEnabled = hapticFeedbackEnabled
    }
}

public enum FontSize: String, CaseIterable, Codable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case extraLarge = "extraLarge"
    
    public var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }
    
    public var scaleFactor: CGFloat {
        switch self {
        case .small: return 0.8
        case .medium: return 1.0
        case .large: return 1.2
        case .extraLarge: return 1.4
        }
    }
}

public enum DarkModePreference: String, CaseIterable, Codable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    public var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

// MARK: - Privacy Settings

public struct PrivacySettings: Codable {
    public var analyticsEnabled: Bool
    public var crashReportingEnabled: Bool
    public var locationDataSharing: Bool
    public var personalizedContent: Bool
    
    public init(
        analyticsEnabled: Bool = false,
        crashReportingEnabled: Bool = true,
        locationDataSharing: Bool = false,
        personalizedContent: Bool = true
    ) {
        self.analyticsEnabled = analyticsEnabled
        self.crashReportingEnabled = crashReportingEnabled
        self.locationDataSharing = locationDataSharing
        self.personalizedContent = personalizedContent
    }
}
