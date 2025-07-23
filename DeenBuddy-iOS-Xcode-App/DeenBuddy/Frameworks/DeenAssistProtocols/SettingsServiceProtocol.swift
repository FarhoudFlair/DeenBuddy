import Foundation

/// Protocol for user settings management
@MainActor
public protocol SettingsServiceProtocol: ObservableObject {
    /// Current calculation method
    var calculationMethod: CalculationMethod { get set }
    
    /// Current prayer calculation madhab
    var madhab: Madhab { get set }

    /// Whether to use astronomical calculation for Ja'fari Maghrib (vs fixed delay)
    var useAstronomicalMaghrib: Bool { get set }

    /// Whether notifications are enabled
    var notificationsEnabled: Bool { get set }
    
    /// Whether notifications are enabled (alias for consistency)
    var enableNotifications: Bool { get set }
    
    /// Current theme setting
    var theme: ThemeMode { get set }
    
    /// Time format preference
    var timeFormat: TimeFormat { get set }
    
    /// Notification offset in seconds before prayer time
    var notificationOffset: TimeInterval { get set }
    
    /// Whether onboarding has been completed
    var hasCompletedOnboarding: Bool { get set }
    
    /// User's preferred name for personalized greetings
    var userName: String { get set }
    
    /// Override battery optimization for prayer times
    var overrideBatteryOptimization: Bool { get set }

    /// Whether to show Arabic symbol in widget and Live Activities
    var showArabicSymbolInWidget: Bool { get set }

    /// Save current settings
    func saveSettings() async throws
    
    /// Load saved settings
    func loadSettings() async throws
    
    /// Reset all settings to defaults
    func resetToDefaults() async throws
    
    /// Force immediate save without debouncing - critical for onboarding
    func saveImmediately() async throws
    
    /// Save critical onboarding settings with enhanced error handling
    func saveOnboardingSettings() async throws
}

