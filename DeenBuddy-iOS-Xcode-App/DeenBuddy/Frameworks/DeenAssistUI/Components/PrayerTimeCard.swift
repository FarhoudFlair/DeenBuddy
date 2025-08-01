import SwiftUI

/// Card component for displaying prayer times
public struct PrayerTimeCard: View {
    let prayer: PrayerTime
    let status: PrayerStatus
    let isNext: Bool
    
    @Environment(\.currentTheme) private var currentTheme
    
    public init(prayer: PrayerTime, status: PrayerStatus, isNext: Bool = false) {
        self.prayer = prayer
        self.status = status
        self.isNext = isNext
    }
    
    private var themeColors: ThemeAwareColorPalette {
        ThemeAwareColorPalette(theme: currentTheme)
    }
    
    public var body: some View {
        HStack(spacing: 16) {
            // Prayer name and status indicator
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(prayer.prayer.displayName)
                            .titleMedium()
                            .foregroundColor(ColorPalette.textPrimary)

                        Text("\(prayer.prayer.defaultRakahCount) rakahs")
                            .caption()
                            .foregroundColor(ColorPalette.rakahText)
                    }

                    if isNext {
                        Text("NEXT")
                            .labelSmall()
                            .fontWeight(.semibold)
                            .foregroundColor(themeColors.nextPrayerHighlight)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                ZStack {
                                    Capsule()
                                        .fill(themeColors.nextPrayerHighlight.opacity(0.12))
                                    
                                    Capsule()
                                        .stroke(themeColors.nextPrayerHighlight.opacity(0.2), lineWidth: 0.5)
                                }
                            )
                            .pulseAnimation(isActive: isNext)
                    }
                }

                if let location = prayer.location {
                    Text(location)
                        .bodySmall()
                        .foregroundColor(ColorPalette.textSecondary)
                }
            }

            Spacer()

            // Prayer time
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeString)
                    .prayerTime()
                    .foregroundColor(statusColor)

                if isNext, let timeRemaining = timeRemainingString {
                    Text(timeRemaining)
                        .labelSmall()
                        .foregroundColor(ColorPalette.textSecondary)
                        .appAnimation(AppAnimations.timerUpdate, value: timeRemaining)
                }
            }
        }
        .padding(16)
        .background(
            ZStack {
                // Base card background
                RoundedRectangle(cornerRadius: 16)
                    .fill(ColorPalette.surfacePrimary)
                
                // Enhanced background for next prayer
                if isNext {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    themeColors.nextPrayerHighlight.opacity(0.08),
                                    themeColors.nextPrayerHighlight.opacity(0.04)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // Subtle inner border for next prayer
                if isNext {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    themeColors.nextPrayerHighlight.opacity(0.3),
                                    themeColors.nextPrayerHighlight.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            }
            .shadow(
                color: isNext ? themeColors.nextPrayerHighlight.opacity(0.15) : Color.black.opacity(0.04),
                radius: isNext ? 8 : 4,
                x: 0,
                y: isNext ? 4 : 2
            )
            .shadow(
                color: Color.black.opacity(0.02),
                radius: 2,
                x: 0,
                y: 1
            )
        )
        .scaleEffect(isNext ? 1.02 : 1.0)
        .appAnimation(AppAnimations.smoothSpring, value: isNext)
        .prayerTimeAccessibility(
            prayer: "\(prayer.prayer.displayName), \(prayer.prayer.defaultRakahCount) rakahs",
            time: timeString,
            status: status.description,
            isNext: isNext
        )
        .onTapGesture {
            HapticFeedback.light()
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: prayer.time)
    }
    
    private var statusColor: Color {
        if isNext {
            return themeColors.nextPrayerHighlight
        }
        return Color.prayerStatus(status)
    }
    
    private var timeRemainingString: String? {
        guard isNext else { return nil }
        
        let now = Date()
        let timeInterval = prayer.time.timeIntervalSince(now)
        
        guard timeInterval > 0 else { return nil }
        
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Preview

#Preview("Prayer Time Cards") {
    VStack(spacing: 12) {
        PrayerTimeCard(
            prayer: PrayerTime(prayer: .fajr, time: Date().addingTimeInterval(3600), location: "New York"),
            status: .upcoming,
            isNext: true
        )
        
        PrayerTimeCard(
            prayer: PrayerTime(prayer: .dhuhr, time: Date().addingTimeInterval(7200)),
            status: .upcoming
        )
        
        PrayerTimeCard(
            prayer: PrayerTime(prayer: .asr, time: Date().addingTimeInterval(-3600)),
            status: .completed
        )
        
        PrayerTimeCard(
            prayer: PrayerTime(prayer: .maghrib, time: Date()),
            status: .active
        )
    }
    .padding()
    .background(ColorPalette.backgroundPrimary)
}
