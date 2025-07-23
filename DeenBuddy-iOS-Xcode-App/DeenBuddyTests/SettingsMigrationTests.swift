//
//  SettingsMigrationTests.swift
//  DeenBuddyTests
//
//  Created by Prayer Time Synchronization Fix
//  Tests for settings migration and unified key functionality
//

import XCTest
@testable import DeenBuddy

class SettingsMigrationTests: XCTestCase {

    private var testUserDefaults: UserDefaults!
    private var testSuiteName: String!
    private var settingsMigration: SettingsMigration!
    private var settingsValidator: SettingsValidator!
    
    override func setUp() {
        super.setUp()
        
        // Create test UserDefaults with unique suite name
        testSuiteName = "test.settings.migration.\(UUID().uuidString)"
        testUserDefaults = UserDefaults(suiteName: testSuiteName)!

        // Clear any existing data
        testUserDefaults.removePersistentDomain(forName: testSuiteName)
        
        settingsMigration = SettingsMigration(userDefaults: testUserDefaults)
        settingsValidator = SettingsValidator(userDefaults: testUserDefaults)
    }
    
    override func tearDown() {
        // Clean up test data
        if testSuiteName != nil {
            testUserDefaults.removePersistentDomain(forName: testSuiteName)
        }

        testUserDefaults = nil
        testSuiteName = nil
        settingsMigration = nil
        settingsValidator = nil

        super.tearDown()
    }
    
    // MARK: - Migration Tests
    
    func testMigrationFromLegacyKeys() {
        // Given: Legacy settings exist
        testUserDefaults.set("MuslimWorldLeague", forKey: UnifiedSettingsKeys.legacyCalculationMethod)
        testUserDefaults.set("Shafi", forKey: UnifiedSettingsKeys.legacyMadhab)
        testUserDefaults.set("2024-01-15", forKey: UnifiedSettingsKeys.legacyCacheDate)
        
        // When: Migration is performed
        settingsMigration.migrateLegacySettings()
        
        // Then: Settings are migrated to unified keys
        XCTAssertEqual(testUserDefaults.string(forKey: UnifiedSettingsKeys.calculationMethod), "MuslimWorldLeague")
        XCTAssertEqual(testUserDefaults.string(forKey: UnifiedSettingsKeys.madhab), "Shafi")
        XCTAssertEqual(testUserDefaults.string(forKey: UnifiedSettingsKeys.cacheDate), "2024-01-15")
        XCTAssertTrue(settingsMigration.isMigrationCompleted)
    }
    
    func testMigrationDoesNotOverwriteExistingSettings() {
        // Given: Both legacy and new settings exist
        testUserDefaults.set("Egyptian", forKey: UnifiedSettingsKeys.legacyCalculationMethod)
        testUserDefaults.set("MuslimWorldLeague", forKey: UnifiedSettingsKeys.calculationMethod)
        
        // When: Migration is performed
        settingsMigration.migrateLegacySettings()
        
        // Then: Existing unified settings are preserved
        XCTAssertEqual(testUserDefaults.string(forKey: UnifiedSettingsKeys.calculationMethod), "MuslimWorldLeague")
    }
    
    func testMigrationOfCachedPrayerTimes() {
        // Given: Legacy cached prayer times exist
        let testData = "test_prayer_data".data(using: .utf8)!
        testUserDefaults.set(testData, forKey: "DeenAssist.CachedPrayerTimes_2024-01-15")
        testUserDefaults.set(testData, forKey: "DeenAssist.CachedPrayerTimes_2024-01-16")
        
        // When: Migration is performed
        settingsMigration.migrateLegacySettings()
        
        // Then: Cached prayer times are migrated
        XCTAssertEqual(testUserDefaults.data(forKey: "DeenAssist.Cache.PrayerTimes_2024-01-15"), testData)
        XCTAssertEqual(testUserDefaults.data(forKey: "DeenAssist.Cache.PrayerTimes_2024-01-16"), testData)
    }
    
    func testMigrationSkippedWhenAlreadyCompleted() {
        // Given: Migration is already completed
        testUserDefaults.set(true, forKey: "DeenAssist.Migration.LegacyKeysCompleted")
        testUserDefaults.set("Egyptian", forKey: UnifiedSettingsKeys.legacyCalculationMethod)
        
        // When: Migration is attempted
        settingsMigration.migrateLegacySettings()
        
        // Then: Legacy settings are not migrated
        XCTAssertNil(testUserDefaults.string(forKey: UnifiedSettingsKeys.calculationMethod))
        XCTAssertTrue(settingsMigration.isMigrationCompleted)
    }
    
    // MARK: - Settings Persistence Tests
    
    func testUnifiedKeysConsistency() {
        // Given: Settings are saved using unified keys
        testUserDefaults.set("Karachi", forKey: UnifiedSettingsKeys.calculationMethod)
        testUserDefaults.set("Hanafi", forKey: UnifiedSettingsKeys.madhab)
        
        // When: Settings are loaded
        let calculationMethod = testUserDefaults.string(forKey: UnifiedSettingsKeys.calculationMethod)
        let madhab = testUserDefaults.string(forKey: UnifiedSettingsKeys.madhab)
        
        // Then: Values are consistent
        XCTAssertEqual(calculationMethod, "Karachi")
        XCTAssertEqual(madhab, "Hanafi")
    }
    
