import XCTest
import SwiftUI
@testable import DeenAssistUI
@testable import DeenAssistProtocols

/// Comprehensive UI flow tests
final class UIFlowTests: XCTestCase {
    
    var coordinator: AppCoordinator!
    var mockLocationService: MockLocationService!
    var mockNotificationService: MockNotificationService!
    var mockPrayerTimeService: MockPrayerTimeService!
    var mockSettingsService: MockSettingsService!
    var themeManager: ThemeManager!
    
    override func setUp() {
        super.setUp()
        
        mockLocationService = MockLocationService()
        mockNotificationService = MockNotificationService()
        mockPrayerTimeService = MockPrayerTimeService()
        mockSettingsService = MockSettingsService()
        themeManager = ThemeManager(settingsService: mockSettingsService)
        
        coordinator = AppCoordinator(
            locationService: mockLocationService,
            notificationService: mockNotificationService,
            prayerTimeService: mockPrayerTimeService,
            settingsService: mockSettingsService,
            themeManager: themeManager
        )
    }
    
    override func tearDown() {
        coordinator = nil
        mockLocationService = nil
        mockNotificationService = nil
        mockPrayerTimeService = nil
        mockSettingsService = nil
        themeManager = nil
        super.tearDown()
    }
    
    // MARK: - Onboarding Flow Tests
    
    func testOnboardingFlowCompletion() async {
        // Given: Fresh app launch
        XCTAssertEqual(coordinator.currentScreen, .loading)
        XCTAssertFalse(mockSettingsService.hasCompletedOnboarding)
        
        // When: App starts
        coordinator.start()
        
        // Wait for initial screen determination
        try? await Task.sleep(nanoseconds: 1_100_000_000)
        
        // Then: Should show onboarding
        await MainActor.run {
            XCTAssertEqual(coordinator.currentScreen, .onboarding(.welcome))
        }
        
        // When: Complete onboarding
        await MainActor.run {
            coordinator.completeOnboarding()
        }
        
        // Then: Should navigate to home and mark onboarding complete
        await MainActor.run {
            XCTAssertEqual(coordinator.currentScreen, .home)
            XCTAssertTrue(mockSettingsService.hasCompletedOnboarding)
        }
    }
    
    func testOnboardingSkipsWhenCompleted() async {
        // Given: Onboarding already completed
        mockSettingsService.hasCompletedOnboarding = true
        
        // When: App starts
        coordinator.start()
        
        // Wait for initial screen determination
        try? await Task.sleep(nanoseconds: 1_100_000_000)
        
        // Then: Should go directly to home
        await MainActor.run {
            XCTAssertEqual(coordinator.currentScreen, .home)
        }
    }
    
    // MARK: - Navigation Tests
    
    func testNavigationToSettings() {
        // Given: App is on home screen
        coordinator.showHome()
        XCTAssertFalse(coordinator.showingSettings)
        
        // When: Navigate to settings
        coordinator.showSettings()
        
        // Then: Settings should be shown
        XCTAssertTrue(coordinator.showingSettings)
        
        // When: Dismiss settings
        coordinator.dismissSettings()
        
        // Then: Settings should be hidden
        XCTAssertFalse(coordinator.showingSettings)
    }
    
    func testNavigationToCompass() {
        // Given: App is on home screen
        coordinator.showHome()
        XCTAssertFalse(coordinator.showingCompass)
        
        // When: Navigate to compass
        coordinator.showCompass()
        
        // Then: Compass should be shown
        XCTAssertTrue(coordinator.showingCompass)
        
        // When: Dismiss compass
        coordinator.dismissCompass()
        
        // Then: Compass should be hidden
        XCTAssertFalse(coordinator.showingCompass)
    }
    
