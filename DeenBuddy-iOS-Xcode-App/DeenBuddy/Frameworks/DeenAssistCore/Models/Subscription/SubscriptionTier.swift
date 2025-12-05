import Foundation

/// Subscription tier levels in the app
public enum SubscriptionTier: String, Codable, CaseIterable {
    case free
    case premium
    
    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        }
    }
    
    /// Features available in this tier
    public var features: [PremiumFeature] {
        switch self {
        case .free:
            return [] // Basic features are available to all
        case .premium:
            return PremiumFeature.allCases
        }
    }
}

/// Premium features that can be gated behind subscription
public enum PremiumFeature: String, Codable, CaseIterable {
    case advancedPrayerTracking
    case unlimitedJournalEntries
    case customNotificationSounds
    case adFreePrayerGuides
    case offlineQuranAccess
    case prioritySupport
    case themeCustomization
    case detailedAnalytics
    case cloudSync
    case advancedQiblaFeatures
    
    public var displayName: String {
        switch self {
        case .advancedPrayerTracking:
            return "Advanced Prayer Tracking"
        case .unlimitedJournalEntries:
            return "Unlimited Journal Entries"
        case .customNotificationSounds:
            return "Custom Notification Sounds"
        case .adFreePrayerGuides:
            return "Ad-Free Prayer Guides"
        case .offlineQuranAccess:
            return "Offline Quran Access"
        case .prioritySupport:
            return "Priority Support"
        case .themeCustomization:
            return "Theme Customization"
        case .detailedAnalytics:
            return "Detailed Analytics"
        case .cloudSync:
            return "Cloud Sync"
        case .advancedQiblaFeatures:
            return "Advanced Qibla Features"
        }
    }
    
    public var description: String {
        switch self {
        case .advancedPrayerTracking:
            return "Track your prayers with detailed statistics and insights"
        case .unlimitedJournalEntries:
            return "Keep unlimited prayer journal entries with no limits"
        case .customNotificationSounds:
            return "Choose custom sounds for your prayer notifications"
        case .adFreePrayerGuides:
            return "Enjoy all prayer guides without advertisements"
        case .offlineQuranAccess:
            return "Access the complete Quran offline anytime"
        case .prioritySupport:
            return "Get priority customer support when you need help"
        case .themeCustomization:
            return "Customize app theme colors and appearance"
        case .detailedAnalytics:
            return "View detailed analytics about your prayer habits"
        case .cloudSync:
            return "Sync your data across all your devices"
        case .advancedQiblaFeatures:
            return "Access advanced Qibla compass features"
        }
    }
    
    /// SF Symbol icon name for the feature
    public var icon: String {
        switch self {
        case .advancedPrayerTracking:
            return "chart.line.uptrend.xyaxis"
        case .unlimitedJournalEntries:
            return "book.fill"
        case .customNotificationSounds:
            return "speaker.wave.3.fill"
        case .adFreePrayerGuides:
            return "play.rectangle.fill"
        case .offlineQuranAccess:
            return "arrow.down.circle.fill"
        case .prioritySupport:
            return "person.crop.circle.badge.checkmark"
        case .themeCustomization:
            return "paintbrush.fill"
        case .detailedAnalytics:
            return "chart.bar.fill"
        case .cloudSync:
            return "icloud.fill"
        case .advancedQiblaFeatures:
            return "location.north.circle.fill"
        }
    }
}

