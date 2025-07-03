import XCTest
import SwiftUI
@testable import DeenAssistUI
@testable import DeenAssistProtocols

/// Performance tests for UI components and flows
final class PerformanceTests: XCTestCase {
    
    var coordinator: AppCoordinator!
    var mockServices: (
        location: MockLocationService,
        notification: MockNotificationService,
        prayerTime: MockPrayerTimeService,
        settings: MockSettingsService
    )!
    
    override func setUp() {
        super.setUp()
        
        mockServices = (
            location: MockLocationService(),
            notification: MockNotificationService(),
            prayerTime: MockPrayerTimeService(),
            settings: MockSettingsService()
        )
        
        coordinator = AppCoordinator(
            locationService: mockServices.location,
            notificationService: mockServices.notification,
            prayerTimeService: mockServices.prayerTime,
            settingsService: mockServices.settings,
            themeManager: ThemeManager(settingsService: mockServices.settings)
        )
    }
    
    override func tearDown() {
        coordinator = nil
        mockServices = nil
        super.tearDown()
    }
    
    // MARK: - Component Creation Performance
    
    func testPrayerTimeCardCreationPerformance() {
        let prayerTime = PrayerTime(prayer: .fajr, time: Date(), location: "Test City")
        
        measure {
            for _ in 0..<1000 {
                let card = PrayerTimeCard(prayer: prayerTime, status: .upcoming, isNext: false)
                _ = card.body // Force view creation
            }
        }
    }
    
    func testCountdownTimerCreationPerformance() {
        let futureTime = Date().addingTimeInterval(3600)
        let prayerTime = PrayerTime(prayer: .dhuhr, time: futureTime)
        
        measure {
            for _ in 0..<500 {
                let timer = CountdownTimer(nextPrayer: prayerTime, timeRemaining: 3600)
                _ = timer.body // Force view creation
            }
        }
    }
    
