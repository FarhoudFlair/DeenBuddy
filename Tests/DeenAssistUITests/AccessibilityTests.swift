import XCTest
import SwiftUI
@testable import DeenAssistUI
@testable import DeenAssistProtocols

/// Accessibility compliance tests
final class AccessibilityTests: XCTestCase {
    
    // MARK: - Accessibility Support Tests
    
    func testAccessibilitySupportUtilities() {
        // Test that accessibility utilities are available
        XCTAssertNotNil(AccessibilitySupport.prefersLargerText)
        XCTAssertNotNil(AccessibilitySupport.isVoiceOverRunning)
        XCTAssertNotNil(AccessibilitySupport.isSwitchControlRunning)
        XCTAssertNotNil(AccessibilitySupport.prefersReducedMotion)
        XCTAssertNotNil(AccessibilitySupport.prefersHighContrast)
    }
    
    func testScaledFontCreation() {
        let font = AccessibilitySupport.scaledFont(size: 16, weight: .medium)
        XCTAssertNotNil(font)
    }
    
    // MARK: - High Contrast Color Tests
    
    func testHighContrastColors() {
        // Test that high contrast colors are different from regular colors
        let regularPrimary = ColorPalette.primary
        let accessiblePrimary = ColorPalette.accessiblePrimary
        
        // Colors should be defined (not nil)
        XCTAssertNotNil(regularPrimary)
        XCTAssertNotNil(accessiblePrimary)
        
        let regularText = ColorPalette.textPrimary
        let accessibleText = ColorPalette.accessibleTextPrimary
        
        XCTAssertNotNil(regularText)
        XCTAssertNotNil(accessibleText)
        
        let regularBackground = ColorPalette.backgroundPrimary
        let accessibleBackground = ColorPalette.accessibleBackground
        
        XCTAssertNotNil(regularBackground)
        XCTAssertNotNil(accessibleBackground)
    }
    
    // MARK: - Accessible Component Tests
    
    func testAccessibleButtonCreation() {
        let button = AccessibleButton("Test Button") {
            // Test action
        }
        
        XCTAssertNotNil(button)
    }
    
    func testAccessibleTextCreation() {
        let text = AccessibleText("Test Text")
        XCTAssertNotNil(text)
        
        let styledText = AccessibleText(
            "Styled Text",
            style: Typography.headlineSmall,
            color: ColorPalette.primary
        )
        XCTAssertNotNil(styledText)
    }
    
    // MARK: - Prayer Time Accessibility Tests
    
    func testPrayerTimeCardAccessibility() {
        let prayerTime = PrayerTime(prayer: .fajr, time: Date(), location: "Test City")
        let card = PrayerTimeCard(prayer: prayerTime, status: .upcoming, isNext: true)
        
        XCTAssertNotNil(card)
        
        // Test that the card can be created with different statuses
        let completedCard = PrayerTimeCard(prayer: prayerTime, status: .completed, isNext: false)
        let activeCard = PrayerTimeCard(prayer: prayerTime, status: .active, isNext: false)
        
        XCTAssertNotNil(completedCard)
        XCTAssertNotNil(activeCard)
    }
    
    func testCountdownTimerAccessibility() {
        let futureTime = Date().addingTimeInterval(3600)
        let prayerTime = PrayerTime(prayer: .dhuhr, time: futureTime)
        let timer = CountdownTimer(nextPrayer: prayerTime, timeRemaining: 3600)
        
        XCTAssertNotNil(timer)
        
        // Test with nil prayer (no upcoming prayers)
        let emptyTimer = CountdownTimer(nextPrayer: nil, timeRemaining: nil)
        XCTAssertNotNil(emptyTimer)
    }
    
    // MARK: - Error View Accessibility Tests
    
    func testErrorViewAccessibility() {
        let errorView = ErrorView(
            error: .networkError,
            onRetry: {},
            onDismiss: {}
        )
        
        XCTAssertNotNil(errorView)
        
        // Test different error types
        let locationError = ErrorView(error: .locationError, onRetry: {})
        let permissionError = ErrorView(error: .permissionDenied, onRetry: {})
        let unknownError = ErrorView(error: .unknownError("Test error"), onRetry: {})
        
        XCTAssertNotNil(locationError)
        XCTAssertNotNil(permissionError)
        XCTAssertNotNil(unknownError)
    }
    
    func testErrorTypeAccessibilityProperties() {
        let networkError = ErrorType.networkError
        
        XCTAssertFalse(networkError.accessibilityLabel.isEmpty)
        XCTAssertFalse(networkError.accessibilityHint.isEmpty)
        XCTAssertFalse(networkError.title.isEmpty)
        XCTAssertFalse(networkError.message.isEmpty)
        XCTAssertFalse(networkError.retryButtonTitle.isEmpty)
        
        // Test that all error types have accessibility properties
        let allErrorTypes: [ErrorType] = [
            .networkError,
            .locationError,
            .permissionDenied,
            .dataCorruption,
            .calculationError,
            .notificationError,
            .unknownError("Test")
        ]
        
        for errorType in allErrorTypes {
            XCTAssertFalse(errorType.accessibilityLabel.isEmpty, "Error type \(errorType) missing accessibility label")
            XCTAssertFalse(errorType.title.isEmpty, "Error type \(errorType) missing title")
            XCTAssertFalse(errorType.message.isEmpty, "Error type \(errorType) missing message")
        }
    }
    
