import Foundation
import SwiftUI

// MARK: - Feature Flag Helper

/// Convenience helper for checking feature flags throughout the app
@MainActor
public struct FeatureFlag {

    /// The shared feature flags instance
    private static var flags: IslamicFeatureFlags {
        return IslamicFeatureFlags.shared
    }

    // MARK: - Convenience Methods

    /// Check if a feature is enabled
    public static func isEnabled(_ feature: IslamicFeature) -> Bool {
        return flags.isEnabled(feature)
    }

    /// Enable a feature (for development/testing)
    public static func enable(_ feature: IslamicFeature) {
        flags.enable(feature)
    }

    /// Disable a feature (for rollback)
    public static func disable(_ feature: IslamicFeature) {
        flags.disable(feature)
    }

    /// Get the shared flags instance
    public static func shared() -> IslamicFeatureFlags {
        return flags
    }
    
    // MARK: - Phase 1 Features
    
    /// Enhanced prayer tracking enabled
    public static var enhancedPrayerTracking: Bool {
        return isEnabled(.enhancedPrayerTracking)
    }
    
    /// Digital Tasbih enabled
    public static var digitalTasbih: Bool {
        return isEnabled(.digitalTasbih)
    }
    
    /// Islamic calendar enabled
    public static var islamicCalendar: Bool {
        return isEnabled(.islamicCalendar)
    }
    
    /// Improved Quran reader enabled
    public static var improvedQuranReader: Bool {
        return isEnabled(.improvedQuranReader)
    }
    
    /// Quran audio enabled
    public static var quranAudio: Bool {
        return isEnabled(.quranAudio)
    }
    
    /// Quran bookmarks enabled
    public static var quranBookmarks: Bool {
        return isEnabled(.quranBookmarks)
    }
    
    // MARK: - Phase 2 Features
    
    /// Hadith collection enabled
    public static var hadithCollection: Bool {
        return isEnabled(.hadithCollection)
    }
    
    /// Expanded duas enabled
    public static var expandedDuas: Bool {
        return isEnabled(.expandedDuas)
    }
    
    /// 99 Names of Allah enabled
    public static var namesOfAllah: Bool {
        return isEnabled(.namesOfAllah)
    }
    
    /// Daily content enabled
    public static var dailyContent: Bool {
        return isEnabled(.dailyContent)
    }
    
    /// Dhikr reminders enabled
    public static var dhikrReminders: Bool {
        return isEnabled(.dhikrReminders)
    }
    
    // MARK: - Phase 3 Features
    
    /// Mosque finder enabled
    public static var mosqueFinder: Bool {
        return isEnabled(.mosqueFinder)
    }
    
    /// Ramadan features enabled
    public static var ramadanFeatures: Bool {
        return isEnabled(.ramadanFeatures)
    }
    
    /// Learning center enabled
    public static var learningCenter: Bool {
        return isEnabled(.learningCenter)
    }
    
    /// Advanced Qibla enabled
    public static var advancedQibla: Bool {
        return isEnabled(.advancedQibla)
    }
    
    /// Islamic events enabled
    public static var islamicEvents: Bool {
        return isEnabled(.islamicEvents)
    }
    
    // MARK: - Phase 4 Features
    
    /// Prayer journal enabled
    public static var prayerJournal: Bool {
        return isEnabled(.prayerJournal)
    }
    
    /// Community features enabled
    public static var communityFeatures: Bool {
        return isEnabled(.communityFeatures)
    }
    
    /// Content library enabled
    public static var contentLibrary: Bool {
        return isEnabled(.contentLibrary)
    }
    
    /// Advanced personalization enabled
    public static var advancedPersonalization: Bool {
        return isEnabled(.advancedPersonalization)
    }
    
    /// Prayer analytics enabled
    public static var prayerAnalytics: Bool {
        return isEnabled(.prayerAnalytics)
    }
    
    /// Social sharing enabled
    public static var socialSharing: Bool {
        return isEnabled(.socialSharing)
    }
    
    // MARK: - Development Helpers

    /// Enable all Phase 1 features (for development)
    public static func enablePhase1() {
        flags.enablePhase(.phase1)
    }

    /// Enable all Phase 2 features (for development)
    public static func enablePhase2() {
        flags.enablePhase(.phase2)
    }

    /// Enable all Phase 3 features (for development)
    public static func enablePhase3() {
        flags.enablePhase(.phase3)
    }

    /// Enable all Phase 4 features (for development)
    public static func enablePhase4() {
        flags.enablePhase(.phase4)
    }

    /// Emergency rollback - disable all features
    public static func emergencyRollback() {
        flags.emergencyRollback()
    }

    /// Safe rollout - enable only low risk features
    public static func safeRollout() {
        flags.safeRollout()
    }

    /// Get feature status for debugging
    public static func getStatus() -> [String: Bool] {
        return flags.getFeatureStatus()
    }
    
    // MARK: - SwiftUI Integration
    
    /// Check if feature is enabled for conditional view display
    public static func when<Content: View>(_ feature: IslamicFeature, @ViewBuilder content: () -> Content) -> some View {
        Group {
            if isEnabled(feature) {
                content()
            }
        }
    }
    
    /// Conditional view modifier
    public static func ifEnabled<Content: View>(_ feature: IslamicFeature, content: Content) -> some View {
        Group {
            if isEnabled(feature) {
                content
            }
        }
    }
}

// MARK: - SwiftUI View Extensions

public extension View {
    
    /// Show view only if feature is enabled
    func featureGated(_ feature: IslamicFeature) -> some View {
        Group {
            if FeatureFlag.isEnabled(feature) {
                self
            }
        }
    }
    
    /// Apply modifier only if feature is enabled
    func featureModifier<Modifier: ViewModifier>(_ feature: IslamicFeature, modifier: Modifier) -> some View {
        Group {
            if FeatureFlag.isEnabled(feature) {
                self.modifier(modifier)
            } else {
                self
            }
        }
    }
}

// MARK: - Environment Integration

/// Environment key for feature flags
public struct FeatureFlagsEnvironmentKey: EnvironmentKey {
    nonisolated public static let defaultValue = IslamicFeatureFlags.shared
}

public extension EnvironmentValues {
    var featureFlags: IslamicFeatureFlags {
        get { self[FeatureFlagsEnvironmentKey.self] }
        set { self[FeatureFlagsEnvironmentKey.self] = newValue }
    }
}

// MARK: - Debug Helpers

#if DEBUG
public extension FeatureFlag {
    
    /// Print all feature statuses (debug only)
    static func printAllStatuses() {
        print("🚩 Feature Flag Status:")
        print("=" * 50)

        for phase in ImplementationPhase.allCases {
            let features = flags.getFeaturesForPhase(phase)
            print("\n\(phase.displayName) - \(phase.description)")
            print("-" * 30)

            for feature in features {
                let status = isEnabled(feature) ? "✅ ENABLED" : "❌ DISABLED"
                let risk = "[\(feature.riskLevel.displayName)]"
                print("\(feature.displayName): \(status) \(risk)")
            }
        }

        print("\n" + "=" * 50)
    }

    /// Reset all features to default values (debug only)
    static func resetToDefaults() {
        print("🔄 Resetting all features to default values")
        flags.resetAll()
    }

    /// Enable features for testing a specific phase
    static func enableForTesting(_ phase: ImplementationPhase) {
        print("🧪 Enabling \(phase.displayName) features for testing")
        flags.enablePhase(phase)
    }
}

/// String multiplication for debug output
private extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
#endif