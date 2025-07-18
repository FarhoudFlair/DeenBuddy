import Foundation
import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Prayer Countdown Live Activity

@available(iOS 16.1, *)
public struct PrayerCountdownActivity: ActivityAttributes {
    
    // MARK: - Static Attributes
    
    public struct ContentState: Codable, Hashable {
        public let nextPrayer: Prayer
        public let prayerTime: Date
        public let timeRemaining: TimeInterval
        public let location: String
        public let hijriDate: String
        public let calculationMethod: String
        
        public init(
            nextPrayer: Prayer,
            prayerTime: Date,
            timeRemaining: TimeInterval,
            location: String,
            hijriDate: String,
            calculationMethod: String
        ) {
            self.nextPrayer = nextPrayer
            self.prayerTime = prayerTime
            self.timeRemaining = timeRemaining
            self.location = location
            self.hijriDate = hijriDate
            self.calculationMethod = calculationMethod
        }
        
        /// Formatted time remaining for display
        public var formattedTimeRemaining: String {
            let hours = Int(timeRemaining) / 3600
            let minutes = Int(timeRemaining) % 3600 / 60
            let seconds = Int(timeRemaining) % 60
            
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%d:%02d", minutes, seconds)
            }
        }
        
        /// Short formatted time for compact displays
        public var shortFormattedTime: String {
            let hours = Int(timeRemaining) / 3600
            let minutes = Int(timeRemaining) % 3600 / 60
            
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }
        
        /// Check if prayer time is imminent (less than 5 minutes)
        public var isImminent: Bool {
            return timeRemaining <= 300 // 5 minutes
        }
        
        /// Check if prayer time has passed
        public var hasPassed: Bool {
            return timeRemaining <= 0
        }
    }
    
    // Fixed attributes that don't change during the activity
    public let prayerId: String
    public let startTime: Date
    public let userId: String?
    
    public init(prayerId: String, startTime: Date = Date(), userId: String? = nil) {
        self.prayerId = prayerId
        self.startTime = startTime
        self.userId = userId
    }
}

// MARK: - Live Activity Manager

