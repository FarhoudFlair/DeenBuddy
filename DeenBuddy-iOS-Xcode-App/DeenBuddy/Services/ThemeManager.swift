//
//  ThemeManager.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-04.
//

import SwiftUI

// MARK: - Theme Mode

enum AppTheme: String, CaseIterable {
    case dark = "dark"
    case islamicGreen = "islamicGreen"
    
    var displayName: String {
        switch self {
        case .dark:
            return "Dark Theme"
        case .islamicGreen:
            return "Islamic Green Theme"
        }
    }
    
    var description: String {
        switch self {
        case .dark:
            return "Modern dark theme with cyan accents"
        case .islamicGreen:
            return "Light theme with Islamic green colors and warm backgrounds"
        }
    }
    
    var colorScheme: ColorScheme {
        switch self {
        case .dark:
            return .dark
        case .islamicGreen:
            return .light
        }
    }
}

// MARK: - Theme Manager

@MainActor
class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme = .dark {
        didSet {
            saveTheme()
        }
    }
    
    private let userDefaults = UserDefaults.standard
    private let themeKey = "app_theme"
    
    init() {
        loadTheme()
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
    }
    
    private func loadTheme() {
        if let themeString = userDefaults.string(forKey: themeKey),
           let theme = AppTheme(rawValue: themeString) {
            currentTheme = theme
        }
    }
    
    private func saveTheme() {
        userDefaults.set(currentTheme.rawValue, forKey: themeKey)
    }
}

// MARK: - Environment Key

private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppTheme = .dark
}

extension EnvironmentValues {
    var currentTheme: AppTheme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - Islamic Green Colors

extension Color {
    // Islamic Green Theme - Primary Colors
    static let islamicPrimaryGreen = Color(red: 0.18, green: 0.49, blue: 0.20) // #2E7D32
    static let islamicSecondaryGreen = Color(red: 0.40, green: 0.73, blue: 0.42) // #66BB6A
    static let islamicAccentGold = Color(red: 1.0, green: 0.70, blue: 0.0) // #FFB300
    
    // Islamic Green Theme - Background Colors
    static let islamicBackgroundPrimary = Color(red: 0.996, green: 0.996, blue: 0.996) // #FEFEFE
    static let islamicBackgroundSecondary = Color(red: 0.973, green: 0.976, blue: 0.980) // #F8F9FA
    static let islamicBackgroundTertiary = Color(red: 0.945, green: 0.965, blue: 0.949) // #F1F8E9
    
    // Islamic Green Theme - Surface Colors
    static let islamicSurfacePrimary = Color(red: 0.909, green: 0.961, blue: 0.909) // #E8F5E8
    static let islamicSurfaceSecondary = Color(red: 0.945, green: 0.965, blue: 0.949) // #F1F8E9
    
    // Islamic Green Theme - Text Colors
    static let islamicTextPrimary = Color(red: 0.106, green: 0.369, blue: 0.125) // #1B5E20
    static let islamicTextSecondary = Color(red: 0.22, green: 0.56, blue: 0.24) // #388E3C
    static let islamicTextTertiary = Color(red: 0.30, green: 0.69, blue: 0.31) // #4CAF50
}

// MARK: - Theme-Aware Color Palette

struct ThemeAwareColorPalette {
    private let theme: AppTheme
    
    init(theme: AppTheme) {
        self.theme = theme
    }
    
    // MARK: - Primary Colors
    
    var primary: Color {
        switch theme {
        case .dark:
            return .cyan
        case .islamicGreen:
            return .islamicPrimaryGreen
        }
    }
    
    var secondary: Color {
        switch theme {
        case .dark:
            return .blue
        case .islamicGreen:
            return .islamicSecondaryGreen
        }
    }
    
    var accent: Color {
        switch theme {
        case .dark:
            return .cyan
        case .islamicGreen:
            return .islamicAccentGold
        }
    }
    
    // MARK: - Background Colors
    
    var backgroundPrimary: Color {
        switch theme {
        case .dark:
            return Color(red: 0.05, green: 0.1, blue: 0.2)
        case .islamicGreen:
            return .islamicBackgroundPrimary
        }
    }
    
    var backgroundSecondary: Color {
        switch theme {
        case .dark:
            return Color(red: 0.1, green: 0.15, blue: 0.25)
        case .islamicGreen:
            return .islamicBackgroundSecondary
        }
    }
    
    var backgroundTertiary: Color {
        switch theme {
        case .dark:
            return Color(red: 0.15, green: 0.2, blue: 0.3)
        case .islamicGreen:
            return .islamicBackgroundTertiary
        }
    }
    
    // MARK: - Surface Colors
    
    var surfacePrimary: Color {
        switch theme {
        case .dark:
            return Color.black.opacity(0.3)
        case .islamicGreen:
            return .islamicSurfacePrimary
        }
    }
    
    var surfaceSecondary: Color {
        switch theme {
        case .dark:
            return Color.black.opacity(0.2)
        case .islamicGreen:
            return .islamicSurfaceSecondary
        }
    }
    
    // MARK: - Text Colors
    
    var textPrimary: Color {
        switch theme {
        case .dark:
            return .white
        case .islamicGreen:
            return .islamicTextPrimary
        }
    }
    
    var textSecondary: Color {
        switch theme {
        case .dark:
            return .white.opacity(0.8)
        case .islamicGreen:
            return .islamicTextSecondary
        }
    }
    
    var textTertiary: Color {
        switch theme {
        case .dark:
            return .white.opacity(0.6)
        case .islamicGreen:
            return .islamicTextTertiary
        }
    }
}

// MARK: - View Extension

extension View {
    func themed(with themeManager: ThemeManager) -> some View {
        self
            .preferredColorScheme(themeManager.currentTheme.colorScheme)
            .environment(\.currentTheme, themeManager.currentTheme)
    }
    
    func themeAwareColors(_ theme: AppTheme) -> ThemeAwareColorPalette {
        ThemeAwareColorPalette(theme: theme)
    }
}