    func testNavigationToGuides() {
        // Given: App is on home screen
        coordinator.showHome()
        XCTAssertFalse(coordinator.showingGuides)
        
        // When: Navigate to guides
        coordinator.showGuides()
        
        // Then: Guides should be shown
        XCTAssertTrue(coordinator.showingGuides)
        
        // When: Dismiss guides
        coordinator.dismissGuides()
        
        // Then: Guides should be hidden
        XCTAssertFalse(coordinator.showingGuides)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() {
        // Given: App is running normally
        XCTAssertFalse(coordinator.showingError)
        XCTAssertNil(coordinator.currentError)
        
        // When: An error occurs
        let error = ErrorType.networkError
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
    
    // MARK: - Loading State Tests
    
    func testLoadingState() {
        // Given: App is not loading
        XCTAssertFalse(coordinator.isLoading)
        
        // When: Loading starts
        coordinator.setLoading(true)
        
        // Then: Loading state should be active
        XCTAssertTrue(coordinator.isLoading)
        
        // When: Loading ends
        coordinator.setLoading(false)
        
        // Then: Loading state should be inactive
        XCTAssertFalse(coordinator.isLoading)
    }
    
    // MARK: - Deep Link Tests
    
    func testDeepLinkHandling() {
        // Given: App is running
        coordinator.showHome()
        
        // When: Settings deep link is received
        let settingsURL = URL(string: "deenassist://settings")!
        coordinator.handleDeepLink(settingsURL)
        
        // Then: Settings should be shown
        XCTAssertTrue(coordinator.showingSettings)
        
        // When: Compass deep link is received
        coordinator.dismissSettings()
        let compassURL = URL(string: "deenassist://compass")!
        coordinator.handleDeepLink(compassURL)
        
        // Then: Compass should be shown
        XCTAssertTrue(coordinator.showingCompass)
        
        // When: Guides deep link is received
        coordinator.dismissCompass()
        let guidesURL = URL(string: "deenassist://guides")!
        coordinator.handleDeepLink(guidesURL)
        
        // Then: Guides should be shown
        XCTAssertTrue(coordinator.showingGuides)
    }
    
    // MARK: - Theme Management Tests
    
    func testThemeManagement() {
        // Given: Default theme
        XCTAssertEqual(themeManager.currentTheme, .system)
        
        // When: Theme is changed to light
        themeManager.setTheme(.light)
        
        // Then: Theme should be updated
        XCTAssertEqual(themeManager.currentTheme, .light)
        XCTAssertEqual(themeManager.getColorScheme(), .light)
        
        // When: Theme is changed to dark
        themeManager.setTheme(.dark)
        
        // Then: Theme should be updated
        XCTAssertEqual(themeManager.currentTheme, .dark)
        XCTAssertEqual(themeManager.getColorScheme(), .dark)
        
        // When: Theme is changed to system
        themeManager.setTheme(.system)
        
        // Then: Theme should be updated
        XCTAssertEqual(themeManager.currentTheme, .system)
        XCTAssertNil(themeManager.getColorScheme())
    }
    
    // MARK: - Service Integration Tests
    
    func testLocationServiceIntegration() async {
        // Given: Location service is available
        XCTAssertEqual(mockLocationService.authorizationStatus, .notDetermined)
        
        // When: Location permission is requested
        mockLocationService.requestLocationPermission()
        
        // Wait for permission update
        try? await Task.sleep(nanoseconds: 1_100_000_000)
        
        // Then: Permission should be granted
        await MainActor.run {
            XCTAssertEqual(mockLocationService.authorizationStatus, .authorizedWhenInUse)
        }
    }
    
    func testNotificationServiceIntegration() async {
        // Given: Notification service is available
        XCTAssertEqual(mockNotificationService.authorizationStatus, .notDetermined)
        
        // When: Notification permission is requested
        do {
            let granted = try await mockNotificationService.requestNotificationPermission()
            
            // Then: Permission should be granted
            XCTAssertTrue(granted)
            XCTAssertEqual(mockNotificationService.authorizationStatus, .authorized)
        } catch {
            XCTFail("Notification permission request should not fail in mock")
        }
    }
    
    func testPrayerTimeServiceIntegration() {
        // Given: Prayer time service is available
        XCTAssertFalse(mockPrayerTimeService.todaysPrayerTimes.isEmpty)
        
        // When: Prayer times are accessed
        let prayerTimes = mockPrayerTimeService.todaysPrayerTimes
        
        // Then: Should have all 5 prayers
        XCTAssertEqual(prayerTimes.count, 5)
        XCTAssertTrue(prayerTimes.contains { $0.prayer == .fajr })
        XCTAssertTrue(prayerTimes.contains { $0.prayer == .dhuhr })
        XCTAssertTrue(prayerTimes.contains { $0.prayer == .asr })
        XCTAssertTrue(prayerTimes.contains { $0.prayer == .maghrib })
        XCTAssertTrue(prayerTimes.contains { $0.prayer == .isha })
    }
}
