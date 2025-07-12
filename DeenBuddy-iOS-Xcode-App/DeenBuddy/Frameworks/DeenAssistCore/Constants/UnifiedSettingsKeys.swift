//
//  UnifiedSettingsKeys.swift
//  DeenAssistCore
//
//  Created by Prayer Time Synchronization Fix
//  Unified UserDefaults keys for consistent settings storage across services
//

import Foundation

/// Unified UserDefaults keys used across all services to ensure consistent settings storage
/// This replaces the separate CacheKeys and SettingsKeys enums to fix synchronization issues
public enum UnifiedSettingsKeys {
    
    // MARK: - Core Prayer Settings (Shared between SettingsService and PrayerTimeService)
    
    /// Calculation method for prayer times (Muslim World League, Egyptian, etc.)
    public static let calculationMethod = "DeenAssist.Settings.CalculationMethod"
    
    /// Madhab for Asr prayer calculation (Shafi, Hanafi)
    public static let madhab = "DeenAssist.Settings.Madhab"
    
    // MARK: - App Settings (SettingsService)
    
    /// Whether prayer notifications are enabled
    public static let notificationsEnabled = "DeenAssist.Settings.NotificationsEnabled"
    
    /// App theme mode (light, dark, system)
    public static let theme = "DeenAssist.Settings.Theme"
    
    /// Time format preference (12-hour, 24-hour)
    public static let timeFormat = "DeenAssist.Settings.TimeFormat"
    
    /// Notification offset in seconds before prayer time
    public static let notificationOffset = "DeenAssist.Settings.NotificationOffset"
    
    /// Whether to override battery optimization
    public static let overrideBatteryOptimization = "DeenAssist.Settings.OverrideBatteryOptimization"
    
    /// Whether user has completed onboarding
    public static let hasCompletedOnboarding = "DeenAssist.Settings.HasCompletedOnboarding"
    
    /// Last settings synchronization date
    public static let lastSyncDate = "DeenAssist.Settings.LastSyncDate"
    
    /// Settings schema version for migration
    public static let settingsVersion = "DeenAssist.Settings.Version"
    
    // MARK: - Cache Keys (PrayerTimeService)
    
    /// Cached prayer times data (with date suffix)
    public static let cachedPrayerTimes = "DeenAssist.Cache.PrayerTimes"
    
    /// Cache validity date
    public static let cacheDate = "DeenAssist.Cache.Date"
    
    // MARK: - Legacy Keys (For Migration)
    
    /// Legacy calculation method key from PrayerTimeService
    public static let legacyCalculationMethod = "DeenAssist.CalculationMethod"
    
    /// Legacy madhab key from PrayerTimeService
    public static let legacyMadhab = "DeenAssist.Madhab"
    
    /// Legacy cached prayer times key from PrayerTimeService
    public static let legacyCachedPrayerTimes = "DeenAssist.CachedPrayerTimes"
    
    /// Legacy cache date key from PrayerTimeService
    public static let legacyCacheDate = "DeenAssist.CacheDate"
}

// MARK: - Migration Helper

/// Helper class for migrating settings from legacy keys to unified keys
public class SettingsMigration {
    
    private let userDefaults: UserDefaults
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    /// Migrates settings from legacy PrayerTimeService keys to unified keys
    /// This ensures no user data is lost during the synchronization fix
    public func migrateLegacySettings() {
        print("Starting settings migration from legacy keys...")
        
        // Migrate calculation method
        if let legacyMethod = userDefaults.string(forKey: UnifiedSettingsKeys.legacyCalculationMethod),
           userDefaults.string(forKey: UnifiedSettingsKeys.calculationMethod) == nil {
            userDefaults.set(legacyMethod, forKey: UnifiedSettingsKeys.calculationMethod)
            print("Migrated calculation method: \(legacyMethod)")
        }
        
        // Migrate madhab
        if let legacyMadhab = userDefaults.string(forKey: UnifiedSettingsKeys.legacyMadhab),
           userDefaults.string(forKey: UnifiedSettingsKeys.madhab) == nil {
            userDefaults.set(legacyMadhab, forKey: UnifiedSettingsKeys.madhab)
            print("Migrated madhab: \(legacyMadhab)")
        }
        
        // Migrate cache date
        if let legacyCacheDate = userDefaults.string(forKey: UnifiedSettingsKeys.legacyCacheDate),
           userDefaults.string(forKey: UnifiedSettingsKeys.cacheDate) == nil {
            userDefaults.set(legacyCacheDate, forKey: UnifiedSettingsKeys.cacheDate)
            print("Migrated cache date: \(legacyCacheDate)")
        }
        
        // Migrate cached prayer times (date-specific entries)
        migrateCachedPrayerTimes()
        
        // Mark migration as completed
        userDefaults.set(true, forKey: "DeenAssist.Migration.LegacyKeysCompleted")
        userDefaults.synchronize()
        
        print("Settings migration completed successfully")
    }
    