@available(iOS 16.1, *)
public class PrayerLiveActivityManager: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = PrayerLiveActivityManager()
    
    private init() {}
    
    // MARK: - Properties
    
    @Published public var currentActivity: Activity<PrayerCountdownActivity>?
    @Published public var isActivityActive: Bool = false
    
    // MARK: - Activity Management
    
    /// Start a new prayer countdown Live Activity
    public func startPrayerCountdown(
        for prayer: Prayer,
        prayerTime: Date,
        location: String,
        hijriDate: String,
        calculationMethod: String
    ) async throws {
        
        // End any existing activity first
        await endCurrentActivity()
        
        let timeRemaining = prayerTime.timeIntervalSince(Date())
        guard timeRemaining > 0 else {
            throw LiveActivityError.prayerTimePassed
        }
        
        let initialContentState = PrayerCountdownActivity.ContentState(
            nextPrayer: prayer,
            prayerTime: prayerTime,
            timeRemaining: timeRemaining,
            location: location,
            hijriDate: hijriDate,
            calculationMethod: calculationMethod
        )
        
        let activityAttributes = PrayerCountdownActivity(
            prayerId: "\(prayer.rawValue)_\(prayerTime.timeIntervalSince1970)",
            startTime: Date()
        )
        
        do {
            // Check if Live Activities are available before attempting to start
            guard isLiveActivityAvailable else {
                throw LiveActivityError.notAvailable
            }

            let activity = try Activity.request(
                attributes: activityAttributes,
                contentState: initialContentState,
                pushType: .token
            )

            await MainActor.run {
                self.currentActivity = activity
                self.isActivityActive = true
            }

            print("✅ Started Live Activity for \(prayer.displayName) prayer")

            // Schedule updates
            scheduleActivityUpdates(for: activity, prayerTime: prayerTime)

        } catch {
            print("❌ Failed to start Live Activity: \(error)")

            // Handle specific ActivityKit errors
            // Note: ActivityKit.ActivityError is not available in all iOS versions
            // Check error description for common permission issues
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("permission") || errorDescription.contains("not enabled") {
                throw LiveActivityError.permissionDenied
            } else {
                throw LiveActivityError.failedToStart(error)
            }
        }
    }
    
    /// Update the current Live Activity with new countdown time
    public func updatePrayerCountdown(
        timeRemaining: TimeInterval,
        location: String? = nil
    ) async {
        guard let activity = currentActivity else { return }
        
        let currentState = activity.contentState
        let updatedState = PrayerCountdownActivity.ContentState(
            nextPrayer: currentState.nextPrayer,
            prayerTime: currentState.prayerTime,
            timeRemaining: timeRemaining,
            location: location ?? currentState.location,
            hijriDate: currentState.hijriDate,
            calculationMethod: currentState.calculationMethod
        )
        
        do {
            await activity.update(using: updatedState)
            print("🔄 Updated Live Activity countdown: \(updatedState.formattedTimeRemaining)")
        } catch {
            print("❌ Failed to update Live Activity: \(error)")
        }
    }
    
    /// End the current Live Activity
    public func endCurrentActivity() async {
        guard let activity = currentActivity else { return }
        
        let finalState = activity.contentState
        let completedState = PrayerCountdownActivity.ContentState(
            nextPrayer: finalState.nextPrayer,
            prayerTime: finalState.prayerTime,
            timeRemaining: 0,
            location: finalState.location,
            hijriDate: finalState.hijriDate,
            calculationMethod: finalState.calculationMethod
        )
        
        do {
            // Keep the activity visible for 5 minutes after prayer time for better visibility
            await activity.end(using: completedState, dismissalPolicy: .after(Date().addingTimeInterval(300)))
            
            await MainActor.run {
                self.currentActivity = nil
                self.isActivityActive = false
            }
            
            print("✅ Ended Live Activity for \(finalState.nextPrayer.displayName) prayer")
        } catch {
            print("❌ Failed to end Live Activity: \(error)")
        }
    }
    
    /// Check if Live Activities are available and enabled
    public var isLiveActivityAvailable: Bool {
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }
    
    /// Request Live Activity permission
    public func requestLiveActivityPermission() async -> Bool {
        // Live Activities don't require explicit permission like notifications
        // They are controlled by system settings
        return isLiveActivityAvailable
    }
    
    // MARK: - Private Methods
    
    private func scheduleActivityUpdates(for activity: Activity<PrayerCountdownActivity>, prayerTime: Date) {
        Task {
            let endTime = prayerTime
            
            while Date() < endTime && currentActivity?.id == activity.id {
                let timeRemaining = endTime.timeIntervalSince(Date())
                
                // Dynamic update interval based on time remaining for better responsiveness
                let updateInterval: TimeInterval
                if timeRemaining <= 60 { // Last minute
                    updateInterval = 5 // Every 5 seconds
                } else if timeRemaining <= 300 { // Last 5 minutes
                    updateInterval = 15 // Every 15 seconds
                } else if timeRemaining <= 1800 { // Last 30 minutes
                    updateInterval = 30 // Every 30 seconds
                } else {
                    updateInterval = 60 // Every minute
                }
                
                try await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
                
                let newTimeRemaining = endTime.timeIntervalSince(Date())
                if newTimeRemaining > 0 {
                    await updatePrayerCountdown(timeRemaining: newTimeRemaining)
                } else {
                    await endCurrentActivity()
                    break
                }
            }
        }
    }
}

// MARK: - Live Activity Errors

public enum LiveActivityError: Error, LocalizedError {
    case prayerTimePassed
    case failedToStart(Error)
    case notAvailable
    case permissionDenied
    
