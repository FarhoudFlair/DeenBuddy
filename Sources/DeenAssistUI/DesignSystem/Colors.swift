import SwiftUI

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
