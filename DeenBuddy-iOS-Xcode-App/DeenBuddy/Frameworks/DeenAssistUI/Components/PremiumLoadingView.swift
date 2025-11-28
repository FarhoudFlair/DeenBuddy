import SwiftUI

/// Premium loading view with skeleton shimmer effects
public struct PremiumLoadingView: View {
    let style: LoadingStyle

    @Environment(\.currentTheme) private var currentTheme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shimmerPhase: CGFloat = 0

    private var themeColors: ThemeAwareColorPalette {
        ThemeAwareColorPalette(theme: currentTheme)
    }

    private var skeletonColor: Color {
        switch currentTheme {
        case .dark where colorScheme == .dark:
            return Color.white.opacity(0.08)
        case .islamicGreen:
            return PremiumDesignTokens.islamicGreen500.opacity(0.06)
        default:
            return Color.gray.opacity(0.12)
        }
    }

    private var shimmerColor: Color {
        switch currentTheme {
        case .dark where colorScheme == .dark:
            return Color.white.opacity(0.12)
        case .islamicGreen:
            return PremiumDesignTokens.islamicGreen100.opacity(0.15)
        default:
            return Color.white.opacity(0.3)
        }
    }

    public init(style: LoadingStyle = .card) {
        self.style = style
    }

    public var body: some View {
        Group {
            switch style {
            case .card:
                cardSkeleton
            case .list:
                listSkeleton
            case .countdown:
                countdownSkeleton
            case .dashboard:
                dashboardSkeleton
            }
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    shimmerPhase = 1.0
                }
            }
        }
    }

    // MARK: - Skeleton Styles

    private var cardSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title skeleton
            RoundedRectangle(cornerRadius: 8)
                .fill(skeletonColor)
                .frame(height: 24)
                .frame(width: 200)
                .shimmerEffect(phase: shimmerPhase, shimmerColor: shimmerColor, cornerRadius: 8)

            // Content skeleton
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(skeletonColor)
                    .frame(height: 16)
                    .shimmerEffect(phase: shimmerPhase, shimmerColor: shimmerColor, cornerRadius: 6)

                RoundedRectangle(cornerRadius: 6)
                    .fill(skeletonColor)
                    .frame(height: 16)
                    .shimmerEffect(phase: shimmerPhase, shimmerColor: shimmerColor, cornerRadius: 6)

                RoundedRectangle(cornerRadius: 6)
                    .fill(skeletonColor)
                    .frame(height: 16)
                    .frame(width: 250)
                    .shimmerEffect(phase: shimmerPhase, shimmerColor: shimmerColor, cornerRadius: 6)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PremiumDesignTokens.cornerRadius24)
                .fill(ColorPalette.surfacePrimary)
        )
        .premiumShadow(.level2)
    }

    private var listSkeleton: some View {
        VStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { _ in
                HStack(spacing: 12) {
                    Circle()
                        .fill(skeletonColor)
                        .frame(width: 24, height: 24)
                        .shimmerEffect(phase: shimmerPhase, shimmerColor: shimmerColor, cornerRadius: 12)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(skeletonColor)
                        .frame(height: 16)
                        .shimmerEffect(phase: shimmerPhase, shimmerColor: shimmerColor, cornerRadius: 6)
                }
                .padding(.vertical, 12)
            }
        }
    }

    private var countdownSkeleton: some View {
        VStack(alignment: .leading, spacing: 16) {
            // "Next Prayer" label
            RoundedRectangle(cornerRadius: 6)
                .fill(skeletonColor)
                .frame(width: 100, height: 14)
                .shimmerEffect(phase: shimmerPhase, shimmerColor: shimmerColor, cornerRadius: 6)

            // Large time display
            RoundedRectangle(cornerRadius: 12)
                .fill(skeletonColor)
                .frame(width: 200, height: 56)
                .shimmerEffect(phase: shimmerPhase, shimmerColor: shimmerColor, cornerRadius: 12)

            // Prayer name badge
            RoundedRectangle(cornerRadius: 16)
                .fill(skeletonColor)
                .frame(width: 80, height: 32)
                .shimmerEffect(phase: shimmerPhase, shimmerColor: shimmerColor, cornerRadius: 16)

            Spacer().frame(height: 8)

            // "Starts In" label
            RoundedRectangle(cornerRadius: 6)
                .fill(skeletonColor)
                .frame(width: 80, height: 14)
                .shimmerEffect(phase: shimmerPhase, shimmerColor: shimmerColor, cornerRadius: 6)

            // Countdown display
            RoundedRectangle(cornerRadius: 10)
                .fill(skeletonColor)
                .frame(width: 120, height: 40)
                .shimmerEffect(phase: shimmerPhase, shimmerColor: shimmerColor, cornerRadius: 10)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PremiumDesignTokens.cornerRadius24)
                .fill(ColorPalette.surfacePrimary)
        )
        .premiumShadow(.level3)
    }

    private var dashboardSkeleton: some View {
        HStack(spacing: 24) {
            // Circular progress skeleton
            Circle()
                .fill(skeletonColor)
                .frame(width: 80, height: 80)
                .shimmerEffect(phase: shimmerPhase, shimmerColor: shimmerColor, cornerRadius: 40)

            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(skeletonColor)
                    .frame(width: 150, height: 16)
                    .shimmerEffect(phase: shimmerPhase, shimmerColor: shimmerColor, cornerRadius: 6)

                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(skeletonColor)
                        .frame(width: 70, height: 32)
                        .shimmerEffect(phase: shimmerPhase, shimmerColor: shimmerColor, cornerRadius: 12)

                    RoundedRectangle(cornerRadius: 12)
                        .fill(skeletonColor)
                        .frame(width: 70, height: 32)
                        .shimmerEffect(phase: shimmerPhase, shimmerColor: shimmerColor, cornerRadius: 12)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PremiumDesignTokens.cornerRadius24)
                .fill(ColorPalette.surfacePrimary)
        )
        .premiumShadow(.level2)
    }

    // MARK: - Loading Styles

    public enum LoadingStyle {
        case card
        case list
        case countdown
        case dashboard
    }
}

// MARK: - Shimmer Effect Modifier

private extension View {
    func shimmerEffect(phase: CGFloat, shimmerColor: Color, cornerRadius: CGFloat = 8) -> some View {
        self.overlay(
            GeometryReader { geometry in
                LinearGradient(
                    colors: [
                        .clear,
                        shimmerColor,
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geometry.size.width * 2)
                .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        )
    }
}

// MARK: - Preview

#Preview("Loading Styles") {
    ScrollView {
        VStack(spacing: 24) {
            Text("Card Loading")
                .font(.headline)
            PremiumLoadingView(style: .card)

            Text("List Loading")
                .font(.headline)
            PremiumLoadingView(style: .list)

            Text("Countdown Loading")
                .font(.headline)
            PremiumLoadingView(style: .countdown)

            Text("Dashboard Loading")
                .font(.headline)
            PremiumLoadingView(style: .dashboard)
        }
        .padding()
        .background(ColorPalette.backgroundPrimary)
    }
}

#Preview("Loading - Dark Mode") {
    ScrollView {
        VStack(spacing: 24) {
            PremiumLoadingView(style: .card)
            PremiumLoadingView(style: .countdown)
            PremiumLoadingView(style: .dashboard)
        }
        .padding()
        .background(ColorPalette.backgroundPrimary)
    }
    .preferredColorScheme(.dark)
}
