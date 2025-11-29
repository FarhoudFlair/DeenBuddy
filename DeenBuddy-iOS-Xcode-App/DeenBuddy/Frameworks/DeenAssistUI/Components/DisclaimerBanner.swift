import SwiftUI

/// Disclaimer banner component with exact approved Islamic accuracy disclaimers
/// CRITICAL: Uses exact copy from `DisclaimerLevel.bannerMessage` - NO VARIATIONS ALLOWED
public struct DisclaimerBanner: View {

    // MARK: - Variant Types

    /// Disclaimer variant determines styling and message
    public enum Variant {
        case shortTerm      // 0-12 months - yellow
        case mediumTerm     // 12-60 months - orange
        case highLatitude   // High-latitude warning - red
        case ramadanEid     // Ramadan/Eid estimate - purple/gold

        var icon: String {
            switch self {
            case .shortTerm:
                return "info.circle.fill"
            case .mediumTerm:
                return "exclamationmark.triangle.fill"
            case .highLatitude:
                return "location.fill"
            case .ramadanEid:
                return "moon.stars.fill"
            }
        }

        /// EXACT disclaimer text - mapped from backend DisclaimerLevel
        var exactText: String {
            switch self {
            case .shortTerm:
                return DisclaimerLevel.shortTerm.bannerMessage
            case .mediumTerm:
                return DisclaimerLevel.mediumTerm.bannerMessage
            case .highLatitude:
                return "High-latitude adjustment in use. Times are approximations. Check your local mosque."
            case .ramadanEid:
                // Uses IslamicEventEstimate.disclaimer exact copy
                return "Estimated by astronomical calculation (planning only). Actual dates set by your local Islamic authority."
            }
        }

        /// Background color (theme-aware)
        func backgroundColor(for theme: ThemeMode, colorScheme: ColorScheme) -> Color {
            let isDark = theme == .dark && colorScheme == .dark

            switch self {
            case .shortTerm:
                // Yellow tint
                return isDark ?
                    Color(red: 0.40, green: 0.35, blue: 0.15).opacity(0.9) :  // Darker yellow for dark mode
                    Color(red: 1.0, green: 0.97, blue: 0.88)  // #FFF8E1 light yellow

            case .mediumTerm:
                // Orange tint
                return isDark ?
                    Color(red: 0.45, green: 0.28, blue: 0.15).opacity(0.9) :  // Darker orange for dark mode
                    Color(red: 1.0, green: 0.88, blue: 0.70)  // #FFE0B2 light orange

            case .highLatitude:
                // Red tint
                return isDark ?
                    Color(red: 0.50, green: 0.20, blue: 0.20).opacity(0.9) :  // Darker red for dark mode
                    Color(red: 1.0, green: 0.80, blue: 0.74)  // #FFCCBC light red

            case .ramadanEid:
                // Purple/gold gradient will be used instead
                return Color.clear
            }
        }

        /// Icon color
        func iconColor(for theme: ThemeMode, colorScheme: ColorScheme) -> Color {
            let isDark = theme == .dark && colorScheme == .dark

            switch self {
            case .shortTerm:
                return isDark ? Color.yellow.opacity(0.9) : Color.orange.opacity(0.8)
            case .mediumTerm:
                return isDark ? Color.orange.opacity(0.9) : Color.orange
            case .highLatitude:
                return isDark ? Color.red.opacity(0.9) : Color.red
            case .ramadanEid:
                return Color.white
            }
        }

        /// Text color
        func textColor(for theme: ThemeMode, colorScheme: ColorScheme) -> Color {
            let isDark = theme == .dark && colorScheme == .dark

            switch self {
            case .ramadanEid:
                return Color.white
            default:
                return isDark ? Color.white : Color.black.opacity(0.87)
            }
        }

