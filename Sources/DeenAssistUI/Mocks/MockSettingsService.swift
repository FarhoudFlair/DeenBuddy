import Foundation
import DeenAssistProtocols

/// Mock implementation of SettingsServiceProtocol for UI development
@MainActor
public class MockSettingsService: SettingsServiceProtocol {
    @Published public var calculationMethod: CalculationMethod = .muslimWorldLeague
    @Published public var madhab: Madhab = .shafi
    @Published public var notificationsEnabled: Bool = true
    @Published public var theme: ThemeMode = .system
    @Published public var hasCompletedOnboarding: Bool = false
    
    public init() {}
    
    public func saveSettings() async throws {
        // Simulate save delay
        try await Task.sleep(nanoseconds: 200_000_000)
        
        print("Mock: Settings saved")
        print("- Calculation Method: \(calculationMethod.displayName)")
        print("- Madhab: \(madhab.displayName)")
        print("- Notifications: \(notificationsEnabled)")
        print("- Theme: \(theme.displayName)")
        print("- Onboarding Complete: \(hasCompletedOnboarding)")
    }
    
    public func loadSettings() async throws {
        // Simulate load delay
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Mock loading some saved settings
        calculationMethod = .muslimWorldLeague
        madhab = .shafi
        notificationsEnabled = true
        theme = .system
        hasCompletedOnboarding = false
        
        print("Mock: Settings loaded")
    }
    
    public func resetToDefaults() async throws {
        // Simulate reset delay
        try await Task.sleep(nanoseconds: 100_000_000)
        
        calculationMethod = .muslimWorldLeague
        madhab = .shafi
        notificationsEnabled = true
        theme = .system
        hasCompletedOnboarding = false
        
        print("Mock: Settings reset to defaults")
    }
}
