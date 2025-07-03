import SwiftUI
import DeenAssistProtocols

/// Card component for displaying prayer times
public struct PrayerTimeCard: View {
    let prayer: PrayerTime
    let status: PrayerStatus
    let isNext: Bool
    
    public init(prayer: PrayerTime, status: PrayerStatus, isNext: Bool = false) {
        self.prayer = prayer
        self.status = status
        self.isNext = isNext
    }
    
    public var body: some View {
        HStack(spacing: 16) {
            // Prayer name and status indicator
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(prayer.prayer.displayName)
                        .titleMedium()
                        .foregroundColor(ColorPalette.textPrimary)

                    if isNext {
                        Text("NEXT")
                            .labelSmall()
                            .foregroundColor(ColorPalette.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(ColorPalette.accent.opacity(0.1))
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
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorPalette.surfacePrimary)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isNext ? ColorPalette.accent : Color.clear, lineWidth: 2)
                .appAnimation(AppAnimations.smooth, value: isNext)
        )
        .scaleEffect(isNext ? 1.02 : 1.0)
        .appAnimation(AppAnimations.smoothSpring, value: isNext)
        .prayerTimeAccessibility(
            prayer: prayer.prayer.displayName,
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
            return ColorPalette.accent
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
