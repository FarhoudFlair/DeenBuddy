import SwiftUI

/// Premium design tokens with comprehensive theme support for DeenBuddy
/// Supports System Light, System Dark, and Islamic Green themes
public struct PremiumDesignTokens {

    // MARK: - Theme Context

    private let theme: ThemeMode
    private let colorScheme: ColorScheme

    public init(theme: ThemeMode, colorScheme: ColorScheme) {
        self.theme = theme
        self.colorScheme = colorScheme
    }

    // MARK: - Fixed Color Palette (Same across all themes)

    /// Islamic green shades
    public static let islamicGreen50 = Color(red: 0.95, green: 0.98, blue: 0.95) // #F1F8F1
    public static let islamicGreen100 = Color(red: 0.89, green: 0.95, blue: 0.89) // #E3F2E3
    public static let islamicGreen500 = Color(red: 0.18, green: 0.49, blue: 0.20) // #2E7D32
    public static let islamicGreen700 = Color(red: 0.16, green: 0.45, blue: 0.18) // #29731D
    public static let islamicGreen900 = Color(red: 0.10, green: 0.37, blue: 0.12) // #1B5E20

    /// Warm gold shades
    public static let warmGold300 = Color(red: 1.0, green: 0.84, blue: 0.50) // #FFD680
    public static let warmGold500 = Color(red: 1.0, green: 0.76, blue: 0.33) // #FFC254
    public static let warmGold700 = Color(red: 1.0, green: 0.70, blue: 0.0) // #FFB300

    /// Warm amber shades (for Islamic Green theme)
    public static let warmAmber300 = Color(red: 0.90, green: 0.65, blue: 0.40) // #E5A566
    public static let warmAmber500 = Color(red: 0.80, green: 0.52, blue: 0.25) // #CC8540

    // MARK: - Theme-Aware Colors

    /// Premium grays that adapt to theme
    public var premiumGray50: Color {
        isSystemDark ? Color(red: 0.10, green: 0.11, blue: 0.12) : Color(red: 0.98, green: 0.98, blue: 0.99)
    }

    public var premiumGray100: Color {
        isSystemDark ? Color(red: 0.16, green: 0.17, blue: 0.19) : Color(red: 0.96, green: 0.96, blue: 0.97)
    }

    public var premiumGray500: Color {
        isSystemDark ? Color(red: 0.69, green: 0.70, blue: 0.72) : Color(red: 0.56, green: 0.57, blue: 0.59)
    }

    public var premiumGray700: Color {
        isSystemDark ? Color(red: 0.83, green: 0.84, blue: 0.85) : Color(red: 0.29, green: 0.30, blue: 0.33)
    }

    public var premiumGray900: Color {
        isSystemDark ? Color(red: 0.98, green: 0.98, blue: 0.99) : Color(red: 0.10, green: 0.11, blue: 0.12)
    }

    // MARK: - Gradient Definitions (Theme-Aware)

