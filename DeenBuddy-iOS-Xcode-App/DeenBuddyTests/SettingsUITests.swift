//
//  SettingsUITests.swift
//  DeenBuddyTests
//
//  Created by Farhoud Talebi on 2025-07-18.
//

import XCTest
import SwiftUI
@testable import DeenBuddy

/// Tests for Settings UI synchronization
@MainActor
class SettingsUITests: XCTestCase {
    
    var settingsService: SettingsService!
    var themeManager: ThemeManager!
    
    override func setUp() async throws {
        try await super.setUp()
        settingsService = SettingsService()
        themeManager = ThemeManager(settingsService: settingsService)
        
        // Load initial settings
        try await settingsService.loadSettings()
    }
    
    override func tearDown() async throws {
        settingsService = nil
        themeManager = nil
        try await super.tearDown()
    }
    
    /// Test that changing calculation method updates the UI
    func testCalculationMethodUISync() async throws {
        // Given: Initial calculation method
        let initialMethod = settingsService.calculationMethod
        let newMethod: CalculationMethod = initialMethod == .muslimWorldLeague ? .egyptian : .muslimWorldLeague
        
        // When: Change calculation method
        settingsService.calculationMethod = newMethod
        
        // Then: Settings service should reflect the change
        XCTAssertEqual(settingsService.calculationMethod, newMethod)
        
        // And: The change should be persisted
        try await settingsService.saveSettings()
        
        // Create a new instance to verify persistence
        let newSettingsService = SettingsService()
        try await newSettingsService.loadSettings()
        XCTAssertEqual(newSettingsService.calculationMethod, newMethod)
    }
    
    /// Test that changing madhab updates the UI
    func testMadhabUISync() async throws {
        // Given: Initial madhab
        let initialMadhab = settingsService.madhab
        let newMadhab: Madhab = initialMadhab == .shafi ? .hanafi : .shafi
        
        // When: Change madhab
        settingsService.madhab = newMadhab
        
        // Then: Settings service should reflect the change
        XCTAssertEqual(settingsService.madhab, newMadhab)
        
        // And: The change should be persisted
        try await settingsService.saveSettings()
        
        // Create a new instance to verify persistence
        let newSettingsService = SettingsService()
        try await newSettingsService.loadSettings()
        XCTAssertEqual(newSettingsService.madhab, newMadhab)
    }
    
    /// Test that multiple setting changes work correctly
    func testMultipleSettingsUISync() async throws {
        // Given: Initial settings
        let initialMethod = settingsService.calculationMethod
        let initialMadhab = settingsService.madhab
        
        let newMethod: CalculationMethod = initialMethod == .muslimWorldLeague ? .egyptian : .muslimWorldLeague
        let newMadhab: Madhab = initialMadhab == .shafi ? .hanafi : .shafi
        
        // When: Change multiple settings
        settingsService.calculationMethod = newMethod
        settingsService.madhab = newMadhab
        
        // Then: Both changes should be reflected
        XCTAssertEqual(settingsService.calculationMethod, newMethod)
        XCTAssertEqual(settingsService.madhab, newMadhab)
        
        // And: Both changes should be persisted
        try await settingsService.saveSettings()
        
        // Create a new instance to verify persistence
        let newSettingsService = SettingsService()
        try await newSettingsService.loadSettings()
        XCTAssertEqual(newSettingsService.calculationMethod, newMethod)
        XCTAssertEqual(newSettingsService.madhab, newMadhab)
    }
    
    /// Test that settings changes trigger notifications
    func testSettingsChangeNotifications() async throws {
        // Given: Notification expectation
        let expectation = XCTestExpectation(description: "Settings change notification")
        
        let observer = NotificationCenter.default.addObserver(
            forName: .settingsDidChange,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        
        defer {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // When: Change a setting
        let newMethod: CalculationMethod = settingsService.calculationMethod == .muslimWorldLeague ? .egyptian : .muslimWorldLeague
        settingsService.calculationMethod = newMethod
        
        // Then: Notification should be posted
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    /// Test EnhancedSettingsView initialization
    func testEnhancedSettingsViewInitialization() {
        // Given: Settings service and theme manager
        let settingsService = SettingsService()
        let themeManager = ThemeManager(settingsService: settingsService)
        
        // When: Create EnhancedSettingsView
        let settingsView = EnhancedSettingsView(
            settingsService: settingsService,
            themeManager: themeManager,
            onDismiss: { }
        )
        
        // Then: View should be created successfully
        XCTAssertNotNil(settingsView)
    }
    
    /// Test SettingsScreen initialization
    func testSettingsScreenInitialization() {
        // Given: Settings service and theme manager
        let settingsService = SettingsService()
        let themeManager = ThemeManager(settingsService: settingsService)
        
        // When: Create SettingsScreen
        let settingsScreen = SettingsScreen(
            settingsService: settingsService,
            themeManager: themeManager,
            onDismiss: { }
        )
        
        // Then: View should be created successfully
        XCTAssertNotNil(settingsScreen)
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let settingsDidChange = Notification.Name("settingsDidChange")
}