    @MainActor
    func testSettingsServiceIntegration() {
        // Given: SettingsService with test UserDefaults
        let settingsService = SettingsService(suiteName: testSuiteName)

        // When: Settings are changed
        settingsService.calculationMethod = CalculationMethod.karachi
        settingsService.madhab = Madhab.hanafi
        
        // Then: Settings are persisted with unified keys
        // Note: This test would need async handling in real implementation
        XCTAssertEqual(testUserDefaults.string(forKey: UnifiedSettingsKeys.calculationMethod), "Karachi")
        XCTAssertEqual(testUserDefaults.string(forKey: UnifiedSettingsKeys.madhab), "Hanafi")
    }
    
    // MARK: - Validation Tests
    
    func testSettingsValidation() {
        // Given: Valid settings
        testUserDefaults.set("MuslimWorldLeague", forKey: UnifiedSettingsKeys.calculationMethod)
        testUserDefaults.set("Shafi", forKey: UnifiedSettingsKeys.madhab)
        
        // When: Validation is performed
        let isValid = settingsValidator.validateCoreSettings()
        
        // Then: Validation passes
        XCTAssertTrue(isValid)
    }
    
    func testSettingsValidationFailsWithInvalidData() {
        // Given: Invalid settings
        testUserDefaults.set("InvalidMethod", forKey: UnifiedSettingsKeys.calculationMethod)
        testUserDefaults.set("InvalidMadhab", forKey: UnifiedSettingsKeys.madhab)
        
        // When: Validation is performed
        let isValid = settingsValidator.validateCoreSettings()
        
        // Then: Validation fails
        XCTAssertFalse(isValid)
    }
    
    func testSettingsResetToDefaults() {
        // Given: Invalid settings
        testUserDefaults.set("InvalidMethod", forKey: UnifiedSettingsKeys.calculationMethod)
        
        // When: Reset to defaults is performed
        settingsValidator.resetToDefaults()
        
        // Then: Settings are reset to valid defaults
        XCTAssertEqual(testUserDefaults.string(forKey: UnifiedSettingsKeys.calculationMethod), "MuslimWorldLeague")
        XCTAssertEqual(testUserDefaults.string(forKey: UnifiedSettingsKeys.madhab), "Shafi")
    }
    
    // MARK: - Cleanup Tests
    
    func testLegacyKeysCleanup() {
        // Given: Migration is completed and legacy keys exist
        testUserDefaults.set("MuslimWorldLeague", forKey: UnifiedSettingsKeys.legacyCalculationMethod)
        testUserDefaults.set("Shafi", forKey: UnifiedSettingsKeys.legacyMadhab)
        testUserDefaults.set(true, forKey: "DeenAssist.Migration.LegacyKeysCompleted")
        
        // When: Cleanup is performed
        settingsMigration.cleanupLegacyKeys()
        
        // Then: Legacy keys are removed
        XCTAssertNil(testUserDefaults.string(forKey: UnifiedSettingsKeys.legacyCalculationMethod))
        XCTAssertNil(testUserDefaults.string(forKey: UnifiedSettingsKeys.legacyMadhab))
    }
    
    func testCleanupPreventsRemovalWhenMigrationNotCompleted() {
        // Given: Migration is not completed
        testUserDefaults.set("MuslimWorldLeague", forKey: UnifiedSettingsKeys.legacyCalculationMethod)
        
        // When: Cleanup is attempted
        settingsMigration.cleanupLegacyKeys()
        
        // Then: Legacy keys are preserved
        XCTAssertEqual(testUserDefaults.string(forKey: UnifiedSettingsKeys.legacyCalculationMethod), "MuslimWorldLeague")
    }
    
    // MARK: - Performance Tests
    
    func testMigrationPerformance() {
        // Given: Large number of cached prayer times
        for i in 1...100 {
            let dateKey = String(format: "2024-01-%02d", i % 31 + 1)
            let testData = "test_data_\(i)".data(using: .utf8)!
            testUserDefaults.set(testData, forKey: "DeenAssist.CachedPrayerTimes_\(dateKey)")
        }
        
        // When: Migration is performed
        measure {
            settingsMigration.migrateLegacySettings()
        }
        
        // Then: Migration completes within reasonable time
        XCTAssertTrue(settingsMigration.isMigrationCompleted)
    }
}

// MARK: - Integration Test Helper

extension SettingsMigrationTests {
    
    /// Helper method to simulate real-world migration scenario
    func simulateUserUpgrade() {
        // Simulate existing user with legacy settings
        testUserDefaults.set("Egyptian", forKey: UnifiedSettingsKeys.legacyCalculationMethod)
        testUserDefaults.set("Hanafi", forKey: UnifiedSettingsKeys.legacyMadhab)
        
        // Add some cached prayer times
        let testData = "cached_prayer_data".data(using: .utf8)!
        testUserDefaults.set(testData, forKey: "DeenAssist.CachedPrayerTimes_2024-01-15")
        
        // Perform migration (simulates app upgrade)
        settingsMigration.migrateLegacySettings()
        
        // Verify migration success
        XCTAssertEqual(testUserDefaults.string(forKey: UnifiedSettingsKeys.calculationMethod), "Egyptian")
        XCTAssertEqual(testUserDefaults.string(forKey: UnifiedSettingsKeys.madhab), "Hanafi")
        XCTAssertEqual(testUserDefaults.data(forKey: "DeenAssist.Cache.PrayerTimes_2024-01-15"), testData)
        XCTAssertTrue(settingsMigration.isMigrationCompleted)
    }
}
