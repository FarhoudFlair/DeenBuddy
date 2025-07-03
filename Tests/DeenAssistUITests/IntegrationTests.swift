import XCTest
import SwiftUI
@testable import DeenAssistUI
@testable import DeenAssistProtocols

/// Integration tests for complete UI flows and component interactions
final class IntegrationTests: XCTestCase {
    
    var coordinator: AppCoordinator!
    var mockServices: (
        location: MockLocationService,
        notification: MockNotificationService,
        prayerTime: MockPrayerTimeService,
        settings: MockSettingsService
    )!
    var themeManager: ThemeManager!
    
    override func setUp() {
        super.setUp()
        
        mockServices = (
            location: MockLocationService(),
            notification: MockNotificationService(),
            prayerTime: MockPrayerTimeService(),
            settings: MockSettingsService()
        )
        
        themeManager = ThemeManager(settingsService: mockServices.settings)
        
        coordinator = AppCoordinator(
            locationService: mockServices.location,
            notificationService: mockServices.notification,
            prayerTimeService: mockServices.prayerTime,
            settingsService: mockServices.settings,
            themeManager: themeManager
        )
    }
    
    override func tearDown() {
        coordinator = nil
        mockServices = nil
        themeManager = nil
        super.tearDown()
    }
    
    // MARK: - Complete App Flow Tests
    
    func testCompleteOnboardingToHomeFlow() async {
        // Given: Fresh app launch
        XCTAssertEqual(coordinator.currentScreen, .loading)
        XCTAssertFalse(mockServices.settings.hasCompletedOnboarding)
        
        // When: App starts
        coordinator.start()
        
        // Wait for loading
        try? await Task.sleep(nanoseconds: 1_100_000_000)
        
        // Then: Should show onboarding
        await MainActor.run {
            XCTAssertEqual(coordinator.currentScreen, .onboarding(.welcome))
        }
        
        // When: Complete onboarding steps
        await MainActor.run {
            // Simulate onboarding completion
            coordinator.completeOnboarding()
        }
        
        // Then: Should be on home screen with onboarding marked complete
        await MainActor.run {
            XCTAssertEqual(coordinator.currentScreen, .home)
            XCTAssertTrue(mockServices.settings.hasCompletedOnboarding)
        }
    }
    
    func testCompleteSettingsFlow() async {
        // Given: App is on home screen
        coordinator.showHome()
        
        // When: Navigate to settings
        coordinator.showSettings()
        XCTAssertTrue(coordinator.showingSettings)
        
        // When: Change settings
        let originalMethod = mockServices.settings.calculationMethod
        let originalMadhab = mockServices.settings.madhab
        let originalTheme = themeManager.currentTheme
        
        mockServices.settings.calculationMethod = .egyptian
        mockServices.settings.madhab = .hanafi
        themeManager.setTheme(.dark)
        
        // Then: Settings should be updated
        XCTAssertNotEqual(mockServices.settings.calculationMethod, originalMethod)
        XCTAssertNotEqual(mockServices.settings.madhab, originalMadhab)
        XCTAssertNotEqual(themeManager.currentTheme, originalTheme)
        
        // When: Save and dismiss settings
        do {
            try await mockServices.settings.saveSettings()
        } catch {
            XCTFail("Settings save should not fail")
        }
        
        coordinator.dismissSettings()
        XCTAssertFalse(coordinator.showingSettings)
    }
    
    func testLocationPermissionFlow() async {
        // Given: Location permission not determined
        XCTAssertEqual(mockServices.location.authorizationStatus, .notDetermined)
        
        // When: Request location permission
        mockServices.location.requestLocationPermission()
        
        // Wait for permission update
        try? await Task.sleep(nanoseconds: 1_100_000_000)
        
        // Then: Permission should be granted
        await MainActor.run {
            XCTAssertEqual(mockServices.location.authorizationStatus, .authorizedWhenInUse)
        }
        
        // When: Start location updates
        await MainActor.run {
            mockServices.location.startUpdatingLocation()
            XCTAssertTrue(mockServices.location.isUpdatingLocation)
        }
        
        // Wait for location update
        try? await Task.sleep(nanoseconds: 2_100_000_000)
        
        // Then: Should have location
        await MainActor.run {
            XCTAssertNotNil(mockServices.location.currentLocation)
            XCTAssertFalse(mockServices.location.isUpdatingLocation)
        }
    }
    
