import Foundation
import Combine

/// Mock implementation of SettingsServiceProtocol for UI development
@MainActor
public class MockSettingsService: SettingsServiceProtocol {
    @Published public var calculationMethod: CalculationMethod = .muslimWorldLeague {
        didSet { notifySettingsChanged() }
    }
    @Published public var madhab: Madhab = .shafi {
        didSet { notifySettingsChanged() }
    }
    @Published public var useAstronomicalMaghrib: Bool = false {
        didSet { notifySettingsChanged() }
    }
    @Published public var notificationsEnabled: Bool = true {
        didSet { notifySettingsChanged() }
    }
    @Published public var theme: ThemeMode = .dark {
        didSet { notifySettingsChanged() }
    }
    @Published public var timeFormat: TimeFormat = .twelveHour {
        didSet { notifySettingsChanged() }
    }
    @Published public var notificationOffset: TimeInterval = 300 {
        didSet { notifySettingsChanged() }
    }
    @Published public var hasCompletedOnboarding: Bool = false {
        didSet { notifySettingsChanged() }
    }
    @Published public var userName: String = "" {
        didSet { notifySettingsChanged() }
    }
    @Published public var overrideBatteryOptimization: Bool = false {
        didSet { notifySettingsChanged() }
    }
    @Published public var showArabicSymbolInWidget: Bool = true {
        didSet { notifySettingsChanged() }
    }
    @Published public var liveActivitiesEnabled: Bool = true {
        didSet { notifySettingsChanged() }
    }

    public var enableNotifications: Bool {
        get { notificationsEnabled }
        set { notificationsEnabled = newValue }
    }
    
    public init() {}

    /// Send notification when settings change (to match real SettingsService behavior)
    private func notifySettingsChanged() {
        NotificationCenter.default.post(name: .settingsDidChange, object: self)
    }

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
        print("- Live Activities Enabled: \(liveActivitiesEnabled)")
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
        useAstronomicalMaghrib = false
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
