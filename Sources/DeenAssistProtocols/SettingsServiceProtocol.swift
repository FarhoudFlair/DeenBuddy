import Foundation

/// Protocol for user settings management
public protocol SettingsServiceProtocol: ObservableObject {
    /// Current calculation method
    var calculationMethod: CalculationMethod { get set }
    
    /// Current madhab
    var madhab: Madhab { get set }
    
    /// Whether notifications are enabled
    var notificationsEnabled: Bool { get set }
    
    /// Current theme setting
    var theme: ThemeMode { get set }
    
    /// Whether onboarding has been completed
    var hasCompletedOnboarding: Bool { get set }
    
    /// Save current settings
    func saveSettings() async throws
    
    /// Load saved settings
    func loadSettings() async throws
    
    /// Reset all settings to defaults
    func resetToDefaults() async throws
}

/// Theme modes
public enum ThemeMode: String, CaseIterable {
    case dark = "dark"
    case islamicGreen = "islamicGreen"

    public var displayName: String {
        switch self {
        case .dark:
            return "Dark Theme"
        case .islamicGreen:
            return "Islamic Green Theme"
        }
    }

    public var description: String {
        switch self {
        case .dark:
            return "Modern dark theme with cyan accents"
        case .islamicGreen:
            return "Light theme with Islamic green colors and warm backgrounds"
        }
    }
}
