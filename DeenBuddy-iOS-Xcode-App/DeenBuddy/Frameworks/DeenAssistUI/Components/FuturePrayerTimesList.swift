import SwiftUI

/// List component displaying future prayer times with precision indicators
/// Shows all 5 daily prayers with Ramadan Isha +30m badge when applicable
public struct FuturePrayerTimesList: View {

    // MARK: - Properties

    let prayerTimeResult: FuturePrayerTimeResult
    let showRakahCount: Bool

    @Environment(\.currentTheme) private var currentTheme
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Initialization

    public init(
        prayerTimeResult: FuturePrayerTimeResult,
        showRakahCount: Bool = false
    ) {
        self.prayerTimeResult = prayerTimeResult
        self.showRakahCount = showRakahCount
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: PremiumDesignTokens.spacing12) {
            ForEach(Prayer.chronologicalOrder, id: \.self) { prayer in
                if let time = prayerTime(for: prayer) {
                    prayerTimeRow(for: prayer, time: time)
                }
            }
        }
    }

    // MARK: - Prayer Time Row

    private func prayerTimeRow(for prayer: Prayer, time: Date) -> some View {
        HStack(spacing: PremiumDesignTokens.spacing12) {
            // Prayer icon
            prayerIcon(for: prayer)

            // Prayer name and rakah count
            VStack(alignment: .leading, spacing: 4) {
                Text(prayer.displayName)
                    .font(Typography.titleMedium)
                    .foregroundColor(themeColors.textPrimary)

                if showRakahCount {
                    Text("\(prayer.defaultRakahCount) Rakah")
                        .font(Typography.labelSmall)
                        .foregroundColor(themeColors.textSecondary)
                }
            }

            Spacer()

            // Prayer time display with precision
            prayerTimeDisplay(for: prayer, time: time)

            // Ramadan Isha badge
            if prayer == .isha && prayerTimeResult.isRamadan {
                ramadanIshaBadge
            }
        }
        .padding(PremiumDesignTokens.spacing12)
        .background(ColorPalette.surfacePrimary)
        .cornerRadius(PremiumDesignTokens.cornerRadius12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: prayer, time: time))
        .accessibilityHint(prayerTimeResult.isRamadan && prayer == .isha ? "Ramadan timing with 30 minute extension" : prayer.timingDescription)
    }

    // MARK: - Prayer Icon

    private func prayerIcon(for prayer: Prayer) -> some View {
        Image(systemName: prayer.systemImageName)
            .font(.system(size: 24, weight: .medium))
            .foregroundColor(prayer.color)
            .frame(width: 32, height: 32)
            .accessibilityHidden(true)  // Icon is decorative
    }

    // MARK: - Prayer Time Display

    @ViewBuilder
    private func prayerTimeDisplay(for prayer: Prayer, time: Date) -> some View {
        let precisionLevel = prayerTimeResult.precision

        switch precisionLevel {
        case .exact:
            // Show exact HH:mm time
            Text(formatExactTime(time))
                .font(Typography.prayerTime)  // Monospaced
                .foregroundColor(themeColors.textPrimary)

        case .window(let minutes):
            // Show ±window time range
            Text(formatWindowTime(time, windowMinutes: minutes))
                .font(Typography.bodyMedium)
                .foregroundColor(themeColors.textPrimary)

        case .timeOfDay:
            // Show approximate time of day
            Text(formatTimeOfDay(time))
                .font(Typography.bodyMedium)
                .foregroundColor(themeColors.textSecondary)
                .opacity(0.9)
        }
    }

    // MARK: - Ramadan Isha Badge

    private var ramadanIshaBadge: some View {
        Text("+30m")
            .font(Typography.labelSmall)
            .foregroundColor(Color.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.purple.opacity(0.8))
            .cornerRadius(4)
            .accessibilityLabel("Plus 30 minutes for Ramadan")
    }

    // MARK: - Helpers

    private var themeColors: ThemeAwareColorPalette {
        ThemeAwareColorPalette(theme: currentTheme)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private func prayerTime(for prayer: Prayer) -> Date? {
        prayerTimeResult.prayerTimes.first { $0.prayer == prayer }?.time
    }

    private func formatExactTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private func formatWindowTime(_ date: Date, windowMinutes: Int) -> String {
        let calendar = Calendar.current
        let halfSeconds = Double(windowMinutes) * 60.0 / 2.0
        let halfSecondsRounded = Int(round(halfSeconds))

        guard let startTime = calendar.date(byAdding: .second, value: -halfSecondsRounded, to: date),
              let endTime = calendar.date(byAdding: .second, value: halfSecondsRounded, to: date) else {
            return formatExactTime(date)
        }

        return "\(Self.timeFormatter.string(from: startTime)) - \(Self.timeFormatter.string(from: endTime))"
    }

    private func formatTimeOfDay(_ date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 0..<6: return "Early Morning"
        case 6..<12: return "Morning"
        case 12..<13: return "Noon"
        case 13..<17: return "Afternoon"
        case 17..<20: return "Evening"
        default: return "Night"
        }
    }

    private func accessibilityLabel(for prayer: Prayer, time: Date) -> String {
        let timeString: String
        switch prayerTimeResult.precision {
        case .exact:
            timeString = "at \(formatExactTime(time))"
        case .window(let minutes):
            timeString = "between \(formatWindowTime(time, windowMinutes: minutes))"
        case .timeOfDay:
            timeString = "in the \(formatTimeOfDay(time))"
        }

        var label = "\(prayer.displayName) prayer \(timeString)"

        if showRakahCount {
            label += ", \(prayer.defaultRakahCount) rakah"
        }

        if prayer == .isha && prayerTimeResult.isRamadan {
            label += ", Ramadan timing plus 30 minutes"
        }

        return label
    }
}