    /// Countdown timer gradient - adapts based on theme
    public var countdownGradient: LinearGradient {
        switch theme {
        case .dark where colorScheme == .dark:
            // System Dark: Muted warm gold
            return LinearGradient(
                colors: [
                    Self.warmGold500.opacity(0.9),
                    Self.warmGold300.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .islamicGreen:
            // Islamic Green: Warm amber
            return LinearGradient(
                colors: [
                    Self.warmAmber500,
                    Self.warmAmber300
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            // System Light: Full warm gold
            return LinearGradient(
                colors: [
                    Self.warmGold500,
                    Self.warmGold300
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    /// Prayer glow radial gradient - subtle emphasis around prayer elements
    public var prayerGlow: RadialGradient {
        let baseOpacity: CGFloat = {
            switch theme {
            case .dark where colorScheme == .dark:
                return 0.25 // Higher opacity for visibility on dark
            case .islamicGreen:
                return 0.12 // Subtle for light Islamic theme
            default:
                return 0.15 // Standard for system light
            }
        }()

        let primaryColor = theme == .islamicGreen ? Color.islamicPrimaryGreen : Color.primaryGreen

        return RadialGradient(
            colors: [
                primaryColor.opacity(baseOpacity),
                Color.clear
            ],
            center: .center,
            startRadius: 0,
            endRadius: 200
        )
    }

    /// Quick action gradients for different actions
    public func actionGradient(_ action: ActionType) -> LinearGradient {
        let opacity: CGFloat = isSystemDark ? 0.95 : 1.0

        switch action {
        case .qibla:
            return LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.49, blue: 0.20).opacity(opacity), // #2E7D32 - Green
                    Color(red: 0.40, green: 0.73, blue: 0.42).opacity(opacity)  // #66BB6A - Teal
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .tasbih:
            return LinearGradient(
                colors: [
                    Color(red: 0.40, green: 0.73, blue: 0.42).opacity(opacity), // #66BB6A - Teal
                    Color(red: 0.26, green: 0.65, blue: 0.96).opacity(opacity)  // #42A5F5 - Blue
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .calendar:
            return LinearGradient(
                colors: [
                    Color(red: 0.61, green: 0.15, blue: 0.69).opacity(opacity), // #9C27B0 - Purple
                    Color(red: 0.91, green: 0.12, blue: 0.39).opacity(opacity)  // #E91E63 - Pink
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    /// Header gradient overlay - subtle atmospheric background
    public var headerGradientOverlay: LinearGradient {
        let primaryColor = theme == .islamicGreen ? Color.islamicPrimaryGreen : Color.primaryGreen
        let opacity: CGFloat = theme == .islamicGreen ? 0.015 : 0.02

        return LinearGradient(
            colors: [Color.clear, primaryColor.opacity(opacity)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Shadow System (Theme-Aware)

    public enum ShadowLevel {
        case level1  // Subtle elevation (quick actions, small cards)
        case level2  // Medium elevation (dashboard cards)
        case level3  // High elevation (countdown timer, hero elements)
    }

    /// Shadow multiplier based on theme
    /// System Light: 1.0x (standard)
    /// System Dark: 5.0x (enhanced for visibility)
    /// Islamic Green: 0.75x (subtle for light theme)
    private var shadowMultiplier: CGFloat {
        switch theme {
        case .dark where colorScheme == .dark:
            return 5.0
        case .islamicGreen:
            return 0.75
        default:
            return 1.0
        }
    }

    /// Get shadow definitions for a specific elevation level
    /// Returns array of (color, radius, x, y) tuples
    public func shadowDefinition(_ level: ShadowLevel) -> [(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)] {
        switch level {
        case .level1:
            return [
                (Color.black.opacity(0.04 * shadowMultiplier), 8, 0, 2),
                (Color.black.opacity(0.08 * shadowMultiplier), 16, 0, 6)
            ]
        case .level2:
            return [
                (Color.black.opacity(0.04 * shadowMultiplier), 8, 0, 2),
                (Color.black.opacity(0.08 * shadowMultiplier), 16, 0, 6),
                (Color.black.opacity(0.12 * shadowMultiplier), 24, 0, 10)
            ]
        case .level3:
            return [
                (Color.black.opacity(0.04 * shadowMultiplier), 8, 0, 2),
                (Color.black.opacity(0.08 * shadowMultiplier), 16, 0, 6),
                (Color.black.opacity(0.12 * shadowMultiplier), 24, 0, 10),
                (Color.black.opacity(0.16 * shadowMultiplier), 32, 0, 12)
            ]
        }
    }

    // MARK: - Spacing Scale (8pt Grid System)

    public static let spacing8: CGFloat = 8
    public static let spacing12: CGFloat = 12
    public static let spacing16: CGFloat = 16
    public static let spacing24: CGFloat = 24
    public static let spacing32: CGFloat = 32
    public static let spacing40: CGFloat = 40
    public static let spacing48: CGFloat = 48  // Section gaps

    // MARK: - Corner Radius Scale

    public static let cornerRadius12: CGFloat = 12
    public static let cornerRadius16: CGFloat = 16
    public static let cornerRadius20: CGFloat = 20
    public static let cornerRadius24: CGFloat = 24
    public static let cornerRadius28: CGFloat = 28

    // MARK: - Helper Properties

    private var isSystemDark: Bool {
        theme == .dark && colorScheme == .dark
    }

    private var isSystemLight: Bool {
        theme == .dark && colorScheme == .light
    }

    private var isIslamicGreen: Bool {
        theme == .islamicGreen
    }

    // MARK: - Action Types

    public enum ActionType {
        case qibla
        case tasbih
        case calendar
    }
}

// MARK: - View Extension for Easy Access

extension View {
    /// Inject premium design tokens into environment
    public func withPremiumTokens(theme: ThemeMode, colorScheme: ColorScheme) -> some View {
        self.environment(\.premiumTokens, PremiumDesignTokens(theme: theme, colorScheme: colorScheme))
    }
}

// MARK: - Environment Key

private struct PremiumTokensKey: EnvironmentKey {
    static let defaultValue = PremiumDesignTokens(theme: .dark, colorScheme: .light)
}

extension EnvironmentValues {
    public var premiumTokens: PremiumDesignTokens {
        get { self[PremiumTokensKey.self] }
        set { self[PremiumTokensKey.self] = newValue }
    }
}

// MARK: - Shadow View Modifier

/// View modifier that applies premium multi-layer shadows based on theme
struct PremiumShadowModifier: ViewModifier {
    let level: PremiumDesignTokens.ShadowLevel
    @Environment(\.premiumTokens) var tokens

    func body(content: Content) -> some View {
        let shadows = tokens.shadowDefinition(level)

        return shadows.enumerated().reduce(AnyView(content)) { current, enumerated in
            let (_, shadow) = enumerated
            return AnyView(
                current.shadow(
                    color: shadow.color,
                    radius: shadow.radius,
                    x: shadow.x,
                    y: shadow.y
                )
            )
        }
    }
}

extension View {
    /// Apply premium multi-layer shadow that adapts to theme
    public func premiumShadow(_ level: PremiumDesignTokens.ShadowLevel) -> some View {
        self.modifier(PremiumShadowModifier(level: level))
    }
}