    func testNotificationPermissionFlow() async {
        // Given: Notification permission not determined
        XCTAssertEqual(mockServices.notification.authorizationStatus, .notDetermined)
        XCTAssertFalse(mockServices.notification.notificationsEnabled)
        
        // When: Request notification permission
        do {
            let granted = try await mockServices.notification.requestNotificationPermission()
            
            // Then: Permission should be granted
            XCTAssertTrue(granted)
            XCTAssertEqual(mockServices.notification.authorizationStatus, .authorized)
            XCTAssertTrue(mockServices.notification.notificationsEnabled)
            
            // When: Schedule notifications
            let prayerTimes = mockServices.prayerTime.todaysPrayerTimes
            try await mockServices.notification.schedulePrayerNotifications(for: prayerTimes)
            
            // Then: Should complete without error
            XCTAssertTrue(true) // If we reach here, scheduling succeeded
            
        } catch {
            XCTFail("Notification flow should not fail: \(error)")
        }
    }
    
    // MARK: - Component Integration Tests
    
    func testPrayerTimeCardWithRealData() {
        // Given: Real prayer time data
        let prayerTimes = mockServices.prayerTime.todaysPrayerTimes
        XCTAssertFalse(prayerTimes.isEmpty)
        
        // When: Create prayer time cards
        for (index, prayerTime) in prayerTimes.enumerated() {
            let isNext = index == 0 // First prayer is next
            let status: PrayerStatus = isNext ? .upcoming : .completed
            
            let card = PrayerTimeCard(
                prayer: prayerTime,
                status: status,
                isNext: isNext
            )
            
            // Then: Card should be created successfully
            XCTAssertNotNil(card)
        }
    }
    
    func testCountdownTimerWithRealData() {
        // Given: Next prayer from service
        let nextPrayer = mockServices.prayerTime.nextPrayer
        let timeRemaining = mockServices.prayerTime.timeUntilNextPrayer
        
        // When: Create countdown timer
        let timer = CountdownTimer(
            nextPrayer: nextPrayer,
            timeRemaining: timeRemaining
        )
        
        // Then: Timer should be created successfully
        XCTAssertNotNil(timer)
    }
    
