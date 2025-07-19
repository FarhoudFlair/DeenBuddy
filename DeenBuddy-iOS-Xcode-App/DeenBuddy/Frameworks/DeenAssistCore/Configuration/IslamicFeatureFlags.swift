import Foundation
import Combine
import os

// MARK: - Islamic Feature Flags

/// Comprehensive feature flag system for Islamic app features
/// Provides safe rollout and rollback capabilities for new features
@MainActor
public class IslamicFeatureFlags: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var flags: [IslamicFeature: Bool] = [:]
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let keyPrefix = "islamic_feature_"
    
    // MARK: - Singleton
    
    public static let shared = IslamicFeatureFlags()
    
    private init() {
        loadAllFlags()
    }
    
    // MARK: - Public Methods
    
    /// Check if a feature is enabled
    public func isEnabled(_ feature: IslamicFeature) -> Bool {
        return flags[feature] ?? feature.defaultValue
    }
    
    /// Enable a feature
    public func enable(_ feature: IslamicFeature) {
        setFlag(feature, enabled: true)
    }
    
    /// Disable a feature
    public func disable(_ feature: IslamicFeature) {
        setFlag(feature, enabled: false)
    }
    
    /// Reset a feature to its default value
    public func reset(_ feature: IslamicFeature) {
        setFlag(feature, enabled: feature.defaultValue)
    }
    
    /// Reset all features to their default values
    public func resetAll() {
        for feature in IslamicFeature.allCases {
            reset(feature)
        }
    }
    
    /// Get all enabled features
    public func getEnabledFeatures() -> [IslamicFeature] {
        return IslamicFeature.allCases.filter { isEnabled($0) }
    }
    
    /// Get feature status for debugging
    public func getFeatureStatus() -> [String: Bool] {
        var status: [String: Bool] = [:]
        for feature in IslamicFeature.allCases {
            status[feature.rawValue] = isEnabled(feature)
        }
        return status
    }
    
    /// Batch enable features (for testing)
    public func enableFeatures(_ features: [IslamicFeature]) {
        features.forEach { enable($0) }
    }
    
    /// Batch disable features (for rollback)
    public func disableFeatures(_ features: [IslamicFeature]) {
        features.forEach { disable($0) }
    }
    
    // MARK: - Private Methods
    
    private func setFlag(_ feature: IslamicFeature, enabled: Bool) {
        flags[feature] = enabled
        userDefaults.set(enabled, forKey: keyPrefix + feature.rawValue)
        
        // Log feature flag changes in debug mode
        #if DEBUG
        print("🚩 Feature Flag Changed: \(feature.rawValue) = \(enabled)")
        #endif
    }
    
    private func loadAllFlags() {
        for feature in IslamicFeature.allCases {
            let key = keyPrefix + feature.rawValue
            if userDefaults.object(forKey: key) != nil {
                flags[feature] = userDefaults.bool(forKey: key)
            } else {
                flags[feature] = feature.defaultValue
            }
        }
    }
}

// MARK: - Islamic Feature Enum

/// Enum defining all Islamic app features that can be toggled
public enum IslamicFeature: String, CaseIterable {
    
    // MARK: - Phase 1 Features
    
    /// Enhanced prayer tracking with completion logging and statistics
    case enhancedPrayerTracking = "enhanced_prayer_tracking"
    
    /// Digital Tasbih with counter and dhikr sessions
    case digitalTasbih = "digital_tasbih"
    
    /// Islamic calendar with Hijri dates and events
    case islamicCalendar = "islamic_calendar"
    
    /// Improved Quran reader with audio and bookmarks
    case improvedQuranReader = "improved_quran_reader"
    
    /// Quran audio playback feature
    case quranAudio = "quran_audio"
    
    /// Quran bookmarking system
    case quranBookmarks = "quran_bookmarks"
    
    // MARK: - Phase 2 Features
    
    /// Hadith collection with search and daily hadith
    case hadithCollection = "hadith_collection"
    
    /// Expanded duas collection with categories
    case expandedDuas = "expanded_duas"
    
    /// 99 Names of Allah with meanings
    case namesOfAllah = "names_of_allah"
    
    /// Daily Islamic content (hadith, verses, etc.)
    case dailyContent = "daily_content"
    
    /// Dhikr reminders and notifications
    case dhikrReminders = "dhikr_reminders"
    
    // MARK: - Phase 3 Features
    
    /// Mosque finder with location services
    case mosqueFinder = "mosque_finder"
    
    /// Ramadan specific features (countdown, iftar, etc.)
    case ramadanFeatures = "ramadan_features"
    
