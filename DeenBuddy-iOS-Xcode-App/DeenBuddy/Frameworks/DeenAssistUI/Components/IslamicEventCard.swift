import SwiftUI

/// Card component displaying Islamic event estimates (Ramadan/Eid)
/// Shows event name, confidence indicator, and "(Planning only)" label
public struct IslamicEventCard: View {

    // MARK: - Properties

    let event: IslamicEventEstimate

    @Environment(\.currentTheme) private var currentTheme
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Initialization

    public init(event: IslamicEventEstimate) {
        self.event = event
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: PremiumDesignTokens.spacing12) {
            // Event icon
            eventIcon

            // Event content
            VStack(alignment: .leading, spacing: 4) {
                // Event name with "(Planning only)" label
                HStack(spacing: PremiumDesignTokens.spacing8) {
                    Text(event.event.name)
                        .font(Typography.titleMedium)
                        .foregroundColor(.white)

                    Text("(Planning only)")
                        .font(Typography.labelSmall)
                        .foregroundColor(.white.opacity(0.8))
                }

                // Confidence indicator
                confidenceBadge
            }

            Spacer()
        }
        .padding(PremiumDesignTokens.spacing16)
        .background(gradientBackground)
        .cornerRadius(PremiumDesignTokens.cornerRadius16)
        .premiumShadow(.level2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(event.disclaimer)
    }

    // MARK: - Components

    private var eventIcon: some View {
        Image(systemName: iconName)
            .font(.system(size: 32, weight: .medium))
            .foregroundColor(.white)
            .accessibilityHidden(true)  // Icon is decorative
    }

    private var confidenceBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)

            Text(event.confidenceLevel.displayText)
                .font(Typography.labelSmall)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.2))
        .cornerRadius(8)
    }

    private var gradientBackground: some View {
        eventGradient
    }

    // MARK: - Helpers

    private var iconName: String {
        let eventName = event.event.name.lowercased()
        if eventName.contains("ramadan") {
            return "moon.stars.fill"
        } else if eventName.contains("eid") {
            return "star.fill"
        } else {
            return "moon.stars"
        }
    }

    private var eventGradient: LinearGradient {
        let eventName = event.event.name.lowercased()

        if eventName.contains("ramadan") {
            // Purple gradient for Ramadan
            return LinearGradient(
                colors: [
                    Color(red: 0.61, green: 0.15, blue: 0.69),  // #9C27B0 - Purple
                    Color(red: 0.61, green: 0.15, blue: 0.69).opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if eventName.contains("eid") {
            // Gold gradient for Eid
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.84, blue: 0.0),   // #FFD700 - Gold
                    Color(red: 1.0, green: 0.65, blue: 0.0)    // #FFA500 - Orange
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // Default green gradient for other events
            return LinearGradient(
                colors: [
                    Color.islamicPrimaryGreen,
                    Color.islamicPrimaryGreen.opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var confidenceColor: Color {
        switch event.confidenceLevel {
        case .high:
            return Color.green
        case .medium:
            return Color.yellow
        case .low:
            return Color.orange
        }
    }

    private var accessibilityLabel: String {
        "\(event.event.name), planning only, \(event.confidenceLevel.displayText), on \(formattedDate)"
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: event.estimatedDate)
    }
}

// MARK: - Preview

#Preview("Islamic Event Card - Ramadan") {
    let ramadanEvent = IslamicEventEstimate(
        event: IslamicEvent.ramadanStart,
        estimatedDate: Date().addingTimeInterval(60 * 60 * 24 * 30),
        hijriDate: HijriDate(day: 1, month: .ramadan, year: 1446),
        confidenceLevel: .high
    )

    return IslamicEventCard(event: ramadanEvent)
        .padding(PremiumDesignTokens.spacing16)
        .background(ColorPalette.backgroundPrimary)
}

#Preview("Islamic Event Card - Eid al-Fitr") {
    let eidEvent = IslamicEventEstimate(
        event: IslamicEvent.eidAlFitr,
        estimatedDate: Date().addingTimeInterval(60 * 60 * 24 * 60),
        hijriDate: HijriDate(day: 1, month: .shawwal, year: 1446),
        confidenceLevel: .high
    )

    return IslamicEventCard(event: eidEvent)
        .padding(PremiumDesignTokens.spacing16)
        .background(ColorPalette.backgroundPrimary)
}

#Preview("Islamic Event Card - Low Confidence") {
    let futureEvent = IslamicEventEstimate(
        event: IslamicEvent.eidAlAdha,
        estimatedDate: Date().addingTimeInterval(60 * 60 * 24 * 365 * 3),  // 3 years out
        hijriDate: HijriDate(day: 10, month: .dhulHijjah, year: 1448),
        confidenceLevel: .low
    )

    return IslamicEventCard(event: futureEvent)
        .padding(PremiumDesignTokens.spacing16)
        .background(ColorPalette.backgroundPrimary)
}

#Preview("Islamic Event Card - Dark Mode") {
    let ramadanEvent = IslamicEventEstimate(
        event: IslamicEvent.ramadanStart,
        estimatedDate: Date().addingTimeInterval(60 * 60 * 24 * 30),
        hijriDate: HijriDate(day: 1, month: .ramadan, year: 1446),
        confidenceLevel: .medium
    )

    return IslamicEventCard(event: ramadanEvent)
        .padding(PremiumDesignTokens.spacing16)
        .background(ColorPalette.backgroundPrimary)
        .environment(\.currentTheme, .dark)
        .environment(\.colorScheme, .dark)
}