    func testHomeScreenWithAllServices() {
        // Given: All services are available
        XCTAssertNotNil(mockServices.prayerTime)
        XCTAssertNotNil(mockServices.location)
        
        // When: Create home screen
        let homeScreen = HomeScreen(
            prayerTimeService: mockServices.prayerTime,
            locationService: mockServices.location,
            onCompassTapped: {
                self.coordinator.showCompass()
            },
            onGuidesTapped: {
                self.coordinator.showGuides()
            },
            onSettingsTapped: {
                self.coordinator.showSettings()
            }
        )
        
        // Then: Home screen should be created successfully
        XCTAssertNotNil(homeScreen)
        
        // When: Trigger actions
        coordinator.showCompass()
        XCTAssertTrue(coordinator.showingCompass)
        
        coordinator.dismissCompass()
        coordinator.showGuides()
        XCTAssertTrue(coordinator.showingGuides)
        
        coordinator.dismissGuides()
        coordinator.showSettings()
        XCTAssertTrue(coordinator.showingSettings)
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testErrorHandlingFlow() {
        // Given: App is running normally
        XCTAssertFalse(coordinator.showingError)
        
        // When: Various errors occur
        let errors: [ErrorType] = [
            .networkError,
            .locationError,
            .permissionDenied,
            .calculationError,
            .notificationError,
            .unknownError("Test error")
        ]
        
        for error in errors {
            // When: Error is shown
            coordinator.showError(error)
            
            // Then: Error should be displayed
            XCTAssertTrue(coordinator.showingError)
            XCTAssertEqual(coordinator.currentError, error)
            
            // When: Error is dismissed
            coordinator.dismissError()
            
            // Then: Error should be cleared
            XCTAssertFalse(coordinator.showingError)
            XCTAssertNil(coordinator.currentError)
        }
    }
    
    // MARK: - Theme Integration Tests
    
    func testThemeIntegrationWithSettings() {
        // Given: Theme manager with settings service
        let themeManager = ThemeManager(settingsService: mockServices.settings)
        
        // When: Theme is changed
        themeManager.setTheme(.light)
        
        // Then: Settings should be updated
        XCTAssertEqual(mockServices.settings.theme, .light)
        XCTAssertEqual(themeManager.currentTheme, .light)
        
        // When: Theme is changed again
        themeManager.setTheme(.dark)
        
        // Then: Settings should be updated again
        XCTAssertEqual(mockServices.settings.theme, .dark)
        XCTAssertEqual(themeManager.currentTheme, .dark)
    }
    
    // MARK: - Accessibility Integration Tests
    
    func testAccessibilityIntegrationWithComponents() {
        // Test that accessibility features work with real components
        let prayerTime = PrayerTime(prayer: .fajr, time: Date(), location: "Test City")
        
        // Create components with accessibility
        let card = PrayerTimeCard(prayer: prayerTime, status: .upcoming, isNext: true)
        let button = AccessibleButton("Test Button") {}
        let text = AccessibleText("Test Text")
        let loadingView = LoadingView.spinner(message: "Loading...")
        let errorView = ErrorView(error: .networkError, onRetry: {})
        
        // All components should be created successfully
        XCTAssertNotNil(card)
        XCTAssertNotNil(button)
        XCTAssertNotNil(text)
        XCTAssertNotNil(loadingView)
        XCTAssertNotNil(errorView)
    }
    
    // MARK: - Performance Integration Tests
    
    func testCompleteAppPerformance() {
        measure {
            // Create complete app structure
            let coordinator = AppCoordinator.mock()
            let app = DeenAssistApp(coordinator: coordinator)
            
            // Force view creation
            _ = app.body
            
            // Simulate navigation
            coordinator.showHome()
            coordinator.showSettings()
            coordinator.dismissSettings()
            coordinator.showCompass()
            coordinator.dismissCompass()
            coordinator.showGuides()
            coordinator.dismissGuides()
        }
    }
    
    // MARK: - Data Flow Integration Tests
    
    func testDataFlowBetweenComponents() async {
        // Given: Services with data
        XCTAssertFalse(mockServices.prayerTime.todaysPrayerTimes.isEmpty)
        
        // When: Data changes in service
        await mockServices.prayerTime.refreshPrayerTimes()
        
        // Then: Components should be able to access updated data
        let updatedPrayerTimes = mockServices.prayerTime.todaysPrayerTimes
        XCTAssertFalse(updatedPrayerTimes.isEmpty)
        
        // When: Settings change
        let originalMethod = mockServices.settings.calculationMethod
        mockServices.settings.calculationMethod = .egyptian
        
        // Then: Change should be reflected
        XCTAssertNotEqual(mockServices.settings.calculationMethod, originalMethod)
        XCTAssertEqual(mockServices.settings.calculationMethod, .egyptian)
    }
    
    // MARK: - Localization Integration Tests
    
    func testLocalizationIntegration() {
        // Test that localized strings are available
        XCTAssertFalse(LocalizedStrings.appName.isEmpty)
        XCTAssertFalse(LocalizedStrings.appTagline.isEmpty)
        XCTAssertFalse(LocalizedStrings.welcomeTitle.isEmpty)
        XCTAssertFalse(LocalizedStrings.nextPrayer.isEmpty)
        
        // Test prayer name localization
        for prayerType in PrayerType.allCases {
            XCTAssertFalse(prayerType.localizedDisplayName.isEmpty)
        }
        
        // Test theme localization
        for theme in ThemeMode.allCases {
            XCTAssertFalse(theme.localizedDisplayName.isEmpty)
        }
    }
}
