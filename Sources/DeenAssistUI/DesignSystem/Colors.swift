import SwiftUI
import DeenAssistProtocols

/// Design system colors for Deen Assist app
public extension Color {
    
    // MARK: - Primary Colors
    
    /// Primary green color - represents peace and Islam
    static let primaryGreen = Color("PrimaryGreen", bundle: .module)
    
    /// Secondary teal color - complementary to primary
    static let secondaryTeal = Color("SecondaryTeal", bundle: .module)
    
    /// Accent gold color - for highlights and important elements
    static let accentGold = Color("AccentGold", bundle: .module)
    
    // MARK: - Semantic Colors
    
    /// Background colors
    static let backgroundPrimary = Color("BackgroundPrimary", bundle: .module)
    static let backgroundSecondary = Color("BackgroundSecondary", bundle: .module)
    static let backgroundTertiary = Color("BackgroundTertiary", bundle: .module)
    
    /// Surface colors for cards and elevated content
    static let surfacePrimary = Color("SurfacePrimary", bundle: .module)
    static let surfaceSecondary = Color("SurfaceSecondary", bundle: .module)
    
    /// Text colors
    static let textPrimary = Color("TextPrimary", bundle: .module)
    static let textSecondary = Color("TextSecondary", bundle: .module)
    static let textTertiary = Color("TextTertiary", bundle: .module)
    
    /// Prayer-specific colors
    static let prayerActive = Color("PrayerActive", bundle: .module)
    static let prayerCompleted = Color("PrayerCompleted", bundle: .module)
    static let prayerUpcoming = Color("PrayerUpcoming", bundle: .module)
    
    /// Status colors
    static let successGreen = Color("SuccessGreen", bundle: .module)
    static let warningOrange = Color("WarningOrange", bundle: .module)
    static let errorRed = Color("ErrorRed", bundle: .module)
    
    // MARK: - Islamic Green Theme Colors

    /// Islamic Green Theme - Primary Colors
    static let islamicPrimaryGreen = Color(red: 0.18, green: 0.49, blue: 0.20) // #2E7D32
    static let islamicSecondaryGreen = Color(red: 0.40, green: 0.73, blue: 0.42) // #66BB6A
    static let islamicAccentGold = Color(red: 1.0, green: 0.70, blue: 0.0) // #FFB300

    /// Islamic Green Theme - Background Colors
    static let islamicBackgroundPrimary = Color(red: 0.996, green: 0.996, blue: 0.996) // #FEFEFE
    static let islamicBackgroundSecondary = Color(red: 0.973, green: 0.976, blue: 0.980) // #F8F9FA
    static let islamicBackgroundTertiary = Color(red: 0.945, green: 0.965, blue: 0.949) // #F1F8E9

    /// Islamic Green Theme - Surface Colors
    static let islamicSurfacePrimary = Color(red: 0.909, green: 0.961, blue: 0.909) // #E8F5E8
    static let islamicSurfaceSecondary = Color(red: 0.945, green: 0.965, blue: 0.949) // #F1F8E9

    /// Islamic Green Theme - Text Colors
    static let islamicTextPrimary = Color(red: 0.106, green: 0.369, blue: 0.125) // #1B5E20
    static let islamicTextSecondary = Color(red: 0.22, green: 0.56, blue: 0.24) // #388E3C
    static let islamicTextTertiary = Color(red: 0.30, green: 0.69, blue: 0.31) // #4CAF50

    // MARK: - Fallback Colors (for when bundle colors aren't available)

    static let fallbackPrimaryGreen = Color(red: 0.2, green: 0.6, blue: 0.4)
    static let fallbackSecondaryTeal = Color(red: 0.2, green: 0.5, blue: 0.6)
    static let fallbackAccentGold = Color(red: 0.8, green: 0.7, blue: 0.3)
}

/// Color palette for easy access
public struct ColorPalette {
    
    // MARK: - Primary Palette
    
    public static let primary = Color.primaryGreen
    public static let secondary = Color.secondaryTeal
    public static let accent = Color.accentGold
    
    // MARK: - Background Palette
    
    public static let backgroundPrimary = Color.backgroundPrimary
    public static let backgroundSecondary = Color.backgroundSecondary
    public static let backgroundTertiary = Color.backgroundTertiary
    
    // MARK: - Surface Palette
    
