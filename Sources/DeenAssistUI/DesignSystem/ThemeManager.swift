import SwiftUI
import DeenAssistProtocols

/// Theme manager for handling app-wide theming
@MainActor
public class ThemeManager: ObservableObject {
    @Published public var currentTheme: ThemeMode = .dark
    @Published public var colorScheme: ColorScheme? = nil
    
    private var settingsService: SettingsServiceProtocol?
    
    public init(settingsService: SettingsServiceProtocol? = nil) {
        self.settingsService = settingsService
        loadTheme()
    }
    
    /// Set the theme mode
    public func setTheme(_ theme: ThemeMode) {
        currentTheme = theme
        updateColorScheme()
        saveTheme()
    }
    
    /// Get the appropriate color scheme for the current theme
    public func getColorScheme() -> ColorScheme? {
        switch currentTheme {
        case .dark:
            return .dark
        case .islamicGreen:
            return .light // Islamic green theme uses light backgrounds
        }
    }
    
    private func updateColorScheme() {
        colorScheme = getColorScheme()
    }
    
    private func loadTheme() {
        if let settingsService = settingsService {
            currentTheme = settingsService.theme
        } else {
            // Load from UserDefaults as fallback
            if let themeString = UserDefaults.standard.string(forKey: "app_theme"),
               let theme = ThemeMode(rawValue: themeString) {
                currentTheme = theme
            }
        }
        updateColorScheme()
    }
    
    private func saveTheme() {
        if let settingsService = settingsService {
            settingsService.theme = currentTheme
            Task {
                try? await settingsService.saveSettings()
            }
        } else {
            // Save to UserDefaults as fallback
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "app_theme")
        }
    }
}

/// View modifier for applying theme
public struct ThemedViewModifier: ViewModifier {
    @ObservedObject private var themeManager: ThemeManager

    public init(themeManager: ThemeManager) {
        self.themeManager = themeManager
    }

    public func body(content: Content) -> some View {
        content
            .preferredColorScheme(themeManager.colorScheme)
            .environment(\.currentTheme, themeManager.currentTheme)
            .background(themeManager.currentTheme == .dark ? ColorPalette.backgroundPrimary : Color.islamicBackgroundPrimary)
    }
}

/// Extension to easily apply theming to views
public extension View {
    func themed(with themeManager: ThemeManager) -> some View {
        self.modifier(ThemedViewModifier(themeManager: themeManager))
    }
}

/// Theme preview helper for SwiftUI previews
public struct ThemePreview {
    public static let darkTheme: ThemeManager = {
        let manager = ThemeManager()
        manager.setTheme(.dark)
        return manager
    }()

    public static let islamicGreenTheme: ThemeManager = {
        let manager = ThemeManager()
        manager.setTheme(.islamicGreen)
        return manager
    }()
}