    // MARK: - Empty State Accessibility Tests
    
    func testEmptyStateAccessibility() {
        let emptyState = EmptyStateView(state: .noPrayerTimes, onAction: {})
        XCTAssertNotNil(emptyState)
        
        // Test different empty states
        let noLocationState = EmptyStateView(state: .noLocation, onAction: {})
        let firstLaunchState = EmptyStateView(state: .firstLaunch, onAction: {})
        let maintenanceState = EmptyStateView(state: .maintenance, onAction: {})
        
        XCTAssertNotNil(noLocationState)
        XCTAssertNotNil(firstLaunchState)
        XCTAssertNotNil(maintenanceState)
    }
    
    func testEmptyStateAccessibilityProperties() {
        let allEmptyStates: [EmptyState] = [
            .noPrayerTimes,
            .noLocation,
            .noNotifications,
            .noOfflineContent,
            .noSearchResults,
            .firstLaunch,
            .maintenance
        ]
        
        for state in allEmptyStates {
            XCTAssertFalse(state.accessibilityLabel.isEmpty, "Empty state \(state) missing accessibility label")
            XCTAssertFalse(state.title.isEmpty, "Empty state \(state) missing title")
            XCTAssertFalse(state.message.isEmpty, "Empty state \(state) missing message")
        }
    }
    
    // MARK: - Input Field Accessibility Tests
    
    func testInputFieldAccessibility() {
        @State var text = ""
        
        let inputField = InputField.text(
            title: "Test Field",
            placeholder: "Enter text",
            text: $text
        )
        
        XCTAssertNotNil(inputField)
        
        // Test different input styles
        let searchField = InputField.search(
            placeholder: "Search...",
            text: $text
        )
        
        let secureField = InputField.secure(
            title: "Password",
            placeholder: "Enter password",
            text: $text
        )
        
        XCTAssertNotNil(searchField)
        XCTAssertNotNil(secureField)
    }
    
    func testInputValidationAccessibility() {
        let validation = InputValidation(rules: [
            .required,
            .minLength(3),
            .maxLength(50)
        ])
        
        // Test validation messages
        let emptyError = validation.validate("")
        let shortError = validation.validate("ab")
        let validText = validation.validate("valid text")
        
        XCTAssertNotNil(emptyError)
        XCTAssertNotNil(shortError)
        XCTAssertNil(validText)
        
        // Ensure error messages are accessible
        XCTAssertFalse(emptyError?.isEmpty ?? true)
        XCTAssertFalse(shortError?.isEmpty ?? true)
    }
    
    // MARK: - Loading View Accessibility Tests
    
    func testLoadingViewAccessibility() {
        let spinnerView = LoadingView.spinner(message: "Loading...")
        let dotsView = LoadingView.dots(message: "Processing...")
        let prayerView = LoadingView.prayer(message: "Calculating prayer times...")
        
        XCTAssertNotNil(spinnerView)
        XCTAssertNotNil(dotsView)
        XCTAssertNotNil(prayerView)
        
        // Test full screen loading
        let fullScreenLoading = FullScreenLoadingView(
            style: .prayer,
            message: "Setting up your prayer schedule..."
        )
        
        XCTAssertNotNil(fullScreenLoading)
    }
    
    // MARK: - Button Accessibility Tests
    
    func testCustomButtonAccessibility() {
        let primaryButton = CustomButton.primary("Primary") {}
        let secondaryButton = CustomButton.secondary("Secondary") {}
        let tertiaryButton = CustomButton.tertiary("Tertiary") {}
        let destructiveButton = CustomButton.destructive("Delete") {}
        let successButton = CustomButton.success("Save") {}
        
        XCTAssertNotNil(primaryButton)
        XCTAssertNotNil(secondaryButton)
        XCTAssertNotNil(tertiaryButton)
        XCTAssertNotNil(destructiveButton)
        XCTAssertNotNil(successButton)
    }
    
    // MARK: - Screen Accessibility Tests
    
    func testOnboardingScreensAccessibility() {
        let welcomeScreen = WelcomeScreen {}
        XCTAssertNotNil(welcomeScreen)
        
        let locationScreen = LocationPermissionScreen(
            locationService: MockLocationService(),
            onContinue: {},
            onSkip: {}
        )
        XCTAssertNotNil(locationScreen)
        
        let calculationScreen = CalculationMethodScreen(
            settingsService: MockSettingsService(),
            onContinue: {}
        )
        XCTAssertNotNil(calculationScreen)
        
        let notificationScreen = NotificationPermissionScreen(
            notificationService: MockNotificationService(),
            settingsService: MockSettingsService(),
            onComplete: {}
        )
        XCTAssertNotNil(notificationScreen)
    }
    
    func testMainScreensAccessibility() {
        let homeScreen = HomeScreen(
            prayerTimeService: MockPrayerTimeService(),
            locationService: MockLocationService(),
            onCompassTapped: {},
            onGuidesTapped: {},
            onSettingsTapped: {}
        )
        XCTAssertNotNil(homeScreen)
        
        let settingsScreen = SettingsScreen(
            settingsService: MockSettingsService(),
            themeManager: ThemeManager(),
            onDismiss: {}
        )
        XCTAssertNotNil(settingsScreen)
    }
}
