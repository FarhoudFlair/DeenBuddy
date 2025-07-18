//
//  UserProfileSettingsTests.swift
//  DeenBuddyTests
//
//  Created by Farhoud Talebi on 2025-07-17.
//

import XCTest
@testable import DeenBuddy

/// Tests for user profile functionality in Settings
class UserProfileSettingsTests: XCTestCase {
    
    var settingsService: SettingsService!
    
    override func setUp() {
        super.setUp()
        settingsService = SettingsService()
    }
    
    override func tearDown() {
        // Clean up UserDefaults after each test
        let userDefaults = UserDefaults.standard
        userDefaults.removeObject(forKey: "DeenBuddy.Settings.UserName")
        userDefaults.synchronize()
        settingsService = nil
        super.tearDown()
    }
    
    // MARK: - User Name Storage Tests
    
    func testUserNamePersistence() async throws {
        // Given
        let testName = "Ahmed Hassan"
        
        // When
        settingsService.userName = testName
        try await settingsService.saveSettings()
        
        // Then
        XCTAssertEqual(settingsService.userName, testName, "User name should be stored correctly")
        
        // Verify persistence by creating new instance
        let newSettingsService = SettingsService()
        try await newSettingsService.loadSettings()
        XCTAssertEqual(newSettingsService.userName, testName, "User name should persist across service instances")
    }
    
    func testEmptyUserNameHandling() async throws {
        // Given
        let emptyName = ""
        
        // When
        settingsService.userName = emptyName
        try await settingsService.saveSettings()
        
        // Then
        XCTAssertEqual(settingsService.userName, emptyName, "Empty user name should be handled correctly")
    }
    
    func testUserNameWithWhitespace() async throws {
        // Given
        let nameWithWhitespace = "  Fatima Al-Zahra  "
        let expectedTrimmedName = "Fatima Al-Zahra"
        
        // When
        settingsService.userName = nameWithWhitespace
        
        // Simulate the validation that happens in the UI
        let trimmedName = settingsService.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        settingsService.userName = trimmedName
        
        try await settingsService.saveSettings()
        
        // Then
        XCTAssertEqual(settingsService.userName, expectedTrimmedName, "User name should be trimmed of whitespace")
    }
    
    func testUserNameWithSpecialCharacters() async throws {
        // Given
        let nameWithSpecialChars = "محمد عبد الله"
        
        // When
        settingsService.userName = nameWithSpecialChars
        try await settingsService.saveSettings()
        
        // Then
        XCTAssertEqual(settingsService.userName, nameWithSpecialChars, "User name should support Arabic characters")
    }
    
    func testLongUserName() async throws {
        // Given
        let longName = "Muhammad Abdullah Ibn Ahmad Al-Rashid Al-Makki"
        
        // When
        settingsService.userName = longName
        try await settingsService.saveSettings()
        
        // Then
        XCTAssertEqual(settingsService.userName, longName, "Long user names should be supported")
    }
    
    // MARK: - Settings Integration Tests
    
    func testUserNameInSettingsReset() async throws {
        // Given
        let testName = "Omar Ibn Al-Khattab"
        settingsService.userName = testName
        try await settingsService.saveSettings()
        
        // When
        try await settingsService.resetToDefaults()
        
        // Then
        XCTAssertEqual(settingsService.userName, "", "User name should be reset to empty string when settings are reset")
    }
    
    func testUserNameDoesNotAffectOtherSettings() async throws {
        // Given
        let originalCalculationMethod = settingsService.calculationMethod
        let originalMadhab = settingsService.madhab
        let testName = "Aisha Bint Abu Bakr"
        
        // When
        settingsService.userName = testName
        try await settingsService.saveSettings()
        
        // Then
        XCTAssertEqual(settingsService.calculationMethod, originalCalculationMethod, "Calculation method should not be affected")
        XCTAssertEqual(settingsService.madhab, originalMadhab, "Madhab should not be affected")
        XCTAssertEqual(settingsService.userName, testName, "User name should be set correctly")
    }
    
    // MARK: - Performance Tests
    
    func testUserNameSavePerformance() {
        // Given
        let testName = "Hassan Ibn Ali"
        
        // When & Then
        measure {
            settingsService.userName = testName
            // The save happens automatically via didSet
        }
    }
    
    // MARK: - Edge Cases
    
    func testUserNameWithOnlyWhitespace() async throws {
        // Given
        let whitespaceOnlyName = "   \n\t   "
        
        // When
        settingsService.userName = whitespaceOnlyName
        
        // Simulate the validation that happens in the UI
        let trimmedName = settingsService.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        settingsService.userName = trimmedName
        
        try await settingsService.saveSettings()
        
        // Then
        XCTAssertEqual(settingsService.userName, "", "Whitespace-only name should become empty string after trimming")
    }
    
    func testUserNameWithNewlines() async throws {
        // Given
        let nameWithNewlines = "Ali\nIbn\nAbi Talib"
        let expectedCleanName = "Ali Ibn Abi Talib"
        
        // When
        settingsService.userName = nameWithNewlines.replacingOccurrences(of: "\n", with: " ")
        try await settingsService.saveSettings()
        
        // Then
        XCTAssertEqual(settingsService.userName, expectedCleanName, "Newlines should be handled appropriately")
    }
}
