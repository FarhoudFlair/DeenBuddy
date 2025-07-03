import XCTest
import SwiftUI
@testable import DeenAssistUI
@testable import DeenAssistProtocols

/// Tests for UI components
final class ComponentTests: XCTestCase {
    
    // MARK: - Prayer Time Card Tests
    
    func testPrayerTimeCardCreation() {
        let prayerTime = PrayerTime(prayer: .fajr, time: Date(), location: "Test City")
        let card = PrayerTimeCard(prayer: prayerTime, status: .upcoming, isNext: true)
        
        XCTAssertNotNil(card)
    }
    
    // MARK: - Countdown Timer Tests
    
    func testCountdownTimerWithValidPrayer() {
        let futureTime = Date().addingTimeInterval(3600) // 1 hour from now
        let prayerTime = PrayerTime(prayer: .dhuhr, time: futureTime)
        let timer = CountdownTimer(nextPrayer: prayerTime, timeRemaining: 3600)
        
        XCTAssertNotNil(timer)
    }
    
    func testCountdownTimerWithNilPrayer() {
        let timer = CountdownTimer(nextPrayer: nil, timeRemaining: nil)
        
        XCTAssertNotNil(timer)
    }
    
    // MARK: - Custom Button Tests
    
    func testCustomButtonCreation() {
        let button = CustomButton.primary("Test Button") {
            // Test action
        }
        
        XCTAssertNotNil(button)
    }
    
    func testCustomButtonStyles() {
        let primaryButton = CustomButton.primary("Primary") {}
        let secondaryButton = CustomButton.secondary("Secondary") {}
        let tertiaryButton = CustomButton.tertiary("Tertiary") {}
        let destructiveButton = CustomButton.destructive("Destructive") {}
        let successButton = CustomButton.success("Success") {}
        
        XCTAssertNotNil(primaryButton)
        XCTAssertNotNil(secondaryButton)
        XCTAssertNotNil(tertiaryButton)
        XCTAssertNotNil(destructiveButton)
        XCTAssertNotNil(successButton)
    }
    
    // MARK: - Loading View Tests
    
    func testLoadingViewStyles() {
        let spinnerView = LoadingView.spinner(message: "Loading...")
        let dotsView = LoadingView.dots(message: "Processing...")
        let pulseView = LoadingView.pulse(message: "Syncing...")
        let prayerView = LoadingView.prayer(message: "Calculating...")
        
        XCTAssertNotNil(spinnerView)
        XCTAssertNotNil(dotsView)
        XCTAssertNotNil(pulseView)
        XCTAssertNotNil(prayerView)
    }
    
    // MARK: - Theme Manager Tests
    
    func testThemeManagerInitialization() {
        let themeManager = ThemeManager()
        
        XCTAssertEqual(themeManager.currentTheme, .system)
    }
    
    func testThemeManagerSetTheme() {
        let themeManager = ThemeManager()
        
        themeManager.setTheme(.light)
        XCTAssertEqual(themeManager.currentTheme, .light)
        
        themeManager.setTheme(.dark)
        XCTAssertEqual(themeManager.currentTheme, .dark)
        
        themeManager.setTheme(.system)
        XCTAssertEqual(themeManager.currentTheme, .system)
    }
    
    func testThemeManagerColorScheme() {
        let themeManager = ThemeManager()
        
        themeManager.setTheme(.light)
        XCTAssertEqual(themeManager.getColorScheme(), .light)
        
        themeManager.setTheme(.dark)
        XCTAssertEqual(themeManager.getColorScheme(), .dark)
        
        themeManager.setTheme(.system)
        XCTAssertNil(themeManager.getColorScheme())
    }
}

// MARK: - Mock Service Tests

final class MockServiceTests: XCTestCase {
    
    func testMockLocationService() async {
        let locationService = MockLocationService()
        
        XCTAssertEqual(locationService.authorizationStatus, .notDetermined)
        XCTAssertNil(locationService.currentLocation)
        XCTAssertFalse(locationService.isUpdatingLocation)
        
        // Test geocoding
        do {
            let location = try await locationService.geocodeCity("New York")
            XCTAssertNotNil(location)
            XCTAssertEqual(location.coordinate.latitude, 40.7128, accuracy: 0.001)
            XCTAssertEqual(location.coordinate.longitude, -74.0060, accuracy: 0.001)
        } catch {
            XCTFail("Geocoding should not fail for known city")
        }
    }
    
    func testMockPrayerTimeService() {
        let prayerService = MockPrayerTimeService()
        
        XCTAssertFalse(prayerService.isLoading)
        XCTAssertEqual(prayerService.calculationMethod, .muslimWorldLeague)
        XCTAssertEqual(prayerService.madhab, .shafi)
        XCTAssertFalse(prayerService.todaysPrayerTimes.isEmpty)
    }
    
    func testMockNotificationService() async {
        let notificationService = MockNotificationService()
        
        XCTAssertEqual(notificationService.authorizationStatus, .notDetermined)
        XCTAssertFalse(notificationService.notificationsEnabled)
        
        // Test permission request
        do {
            let granted = try await notificationService.requestNotificationPermission()
            XCTAssertTrue(granted)
            XCTAssertEqual(notificationService.authorizationStatus, .authorized)
            XCTAssertTrue(notificationService.notificationsEnabled)
        } catch {
            XCTFail("Mock notification permission should not fail")
        }
    }
    
    func testMockSettingsService() async {
        let settingsService = MockSettingsService()
        
        XCTAssertEqual(settingsService.calculationMethod, .muslimWorldLeague)
        XCTAssertEqual(settingsService.madhab, .shafi)
        XCTAssertTrue(settingsService.notificationsEnabled)
        XCTAssertEqual(settingsService.theme, .system)
        XCTAssertFalse(settingsService.hasCompletedOnboarding)
        
        // Test settings modification
        settingsService.calculationMethod = .egyptian
        settingsService.madhab = .hanafi
        settingsService.theme = .dark
        settingsService.hasCompletedOnboarding = true
        
        XCTAssertEqual(settingsService.calculationMethod, .egyptian)
        XCTAssertEqual(settingsService.madhab, .hanafi)
        XCTAssertEqual(settingsService.theme, .dark)
        XCTAssertTrue(settingsService.hasCompletedOnboarding)
        
        // Test save and reset
        do {
            try await settingsService.saveSettings()
            try await settingsService.resetToDefaults()
            
            XCTAssertEqual(settingsService.calculationMethod, .muslimWorldLeague)
            XCTAssertEqual(settingsService.madhab, .shafi)
            XCTAssertEqual(settingsService.theme, .system)
            XCTAssertFalse(settingsService.hasCompletedOnboarding)
        } catch {
            XCTFail("Mock settings operations should not fail")
        }
    }
}