    public var errorDescription: String? {
        switch self {
        case .prayerTimePassed:
            return "Cannot start Live Activity for a prayer time that has already passed"
        case .failedToStart(let error):
            return "Failed to start Live Activity: \(error.localizedDescription)"
        case .notAvailable:
            return "Live Activities are not available on this device"
        case .permissionDenied:
            return "Live Activities permission denied"
        }
    }
}

// MARK: - Live Activity Widget Views

#if canImport(WidgetKit) && !os(macOS)
@available(iOS 16.1, *)
struct PrayerCountdownLiveActivityView: View {
    // Note: ActivityViewContext is only available in widget extensions
    // This view should be moved to the widget extension target
    // For now, we'll use a placeholder to prevent compilation errors
    let state: PrayerCountdownActivity.ContentState
    
    var body: some View {
        VStack(spacing: 8) {
            // Header with Islamic symbol and prayer info
            HStack {
                HStack(spacing: 8) {
                    // Arabic Allah symbol
                    Text("الله")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(state.nextPrayer.color)
                    
                    Image(systemName: state.nextPrayer.systemImageName)
                        .foregroundColor(state.nextPrayer.color)
                        .font(.title2)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.nextPrayer.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text(state.nextPrayer.arabicName)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                }

                Spacer()

                // Countdown
                VStack(alignment: .trailing, spacing: 2) {
                    if state.hasPassed {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("حان وقت الصلاة")
                                .font(.caption)
                                .foregroundColor(state.nextPrayer.color)
                            
                            Text("Prayer Time")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(state.nextPrayer.color)
                        }
                    } else {
                        Text(state.formattedTimeRemaining)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(state.isImminent ? .red : state.nextPrayer.color)
                            .monospacedDigit()
                    }

                    Text(formatPrayerTime(state.prayerTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Footer with location and date
            HStack {
                Text(state.location)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(state.hijriDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func formatPrayerTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Dynamic Island Views

@available(iOS 16.1, *)
extension PrayerCountdownLiveActivityView {
    
    /// Compact leading view for Dynamic Island with Islamic styling
    @ViewBuilder
    func dynamicIslandCompactLeading() -> some View {
        HStack(spacing: 2) {
            // White Arabic Allah symbol
            Text("الله")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Image(systemName: state.nextPrayer.systemImageName)
                .foregroundColor(state.nextPrayer.color)
                .font(.title3)
        }
    }

    /// Compact trailing view for Dynamic Island
    @ViewBuilder
    func dynamicIslandCompactTrailing() -> some View {
        Text(state.shortFormattedTime)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(state.isImminent ? .red : .primary)
            .monospacedDigit()
    }

    /// Minimal view for Dynamic Island with Islamic symbol
    @ViewBuilder
    func dynamicIslandMinimal() -> some View {
        HStack(spacing: 1) {
            // White Arabic Allah symbol for minimal persistent display in top-left
            Text("الله")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Image(systemName: state.nextPrayer.systemImageName)
                .foregroundColor(state.nextPrayer.color)
                .font(.caption)
        }
    }
    
    /// Expanded view for Dynamic Island with enhanced Islamic styling
    @ViewBuilder
    func dynamicIslandExpanded() -> some View {
        VStack(spacing: 6) {
            // Top row: Islamic symbol and prayer info
            HStack {
                HStack(spacing: 6) {
                    // White Arabic Allah symbol
                    Text("الله")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Image(systemName: state.nextPrayer.systemImageName)
                        .foregroundColor(state.nextPrayer.color)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(state.nextPrayer.displayName)
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Text(state.nextPrayer.arabicName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(state.formattedTimeRemaining)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(state.isImminent ? .red : state.nextPrayer.color)
                        .monospacedDigit()

                    Text(formatPrayerTime(state.prayerTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Bottom row: Location and Hijri date
            HStack {
                Text(state.location)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(state.hijriDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}
#endif
