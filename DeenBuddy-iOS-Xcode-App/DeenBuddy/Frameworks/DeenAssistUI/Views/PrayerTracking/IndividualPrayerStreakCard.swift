import SwiftUI

/// Card displaying individual prayer streak information with visual appeal
public struct IndividualPrayerStreakCard: View {

    // MARK: - Properties

    let streak: IndividualPrayerStreak
    let showDetails: Bool

    // MARK: - State

    @State private var isAnimating: Bool = false

    // MARK: - Initialization

    public init(streak: IndividualPrayerStreak, showDetails: Bool = false) {
        self.streak = streak
        self.showDetails = showDetails
    }

    // MARK: - Body

    public var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header: Prayer Name and Icon
                HStack {
                    prayerIcon

                    VStack(alignment: .leading, spacing: 2) {
                        Text(streak.prayer.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        if let lastCompleted = streak.lastCompleted {
                            Text("Last: \(relativeTime(from: lastCompleted))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Not completed yet")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Active indicator
                    if streak.isActiveToday {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                    }
                }

                Divider()

                // Streak Information
                HStack(spacing: 16) {
                    // Current Streak
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: streak.intensityLevel.icon)
                                .foregroundColor(streak.intensityLevel.color)
                                .font(.title2)
                                .scaleEffect(isAnimating ? 1.1 : 1.0)

                            Text("\(streak.currentStreak)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }

                        Text("Day Streak")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Longest Streak
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)

                            Text("\(streak.longestStreak)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }

                        Text("Best")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Details section (conditionally shown)
                if showDetails {
                    // Progress to Next Milestone (only if active)
                    if streak.currentStreak > 0 {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Next milestone: \(streak.nextMilestone) days")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text("\(streak.daysToMilestone) to go")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(streak.intensityLevel.color)
                            }

                            ProgressView(value: streak.milestoneProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: streak.intensityLevel.color))
                                .frame(height: 6)
                        }
                    }

                    // Intensity Label
                    Text(streak.intensityLevel.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(streak.intensityLevel.color)
                        )
                }
            }
            .padding()
        }
        .onAppear {
            if streak.currentStreak > 0 {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }

    // MARK: - Components

    private var prayerIcon: some View {
        let iconData = getPrayerIconData()

        return Image(systemName: iconData.name)
            .font(.title2)
            .foregroundColor(iconData.color)
            .frame(width: 40, height: 40)
            .background(
                Circle()
                    .fill(iconData.color.opacity(0.15))
            )
    }

    private func getPrayerIconData() -> (name: String, color: Color) {
        switch streak.prayer {
        case .fajr:
            return ("sunrise.fill", .orange)
        case .dhuhr:
            return ("sun.max.fill", .yellow)
        case .asr:
            return ("sun.min.fill", .blue)
        case .maghrib:
            return ("sunset.fill", .red)
        case .isha:
            return ("moon.stars.fill", .purple)
        }
    }

    // MARK: - Helper Methods

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview("Individual Prayer Streak Card") {
    VStack(spacing: 16) {
        // Active streak with details
        IndividualPrayerStreakCard(
            streak: IndividualPrayerStreak(
                prayer: .fajr,
                currentStreak: 12,
                longestStreak: 30,
                lastCompleted: Date(),
                isActiveToday: true,
                startDate: Calendar.current.date(byAdding: .day, value: -12, to: Date())
            ),
            showDetails: true
        )

        // Building momentum without details (compact view)
        IndividualPrayerStreakCard(
            streak: IndividualPrayerStreak(
                prayer: .dhuhr,
                currentStreak: 5,
                longestStreak: 15,
                lastCompleted: Date().addingTimeInterval(-3600),
                isActiveToday: true,
                startDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())
            ),
            showDetails: false
        )

        // No streak with details
        IndividualPrayerStreakCard(
            streak: IndividualPrayerStreak(
                prayer: .asr,
                currentStreak: 0,
                longestStreak: 7,
                lastCompleted: Date().addingTimeInterval(-86400 * 3),
                isActiveToday: false,
                startDate: nil
            ),
            showDetails: true
        )
    }
    .padding()
}
