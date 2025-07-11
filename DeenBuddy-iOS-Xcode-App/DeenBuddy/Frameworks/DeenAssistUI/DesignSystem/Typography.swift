import SwiftUI

/// Typography system for Deen Assist app
public struct Typography {
    
    // MARK: - Font Weights
    
    public static let light = Font.Weight.light
    public static let regular = Font.Weight.regular
    public static let medium = Font.Weight.medium
    public static let semibold = Font.Weight.semibold
    public static let bold = Font.Weight.bold
    
    // MARK: - Display Fonts (Large titles, hero text)
    
    public static let displayLarge = Font.system(size: 57, weight: .regular, design: .default)
    public static let displayMedium = Font.system(size: 45, weight: .regular, design: .default)
    public static let displaySmall = Font.system(size: 36, weight: .regular, design: .default)
    
    // MARK: - Headline Fonts (Page titles, section headers)
    
    public static let headlineLarge = Font.system(size: 32, weight: .semibold, design: .default)
    public static let headlineMedium = Font.system(size: 28, weight: .semibold, design: .default)
    public static let headlineSmall = Font.system(size: 24, weight: .semibold, design: .default)
    
    // MARK: - Title Fonts (Card titles, important labels)
    
    public static let titleLarge = Font.system(size: 22, weight: .medium, design: .default)
    public static let titleMedium = Font.system(size: 16, weight: .medium, design: .default)
    public static let titleSmall = Font.system(size: 14, weight: .medium, design: .default)
    
    // MARK: - Body Fonts (Main content, descriptions)
    
    public static let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)
    public static let bodyMedium = Font.system(size: 14, weight: .regular, design: .default)
    public static let bodySmall = Font.system(size: 12, weight: .regular, design: .default)
    
    // MARK: - Label Fonts (UI labels, captions)
    
    public static let labelLarge = Font.system(size: 14, weight: .medium, design: .default)
    public static let labelMedium = Font.system(size: 12, weight: .medium, design: .default)
    public static let labelSmall = Font.system(size: 11, weight: .medium, design: .default)
    
    // MARK: - Special Purpose Fonts
    
    /// Large countdown timer font
    public static let timerLarge = Font.system(size: 48, weight: .light, design: .monospaced)
    
    /// Medium countdown timer font
    public static let timerMedium = Font.system(size: 32, weight: .light, design: .monospaced)
    
    /// Small countdown timer font
    public static let timerSmall = Font.system(size: 24, weight: .light, design: .monospaced)
    
    /// Prayer time display font
    public static let prayerTime = Font.system(size: 18, weight: .medium, design: .monospaced)
    
    /// Navigation title font
    public static let navigationTitle = Font.system(size: 20, weight: .semibold, design: .default)
    
    /// Button text font
    public static let buttonText = Font.system(size: 16, weight: .semibold, design: .default)
    
    /// Caption font for small details
    public static let caption = Font.system(size: 10, weight: .regular, design: .default)
    
    /// Caption medium font for small details with emphasis
    public static let captionMedium = Font.system(size: 10, weight: .medium, design: .default)
    
    /// Caption small font for very small details
    public static let captionSmall = Font.system(size: 9, weight: .regular, design: .default)
}

/// Text style modifiers for consistent styling
public extension Text {
    
    // MARK: - Display Styles
    
    func displayLarge() -> some View {
        self.font(Typography.displayLarge)
    }
    
    func displayMedium() -> some View {
        self.font(Typography.displayMedium)
    }
    
    func displaySmall() -> some View {
        self.font(Typography.displaySmall)
    }
    
    // MARK: - Headline Styles
    
    func headlineLarge() -> some View {
        self.font(Typography.headlineLarge)
    }
    
    func headlineMedium() -> some View {
        self.font(Typography.headlineMedium)
    }
    
    func headlineSmall() -> some View {
        self.font(Typography.headlineSmall)
    }
    
    // MARK: - Title Styles
    
    func titleLarge() -> some View {
        self.font(Typography.titleLarge)
    }
    
    func titleMedium() -> some View {
        self.font(Typography.titleMedium)
    }
    
    func titleSmall() -> some View {
        self.font(Typography.titleSmall)
    }
    
    // MARK: - Body Styles
    
    func bodyLarge() -> some View {
        self.font(Typography.bodyLarge)
    }
    
    func bodyMedium() -> some View {
        self.font(Typography.bodyMedium)
    }
    
    func bodySmall() -> some View {
        self.font(Typography.bodySmall)
    }
    
    // MARK: - Label Styles
    
    func labelLarge() -> some View {
        self.font(Typography.labelLarge)
    }
    
    func labelMedium() -> some View {
        self.font(Typography.labelMedium)
    }
    
    func labelSmall() -> some View {
        self.font(Typography.labelSmall)
    }
    
    // MARK: - Special Styles
    
    func timerLarge() -> some View {
        self.font(Typography.timerLarge)
    }
    
    func timerMedium() -> some View {
        self.font(Typography.timerMedium)
    }
    
    func timerSmall() -> some View {
        self.font(Typography.timerSmall)
    }
    
    func prayerTime() -> some View {
        self.font(Typography.prayerTime)
    }
    
    func navigationTitle() -> some View {
        self.font(Typography.navigationTitle)
    }
    
    func buttonText() -> some View {
        self.font(Typography.buttonText)
    }
    
    func caption() -> some View {
        self.font(Typography.caption)
    }
    
    func captionMedium() -> some View {
        self.font(Typography.captionMedium)
    }
    
    func captionSmall() -> some View {
        self.font(Typography.captionSmall)
    }
}