    public static let surfacePrimary = Color.surfacePrimary
    public static let surfaceSecondary = Color.surfaceSecondary
    
    // MARK: - Text Palette
    
    public static let textPrimary = Color.textPrimary
    public static let textSecondary = Color.textSecondary
    public static let textTertiary = Color.textTertiary
    
    // MARK: - Prayer Status Palette
    
    public static let prayerActive = Color.prayerActive
    public static let prayerCompleted = Color.prayerCompleted
    public static let prayerUpcoming = Color.prayerUpcoming
    
    // MARK: - Status Palette

    public static let success = Color.successGreen
    public static let warning = Color.warningOrange
    public static let error = Color.errorRed
}

// MARK: - Environment Key for Theme

private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: ThemeMode = .dark
}

public extension EnvironmentValues {
    var currentTheme: ThemeMode {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - Theme-Aware Color Palette

/// Theme-aware color palette that returns different colors based on current theme
public struct ThemeAwareColorPalette {
    private let theme: ThemeMode

    public init(theme: ThemeMode) {
        self.theme = theme
    }

    // MARK: - Primary Palette

    public var primary: Color {
        switch theme {
        case .dark:
            return Color.primaryGreen
        case .islamicGreen:
            return Color.islamicPrimaryGreen
        }
    }

    public var secondary: Color {
        switch theme {
        case .dark:
            return Color.secondaryTeal
        case .islamicGreen:
            return Color.islamicSecondaryGreen
        }
    }

    public var accent: Color {
        switch theme {
        case .dark:
            return Color.accentGold
        case .islamicGreen:
            return Color.islamicAccentGold
        }
    }

    // MARK: - Background Palette

    public var backgroundPrimary: Color {
        switch theme {
        case .dark:
            return Color.backgroundPrimary
        case .islamicGreen:
            return Color.islamicBackgroundPrimary
        }
    }

    public var backgroundSecondary: Color {
        switch theme {
        case .dark:
            return Color.backgroundSecondary
        case .islamicGreen:
            return Color.islamicBackgroundSecondary
        }
    }

    public var backgroundTertiary: Color {
        switch theme {
        case .dark:
            return Color.backgroundTertiary
        case .islamicGreen:
            return Color.islamicBackgroundTertiary
        }
    }

    // MARK: - Surface Palette

    public var surfacePrimary: Color {
        switch theme {
        case .dark:
            return Color.surfacePrimary
        case .islamicGreen:
            return Color.islamicSurfacePrimary
        }
    }

    public var surfaceSecondary: Color {
        switch theme {
        case .dark:
            return Color.surfaceSecondary
        case .islamicGreen:
            return Color.islamicSurfaceSecondary
        }
    }

    // MARK: - Text Palette

    public var textPrimary: Color {
        switch theme {
        case .dark:
            return Color.textPrimary
        case .islamicGreen:
            return Color.islamicTextPrimary
        }
    }

    public var textSecondary: Color {
        switch theme {
        case .dark:
            return Color.textSecondary
        case .islamicGreen:
            return Color.islamicTextSecondary
        }
    }

    public var textTertiary: Color {
        switch theme {
        case .dark:
            return Color.textTertiary
        case .islamicGreen:
            return Color.islamicTextTertiary
        }
    }

    // MARK: - Status Palette (same for all themes)

    public var success: Color { Color.successGreen }
    public var warning: Color { Color.warningOrange }
    public var error: Color { Color.errorRed }
}

// MARK: - View Extension for Theme-Aware Colors

public extension View {
    /// Get theme-aware color palette
    func themeAwareColors(_ theme: ThemeMode) -> ThemeAwareColorPalette {
        ThemeAwareColorPalette(theme: theme)
    }
}

/// Extension to provide semantic color access
public extension Color {
    
    /// Get color based on prayer status
    static func prayerStatus(_ status: PrayerStatus) -> Color {
        switch status {
        case .active:
            return .prayerActive
        case .completed:
            return .prayerCompleted
        case .upcoming:
            return .prayerUpcoming
        }
    }
}

/// Prayer status enumeration
public enum PrayerStatus {
    case active
    case completed
    case upcoming

    public var description: String {
        switch self {
        case .active:
            return "Active"
        case .completed:
            return "Completed"
        case .upcoming:
            return "Upcoming"
        }
    }
}