        /// Gradient for Ramadan/Eid variant
        func gradient(for theme: ThemeMode) -> LinearGradient {
            LinearGradient(
                colors: [
                    Color(red: 0.61, green: 0.15, blue: 0.69),  // #9C27B0 - Purple
                    Color(red: 1.0, green: 0.70, blue: 0.0)     // #FFB300 - Gold
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Properties

    let variant: Variant
    @Binding var isVisible: Bool
    let forceShow: Bool  // Always show in production for non-today dates

    @Environment(\.currentTheme) private var currentTheme
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage private var isDismissed: Bool

    // MARK: - Initialization

    /// Create disclaimer banner
    /// - Parameters:
    ///   - variant: The type of disclaimer to show
    ///   - isVisible: Binding to control visibility
    ///   - forceShow: If true, ignores dismissal state (use true for production)
    public init(
        variant: Variant,
        isVisible: Binding<Bool>,
        forceShow: Bool = true
    ) {
        self.variant = variant
        self._isVisible = isVisible
        self.forceShow = forceShow

        // Storage key per variant type
        self._isDismissed = AppStorage(wrappedValue: false, "disclaimer_dismissed_\(String(describing: variant))")
    }

    // MARK: - Body

    public var body: some View {
        if shouldShow {
            bannerContent
                .appTransition(.move(edge: .top).combined(with: .opacity))
                .appAnimation(AppAnimations.standard, value: isVisible)
        }
    }

    // MARK: - Components

    private var bannerContent: some View {
        HStack(alignment: .top, spacing: PremiumDesignTokens.spacing12) {
            // Icon
            Image(systemName: variant.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(variant.iconColor(for: currentTheme, colorScheme: colorScheme))
                .accessibilityHidden(true)  // Icon is decorative

            // Message text
            VStack(alignment: .leading, spacing: PremiumDesignTokens.spacing8) {
                Text(variant.exactText)
                    .font(Typography.bodyMedium)
                    .foregroundColor(variant.textColor(for: currentTheme, colorScheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)  // Allow multi-line
                    .dynamicTypeSize(...DynamicTypeSize.accessibility5)  // Support up to +7
            }

            Spacer()

            // Dismiss button (only shown if not forceShow)
            if !forceShow {
                Button(action: dismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(variant.iconColor(for: currentTheme, colorScheme: colorScheme).opacity(0.7))
                }
                .buttonAccessibility(label: "Dismiss disclaimer", hint: "Double tap to dismiss this notice")
            }
        }
        .padding(PremiumDesignTokens.spacing16)
        .background(backgroundView)
        .cornerRadius(PremiumDesignTokens.cornerRadius12)
        .premiumShadow(.level1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Important notice: \(variant.exactText)")
        .accessibilityAddTraits(.isStaticText)
    }

    @ViewBuilder
    private var backgroundView: some View {
        if variant == .ramadanEid {
            // Special gradient for Ramadan/Eid
            variant.gradient(for: currentTheme)
        } else {
            variant.backgroundColor(for: currentTheme, colorScheme: colorScheme)
        }
    }

    // MARK: - Helpers

    private var shouldShow: Bool {
        // CRITICAL: In production (forceShow = true), always show for non-today dates
        if forceShow {
            return isVisible
        }
        // In development, allow dismissal
        return isVisible && !isDismissed
    }

    private func dismiss() {
        withAnimation(AppAnimations.standard) {
            isVisible = false
        }
        isDismissed = true
        HapticFeedback.light()
    }
}

// MARK: - Convenience Initializers

public extension DisclaimerBanner {

    /// Create disclaimer banner from DisclaimerLevel
    /// - Parameters:
    ///   - disclaimerLevel: The disclaimer level from backend
    ///   - isVisible: Binding to control visibility
    ///   - forceShow: If true, ignores dismissal state (use true for production)
    init(
        disclaimerLevel: DisclaimerLevel,
        isVisible: Binding<Bool>,
        forceShow: Bool = true
    ) {
        let variant: Variant
        switch disclaimerLevel {
        case .today:
            variant = .shortTerm  // Won't be shown anyway
        case .shortTerm:
            variant = .shortTerm
        case .mediumTerm, .longTerm:
            variant = .mediumTerm
        }

        self.init(variant: variant, isVisible: isVisible, forceShow: forceShow)
    }

    /// Create high-latitude disclaimer banner
    static func highLatitude(isVisible: Binding<Bool>, forceShow: Bool = true) -> DisclaimerBanner {
        DisclaimerBanner(variant: .highLatitude, isVisible: isVisible, forceShow: forceShow)
    }

    /// Create Ramadan/Eid disclaimer banner
    static func ramadanEid(isVisible: Binding<Bool>, forceShow: Bool = true) -> DisclaimerBanner {
        DisclaimerBanner(variant: .ramadanEid, isVisible: isVisible, forceShow: forceShow)
    }
}

// MARK: - Preview

#Preview("Disclaimer Banners") {
    VStack(spacing: PremiumDesignTokens.spacing16) {
        DisclaimerBanner(
            variant: .shortTerm,
            isVisible: .constant(true),
            forceShow: false
        )

        DisclaimerBanner(
            variant: .mediumTerm,
            isVisible: .constant(true),
            forceShow: false
        )

        DisclaimerBanner(
            variant: .highLatitude,
            isVisible: .constant(true),
            forceShow: false
        )

        DisclaimerBanner(
            variant: .ramadanEid,
            isVisible: .constant(true),
            forceShow: false
        )
    }
    .padding(PremiumDesignTokens.spacing16)
    .background(ColorPalette.backgroundPrimary)
}

#Preview("Short Term - Dark") {
    DisclaimerBanner(
        disclaimerLevel: .shortTerm,
        isVisible: .constant(true),
        forceShow: false
    )
    .padding(PremiumDesignTokens.spacing16)
    .background(ColorPalette.backgroundPrimary)
    .environment(\.currentTheme, .dark)
    .environment(\.colorScheme, .dark)
}

#Preview("Medium Term - Islamic Green") {
    DisclaimerBanner(
        disclaimerLevel: .mediumTerm,
        isVisible: .constant(true),
        forceShow: false
    )
    .padding(PremiumDesignTokens.spacing16)
    .background(Color.islamicBackgroundPrimary)
    .environment(\.currentTheme, .islamicGreen)
}
