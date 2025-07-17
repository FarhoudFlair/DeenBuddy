import SwiftUI

/// Countdown timer component for next prayer
public struct CountdownTimer: View {
    let nextPrayer: PrayerTime?
    let timeRemaining: TimeInterval?
    
    @State private var currentTime = Date()
    @StateObject private var timerManager = CountdownTimerManager()
    
    public init(nextPrayer: PrayerTime?, timeRemaining: TimeInterval?) {
        self.nextPrayer = nextPrayer
        self.timeRemaining = timeRemaining
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            if let nextPrayer = nextPrayer {
                // Next prayer info
                VStack(spacing: 8) {
                    Text("Next Prayer")
                        .labelLarge()
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    Text(nextPrayer.prayer.displayName)
                        .headlineMedium()
                        .foregroundColor(ColorPalette.textPrimary)
                    
                    Text(prayerTimeString)
                        .titleMedium()
                        .foregroundColor(ColorPalette.textSecondary)
                }
                
                // Countdown display
                if let remaining = calculatedTimeRemaining, remaining > 0 {
                    VStack(spacing: 4) {
                        Text("Time Remaining")
                            .labelMedium()
                            .foregroundColor(ColorPalette.textSecondary)
                        
                        Text(formatTimeRemaining(remaining))
                            .timerLarge()
                            .foregroundColor(ColorPalette.accent)
                            .monospacedDigit()
                            .appAnimation(AppAnimations.timerUpdate, value: remaining)
                            .countdownAccessibility(
                                prayer: nextPrayer.prayer.displayName,
                                timeRemaining: formatTimeRemaining(remaining)
                            )
                    }
                } else {
                    Text("Prayer time has arrived")
                        .titleLarge()
                        .foregroundColor(ColorPalette.success)
                }
            } else {
                // No upcoming prayer
                VStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 48))
                        .foregroundColor(ColorPalette.accent)
                    
                    Text("All prayers completed")
                        .headlineSmall()
                        .foregroundColor(ColorPalette.textPrimary)
                    
                    Text("Next prayer is Fajr tomorrow")
                        .bodyMedium()
                        .foregroundColor(ColorPalette.textSecondary)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorPalette.surfacePrimary)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
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
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: nextPrayer.time)
    }
    
    private var calculatedTimeRemaining: TimeInterval? {
        guard let nextPrayer = nextPrayer else { return nil }
        
        let remaining = nextPrayer.time.timeIntervalSince(currentTime)
        return remaining > 0 ? remaining : 0
    }
    
    private func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
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
        MainActor.assumeIsolated {
            timerManager.cancelTimer(id: timerID)
        }
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
