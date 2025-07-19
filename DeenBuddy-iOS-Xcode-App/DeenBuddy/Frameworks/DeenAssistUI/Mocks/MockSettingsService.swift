import Foundation
import Combine

/// Mock implementation of SettingsServiceProtocol for UI development
@MainActor
public class MockSettingsService: SettingsServiceProtocol {
    @Published public var calculationMethod: CalculationMethod = .muslimWorldLeague
    @Published public var madhab: Madhab = .shafi
    @Published public var notificationsEnabled: Bool = true
    @Published public var theme: ThemeMode = .dark
    @Published public var timeFormat: TimeFormat = .twelveHour
    @Published public var notificationOffset: TimeInterval = 300
    @Published public var hasCompletedOnboarding: Bool = false
    @Published public var userName: String = ""
    @Published public var overrideBatteryOptimization: Bool = false
    @Published public var showArabicSymbolInWidget: Bool = true

    public var enableNotifications: Bool {
        get { notificationsEnabled }
        set { notificationsEnabled = newValue }
    }
    
    public init() {}
    
    public func saveSettings() async throws {
        // Simulate save delay
        try await Task.sleep(nanoseconds: 200_000_000)
        
        print("Mock: Settings saved")
        print("- Calculation Method: \(calculationMethod.displayName)")
        print("- Madhab: \(madhab.displayName)")
        print("- Notifications: \(notificationsEnabled)")
        print("- Theme: \(theme.displayName)")
        print("- Time Format: \(timeFormat.displayName)")
        print("- Notification Offset: \(notificationOffset)")
        print("- Onboarding Complete: \(hasCompletedOnboarding)")
        print("- User Name: \(userName)")
        print("- Override Battery Optimization: \(overrideBatteryOptimization)")
        print("- Show Arabic Symbol in Widget: \(showArabicSymbolInWidget)")
    }
    
    public func loadSettings() async throws {
        // Simulate load delay
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Mock loading some saved settings
        calculationMethod = .muslimWorldLeague
        madhab = .shafi
        notificationsEnabled = true
        theme = .dark
        timeFormat = .twelveHour
        notificationOffset = 300
        hasCompletedOnboarding = false
        userName = ""
        overrideBatteryOptimization = false
        showArabicSymbolInWidget = true

        print("Mock: Settings loaded")
    }
    
    public func resetToDefaults() async throws {
        // Simulate reset delay
        try await Task.sleep(nanoseconds: 100_000_000)
        
        calculationMethod = .muslimWorldLeague
        madhab = .shafi
        notificationsEnabled = true
        theme = .dark
        timeFormat = .twelveHour
        notificationOffset = 300
        hasCompletedOnboarding = false
        userName = ""
        overrideBatteryOptimization = false
        showArabicSymbolInWidget = true

        print("Mock: Settings reset to defaults")
    }
    
    public func saveImmediately() async throws {
        // Mock immediate save (no delay to simulate immediate behavior)
        print("Mock: Settings saved immediately")
        print("- Calculation Method: \(calculationMethod.displayName)")
        print("- Madhab: \(madhab.displayName)")
        print("- Notifications: \(notificationsEnabled)")
        print("- Onboarding Complete: \(hasCompletedOnboarding)")
        print("- User Name: \(userName)")
    }
    
    public func saveOnboardingSettings() async throws {
        // Mock onboarding save with enhanced logging
        print("Mock: Saving onboarding settings with enhanced error handling")
        
        // Simulate potential save operation
        try await saveImmediately()
        
        print("Mock: Onboarding settings saved successfully")
    }
}