    /// Islamic learning center with educational content
    case learningCenter = "learning_center"
    
    /// Advanced Qibla features with enhanced accuracy
    case advancedQibla = "advanced_qibla"
    
    /// Islamic event notifications
    case islamicEvents = "islamic_events"
    
    // MARK: - Phase 4 Features (Advanced)
    
    /// Prayer journal with detailed analytics
    case prayerJournal = "prayer_journal"
    
    /// Community features for social interaction
    case communityFeatures = "community_features"
    
    /// Islamic content library (media, videos, etc.)
    case contentLibrary = "content_library"
    
    /// Advanced personalization with AI recommendations
    case advancedPersonalization = "advanced_personalization"
    
    /// Prayer analytics and insights
    case prayerAnalytics = "prayer_analytics"
    
    /// Social sharing features
    case socialSharing = "social_sharing"
    
    // MARK: - Properties
    
    /// User-friendly display name for the feature
    public var displayName: String {
        switch self {
        case .enhancedPrayerTracking:
            return "Enhanced Prayer Tracking"
        case .digitalTasbih:
            return "Digital Tasbih"
        case .islamicCalendar:
            return "Islamic Calendar"
        case .improvedQuranReader:
            return "Improved Quran Reader"
        case .quranAudio:
            return "Quran Audio"
        case .quranBookmarks:
            return "Quran Bookmarks"
        case .hadithCollection:
            return "Hadith Collection"
        case .expandedDuas:
            return "Expanded Duas"
        case .namesOfAllah:
            return "99 Names of Allah"
        case .dailyContent:
            return "Daily Content"
        case .dhikrReminders:
            return "Dhikr Reminders"
        case .mosqueFinder:
            return "Mosque Finder"
        case .ramadanFeatures:
            return "Ramadan Features"
        case .learningCenter:
            return "Learning Center"
        case .advancedQibla:
            return "Advanced Qibla"
        case .islamicEvents:
            return "Islamic Events"
        case .prayerJournal:
            return "Prayer Journal"
        case .communityFeatures:
            return "Community Features"
        case .contentLibrary:
            return "Content Library"
        case .advancedPersonalization:
            return "Advanced Personalization"
        case .prayerAnalytics:
            return "Prayer Analytics"
        case .socialSharing:
            return "Social Sharing"
        }
    }
    
    /// Description of what the feature does
    public var description: String {
        switch self {
        case .enhancedPrayerTracking:
            return "Track prayer completion with statistics and streaks"
        case .digitalTasbih:
            return "Digital counter for dhikr and tasbih sessions"
        case .islamicCalendar:
            return "Hijri calendar with Islamic events and dates"
        case .improvedQuranReader:
            return "Enhanced Quran reading experience with translations"
        case .quranAudio:
            return "Audio recitation for Quran verses"
        case .quranBookmarks:
            return "Save and organize favorite Quran verses"
        case .hadithCollection:
            return "Browse authentic hadith collections"
        case .expandedDuas:
            return "Comprehensive collection of Islamic supplications"
        case .namesOfAllah:
            return "Learn the 99 beautiful names of Allah"
        case .dailyContent:
            return "Daily Islamic content including hadith and verses"
        case .dhikrReminders:
            return "Notifications for dhikr and remembrance"
        case .mosqueFinder:
            return "Find nearby mosques and Islamic centers"
        case .ramadanFeatures:
            return "Special features for Ramadan including countdown"
        case .learningCenter:
            return "Islamic educational content and courses"
        case .advancedQibla:
            return "Enhanced Qibla direction with improved accuracy"
        case .islamicEvents:
            return "Notifications for Islamic holidays and events"
        case .prayerJournal:
            return "Detailed prayer tracking with insights"
        case .communityFeatures:
            return "Connect with other Muslims in your area"
        case .contentLibrary:
            return "Library of Islamic videos, audio, and articles"
        case .advancedPersonalization:
            return "AI-powered personalized Islamic content"
        case .prayerAnalytics:
            return "Advanced analytics for prayer patterns"
        case .socialSharing:
            return "Share Islamic content with friends and family"
        }
    }
    
    /// Default value for the feature (enabled/disabled by default)
    public var defaultValue: Bool {
        switch self {
        // Phase 1 features - disabled by default for safe rollout
        case .enhancedPrayerTracking, .digitalTasbih, .islamicCalendar, .improvedQuranReader:
            return false
        case .quranAudio, .quranBookmarks:
            return false
            
        // Phase 2 features - disabled by default
        case .hadithCollection, .expandedDuas, .namesOfAllah, .dailyContent, .dhikrReminders:
            return false
            
        // Phase 3 features - disabled by default
        case .mosqueFinder, .ramadanFeatures, .learningCenter, .advancedQibla, .islamicEvents:
            return false
            
        // Phase 4 features - disabled by default (advanced features)
        case .prayerJournal, .communityFeatures, .contentLibrary, .advancedPersonalization, .prayerAnalytics, .socialSharing:
            return false
        }
    }
    