    func testCustomButtonCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                let button = CustomButton.primary("Test Button") {}
                _ = button.body // Force view creation
            }
        }
    }
    
    func testLoadingViewCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                let loadingView = LoadingView.spinner(message: "Loading...")
                _ = loadingView.body // Force view creation
            }
        }
    }
    
    func testErrorViewCreationPerformance() {
        measure {
            for _ in 0..<500 {
                let errorView = ErrorView(error: .networkError, onRetry: {})
                _ = errorView.body // Force view creation
            }
        }
    }
    
    func testEmptyStateViewCreationPerformance() {
        measure {
            for _ in 0..<500 {
                let emptyState = EmptyStateView(state: .noPrayerTimes, onAction: {})
                _ = emptyState.body // Force view creation
            }
        }
    }
    
    // MARK: - Screen Creation Performance
    
    func testWelcomeScreenCreationPerformance() {
        measure {
            for _ in 0..<100 {
                let screen = WelcomeScreen {}
                _ = screen.body // Force view creation
            }
        }
    }
    
    func testHomeScreenCreationPerformance() {
        measure {
            for _ in 0..<50 {
                let screen = HomeScreen(
                    prayerTimeService: mockServices.prayerTime,
                    locationService: mockServices.location,
                    onCompassTapped: {},
                    onGuidesTapped: {},
                    onSettingsTapped: {}
                )
                _ = screen.body // Force view creation
            }
        }
    }
    
    func testSettingsScreenCreationPerformance() {
        measure {
            for _ in 0..<50 {
                let screen = SettingsScreen(
                    settingsService: mockServices.settings,
                    themeManager: ThemeManager(),
                    onDismiss: {}
                )
                _ = screen.body // Force view creation
            }
        }
    }
    
    // MARK: - Animation Performance
    
    func testAnimationPerformance() {
        measure {
            for _ in 0..<100 {
                // Test various animations
                let _ = AppAnimations.quick
                let _ = AppAnimations.standard
                let _ = AppAnimations.smooth
                let _ = AppAnimations.bouncy
                let _ = AppAnimations.smoothSpring
                let _ = AppAnimations.snappy
            }
        }
    }
    
    func testTransitionPerformance() {
        measure {
            for _ in 0..<100 {
                // Test various transitions
                let _ = AppTransitions.slide
                let _ = AppTransitions.fade
                let _ = AppTransitions.scale
                let _ = AppTransitions.push
                let _ = AppTransitions.slideUp
                let _ = AppTransitions.prayerCard
            }
        }
    }
    
    // MARK: - Theme Performance
    
    func testThemeManagerPerformance() {
        let themeManager = ThemeManager()
        
        measure {
            for _ in 0..<1000 {
                themeManager.setTheme(.light)
                themeManager.setTheme(.dark)
                themeManager.setTheme(.system)
            }
        }
    }
    
    func testColorPalettePerformance() {
        measure {
            for _ in 0..<10000 {
                let _ = ColorPalette.primary
                let _ = ColorPalette.secondary
                let _ = ColorPalette.accent
                let _ = ColorPalette.backgroundPrimary
                let _ = ColorPalette.textPrimary
                let _ = ColorPalette.surfacePrimary
            }
        }
    }
    
    // MARK: - Typography Performance
    
    func testTypographyPerformance() {
        measure {
            for _ in 0..<10000 {
                let _ = Typography.displayLarge
                let _ = Typography.headlineLarge
                let _ = Typography.titleLarge
                let _ = Typography.bodyLarge
                let _ = Typography.labelLarge
                let _ = Typography.timerLarge
            }
        }
    }
    
    // MARK: - Mock Service Performance
    
    func testMockLocationServicePerformance() async {
        measure {
            Task {
                for _ in 0..<100 {
                    do {
                        _ = try await mockServices.location.geocodeCity("New York")
                    } catch {
                        // Ignore errors for performance testing
                    }
                }
            }
        }
    }
    
    func testMockPrayerTimeServicePerformance() async {
        measure {
            Task {
                for _ in 0..<100 {
                    await mockServices.prayerTime.refreshPrayerTimes()
                }
            }
        }
    }
    
    func testMockNotificationServicePerformance() async {
        measure {
            Task {
                for _ in 0..<100 {
                    do {
                        _ = try await mockServices.notification.requestNotificationPermission()
                    } catch {
                        // Ignore errors for performance testing
                    }
                }
            }
        }
    }
    
    func testMockSettingsServicePerformance() async {
        measure {
            Task {
                for _ in 0..<100 {
                    do {
                        try await mockServices.settings.saveSettings()
                        try await mockServices.settings.loadSettings()
                    } catch {
                        // Ignore errors for performance testing
                    }
                }
            }
        }
    }
    
    // MARK: - Navigation Performance
    
    func testNavigationPerformance() {
        measure {
            for _ in 0..<1000 {
                coordinator.showHome()
                coordinator.showSettings()
                coordinator.dismissSettings()
                coordinator.showCompass()
                coordinator.dismissCompass()
                coordinator.showGuides()
                coordinator.dismissGuides()
            }
        }
    }
    
    // MARK: - Accessibility Performance
    
    func testAccessibilityPerformance() {
        measure {
            for _ in 0..<1000 {
                let _ = AccessibilitySupport.prefersLargerText
                let _ = AccessibilitySupport.isVoiceOverRunning
                let _ = AccessibilitySupport.prefersReducedMotion
                let _ = AccessibilitySupport.prefersHighContrast
            }
        }
    }
    
    func testAccessibleComponentPerformance() {
        measure {
            for _ in 0..<500 {
                let button = AccessibleButton("Test") {}
                _ = button.body // Force view creation
                
                let text = AccessibleText("Test Text")
                _ = text.body // Force view creation
            }
        }
    }
    
    // MARK: - Input Field Performance
    
    func testInputFieldPerformance() {
        @State var text = ""
        
        measure {
            for _ in 0..<500 {
                let field = InputField.text(
                    title: "Test",
                    placeholder: "Enter text",
                    text: $text
                )
                _ = field.body // Force view creation
            }
        }
    }
    
    func testInputValidationPerformance() {
        let validation = InputValidation(rules: [
            .required,
            .minLength(3),
            .maxLength(50),
            .email
        ])
        
        measure {
            for _ in 0..<10000 {
                _ = validation.validate("test@example.com")
                _ = validation.validate("short")
                _ = validation.validate("")
                _ = validation.validate("valid text input")
            }
        }
    }
    
    // MARK: - Memory Performance
    
    func testMemoryUsage() {
        // Create many components to test memory usage
        var components: [Any] = []
        
        measure {
            for i in 0..<1000 {
                let prayerTime = PrayerTime(prayer: .fajr, time: Date(), location: "City \(i)")
                let card = PrayerTimeCard(prayer: prayerTime, status: .upcoming, isNext: false)
                components.append(card)
                
                let button = CustomButton.primary("Button \(i)") {}
                components.append(button)
                
                let loadingView = LoadingView.spinner(message: "Loading \(i)")
                components.append(loadingView)
            }
        }
        
        // Clear components to test cleanup
        components.removeAll()
    }
}