    /// Migrates date-specific cached prayer times
    private func migrateCachedPrayerTimes() {
        // Get all UserDefaults keys
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Find legacy cached prayer time entries (format: "DeenAssist.CachedPrayerTimes_YYYY-MM-DD")
        let legacyCachePrefix = UnifiedSettingsKeys.legacyCachedPrayerTimes + "_"
        let newCachePrefix = UnifiedSettingsKeys.cachedPrayerTimes + "_"
        
        for key in allKeys {
            if key.hasPrefix(legacyCachePrefix) {
                // Extract date suffix
                let dateSuffix = String(key.dropFirst(legacyCachePrefix.count))
                let newKey = newCachePrefix + dateSuffix
                
                // Migrate if new key doesn't exist
                if let cachedData = userDefaults.data(forKey: key),
                   userDefaults.data(forKey: newKey) == nil {
                    userDefaults.set(cachedData, forKey: newKey)
                    print("Migrated cached prayer times for date: \(dateSuffix)")
                }
            }
        }
    }
    
    /// Checks if migration has been completed
    public var isMigrationCompleted: Bool {
        return userDefaults.bool(forKey: "DeenAssist.Migration.LegacyKeysCompleted")
    }
    
    /// Cleans up legacy keys after successful migration (optional)
    public func cleanupLegacyKeys() {
        guard isMigrationCompleted else {
            print("Cannot cleanup legacy keys: migration not completed")
            return
        }
        
        print("Cleaning up legacy keys...")
        
        // Remove legacy keys
        userDefaults.removeObject(forKey: UnifiedSettingsKeys.legacyCalculationMethod)
        userDefaults.removeObject(forKey: UnifiedSettingsKeys.legacyMadhab)
        userDefaults.removeObject(forKey: UnifiedSettingsKeys.legacyCacheDate)
        
        // Remove legacy cached prayer times
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let legacyCachePrefix = UnifiedSettingsKeys.legacyCachedPrayerTimes + "_"
        
        for key in allKeys {
            if key.hasPrefix(legacyCachePrefix) {
                userDefaults.removeObject(forKey: key)
            }
        }
        
        userDefaults.synchronize()
        print("Legacy keys cleanup completed")
    }
}

// MARK: - Validation Helper

/// Helper for validating settings consistency
public class SettingsValidator {
    
    private let userDefaults: UserDefaults
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    /// Validates that core prayer settings are consistent
    public func validateCoreSettings() -> Bool {
        // Check calculation method
        guard let calculationMethod = userDefaults.string(forKey: UnifiedSettingsKeys.calculationMethod),
              CalculationMethod(rawValue: calculationMethod) != nil else {
            print("Invalid or missing calculation method")
            return false
        }
        
        // Check madhab
        guard let madhab = userDefaults.string(forKey: UnifiedSettingsKeys.madhab),
              Madhab(rawValue: madhab) != nil else {
            print("Invalid or missing madhab")
            return false
        }
        
        print("Core settings validation passed")
        return true
    }
    
    /// Resets core settings to defaults if validation fails
    public func resetToDefaults() {
        print("Resetting core settings to defaults...")
        
        userDefaults.set(CalculationMethod.muslimWorldLeague.rawValue, forKey: UnifiedSettingsKeys.calculationMethod)
        userDefaults.set(Madhab.shafi.rawValue, forKey: UnifiedSettingsKeys.madhab)
        userDefaults.synchronize()
        
        print("Core settings reset to defaults completed")
    }
}
