import SwiftUI

/// Countdown timer component for next prayer
public struct CountdownTimer: View {
    let nextPrayer: PrayerTime?
    let timeRemaining: TimeInterval?
    
    @State private var currentTime = Date()
    @StateObject private var timerManager = CountdownTimerManager()
    @Environment(\.currentTheme) private var currentTheme
    
    public init(nextPrayer: PrayerTime?, timeRemaining: TimeInterval?) {
        self.nextPrayer = nextPrayer
        self.timeRemaining = timeRemaining
    }
    
    private var themeColors: ThemeAwareColorPalette {
        ThemeAwareColorPalette(theme: currentTheme)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let nextPrayer = nextPrayer {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Next Prayer")
                        .font(.caption)
                        .foregroundColor(ColorPalette.textSecondary)
                        .textCase(.uppercase)

                    Text(prayerTimeString)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(ColorPalette.textPrimary)
                        .minimumScaleFactor(0.8)

                    Text(nextPrayer.prayer.displayName)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(ColorPalette.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(ColorPalette.primary.opacity(0.1))
                        )
                }

                if let components = timeRemainingComponents {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Starts In")
                            .font(.caption)
                            .foregroundColor(ColorPalette.textSecondary)
                            .textCase(.uppercase)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(components.display)
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .foregroundColor(themeColors.nextPrayerHighlight)
                                .appAnimation(AppAnimations.timerUpdate, value: components.display)
                                .countdownAccessibility(
                                    prayer: nextPrayer.prayer.displayName,
                                    timeRemaining: components.accessibility
                                )

                            Text("remaining")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                    }
                } else {
                    Text("Prayer time is starting now")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ColorPalette.textSecondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("All prayers completed")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(ColorPalette.textPrimary)

                    Text("We'll notify you when the next prayer is available")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ColorPalette.textSecondary)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(ColorPalette.surfacePrimary)
                .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(ColorPalette.border, lineWidth: 1)
        )
        .onReceive(timerManager.$currentTime) { time in
            currentTime = time
        }
        .onAppear {
            timerManager.startTimer()
        }
        .onDisappear {
            timerManager.stopTimer()
        }
    }
    
    private var prayerTimeString: String {
        guard let nextPrayer = nextPrayer else { return "" }
        
        return Self.timeFormatter.string(from: nextPrayer.time)
    }
    
    private var calculatedTimeRemaining: TimeInterval? {
        guard let nextPrayer = nextPrayer else { return nil }

        let remaining = nextPrayer.time.timeIntervalSince(currentTime)
        return remaining > 0 ? remaining : nil
    }

    private var timeRemainingInterval: TimeInterval? {
        if let explicit = timeRemaining, explicit > 0 {
            return explicit
        }
        return calculatedTimeRemaining
    }

    private var timeRemainingComponents: (display: String, accessibility: String)? {
        guard let interval = timeRemainingInterval, interval > 0 else { return nil }

        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            let display = "\(hours)h \(minutes)m"

            var accessibility = "\(hours) hour\(hours == 1 ? "" : "s")"
            if minutes > 0 {
                accessibility += " and \(minutes) minute\(minutes == 1 ? "" : "s")"
            }

            return (display, accessibility)
        } else if minutes > 0 {
            let display = "\(minutes)m"
            let accessibility = "\(minutes) minute\(minutes == 1 ? "" : "s")"
            return (display, accessibility)
        } else {
            return ("<1m", "less than one minute")
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale.autoupdatingCurrent
        return formatter
    }()
}

// MARK: - Timer Manager

@MainActor
private class CountdownTimerManager: ObservableObject {
    @Published var currentTime = Date()
    
    private let timerManager = BatteryAwareTimerManager.shared
    private let timerID = "countdown-timer-\(UUID().uuidString)"
    
    func startTimer() {
        timerManager.scheduleTimer(id: timerID, type: .countdownUI) { [weak self] in
            Task { @MainActor in
                self?.currentTime = Date()
            }
        }
    }
    
    func stopTimer() {
        timerManager.cancelTimer(id: timerID)
    }
    
    deinit {
        // Use the synchronous timer cancellation method designed for deinit
        timerManager.cancelTimerSync(id: timerID)
    }
}

// MARK: - Preview

#Preview("Countdown Timer") {
    VStack(spacing: 20) {
        CountdownTimer(
            nextPrayer: PrayerTime(prayer: .maghrib, time: Date().addingTimeInterval(3665)),
            timeRemaining: 3665
        )
        
        CountdownTimer(
            nextPrayer: PrayerTime(prayer: .isha, time: Date().addingTimeInterval(125)),
            timeRemaining: 125
        )
        
        CountdownTimer(
            nextPrayer: nil,
            timeRemaining: nil
        )
    }
    .padding()
    .background(ColorPalette.backgroundPrimary)
}
