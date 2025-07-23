import Foundation
import Combine

/// Real implementation of SettingsServiceProtocol using UserDefaults
@MainActor
public class SettingsService: SettingsServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var calculationMethod: CalculationMethod = .muslimWorldLeague {
        didSet {
            // Skip observer actions during rollback operations
            guard !isRestoring else { return }
            
            notifyAndSaveSettings(
                rollbackAction: { [weak self] in
                    await MainActor.run {
                        self?.isRestoring = true
                        defer { self?.isRestoring = false }
                        self?.calculationMethod = oldValue
                    }
                },
                propertyName: "calculationMethod",
                oldValue: oldValue.rawValue,
                newValue: calculationMethod.rawValue
            )
        }
    }

    @Published public var madhab: Madhab = .shafi {
        didSet {
            // Skip observer actions during rollback operations
            guard !isRestoring else { return }
            
            notifyAndSaveSettings(
                rollbackAction: { [weak self] in
                    await MainActor.run {
                        self?.isRestoring = true
                        defer { self?.isRestoring = false }
                        self?.madhab = oldValue
                    }
                },
                propertyName: "madhab",
                oldValue: oldValue.rawValue,
                newValue: madhab.rawValue
            )
        }
    }
    
    @Published public var notificationsEnabled: Bool = true {
        didSet {
            // Skip observer actions during rollback operations
            guard !isRestoring else { return }
            
            notifyAndSaveSettings(
                rollbackAction: { [weak self] in
                    await MainActor.run {
                        self?.isRestoring = true
                        defer { self?.isRestoring = false }
                        self?.notificationsEnabled = oldValue
                    }
                },
                propertyName: "notificationsEnabled",
                oldValue: oldValue,
                newValue: notificationsEnabled
            )
        }
    }

    @Published public var theme: ThemeMode = .dark {
        didSet {
            // Skip observer actions during rollback operations
            guard !isRestoring else { return }
            
            notifyAndSaveSettings(
                rollbackAction: { [weak self] in
                    await MainActor.run {
                        self?.isRestoring = true
                        defer { self?.isRestoring = false }
                        self?.theme = oldValue
                    }
                },
                propertyName: "theme",
                oldValue: oldValue.rawValue,
                newValue: theme.rawValue
            )
        }
    }

    @Published public var hasCompletedOnboarding: Bool = false {
        didSet {
            // Skip observer actions during rollback operations
            guard !isRestoring else { return }
            
            notifyAndSaveSettings(
                rollbackAction: { [weak self] in
                    await MainActor.run {
                        self?.isRestoring = true
                        defer { self?.isRestoring = false }
                        self?.hasCompletedOnboarding = oldValue
                    }
                },
                propertyName: "hasCompletedOnboarding",
                oldValue: oldValue,
                newValue: hasCompletedOnboarding
            )
        }
    }

    @Published public var userName: String = "" {
        didSet {
            // Skip observer actions during rollback operations
            guard !isRestoring else { return }
            
            notifyAndSaveSettings(
                rollbackAction: { [weak self] in
                    await MainActor.run {
                        self?.isRestoring = true
                        defer { self?.isRestoring = false }
                        self?.userName = oldValue
                    }
                },
                propertyName: "userName",
                oldValue: oldValue,
                newValue: userName
            )
        }
    }

    @Published public var timeFormat: TimeFormat = .twelveHour {
        didSet {
            // Skip observer actions during rollback operations
            guard !isRestoring else { return }
            
            notifyAndSaveSettings(
                rollbackAction: { [weak self] in
                    await MainActor.run {
                        self?.isRestoring = true
                        defer { self?.isRestoring = false }
                        self?.timeFormat = oldValue
                    }
                },
                propertyName: "timeFormat",
                oldValue: oldValue.rawValue,
                newValue: timeFormat.rawValue
            )
        }
    }

    @Published public var notificationOffset: TimeInterval = 300 { // 5 minutes default
        didSet {
            // Skip observer actions during rollback operations
            guard !isRestoring else { return }
            
            notifyAndSaveSettings(
                rollbackAction: { [weak self] in
                    await MainActor.run {
                        self?.isRestoring = true
                        defer { self?.isRestoring = false }
                        self?.notificationOffset = oldValue
                    }
                },
                propertyName: "notificationOffset",
                oldValue: oldValue,
                newValue: notificationOffset
            )
        }
    }

    @Published public var overrideBatteryOptimization: Bool = false {
        didSet {
            // Skip observer actions during rollback operations
            guard !isRestoring else { return }
            
            notifyAndSaveSettings(
                rollbackAction: { [weak self] in
                    await MainActor.run {
                        self?.isRestoring = true
                        defer { self?.isRestoring = false }
                        self?.overrideBatteryOptimization = oldValue
                    }
                },
                propertyName: "overrideBatteryOptimization",
                oldValue: oldValue,
                newValue: overrideBatteryOptimization
            )
        }
    }

    @Published public var showArabicSymbolInWidget: Bool = true {
        didSet {
            // Skip observer actions during rollback operations
            guard !isRestoring else { return }
            
            notifyAndSaveSettings(
                rollbackAction: { [weak self] in
                    await MainActor.run {
                        self?.isRestoring = true
                        defer { self?.isRestoring = false }
                        self?.showArabicSymbolInWidget = oldValue
                    }
                },
                propertyName: "showArabicSymbolInWidget",
                oldValue: oldValue,
                newValue: showArabicSymbolInWidget
            )
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
    
    // Circuit breaker for preventing infinite rollback loops
    private var isPerformingRollback = false
    private var rollbackCount = 0
    private var lastRollbackTime: Date?
    private let maxRollbackAttempts = 3
    private let rollbackCooldownPeriod: TimeInterval = 5.0 // 5 seconds
    
    // Guard flag to suppress didSet observers during rollback operations
    private var isRestoring = false
    
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

    deinit {
        // Cancel any pending save task to prevent memory leaks
        saveTask?.cancel()
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

            // Save Arabic symbol widget setting
            userDefaults.set(showArabicSymbolInWidget, forKey: UnifiedSettingsKeys.showArabicSymbolInWidget)

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

        // Load Arabic symbol widget setting (default to true for existing users)
        if userDefaults.object(forKey: UnifiedSettingsKeys.showArabicSymbolInWidget) != nil {
            showArabicSymbolInWidget = userDefaults.bool(forKey: UnifiedSettingsKeys.showArabicSymbolInWidget)
        } else {
            showArabicSymbolInWidget = true // Default to true for backward compatibility
        }

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
        var foundLegacyKeys: [String] = []
        for legacyKey in UnifiedSettingsKeys.legacyKeys {
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
            UnifiedSettingsKeys.userName,
            UnifiedSettingsKeys.showArabicSymbolInWidget,
            UnifiedSettingsKeys.settingsVersion
        ]

        for key in settingsKeys {
            userDefaults.removeObject(forKey: key)
        }

        // Also clear any legacy keys
        for key in UnifiedSettingsKeys.legacyKeys {
            userDefaults.removeObject(forKey: key)
        }
        // Removed deprecated userDefaults.synchronize()
        print("🗑️ All settings cleared")
    }

    public func resetToDefaults() async throws {
        do {
            await MainActor.run {
                // Set the isRestoring flag to prevent didSet observers from interfering
                isRestoring = true
                defer { isRestoring = false }

                calculationMethod = .muslimWorldLeague
                madhab = .shafi
                notificationsEnabled = true
                theme = .dark
                timeFormat = .twelveHour
                notificationOffset = 300 // 5 minutes
                overrideBatteryOptimization = false
                hasCompletedOnboarding = false
                userName = "" // Reset user name to empty string
                showArabicSymbolInWidget = true
            }

            // Save the defaults
            try await saveSettings()

            print("Settings reset to defaults - userName is now: '\(userName)'")

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

    /// Get comprehensive diagnostic information about current settings state
    public func getDiagnosticInfo() -> [String: Any] {
        var diagnostics: [String: Any] = [:]

        // Core settings
        diagnostics["calculationMethod"] = calculationMethod.rawValue
        diagnostics["madhab"] = madhab.rawValue
        diagnostics["notificationsEnabled"] = notificationsEnabled
        diagnostics["theme"] = theme.rawValue
        diagnostics["timeFormat"] = timeFormat.rawValue
        diagnostics["notificationOffset"] = notificationOffset
        diagnostics["overrideBatteryOptimization"] = overrideBatteryOptimization
        diagnostics["hasCompletedOnboarding"] = hasCompletedOnboarding
        diagnostics["userName"] = userName.isEmpty ? "<empty>" : "<set>"
        diagnostics["showArabicSymbolInWidget"] = showArabicSymbolInWidget
        diagnostics["settingsVersion"] = userDefaults.integer(forKey: UnifiedSettingsKeys.settingsVersion)
        
        // Circuit breaker status
        diagnostics["rollbackCount"] = rollbackCount
        diagnostics["maxRollbackAttempts"] = maxRollbackAttempts
        diagnostics["isPerformingRollback"] = isPerformingRollback
        diagnostics["lastRollbackTime"] = lastRollbackTime?.timeIntervalSince1970 ?? "never"
        diagnostics["rollbackCooldownPeriod"] = rollbackCooldownPeriod
        
        // Save task status
        diagnostics["hasPendingSaveTask"] = saveTask != nil && !(saveTask?.isCancelled ?? true)
        diagnostics["saveDebounceInterval"] = saveDebounceInterval
        
        // UserDefaults status
        diagnostics["userDefaultsSuite"] = suiteName ?? "standard"
        diagnostics["lastSyncDate"] = lastSyncDate?.timeIntervalSince1970 ?? "never"
        diagnostics["isValid"] = isValid

        // Check for legacy keys
        var foundLegacyKeys: [String] = []
        for key in UnifiedSettingsKeys.legacyKeys {
            if userDefaults.object(forKey: key) != nil {
                foundLegacyKeys.append(key)
            }
        }
        diagnostics["legacyKeysFound"] = foundLegacyKeys
        
        // System info
        diagnostics["timestamp"] = Date().timeIntervalSince1970
        diagnostics["diagnosticVersion"] = "1.1"

        return diagnostics
    }
    
    /// Print comprehensive diagnostic information for troubleshooting
    public func printDiagnostics() {
        let diagnostics = getDiagnosticInfo()
        print("\n🔍 ===== SETTINGS SERVICE DIAGNOSTICS =====")
        print("📱 App: DeenBuddy Settings Service")
        print("⏰ Timestamp: \(Date())")
        print("")
        
        print("🎯 Core Settings:")
        print("  • Calculation Method: \(diagnostics["calculationMethod"] ?? "unknown")")
        print("  • Madhab: \(diagnostics["madhab"] ?? "unknown")")
        print("  • Notifications: \(diagnostics["notificationsEnabled"] ?? "unknown")")
        print("  • Theme: \(diagnostics["theme"] ?? "unknown")")
        print("  • Time Format: \(diagnostics["timeFormat"] ?? "unknown")")
        print("  • Onboarding Complete: \(diagnostics["hasCompletedOnboarding"] ?? "unknown")")
        print("")
        
        print("🔧 Circuit Breaker Status:")
        print("  • Rollback Count: \(diagnostics["rollbackCount"] ?? "unknown")")
        print("  • Max Attempts: \(diagnostics["maxRollbackAttempts"] ?? "unknown")")
        print("  • Currently Rolling Back: \(diagnostics["isPerformingRollback"] ?? "unknown")")
        print("  • Last Rollback: \(diagnostics["lastRollbackTime"] ?? "never")")
        print("  • Cooldown Period: \(diagnostics["rollbackCooldownPeriod"] ?? "unknown")s")
        print("")
        
        print("💾 Persistence Status:")
        print("  • Pending Save Task: \(diagnostics["hasPendingSaveTask"] ?? "unknown")")
        print("  • Debounce Interval: \(diagnostics["saveDebounceInterval"] ?? "unknown")s")
        print("  • UserDefaults Suite: \(diagnostics["userDefaultsSuite"] ?? "unknown")")
        print("  • Last Sync: \(diagnostics["lastSyncDate"] ?? "never")")
        print("  • Settings Valid: \(diagnostics["isValid"] ?? "unknown")")
        print("")
        
        if let legacyKeys = diagnostics["legacyKeysFound"] as? [String], !legacyKeys.isEmpty {
            print("⚠️ Legacy Keys Found: \(legacyKeys.joined(separator: ", "))")
        } else {
            print("✅ No Legacy Keys Found")
        }
        
        print("==========================================\n")
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
    
    /// Helper to post settingsDidChange notification and call saveSettingsAsync with optional rollback and property info
    private func notifyAndSaveSettings(
        rollbackAction: (() async -> Void)? = nil,
        propertyName: String? = nil,
        oldValue: Any? = nil,
        newValue: Any? = nil
    ) {
        // Don't post notifications or trigger saves during rollback to prevent cascading
        if isPerformingRollback {
            print("🔄 Skipping notification and save during rollback for \(propertyName ?? "unknown property")")
            return
        }
        
        NotificationCenter.default.post(name: .settingsDidChange, object: self)
        if let rollback = rollbackAction, let property = propertyName, let oldVal = oldValue, let newVal = newValue {
            saveSettingsAsync(
                rollbackAction: rollback,
                propertyName: property,
                oldValue: oldVal,
                newValue: newVal
            )
        } else {
            saveSettingsAsync()
        }
    }
    
    private func saveSettingsAsync() {
        // Cancel any existing save task
        saveTask?.cancel()

        // Create a new debounced save task with improved error handling
        saveTask = Task {
            do {
                // Use DispatchQueue for non-cancellable delay instead of Task.sleep
                await withCheckedContinuation { continuation in
                    DispatchQueue.main.asyncAfter(deadline: .now() + saveDebounceInterval) {
                        continuation.resume()
                    }
                }

                // Check if the task was cancelled after delay
                if !Task.isCancelled {
                    try await saveSettings()
                    print("✅ Settings saved successfully via debounced operation")
                }
            } catch is CancellationError {
                // Handle cancellation gracefully without triggering rollback
                print("ℹ️ Settings save operation was cancelled (this is normal for rapid changes)")
            } catch {
                // Handle other save errors gracefully
                print("❌ Failed to save settings: \(error.localizedDescription)")

                // Post notification about save failure for UI to handle
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .settingsSaveFailed,
                        object: self,
                        userInfo: ["error": error]
                    )
                }
            }
        }
    }

    /// Save settings with rollback capability on failure and circuit breaker protection
    private func saveSettingsAsync(
        rollbackAction: @escaping () async -> Void,
        propertyName: String,
        oldValue: Any,
        newValue: Any
    ) {
        // Cancel any existing save task
        saveTask?.cancel()

        // Create a new debounced save task with rollback capability
        saveTask = Task {
            do {
                // Use DispatchQueue for non-cancellable delay instead of Task.sleep
                await withCheckedContinuation { continuation in
                    DispatchQueue.main.asyncAfter(deadline: .now() + saveDebounceInterval) {
                        continuation.resume()
                    }
                }

                // Check if the task was cancelled after delay
                if !Task.isCancelled {
                    try await saveSettings()
                    // Reset rollback counter on successful save
                    rollbackCount = 0
                    lastRollbackTime = nil
                    print("✅ Successfully saved setting: \(propertyName) = \(newValue)")
                }
            } catch is CancellationError {
                // Handle cancellation gracefully without triggering rollback
                print("ℹ️ Settings save operation for \(propertyName) was cancelled (this is normal for rapid changes)")
            } catch {
                // Check circuit breaker before attempting rollback
                if shouldAttemptRollback() {
                    print("❌ Failed to save settings for \(propertyName): \(error.localizedDescription)")
                    print("🔄 Rolling back \(propertyName) from \(newValue) to \(oldValue) (attempt \(rollbackCount + 1)/\(maxRollbackAttempts))")

                    // Increment rollback counter and update timestamp
                    rollbackCount += 1
                    lastRollbackTime = Date()
                    
                    // Set rollback flag to prevent infinite loops
                    isPerformingRollback = true
                    
                    // Execute rollback action
                    await rollbackAction()
                    
                    // Clear rollback flag
                    isPerformingRollback = false

                    // Post notification about save failure with rollback info
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: .settingsSaveFailed,
                            object: self,
                            userInfo: [
                                "error": error,
                                "propertyName": propertyName,
                                "attemptedValue": newValue,
                                "rolledBackTo": oldValue,
                                "rollbackPerformed": true,
                                "rollbackAttempt": rollbackCount
                            ]
                        )
                    }
                } else {
                    // Circuit breaker triggered - give up gracefully
                    print("🚫 Circuit breaker triggered for \(propertyName) - max rollback attempts reached or cooldown period active")
                    print("⚠️ Setting \(propertyName) will remain at \(newValue) despite save failure")
                    
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: .settingsSaveFailed,
                            object: self,
                            userInfo: [
                                "error": error,
                                "propertyName": propertyName,
                                "attemptedValue": newValue,
                                "rolledBackTo": oldValue,
                                "rollbackPerformed": false,
                                "circuitBreakerTriggered": true
                            ]
                        )
                    }
                }
            }
        }
    }
    
    /// Check if rollback should be attempted based on circuit breaker logic
    private func shouldAttemptRollback() -> Bool {
        // Don't rollback if already performing rollback (prevents infinite loops)
        if isPerformingRollback {
            return false
        }
        
        // Check if we've exceeded maximum rollback attempts
        if rollbackCount >= maxRollbackAttempts {
            // Check if enough time has passed to reset the counter
            if let lastTime = lastRollbackTime, 
               Date().timeIntervalSince(lastTime) > rollbackCooldownPeriod {
                // Reset counter after cooldown period
                rollbackCount = 0
                lastRollbackTime = nil
                return true
            }
            return false
        }
        
        return true
    }
    
    /// Force immediate save without debouncing - critical for onboarding
    public func saveImmediately() async throws {
        // Cancel any pending debounced save
        saveTask?.cancel()
        
        print("⚡ Performing immediate save (bypassing debounce)")
        
        // Save immediately without rollback mechanism for critical operations
        try await saveSettings()
        
        // Reset rollback state on successful immediate save
        rollbackCount = 0
        lastRollbackTime = nil
        
        print("✅ Immediate save completed successfully")
    }
    
    /// Save critical onboarding settings with enhanced error handling
    public func saveOnboardingSettings() async throws {
        print("🚀 Saving onboarding settings with enhanced error handling...")
        
        do {
            try await saveImmediately()
            print("✅ Onboarding settings saved successfully")
        } catch {
            print("⚠️ Failed to save onboarding settings: \(error.localizedDescription)")
            print("🔧 Attempting recovery by saving individual critical settings...")
            
            // Try to save critical settings individually
            let criticalKeys: [(String, Any)] = [
                (UnifiedSettingsKeys.hasCompletedOnboarding, hasCompletedOnboarding),
                (UnifiedSettingsKeys.calculationMethod, calculationMethod.rawValue),
                (UnifiedSettingsKeys.madhab, madhab.rawValue)
            ]
            
            var savedCount = 0
            for (key, value) in criticalKeys {
                // UserDefaults.set() doesn't throw, so we verify by reading back the value
                userDefaults.set(value, forKey: key)

                // Verify the save was successful by reading back the value
                let savedValue = userDefaults.object(forKey: key)
                let saveSuccessful = verifyValueMatch(original: value, saved: savedValue)

                if saveSuccessful {
                    savedCount += 1
                    print("✅ Saved and verified critical setting: \(key)")
                } else {
                    print("❌ Failed to save critical setting \(key): value verification failed")
                }
            }
            
            // Force synchronization
            userDefaults.synchronize()
            
            if savedCount > 0 {
                print("✅ Recovered by saving \(savedCount) critical settings")
            } else {
                throw SettingsError.saveFailed(error)
            }
        }
    }

    /// Helper method to verify that a value was successfully saved to UserDefaults
    private func verifyValueMatch(original: Any, saved: Any?) -> Bool {
        guard let saved = saved else { return false }

        // Handle different types appropriately
        switch original {
        case let boolValue as Bool:
            return saved as? Bool == boolValue
        case let stringValue as String:
            return saved as? String == stringValue
        case let intValue as Int:
            return saved as? Int == intValue
        case let doubleValue as Double:
            return saved as? Double == doubleValue
        default:
            // For other types, use string representation comparison
            return String(describing: original) == String(describing: saved)
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
