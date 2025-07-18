import Foundation
import Combine

/// Real implementation of SettingsServiceProtocol using UserDefaults
@MainActor
public class SettingsService: SettingsServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var calculationMethod: CalculationMethod = .muslimWorldLeague {
        didSet {
            // Notify immediately for UI updates
            NotificationCenter.default.post(name: .settingsDidChange, object: self)
            
            // Debounce the save operation
            saveSettingsAsync()
        }
    }

    @Published public var madhab: Madhab = .shafi {
        didSet {
            // Notify immediately for UI updates
            NotificationCenter.default.post(name: .settingsDidChange, object: self)
            
            // Debounce the save operation
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
    
    @Published public var userName: String = "" {
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
    private let migrationHelper: SettingsMigration
    private var saveTask: Task<Void, Never>?
    private let saveDebounceInterval: TimeInterval = 0.5
    
    // MARK: - Settings Keys (Now using UnifiedSettingsKeys)
    // Note: SettingsKeys enum removed - now using UnifiedSettingsKeys for consistency
    
    // MARK: - Constants
    
    private let currentSettingsVersion = 1
    
    // MARK: - Initialization
    
    public init(suiteName: String? = nil) {
        self.suiteName = suiteName
        self.userDefaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
        self.migrationHelper = SettingsMigration(userDefaults: self.userDefaults)

        // Perform migration if needed
        if !migrationHelper.isMigrationCompleted {
            migrationHelper.migrateLegacySettings()
        }

        Task {
            try await loadSettings()
        }
    }
    
    // MARK: - Protocol Implementation
    
    public func saveSettings() async throws {
        do {
            // Save calculation method
            userDefaults.set(calculationMethod.rawValue, forKey: UnifiedSettingsKeys.calculationMethod)

            // Save madhab
            userDefaults.set(madhab.rawValue, forKey: UnifiedSettingsKeys.madhab)

            // Save notifications enabled
            userDefaults.set(notificationsEnabled, forKey: UnifiedSettingsKeys.notificationsEnabled)

            // Save theme
            userDefaults.set(theme.rawValue, forKey: UnifiedSettingsKeys.theme)

            // Save time format
            userDefaults.set(timeFormat.rawValue, forKey: UnifiedSettingsKeys.timeFormat)

            // Save notification offset
            userDefaults.set(notificationOffset, forKey: UnifiedSettingsKeys.notificationOffset)

            // Save battery optimization override
            userDefaults.set(overrideBatteryOptimization, forKey: UnifiedSettingsKeys.overrideBatteryOptimization)

            // Save onboarding status
            userDefaults.set(hasCompletedOnboarding, forKey: UnifiedSettingsKeys.hasCompletedOnboarding)
            
            // Save user name
            userDefaults.set(userName, forKey: UnifiedSettingsKeys.userName)

            // Save metadata
            userDefaults.set(Date(), forKey: UnifiedSettingsKeys.lastSyncDate)
            userDefaults.set(currentSettingsVersion, forKey: UnifiedSettingsKeys.settingsVersion)
            
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
            try await loadAndValidateSettings()
            print("✅ Settings loaded and validated successfully")
        } catch {
            print("⚠️ Settings validation failed: \(error). Attempting recovery...")
            do {
                try await recoverFromCorruptedSettings()
                print("✅ Settings recovered successfully")
            } catch let recoveryError {
                print("❌ Settings recovery failed: \(recoveryError)")
                throw SettingsError.recoveryFailed(recoveryError)
            }
        }
    }

    /// Load and validate settings with comprehensive checks
    private func loadAndValidateSettings() async throws {
        // Check if settings exist
        let settingsVersion = userDefaults.integer(forKey: UnifiedSettingsKeys.settingsVersion)

        if settingsVersion == 0 {
            // First time launch, use defaults
            try await resetToDefaults()
            return
        }

        // Load calculation method with validation
        if let methodRawValue = userDefaults.string(forKey: UnifiedSettingsKeys.calculationMethod),
           let method = CalculationMethod(rawValue: methodRawValue) {
            calculationMethod = method
        } else {
            throw SettingsError.missingRequiredSetting(UnifiedSettingsKeys.calculationMethod)
        }

        // Load madhab with validation
        if let madhabRawValue = userDefaults.string(forKey: UnifiedSettingsKeys.madhab),
           let madhab = Madhab(rawValue: madhabRawValue) {
            self.madhab = madhab
        } else {
            throw SettingsError.missingRequiredSetting(UnifiedSettingsKeys.madhab)
        }

        // Load other settings with defaults
        notificationsEnabled = userDefaults.bool(forKey: UnifiedSettingsKeys.notificationsEnabled)

        // Load theme
        if let themeRawValue = userDefaults.string(forKey: UnifiedSettingsKeys.theme),
           let theme = ThemeMode(rawValue: themeRawValue) {
            self.theme = theme
        }

        // Load time format
        if let timeFormatRawValue = userDefaults.string(forKey: UnifiedSettingsKeys.timeFormat),
           let timeFormat = TimeFormat(rawValue: timeFormatRawValue) {
            self.timeFormat = timeFormat
        }

        // Load notification offset
        notificationOffset = userDefaults.double(forKey: UnifiedSettingsKeys.notificationOffset)
        if notificationOffset == 0 {
            notificationOffset = 300 // Default 5 minutes
        }

        // Load battery optimization override
        overrideBatteryOptimization = userDefaults.bool(forKey: UnifiedSettingsKeys.overrideBatteryOptimization)

        // Load onboarding status
        hasCompletedOnboarding = userDefaults.bool(forKey: UnifiedSettingsKeys.hasCompletedOnboarding)
        
        // Load user name
        userName = userDefaults.string(forKey: UnifiedSettingsKeys.userName) ?? ""

        // Perform comprehensive validation
        try validateSettingsConsistency()
    }
    
    /// Validate that settings are consistent and not corrupted
    private func validateSettingsConsistency() throws {
        // Check for invalid enum values by attempting to re-parse
        guard let methodString = userDefaults.string(forKey: UnifiedSettingsKeys.calculationMethod),
              CalculationMethod(rawValue: methodString) != nil else {
            throw SettingsError.corruptedSettings("Invalid calculation method value")
        }

        guard let madhabString = userDefaults.string(forKey: UnifiedSettingsKeys.madhab),
              Madhab(rawValue: madhabString) != nil else {
            throw SettingsError.corruptedSettings("Invalid madhab value")
        }

        // Check for reasonable notification offset values
        let offset = userDefaults.double(forKey: UnifiedSettingsKeys.notificationOffset)
        if offset < 0 || offset > 3600 { // 0 to 1 hour
            throw SettingsError.validationFailed("Notification offset out of valid range: \(offset)")
        }

        // Check for duplicate or conflicting legacy keys
        let legacyKeys = ["calculationMethod", "madhab", "prayer_calculation_method", "prayer_madhab"]
        var foundLegacyKeys: [String] = []

        for legacyKey in legacyKeys {
            if userDefaults.object(forKey: legacyKey) != nil {
                foundLegacyKeys.append(legacyKey)
            }
        }

        if !foundLegacyKeys.isEmpty {
            print("⚠️ Found legacy settings keys: \(foundLegacyKeys). These may cause conflicts.")
            // Don't throw error, but log for monitoring
        }

        // Validate settings version
        let version = userDefaults.integer(forKey: UnifiedSettingsKeys.settingsVersion)
        if version > 1 { // Current version is 1
            throw SettingsError.incompatibleVersion
        }

        print("✅ Settings validation passed")
    }

    /// Recover from corrupted settings by attempting repair or reset
    private func recoverFromCorruptedSettings() async throws {
        print("🔧 Attempting to recover from corrupted settings...")

        // Try to salvage what we can
        var recoveredSettings: [String: Any] = [:]

        // Attempt to recover calculation method
        if let methodString = userDefaults.string(forKey: UnifiedSettingsKeys.calculationMethod),
           CalculationMethod(rawValue: methodString) != nil {
            recoveredSettings[UnifiedSettingsKeys.calculationMethod] = methodString
        }

        // Attempt to recover madhab
        if let madhabString = userDefaults.string(forKey: UnifiedSettingsKeys.madhab),
           Madhab(rawValue: madhabString) != nil {
            recoveredSettings[UnifiedSettingsKeys.madhab] = madhabString
        }

        // Attempt to recover other settings
        recoveredSettings[UnifiedSettingsKeys.notificationsEnabled] = userDefaults.bool(forKey: UnifiedSettingsKeys.notificationsEnabled)
        recoveredSettings[UnifiedSettingsKeys.hasCompletedOnboarding] = userDefaults.bool(forKey: UnifiedSettingsKeys.hasCompletedOnboarding)

        // Clear all settings and start fresh
        clearAllSettings()

        // Reset to defaults first
        try await resetToDefaults()

        // Apply recovered settings
        for (key, value) in recoveredSettings {
            userDefaults.set(value, forKey: key)
        }

        // Reload with recovered settings
        try await loadAndValidateSettings()

        print("✅ Settings recovery completed")
    }

    /// Clear all settings from UserDefaults
    private func clearAllSettings() {
        let settingsKeys = [
            UnifiedSettingsKeys.calculationMethod,
            UnifiedSettingsKeys.madhab,
            UnifiedSettingsKeys.notificationsEnabled,
            UnifiedSettingsKeys.theme,
            UnifiedSettingsKeys.timeFormat,
            UnifiedSettingsKeys.notificationOffset,
            UnifiedSettingsKeys.overrideBatteryOptimization,
            UnifiedSettingsKeys.hasCompletedOnboarding,
            UnifiedSettingsKeys.settingsVersion
        ]

        for key in settingsKeys {
            userDefaults.removeObject(forKey: key)
        }

        // Also clear any legacy keys
        let legacyKeys = ["calculationMethod", "madhab", "prayer_calculation_method", "prayer_madhab"]
        for key in legacyKeys {
            userDefaults.removeObject(forKey: key)
        }

        userDefaults.synchronize()
        print("🗑️ All settings cleared")
    }

    public func resetToDefaults() async throws {
        do {
            calculationMethod = .muslimWorldLeague
            madhab = .shafi
            notificationsEnabled = true
            theme = .dark
            timeFormat = .twelveHour
            notificationOffset = 300 // 5 minutes
            overrideBatteryOptimization = false
            hasCompletedOnboarding = false

            // Save the defaults
            try await saveSettings()

            print("Settings reset to defaults")

        } catch {
            print("Failed to reset settings: \(error)")
            throw SettingsError.resetFailed(error)
        }
    }
    
    // MARK: - Settings Validation & Recovery

    /// Validate settings consistency with another service (e.g., PrayerTimeService)
    public func validateConsistencyWith(calculationMethod otherMethod: CalculationMethod, madhab otherMadhab: Madhab) throws {
        if self.calculationMethod != otherMethod {
            throw SettingsError.inconsistentState("Calculation method mismatch: SettingsService=\(calculationMethod.rawValue), Other=\(otherMethod.rawValue)")
        }

        if self.madhab != otherMadhab {
            throw SettingsError.inconsistentState("Madhab mismatch: SettingsService=\(madhab.rawValue), Other=\(otherMadhab.rawValue)")
        }

        print("✅ Settings consistency validation passed")
    }

    /// Force synchronization of settings to ensure consistency
    public func forceSynchronization() async throws {
        print("🔄 Forcing settings synchronization...")

        // Save current settings to ensure they're persisted
        try await saveSettings()

        // Reload settings to ensure consistency
        try await loadSettings()

        print("✅ Settings synchronization completed")
    }

    /// Get diagnostic information about current settings state
    public func getDiagnosticInfo() -> [String: Any] {
        var diagnostics: [String: Any] = [:]

        diagnostics["calculationMethod"] = calculationMethod.rawValue
        diagnostics["madhab"] = madhab.rawValue
        diagnostics["notificationsEnabled"] = notificationsEnabled
        diagnostics["theme"] = theme.rawValue
        diagnostics["timeFormat"] = timeFormat.rawValue
        diagnostics["notificationOffset"] = notificationOffset
        diagnostics["overrideBatteryOptimization"] = overrideBatteryOptimization
        diagnostics["hasCompletedOnboarding"] = hasCompletedOnboarding
        diagnostics["settingsVersion"] = userDefaults.integer(forKey: UnifiedSettingsKeys.settingsVersion)

        // Check for legacy keys
        let legacyKeys = ["calculationMethod", "madhab", "prayer_calculation_method", "prayer_madhab"]
        var foundLegacyKeys: [String] = []
        for key in legacyKeys {
            if userDefaults.object(forKey: key) != nil {
                foundLegacyKeys.append(key)
            }
        }
        diagnostics["legacyKeysFound"] = foundLegacyKeys

        return diagnostics
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
        return userDefaults.object(forKey: UnifiedSettingsKeys.lastSyncDate) as? Date
    }

    /// Check if settings are valid
    public var isValid: Bool {
        return userDefaults.integer(forKey: UnifiedSettingsKeys.settingsVersion) > 0
    }
    
    // MARK: - Private Methods
    
    private func saveSettingsAsync() {
        // Cancel any existing save task
        saveTask?.cancel()
        
        // Create a new debounced save task
        saveTask = Task {
            // Wait for the debounce interval
            try? await Task.sleep(nanoseconds: UInt64(saveDebounceInterval * 1_000_000_000))
            
            // Check if the task was cancelled
            if !Task.isCancelled {
                try? await saveSettings()
            }
        }
    }
    
    /// Force immediate save without debouncing
    public func saveImmediately() async throws {
        // Cancel any pending debounced save
        saveTask?.cancel()
        
        // Save immediately
        try await saveSettings()
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
    case validationFailed(String)
    case missingRequiredSetting(String)
    case corruptedSettings(String)
    case inconsistentState(String)
    case recoveryFailed(Error)

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
        case .validationFailed(let reason):
            return "Settings validation failed: \(reason)"
        case .missingRequiredSetting(let key):
            return "Missing required setting: \(key)"
        case .corruptedSettings(let details):
            return "Settings are corrupted: \(details)"
        case .inconsistentState(let details):
            return "Settings are in an inconsistent state: \(details)"
        case .recoveryFailed(let error):
            return "Failed to recover from corrupted settings: \(error.localizedDescription)"
        }
    }
}
