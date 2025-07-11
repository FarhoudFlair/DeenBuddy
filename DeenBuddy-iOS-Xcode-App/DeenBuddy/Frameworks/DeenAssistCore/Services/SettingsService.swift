import Foundation
import Combine

/// Real implementation of SettingsServiceProtocol using UserDefaults
@MainActor
public class SettingsService: SettingsServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var calculationMethod: CalculationMethod = .muslimWorldLeague {
        didSet {
            saveSettingsAsync()
        }
    }
    
    @Published public var madhab: Madhab = .shafi {
        didSet {
            saveSettingsAsync()
        }
    }
    
    @Published public var notificationsEnabled: Bool = true {
        didSet {
            saveSettingsAsync()
        }
    }
    
    @Published public var theme: ThemeMode = .dark {
        didSet {
            saveSettingsAsync()
        }
    }
    
    @Published public var hasCompletedOnboarding: Bool = false {
        didSet {
            saveSettingsAsync()
        }
    }
    
    @Published public var timeFormat: TimeFormat = .twelveHour {
        didSet {
            saveSettingsAsync()
        }
    }
    
    @Published public var notificationOffset: TimeInterval = 300 { // 5 minutes default
        didSet {
            saveSettingsAsync()
        }
    }
    
    @Published public var overrideBatteryOptimization: Bool = false {
        didSet {
            saveSettingsAsync()
        }
    }
    
    // Alias for enableNotifications
    public var enableNotifications: Bool {
        get { notificationsEnabled }
        set { notificationsEnabled = newValue }
    }
    
    // MARK: - Private Properties
    
    private let userDefaults: UserDefaults
    private let suiteName: String?
    
    // MARK: - Settings Keys
    
    private enum SettingsKeys {
        static let calculationMethod = "DeenAssist.Settings.CalculationMethod"
        static let madhab = "DeenAssist.Settings.Madhab"
        static let notificationsEnabled = "DeenAssist.Settings.NotificationsEnabled"
        static let theme = "DeenAssist.Settings.Theme"
        static let timeFormat = "DeenAssist.Settings.TimeFormat"
        static let notificationOffset = "DeenAssist.Settings.NotificationOffset"
        static let hasCompletedOnboarding = "DeenAssist.Settings.HasCompletedOnboarding"
        static let overrideBatteryOptimization = "DeenAssist.Settings.OverrideBatteryOptimization"
        static let lastSyncDate = "DeenAssist.Settings.LastSyncDate"
        static let settingsVersion = "DeenAssist.Settings.Version"
    }
    
    // MARK: - Constants
    
    private let currentSettingsVersion = 1
    
    // MARK: - Initialization
    
    public init(suiteName: String? = nil) {
        self.suiteName = suiteName
        self.userDefaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        
        Task {
            try await loadSettings()
        }
    }
    
    // MARK: - Protocol Implementation
    
    public func saveSettings() async throws {
        do {
            // Save calculation method
            userDefaults.set(calculationMethod.rawValue, forKey: SettingsKeys.calculationMethod)
            
            // Save madhab
            userDefaults.set(madhab.rawValue, forKey: SettingsKeys.madhab)
            
            // Save notifications enabled
            userDefaults.set(notificationsEnabled, forKey: SettingsKeys.notificationsEnabled)
            
            // Save theme
            userDefaults.set(theme.rawValue, forKey: SettingsKeys.theme)
            
            // Save time format
            userDefaults.set(timeFormat.rawValue, forKey: SettingsKeys.timeFormat)
            
            // Save notification offset
            userDefaults.set(notificationOffset, forKey: SettingsKeys.notificationOffset)
            
            // Save onboarding status
            userDefaults.set(hasCompletedOnboarding, forKey: SettingsKeys.hasCompletedOnboarding)
            
            // Save battery optimization override
            userDefaults.set(overrideBatteryOptimization, forKey: SettingsKeys.overrideBatteryOptimization)
            
            // Save metadata
            userDefaults.set(Date(), forKey: SettingsKeys.lastSyncDate)
            userDefaults.set(currentSettingsVersion, forKey: SettingsKeys.settingsVersion)
            
            // Synchronize to disk
            userDefaults.synchronize()
            
            print("Settings saved successfully")
            
        } catch {
            print("Failed to save settings: \(error)")
            throw SettingsError.saveFailed(error)
        }
    }
    
    public func loadSettings() async throws {
        do {
            // Check if settings exist
            let settingsVersion = userDefaults.integer(forKey: SettingsKeys.settingsVersion)
            
            if settingsVersion == 0 {
                // First time launch, use defaults
                try await resetToDefaults()
                return
            }
            
            // Load calculation method
            if let methodRawValue = userDefaults.string(forKey: SettingsKeys.calculationMethod),
               let method = CalculationMethod(rawValue: methodRawValue) {
                calculationMethod = method
            }
            
            // Load madhab
            if let madhabRawValue = userDefaults.string(forKey: SettingsKeys.madhab),
               let madhab = Madhab(rawValue: madhabRawValue) {
                self.madhab = madhab
            }
            
            // Load notifications enabled
            notificationsEnabled = userDefaults.bool(forKey: SettingsKeys.notificationsEnabled)
            
            // Load theme
            if let themeRawValue = userDefaults.string(forKey: SettingsKeys.theme),
               let theme = ThemeMode(rawValue: themeRawValue) {
                self.theme = theme
            }
            
            // Load time format
            if let timeFormatRawValue = userDefaults.string(forKey: SettingsKeys.timeFormat),
               let timeFormat = TimeFormat(rawValue: timeFormatRawValue) {
                self.timeFormat = timeFormat
            }
            
            // Load notification offset
            notificationOffset = userDefaults.double(forKey: SettingsKeys.notificationOffset)
            if notificationOffset == 0 {
                notificationOffset = 300 // Default 5 minutes
            }
            
            // Load onboarding status
            hasCompletedOnboarding = userDefaults.bool(forKey: SettingsKeys.hasCompletedOnboarding)
            
            // Load battery optimization override
            overrideBatteryOptimization = userDefaults.bool(forKey: SettingsKeys.overrideBatteryOptimization)
            
            print("Settings loaded successfully")
            
        } catch {
            print("Failed to load settings: \(error)")
            throw SettingsError.loadFailed(error)
        }
    }
    
    public func resetToDefaults() async throws {
        do {
            calculationMethod = .muslimWorldLeague
            madhab = .shafi
            notificationsEnabled = true
            theme = .dark
            timeFormat = .twelveHour
            notificationOffset = 300 // 5 minutes
            hasCompletedOnboarding = false
            overrideBatteryOptimization = false
            
            // Save the defaults
            try await saveSettings()
            
            print("Settings reset to defaults")
            
        } catch {
            print("Failed to reset settings: \(error)")
            throw SettingsError.resetFailed(error)
        }
    }
    
    // MARK: - Additional Methods
    
    /// Export settings as a dictionary for backup purposes
    public func exportSettings() -> [String: Any] {
        return [
            "calculationMethod": calculationMethod.rawValue,
            "madhab": madhab.rawValue,
            "notificationsEnabled": notificationsEnabled,
            "theme": theme.rawValue,
            "hasCompletedOnboarding": hasCompletedOnboarding,
            "version": currentSettingsVersion,
            "exportDate": Date()
        ]
    }
    
    /// Import settings from a dictionary
    public func importSettings(from data: [String: Any]) async throws {
        guard let version = data["version"] as? Int, version <= currentSettingsVersion else {
            throw SettingsError.incompatibleVersion
        }
        
        // Import calculation method
        if let methodRawValue = data["calculationMethod"] as? String,
           let method = CalculationMethod(rawValue: methodRawValue) {
            calculationMethod = method
        }
        
        // Import madhab
        if let madhabRawValue = data["madhab"] as? String,
           let madhab = Madhab(rawValue: madhabRawValue) {
            self.madhab = madhab
        }
        
        // Import notifications enabled
        if let enabled = data["notificationsEnabled"] as? Bool {
            notificationsEnabled = enabled
        }
        
        // Import theme
        if let themeRawValue = data["theme"] as? String,
           let theme = ThemeMode(rawValue: themeRawValue) {
            self.theme = theme
        }
        
        // Import onboarding status
        if let completed = data["hasCompletedOnboarding"] as? Bool {
            hasCompletedOnboarding = completed
        }
        
        // Save imported settings
        try await saveSettings()
    }
    
    /// Get the last sync date
    public var lastSyncDate: Date? {
        return userDefaults.object(forKey: SettingsKeys.lastSyncDate) as? Date
    }
    
    /// Check if settings are valid
    public var isValid: Bool {
        return userDefaults.integer(forKey: SettingsKeys.settingsVersion) > 0
    }
    
    // MARK: - Private Methods
    
    private func saveSettingsAsync() {
        Task {
            try? await saveSettings()
        }
    }
}

// MARK: - Theme Mode

public enum ThemeMode: String, CaseIterable, Sendable {
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

// MARK: - Error Types

public enum SettingsError: LocalizedError {
    case saveFailed(Error)
    case loadFailed(Error)
    case resetFailed(Error)
    case incompatibleVersion
    case invalidData
    
    public var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save settings: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load settings: \(error.localizedDescription)"
        case .resetFailed(let error):
            return "Failed to reset settings: \(error.localizedDescription)"
        case .incompatibleVersion:
            return "Settings version is incompatible"
        case .invalidData:
            return "Settings data is invalid"
        }
    }
}