    /// Implementation phase for the feature
    public var phase: ImplementationPhase {
        switch self {
        case .enhancedPrayerTracking, .digitalTasbih, .islamicCalendar, .improvedQuranReader, .quranAudio, .quranBookmarks:
            return .phase1
        case .hadithCollection, .expandedDuas, .namesOfAllah, .dailyContent, .dhikrReminders:
            return .phase2
        case .mosqueFinder, .ramadanFeatures, .learningCenter, .advancedQibla, .islamicEvents:
            return .phase3
        case .prayerJournal, .communityFeatures, .contentLibrary, .advancedPersonalization, .prayerAnalytics, .socialSharing:
            return .phase4
        }
    }
    
    /// Risk level for the feature
    public var riskLevel: RiskLevel {
        switch self {
        case .enhancedPrayerTracking, .digitalTasbih, .quranBookmarks, .dailyContent, .dhikrReminders:
            return .low
        case .islamicCalendar, .improvedQuranReader, .quranAudio, .hadithCollection, .expandedDuas, .namesOfAllah, .advancedQibla, .islamicEvents:
            return .medium
        case .mosqueFinder, .ramadanFeatures, .learningCenter, .prayerJournal, .prayerAnalytics:
            return .mediumHigh
        case .communityFeatures, .contentLibrary, .advancedPersonalization, .socialSharing:
            return .high
        }
    }
}

// MARK: - Supporting Enums

/// Implementation phases for features
public enum ImplementationPhase: Int, CaseIterable {
    case phase1 = 1
    case phase2 = 2
    case phase3 = 3
    case phase4 = 4
    
    public var displayName: String {
        return "Phase \(rawValue)"
    }
    
    public var description: String {
        switch self {
        case .phase1:
            return "Core Islamic Features (4 months)"
        case .phase2:
            return "Content & Knowledge (4 months)"
        case .phase3:
            return "Location & Discovery (4 months)"
        case .phase4:
            return "Advanced Features (2-4 months)"
        }
    }
}

/// Risk levels for features
public enum RiskLevel: Int, CaseIterable {
    case low = 1
    case medium = 2
    case mediumHigh = 3
    case high = 4
    
    public var displayName: String {
        switch self {
        case .low:
            return "Low Risk"
        case .medium:
            return "Medium Risk"
        case .mediumHigh:
            return "Medium-High Risk"
        case .high:
            return "High Risk"
        }
    }
    
    public var color: String {
        switch self {
        case .low:
            return "green"
        case .medium:
            return "yellow"
        case .mediumHigh:
            return "orange"
        case .high:
            return "red"
        }
    }
}

// MARK: - Convenience Extensions

public extension IslamicFeatureFlags {
    
    /// Get all features for a specific phase
    func getFeaturesForPhase(_ phase: ImplementationPhase) -> [IslamicFeature] {
        return IslamicFeature.allCases.filter { $0.phase == phase }
    }
    
    /// Get all features with a specific risk level
    func getFeaturesWithRiskLevel(_ riskLevel: RiskLevel) -> [IslamicFeature] {
        return IslamicFeature.allCases.filter { $0.riskLevel == riskLevel }
    }
    
    /// Enable all features for a specific phase
    func enablePhase(_ phase: ImplementationPhase) {
        let features = getFeaturesForPhase(phase)
        enableFeatures(features)
    }
    
    /// Disable all features for a specific phase
    func disablePhase(_ phase: ImplementationPhase) {
        let features = getFeaturesForPhase(phase)
        disableFeatures(features)
    }
    
    /// Emergency rollback - disable all features
    func emergencyRollback() {
        #if DEBUG
        let logger = Logger(subsystem: "com.deenbuddy.app", category: "IslamicFeatureFlags")
        logger.error("🚨 Emergency rollback: Disabling all Islamic features")
        #endif
        disableFeatures(IslamicFeature.allCases)
    }
    
    /// Safe rollout - enable only low risk features
    func safeRollout() {
        let lowRiskFeatures = getFeaturesWithRiskLevel(RiskLevel.low)
        enableFeatures(lowRiskFeatures)
        print("✅ Safe rollout: Enabled \(lowRiskFeatures.count) low-risk features")
    }
}