// MARK: - Preview

#Preview("Future Prayer Times List") {
    let sampleTimes: [AppPrayerTime] = [
        AppPrayerTime(prayer: .fajr, time: Calendar.current.date(bySettingHour: 5, minute: 30, second: 0, of: Date())!),
        AppPrayerTime(prayer: .dhuhr, time: Calendar.current.date(bySettingHour: 12, minute: 45, second: 0, of: Date())!),
        AppPrayerTime(prayer: .asr, time: Calendar.current.date(bySettingHour: 15, minute: 30, second: 0, of: Date())!),
        AppPrayerTime(prayer: .maghrib, time: Calendar.current.date(bySettingHour: 18, minute: 15, second: 0, of: Date())!),
        AppPrayerTime(prayer: .isha, time: Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!)
    ]

    let result = FuturePrayerTimeResult(
        date: Date(),
        prayerTimes: sampleTimes,
        hijriDate: HijriDate(day: 15, month: .ramadan, year: 1446),
        isRamadan: true,
        disclaimerLevel: .shortTerm,
        calculationTimezone: TimeZone.current,
        isHighLatitude: false,
        precision: .exact
    )

    return FuturePrayerTimesList(prayerTimeResult: result, showRakahCount: true)
        .padding(PremiumDesignTokens.spacing16)
        .background(ColorPalette.backgroundPrimary)
}

#Preview("Future Prayer Times - Window Precision") {
    let sampleTimes: [AppPrayerTime] = [
        AppPrayerTime(prayer: .fajr, time: Calendar.current.date(bySettingHour: 5, minute: 30, second: 0, of: Date())!),
        AppPrayerTime(prayer: .dhuhr, time: Calendar.current.date(bySettingHour: 12, minute: 45, second: 0, of: Date())!),
        AppPrayerTime(prayer: .asr, time: Calendar.current.date(bySettingHour: 15, minute: 30, second: 0, of: Date())!),
        AppPrayerTime(prayer: .maghrib, time: Calendar.current.date(bySettingHour: 18, minute: 15, second: 0, of: Date())!),
        AppPrayerTime(prayer: .isha, time: Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!)
    ]

    let result = FuturePrayerTimeResult(
        date: Date().addingTimeInterval(60 * 60 * 24 * 400),  // ~13 months out
        prayerTimes: sampleTimes,
        hijriDate: HijriDate(day: 10, month: .shawwal, year: 1447),
        isRamadan: false,
        disclaimerLevel: .mediumTerm,
        calculationTimezone: TimeZone.current,
        isHighLatitude: false,
        precision: .window(minutes: 30)
    )

    return FuturePrayerTimesList(prayerTimeResult: result)
        .padding(PremiumDesignTokens.spacing16)
        .background(ColorPalette.backgroundPrimary)
}

#Preview("Future Prayer Times - Dark Mode") {
    let sampleTimes: [AppPrayerTime] = [
        AppPrayerTime(prayer: .fajr, time: Calendar.current.date(bySettingHour: 5, minute: 30, second: 0, of: Date())!),
        AppPrayerTime(prayer: .dhuhr, time: Calendar.current.date(bySettingHour: 12, minute: 45, second: 0, of: Date())!),
        AppPrayerTime(prayer: .asr, time: Calendar.current.date(bySettingHour: 15, minute: 30, second: 0, of: Date())!),
        AppPrayerTime(prayer: .maghrib, time: Calendar.current.date(bySettingHour: 18, minute: 15, second: 0, of: Date())!),
        AppPrayerTime(prayer: .isha, time: Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!)
    ]

    let result = FuturePrayerTimeResult(
        date: Date(),
        prayerTimes: sampleTimes,
        hijriDate: HijriDate(day: 15, month: .ramadan, year: 1446),
        isRamadan: true,
        disclaimerLevel: .shortTerm,
        calculationTimezone: TimeZone.current,
        isHighLatitude: false,
        precision: .exact
    )

    return FuturePrayerTimesList(prayerTimeResult: result, showRakahCount: true)
        .padding(PremiumDesignTokens.spacing16)
        .background(ColorPalette.backgroundPrimary)
        .environment(\.currentTheme, .dark)
        .environment(\.colorScheme, .dark)
}
