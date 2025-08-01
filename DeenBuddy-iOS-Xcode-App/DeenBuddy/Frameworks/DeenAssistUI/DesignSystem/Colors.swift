import SwiftUI

/// Main color palette for the DeenBuddy app
public struct ColorPalette {
    
    // MARK: - Primary Colors
    
    public static let primary = Color.primaryGreen
    public static let secondary = Color.secondaryTeal
    public static let accent = Color.accentGold
    
    // MARK: - Background Colors
    
    public static let backgroundPrimary = Color(.systemBackground)
    public static let backgroundSecondary = Color(.secondarySystemBackground)
    public static let backgroundTertiary = Color(.tertiarySystemBackground)
    
    // MARK: - Surface Colors
    
    public static let surfacePrimary = Color(.systemBackground)
    public static let surfaceSecondary = Color(.secondarySystemBackground)
    public static let surface = Color(.systemBackground)
    
    // MARK: - Text Colors
    
    public static let textPrimary = Color(.label)
    public static let textSecondary = Color(.secondaryLabel)
    public static let textTertiary = Color(.tertiaryLabel)

    // MARK: - Prayer-specific Text Colors

    /// Rakah count text color - brighter than tertiary in dark theme for better readability
    public static let rakahText = Color.rakahText
    
    // MARK: - Status Colors
    
    public static let success = Color.successGreen
    public static let warning = Color.warningOrange
    public static let error = Color.errorRed
    
    // MARK: - Prayer Status Colors
    
    public static let prayerActive = Color.prayerActive
    public static let prayerCompleted = Color.prayerCompleted
    public static let prayerUpcoming = Color.prayerUpcoming
    
    // MARK: - Border Colors
    
    public static let border = Color(.systemGray).opacity(0.3)
    
    // MARK: - Accessibility Colors
    
    public static let accessibleTextPrimary = Color(.label)
    public static let accessibleBackground = Color(.systemBackground)
}

/// Design system colors for DeenBuddy app
public extension Color {
    
    // MARK: - Primary Colors
    
    /// Primary green color - represents peace and Islam
    static let primaryGreen = Color.islamicPrimaryGreen
    
    /// Secondary teal color - complementary to primary
    static let secondaryTeal = Color.islamicSecondaryGreen
    
    /// Accent gold color - for highlights and important elements
    static let accentGold = Color.islamicAccentGold
    
    /// Next prayer highlight color - warmer, less yellow tone for Islamic theme
    static let nextPrayerHighlight = Color.islamicNextPrayerHighlight
    
    // MARK: - Semantic Colors
    
    /// Background colors - using ColorPalette instead
    // Removed duplicates - use ColorPalette.backgroundPrimary instead
    
    /// Surface colors for cards and elevated content - using ColorPalette instead
    // Removed duplicates - use ColorPalette.surfacePrimary instead
    
    /// Text colors - using ColorPalette instead
    // Removed duplicates - use ColorPalette.textPrimary instead
    
    /// Prayer-specific colors
    static let prayerActive = Color.islamicPrimaryGreen
    static let prayerCompleted = Color.green
    static let prayerUpcoming = Color.gray
    
    /// Status colors
    static let successGreen = Color.green
    static let warningOrange = Color.orange
    static let errorRed = Color.red

    /// Rakah count text - brighter than tertiary in dark theme
    static let rakahText: Color = {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                // In dark mode, use a brighter color (60% white instead of tertiary's ~40%)
                return UIColor.white.withAlphaComponent(0.75)
            default:
                // In light mode, use secondary label (darker than tertiary)
                return UIColor.secondaryLabel
            }
        })
    }()
    
    // MARK: - Islamic Green Theme Colors

    /// Islamic Green Theme - Primary Colors
    static let islamicPrimaryGreen = Color(red: 0.18, green: 0.49, blue: 0.20) // #2E7D32
    static let islamicSecondaryGreen = Color(red: 0.40, green: 0.73, blue: 0.42) // #66BB6A
    static let islamicAccentGold = Color(red: 1.0, green: 0.70, blue: 0.0) // #FFB300
    static let islamicNextPrayerHighlight = Color(red: 0.80, green: 0.52, blue: 0.25) // #CC8540 - Warm amber tone

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

// MARK: - Removed duplicate ColorPalette struct to prevent conflicts

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
    
    /// Next prayer highlight color - theme-aware
    public var nextPrayerHighlight: Color {
        switch theme {
        case .dark:
            return Color.accentGold
        case .islamicGreen:
            return Color.islamicNextPrayerHighlight
        }
    }

    // MARK: - Background Palette

    public var backgroundPrimary: Color {
        switch theme {
        case .dark:
            return ColorPalette.backgroundPrimary
        case .islamicGreen:
            return Color.islamicBackgroundPrimary
        }
    }

    public var backgroundSecondary: Color {
        switch theme {
        case .dark:
            return ColorPalette.backgroundSecondary
        case .islamicGreen:
            return Color.islamicBackgroundSecondary
        }
    }

    public var backgroundTertiary: Color {
        switch theme {
        case .dark:
            return ColorPalette.backgroundTertiary
        case .islamicGreen:
            return Color.islamicBackgroundTertiary
        }
    }

    // MARK: - Surface Palette

    public var surfacePrimary: Color {
        switch theme {
        case .dark:
            return ColorPalette.surfacePrimary
        case .islamicGreen:
            return Color.islamicSurfacePrimary
        }
    }

    public var surfaceSecondary: Color {
        switch theme {
        case .dark:
            return ColorPalette.surfaceSecondary
        case .islamicGreen:
            return Color.islamicSurfaceSecondary
        }
    }

    // MARK: - Text Palette

    public var textPrimary: Color {
        switch theme {
        case .dark:
            return ColorPalette.textPrimary
        case .islamicGreen:
            return Color.islamicTextPrimary
        }
    }

    public var textSecondary: Color {
        switch theme {
        case .dark:
            return ColorPalette.textSecondary
        case .islamicGreen:
            return Color.islamicTextSecondary
        }
    }

    public var textTertiary: Color {
        switch theme {
        case .dark:
            return ColorPalette.textTertiary
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
        case .passed:
            return .prayerUpcoming
        }
    }
}

/// Prayer status enumeration
public enum PrayerStatus {
    case active
    case completed
    case upcoming
    case passed

    public var description: String {
        switch self {
        case .active:
            return "Active"
        case .completed:
            return "Completed"
        case .upcoming:
            return "Upcoming"
        case .passed:
            return "Passed"
        }
    }
}
