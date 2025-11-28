import SwiftUI

/// Subtle Islamic geometric pattern overlay for background decoration
/// Respects user preference via `enableIslamicPatterns` setting
public struct IslamicPatternOverlay: View {
    @Environment(\.currentTheme) private var currentTheme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var patternOpacity: Double {
        switch currentTheme {
        case .dark where colorScheme == .dark:
            return 0.03 // Very subtle on dark mode
        case .islamicGreen:
            return 0.06 // Slightly more visible on Islamic green
        default:
            return 0.04 // Subtle on light mode
        }
    }

    private var patternColor: Color {
        switch currentTheme {
        case .dark where colorScheme == .dark:
            return Color.white
        case .islamicGreen:
            return PremiumDesignTokens.islamicGreen500
        default:
            return ColorPalette.primary
        }
    }

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Draw repeating pattern across the canvas
                let patternSize: CGFloat = 120
                let rows = Int(ceil(size.height / patternSize)) + 1
                let columns = Int(ceil(size.width / patternSize)) + 1

                for row in 0..<rows {
                    for column in 0..<columns {
                        let x = CGFloat(column) * patternSize
                        let y = CGFloat(row) * patternSize

                        // Offset alternating rows for brick-like pattern
                        let offset = row % 2 == 0 ? 0 : patternSize / 2

                        drawEightPointStar(
                            context: context,
                            center: CGPoint(x: x + offset, y: y),
                            radius: 30,
                            opacity: patternOpacity
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Draw an 8-point Islamic star pattern
    private func drawEightPointStar(context: GraphicsContext, center: CGPoint, radius: CGFloat, opacity: Double) {
        var path = Path()

        let points = 8
        let angleIncrement = (2 * .pi) / Double(points * 2)
        let outerRadius = radius
        let innerRadius = radius * 0.4

        for i in 0..<(points * 2) {
            let angle = angleIncrement * Double(i) - .pi / 2
            let currentRadius = i % 2 == 0 ? outerRadius : innerRadius
            let x = center.x + currentRadius * cos(angle)
            let y = center.y + currentRadius * sin(angle)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()

        context.fill(
            path,
            with: .color(patternColor.opacity(opacity))
        )
    }
}

/// Conditional pattern overlay that respects user settings
public struct ConditionalIslamicPatternOverlay: View {
    let enabled: Bool

    public init(enabled: Bool) {
        self.enabled = enabled
    }

    public var body: some View {
        if enabled {
            IslamicPatternOverlay()
        }
    }
}

// MARK: - Preview

#Preview("Islamic Pattern Overlay - Light") {
    ZStack {
        ColorPalette.backgroundPrimary
        IslamicPatternOverlay()
    }
    .frame(width: 400, height: 600)
}

#Preview("Islamic Pattern Overlay - Dark") {
    ZStack {
        ColorPalette.backgroundPrimary
        IslamicPatternOverlay()
    }
    .frame(width: 400, height: 600)
    .preferredColorScheme(.dark)
}

#Preview("Islamic Pattern Overlay - Islamic Green") {
    ZStack {
        ColorPalette.backgroundPrimary
        IslamicPatternOverlay()
    }
    .frame(width: 400, height: 600)
    .environment(\.currentTheme, .islamicGreen)
}
