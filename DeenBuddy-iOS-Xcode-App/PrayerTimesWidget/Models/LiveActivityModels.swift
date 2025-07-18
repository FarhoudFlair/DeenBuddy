import Foundation
import ActivityKit

// MARK: - Live Activity Models

@available(iOS 16.1, *)
struct PrayerCountdownActivity: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        let nextPrayer: PrayerTime
        let timeUntilNext: TimeInterval
        let currentTime: Date
        let arabicSymbol: String
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(nextPrayer.prayer.rawValue)
            hasher.combine(timeUntilNext)
            hasher.combine(currentTime)
            hasher.combine(arabicSymbol)
        }

        static func == (lhs: ContentState, rhs: ContentState) -> Bool {
            return lhs.nextPrayer.prayer == rhs.nextPrayer.prayer &&
                   lhs.timeUntilNext == rhs.timeUntilNext &&
                   lhs.currentTime == rhs.currentTime &&
                   lhs.arabicSymbol == rhs.arabicSymbol
        }
        
        // Arabic prayer symbols
        var prayerSymbol: String {
            switch nextPrayer.prayer {
            case .fajr: return "الله" // Allah symbol
            case .dhuhr: return "﷽" // Bismillah
            case .asr: return "الله" // Allah symbol
            case .maghrib: return "﷽" // Bismillah
            case .isha: return "الله" // Allah symbol
            }
        }
        
        var formattedTimeRemaining: String {
            let hours = Int(timeUntilNext) / 3600
            let minutes = Int(timeUntilNext) % 3600 / 60
            let seconds = Int(timeUntilNext) % 60
            
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%d:%02d", minutes, seconds)
            }
        }
        
        /// Short formatted time for compact displays
        var shortFormattedTime: String {
            let hours = Int(timeUntilNext) / 3600
            let minutes = Int(timeUntilNext) % 3600 / 60
            
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }
        
        /// Check if prayer time is imminent (less than 5 minutes)
        var isImminent: Bool {
            return timeUntilNext <= 300 // 5 minutes
        }
        
        /// Check if prayer time has passed
        var hasPassed: Bool {
            return timeUntilNext <= 0
        }
    }
    
    let name: String
    let isUrgent: Bool
    let showArabicText: Bool
}

// MARK: - Live Activity Manager

@available(iOS 16.1, *)
class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<PrayerCountdownActivity>?
    
    func startPrayerCountdown(for prayer: PrayerTime, timeUntil: TimeInterval) async {
        // End existing activity
        await endCurrentActivity()
        
        let attributes = PrayerCountdownActivity(
            name: "Prayer Countdown",
            isUrgent: timeUntil < 300, // Urgent if less than 5 minutes
            showArabicText: true
        )
        
        let contentState = PrayerCountdownActivity.ContentState(
            nextPrayer: prayer,
            timeUntilNext: timeUntil,
            currentTime: Date(),
            arabicSymbol: getArabicSymbol(for: prayer.prayer)
        )
        
        do {
            currentActivity = try Activity<PrayerCountdownActivity>.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: .token
            )
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }
    
    func updatePrayerCountdown(for prayer: PrayerTime, timeUntil: TimeInterval) async {
        guard let activity = currentActivity else { return }

        let contentState = PrayerCountdownActivity.ContentState(
            nextPrayer: prayer,
            timeUntilNext: timeUntil,
            currentTime: Date(),
            arabicSymbol: getArabicSymbol(for: prayer.prayer)
        )

        await activity.update(.init(state: contentState, staleDate: nil))
    }
    
    func endCurrentActivity() async {
        await currentActivity?.end(nil, dismissalPolicy: .immediate)
        currentActivity = nil
    }
    
    private func getArabicSymbol(for prayer: Prayer) -> String {
        switch prayer {
        case .fajr: return "الله"
        case .dhuhr: return "﷽"
        case .asr: return "الله"
        case .maghrib: return "﷽"
        case .isha: return "الله"
        }
    }
}