import Foundation

public enum Madhab: String, CaseIterable, Codable {
    case shafi = "shafi"
    case hanafi = "hanafi"
    case maliki = "maliki"
    case hanbali = "hanbali"
    case jafari = "jafari"
    
    public var displayName: String {
        switch self {
        case .shafi: return "Shafi"
        case .hanafi: return "Hanafi"
        case .maliki: return "Maliki"
        case .hanbali: return "Hanbali"
        case .jafari: return "Jafari (Shia)"
        }
    }
    
    public var description: String {
        switch self {
        case .shafi:
            return "Shafi school - Asr when shadow equals object length"
        case .hanafi:
            return "Hanafi school - Asr when shadow equals twice object length"
        case .maliki:
            return "Maliki school - Asr when shadow equals object length"
        case .hanbali:
            return "Hanbali school - Asr when shadow equals object length"
        case .jafari:
            return "Jafari school (Shia) - Asr when shadow equals object length"
        }
    }
}

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
