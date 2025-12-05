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
    public static let calculationMethod = "DeenBuddy.Settings.CalculationMethod"
    
    /// Madhab for Asr prayer calculation (Shafi, Hanafi)
    public static let madhab = "DeenBuddy.Settings.Madhab"

    /// Whether to use astronomical calculation for Ja'fari Maghrib (vs fixed delay)
    public static let useAstronomicalMaghrib = "DeenBuddy.Settings.UseAstronomicalMaghrib"

    // MARK: - App Settings (SettingsService)
    
    /// Whether prayer notifications are enabled
    public static let notificationsEnabled = "DeenBuddy.Settings.NotificationsEnabled"
    
    /// App theme mode (light, dark, system)
    public static let theme = "DeenBuddy.Settings.Theme"
    
    /// Time format preference (12-hour, 24-hour)
    public static let timeFormat = "DeenBuddy.Settings.TimeFormat"
    
    /// Notification offset in seconds before prayer time
    public static let notificationOffset = "DeenBuddy.Settings.NotificationOffset"
    
    /// Whether to override battery optimization
    public static let overrideBatteryOptimization = "DeenBuddy.Settings.OverrideBatteryOptimization"
    
    /// Whether user has completed onboarding
    public static let hasCompletedOnboarding = "DeenBuddy.Settings.HasCompletedOnboarding"
    
    /// User's preferred name for personalized greetings
    public static let userName = "DeenBuddy.Settings.UserName"

    /// Whether to show Arabic symbol in widget and Live Activities
    public static let showArabicSymbolInWidget = "DeenBuddy.Settings.ShowArabicSymbolInWidget"
    
    /// Whether Live Activities are enabled for prayer countdowns
    public static let liveActivitiesEnabled = "DeenBuddy.Settings.LiveActivitiesEnabled"

    /// Whether to show subtle Islamic geometric patterns in the UI
    public static let enableIslamicPatterns = "DeenBuddy.Settings.EnableIslamicPatterns"

    /// Maximum future lookahead for prayer times (months)
    public static let maxLookaheadMonths = "DeenBuddy.Settings.MaxLookaheadMonths"

    /// Whether to apply +30m Isha during Ramadan for Umm Al Qura/Qatar
    public static let useRamadanIshaOffset = "DeenBuddy.Settings.UseRamadanIshaOffset"

    /// Whether to show exact long-range times (>12 months)
    public static let showLongRangePrecision = "DeenBuddy.Settings.ShowLongRangePrecision"

    /// Last settings synchronization date
    public static let lastSyncDate = "DeenBuddy.Settings.LastSyncDate"
    
    /// Settings schema version for migration
    public static let settingsVersion = "DeenBuddy.Settings.Version"
    
    // MARK: - Cache Keys (PrayerTimeService)
    
    /// Cached prayer times data (with date suffix)
    public static let cachedPrayerTimes = "DeenBuddy.Cache.PrayerTimes"
    
    /// Cache validity date
    public static let cacheDate = "DeenBuddy.Cache.Date"
    
    // MARK: - Legacy Keys (For Migration)
    
    /// Legacy calculation method key from PrayerTimeService
    public static let legacyCalculationMethod = "DeenBuddy.CalculationMethod"
    
    /// Legacy madhab key from PrayerTimeService
    public static let legacyMadhab = "DeenBuddy.Madhab"
    
    /// Legacy cached prayer times key from PrayerTimeService
    public static let legacyCachedPrayerTimes = "DeenBuddy.CachedPrayerTimes"
    
    /// Legacy cache date key from PrayerTimeService
    public static let legacyCacheDate = "DeenBuddy.CacheDate"
    
    /// List of legacy UserDefaults keys for migration and cleanup
    public static let legacyKeys = [
        "calculationMethod",
        "madhab",
        "prayer_calculation_method",
        "prayer_madhab"
    ]
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

        // Resource monitoring safeguards
        let startTime = Date()
        let maxMigrationTime: TimeInterval = 30.0 // 30 seconds max
        var migratedKeysCount = 0
        let maxKeysToMigrate = 100 // Prevent excessive migration

        defer {
            let duration = Date().timeIntervalSince(startTime)
            print("Settings migration completed in \(String(format: "%.2f", duration))s, migrated \(migratedKeysCount) keys")

            if duration > maxMigrationTime {
                print("⚠️ WARNING: Settings migration took longer than expected (\(duration)s)")
            }
        }

        // First migrate old DeenAssist keys to DeenBuddy keys (rebrand migration)
        migrateRebrandKeys()

        // Then migrate legacy calculation method with safeguards
        if let legacyMethod = userDefaults.string(forKey: UnifiedSettingsKeys.legacyCalculationMethod),
           userDefaults.string(forKey: UnifiedSettingsKeys.calculationMethod) == nil,
           migratedKeysCount < maxKeysToMigrate {
            userDefaults.set(legacyMethod, forKey: UnifiedSettingsKeys.calculationMethod)
            migratedKeysCount += 1
            print("Migrated calculation method: \(legacyMethod)")
        }
        
        // Migrate madhab with safeguards and enum simplification
        if let legacyMadhab = userDefaults.string(forKey: UnifiedSettingsKeys.legacyMadhab),
           userDefaults.string(forKey: UnifiedSettingsKeys.madhab) == nil,
           migratedKeysCount < maxKeysToMigrate {
            let migratedMadhab = migrateMadhabValue(legacyMadhab)
            userDefaults.set(migratedMadhab, forKey: UnifiedSettingsKeys.madhab)
            migratedKeysCount += 1
            print("Migrated madhab: \(legacyMadhab) -> \(migratedMadhab)")
        }

        // Also check for current madhab values that need migration (for existing users)
        if let currentMadhab = userDefaults.string(forKey: UnifiedSettingsKeys.madhab),
           migratedKeysCount < maxKeysToMigrate {
            let migratedMadhab = migrateMadhabValue(currentMadhab)
            if migratedMadhab != currentMadhab {
                userDefaults.set(migratedMadhab, forKey: UnifiedSettingsKeys.madhab)
                migratedKeysCount += 1
                print("Updated madhab: \(currentMadhab) -> \(migratedMadhab)")
            }
        }

        // Migrate cache date with safeguards
        if let legacyCacheDate = userDefaults.string(forKey: UnifiedSettingsKeys.legacyCacheDate),
           userDefaults.string(forKey: UnifiedSettingsKeys.cacheDate) == nil,
           migratedKeysCount < maxKeysToMigrate {
            userDefaults.set(legacyCacheDate, forKey: UnifiedSettingsKeys.cacheDate)
            migratedKeysCount += 1
            print("Migrated cache date: \(legacyCacheDate)")
        }

        // Migrate cached prayer times (date-specific entries) with safeguards
        if migratedKeysCount < maxKeysToMigrate {
            let additionalMigrated = migrateCachedPrayerTimes(maxKeys: maxKeysToMigrate - migratedKeysCount)
            migratedKeysCount += additionalMigrated
        }

        // Check for timeout
        if Date().timeIntervalSince(startTime) > maxMigrationTime {
            print("⚠️ Settings migration timeout reached, stopping early")
            return
        }

        // Mark migration as completed
        userDefaults.set(true, forKey: "DeenBuddy.Migration.LegacyKeysCompleted")
        userDefaults.synchronize()

        print("Settings migration completed successfully")
    }
    
    /// Migrates settings from old "DeenAssist" keys to new "DeenBuddy" keys
    private func migrateRebrandKeys() {
        print("Starting rebrand migration from DeenAssist to DeenBuddy...")
        
        let oldToNewMappings = [
            "DeenAssist.Settings.CalculationMethod": UnifiedSettingsKeys.calculationMethod,
            "DeenAssist.Settings.Madhab": UnifiedSettingsKeys.madhab,
            "DeenAssist.Settings.NotificationsEnabled": UnifiedSettingsKeys.notificationsEnabled,
            "DeenAssist.Settings.Theme": UnifiedSettingsKeys.theme,
            "DeenAssist.Settings.TimeFormat": UnifiedSettingsKeys.timeFormat,
            "DeenAssist.Settings.NotificationOffset": UnifiedSettingsKeys.notificationOffset,
            "DeenAssist.Settings.OverrideBatteryOptimization": UnifiedSettingsKeys.overrideBatteryOptimization,
            "DeenAssist.Settings.HasCompletedOnboarding": UnifiedSettingsKeys.hasCompletedOnboarding,
            "DeenAssist.Settings.LastSyncDate": UnifiedSettingsKeys.lastSyncDate,
            "DeenAssist.Settings.Version": UnifiedSettingsKeys.settingsVersion,
            "DeenAssist.Cache.PrayerTimes": UnifiedSettingsKeys.cachedPrayerTimes,
            "DeenAssist.Cache.Date": UnifiedSettingsKeys.cacheDate
        ]
        
        for (oldKey, newKey) in oldToNewMappings {
            if let oldValue = userDefaults.object(forKey: oldKey),
               userDefaults.object(forKey: newKey) == nil {
                userDefaults.set(oldValue, forKey: newKey)
                print("Migrated rebrand key: \(oldKey) -> \(newKey)")
            }
        }
        
        // Migrate date-specific cached prayer times from DeenAssist to DeenBuddy
        migrateRebrandCachedPrayerTimes()
        
        print("Rebrand migration completed")
    }
    
    /// Migrates date-specific cached prayer times from DeenAssist to DeenBuddy
    private func migrateRebrandCachedPrayerTimes() {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let oldCachePrefix = "DeenAssist.Cache.PrayerTimes_"
        let newCachePrefix = "DeenBuddy.Cache.PrayerTimes_"
        
        for key in allKeys {
            if key.hasPrefix(oldCachePrefix) {
                let dateSuffix = String(key.dropFirst(oldCachePrefix.count))
                let newKey = newCachePrefix + dateSuffix
                
                if let cachedData = userDefaults.data(forKey: key),
                   userDefaults.data(forKey: newKey) == nil {
                    userDefaults.set(cachedData, forKey: newKey)
                    print("Migrated rebrand cached prayer times for date: \(dateSuffix)")
                }
            }
        }
    }
    
    /// Migrates date-specific cached prayer times with resource safeguards
    private func migrateCachedPrayerTimes(maxKeys: Int = 50) -> Int {
        // Get all UserDefaults keys
        let allKeys = userDefaults.dictionaryRepresentation().keys

        // Find legacy cached prayer time entries (format: "DeenBuddy.CachedPrayerTimes_YYYY-MM-DD")
        let legacyCachePrefix = UnifiedSettingsKeys.legacyCachedPrayerTimes + "_"
        let newCachePrefix = UnifiedSettingsKeys.cachedPrayerTimes + "_"

        var migratedCount = 0

        for key in allKeys {
            // Check limits to prevent resource exhaustion
            guard migratedCount < maxKeys else {
                print("⚠️ Cached prayer times migration limit reached (\(maxKeys)), stopping")
                break
            }

            if key.hasPrefix(legacyCachePrefix) {
                // Extract date suffix
                let dateSuffix = String(key.dropFirst(legacyCachePrefix.count))
                let newKey = newCachePrefix + dateSuffix

                // Migrate if new key doesn't exist
                if let cachedData = userDefaults.data(forKey: key),
                   userDefaults.data(forKey: newKey) == nil {
                    userDefaults.set(cachedData, forKey: newKey)
                    migratedCount += 1
                    print("Migrated cached prayer times for date: \(dateSuffix)")
                }
            }
        }

        return migratedCount
    }
    
    /// Checks if migration has been completed
    public var isMigrationCompleted: Bool {
        return userDefaults.bool(forKey: "DeenBuddy.Migration.LegacyKeysCompleted")
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

    /// Migrates old madhab enum values to new simplified enum
    /// Handles the transition from 4 cases (sunni, shia, shafi, hanafi) to 3 cases (hanafi, shafi, jafari)
    private func migrateMadhabValue(_ oldValue: String) -> String {
        switch oldValue.lowercased() {
        case "sunni":
            return "shafi"  // General Sunni -> Shafi'i (most common)
        case "shia":
            return "jafari" // Shia -> Ja'fari (Twelver Shia)
        case "shafi", "shafi'i":
            return "shafi"  // Already correct
        case "hanafi":
            return "hanafi" // Already correct
        case "maliki":
            return "shafi"  // Maliki -> Shafi'i (similar timing)
        case "hanbali":
            return "shafi"  // Hanbali -> Shafi'i (similar timing)
        case "jafari", "ja'fari":
            return "jafari" // Already correct
        default:
            print("⚠️ Unknown madhab value '\(oldValue)', defaulting to 'shafi'")
            return "shafi"  // Default fallback
        }
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
