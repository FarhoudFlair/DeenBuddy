import Foundation
import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Dynamic Island Manager

@available(iOS 16.1, *)
public class DynamicIslandManager: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = DynamicIslandManager()
    
    private init() {}
    
    // MARK: - Properties
    
    @Published public var isDynamicIslandSupported: Bool = false
    @Published public var currentPrayerActivity: Activity<PrayerCountdownActivity>?
    
    // MARK: - Device Support
    
    /// Check if device supports Dynamic Island
    public func checkDynamicIslandSupport() {
        // Dynamic Island requires Live Activities enabled and supported hardware
        isDynamicIslandSupported = ActivityAuthorizationInfo().areActivitiesEnabled && hasDynamicIslandHardware()
        
        print("📱 Dynamic Island support: \(isDynamicIslandSupported)")
    }
    
    /// Start Dynamic Island prayer countdown
    public func startPrayerCountdownInDynamicIsland(
        for prayer: Prayer,
        prayerTime: Date,
        location: String,
        hijriDate: String,
        calculationMethod: String
    ) async throws {
        
        guard isDynamicIslandSupported else {
            throw DynamicIslandError.notSupported
        }
        
        // Use the Live Activity manager to start the activity
        try await PrayerLiveActivityManager.shared.startPrayerCountdown(
            for: prayer,
            prayerTime: prayerTime,
            location: location,
            hijriDate: hijriDate,
            calculationMethod: calculationMethod
        )
        
        await MainActor.run {
            self.currentPrayerActivity = PrayerLiveActivityManager.shared.currentActivity
        }
        
        print("🏝️ Started Dynamic Island prayer countdown for \(prayer.displayName)")
    }
    
    /// Update Dynamic Island content
    public func updateDynamicIslandContent(timeRemaining: TimeInterval) async {
        guard isDynamicIslandSupported else { return }
        
        await PrayerLiveActivityManager.shared.updatePrayerCountdown(timeRemaining: timeRemaining)
        
        await MainActor.run {
            self.currentPrayerActivity = PrayerLiveActivityManager.shared.currentActivity
        }
    }
    
    /// End Dynamic Island activity
    public func endDynamicIslandActivity() async {
        guard isDynamicIslandSupported else { return }
        
        await PrayerLiveActivityManager.shared.endCurrentActivity()
        
        await MainActor.run {
            self.currentPrayerActivity = nil
        }
        
        print("🏝️ Ended Dynamic Island prayer countdown")
    }
    
    /// Get Dynamic Island presentation style based on prayer urgency
    public func getDynamicIslandStyle(for contentState: PrayerCountdownActivity.ContentState) -> DynamicIslandStyle {
        if contentState.hasPassed {
            return .prayerTime
        } else if contentState.isImminent {
            return .urgent
        } else if contentState.timeRemaining <= 1800 { // 30 minutes
            return .approaching
        } else {
            return .normal
        }
    }
}

// MARK: - Dynamic Island Styles

public enum DynamicIslandStyle {
    case normal
    case approaching
    case urgent
    case prayerTime
    
    public var backgroundColor: Color {
        switch self {
        case .normal:
            return .clear
        case .approaching:
            return .orange.opacity(0.1)
        case .urgent:
            return .red.opacity(0.1)
        case .prayerTime:
            return .green.opacity(0.1)
        }
    }
    
    public var textColor: Color {
        switch self {
        case .normal:
            return .primary
        case .approaching:
            return .orange
        case .urgent:
            return .red
        case .prayerTime:
            return .green
        }
    }
    
    public var pulseAnimation: Bool {
        switch self {
        case .urgent, .prayerTime:
            return true
        default:
            return false
        }
    }
}

// MARK: - Dynamic Island Errors

public enum DynamicIslandError: Error, LocalizedError {
    case notSupported
    case activityNotFound
    case updateFailed
    case invalidPrayerRawValue(String)
    
    public var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Dynamic Island is not supported on this device"
        case .activityNotFound:
            return "No active Dynamic Island activity found"
        case .updateFailed:
            return "Failed to update Dynamic Island content"
        case .invalidPrayerRawValue(let raw):
            return "Invalid prayer value: \(raw)"
        }
    }
}

// MARK: - Enhanced Dynamic Island Views

#if canImport(WidgetKit) && !os(macOS)
@available(iOS 16.1, *)
public struct PrayerDynamicIslandView: View {
    // Note: ActivityViewContext is only available in widget extensions
    // This view should be moved to the widget extension target
    let state: PrayerCountdownActivity.ContentState
    @StateObject private var dynamicIslandManager = DynamicIslandManager.shared

    public var body: some View {
        // This view is only intended for widget extensions
        // In the main app, we return a placeholder
        Text("Dynamic Island View - Widget Extension Only")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    // MARK: - Helper Views (for widget extension use)
    /*
    // These views are intended for use in widget extensions
    // They are commented out in the main app to avoid compilation issues
    
    @ViewBuilder
    private func expandedLeadingView(style: DynamicIslandStyle) -> some View {
        HStack(spacing: 8) {
            Image(systemName: state.nextPrayer.systemImageName)
                .foregroundColor(state.nextPrayer.color)
                .font(.title2)
                .scaleEffect(style.pulseAnimation ? 1.1 : 1.0)
                .animation(style.pulseAnimation ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .none, value: style.pulseAnimation)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(state.nextPrayer.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(state.nextPrayer.arabicName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func expandedTrailingView(style: DynamicIslandStyle) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            if state.hasPassed {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Prayer")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(style.textColor)
                    
                    Text("Time")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(style.textColor)
                }
            } else {
                Text(state.formattedTimeRemaining)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(style.textColor)
                    .monospacedDigit()
                    .scaleEffect(style.pulseAnimation ? 1.05 : 1.0)
                    .animation(style.pulseAnimation ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .none, value: style.pulseAnimation)
            }
            
            Text(formatPrayerTime(state.prayerTime))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private func expandedBottomView(style: DynamicIslandStyle) -> some View {
        HStack {
            // Location
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(state.location)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Hijri date
            Text(state.hijriDate)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Progress indicator
            if !state.hasPassed {
                ProgressView(value: progressValue)
                    .progressViewStyle(LinearProgressViewStyle(tint: state.nextPrayer.color))
                    .frame(width: 40)
            }
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Compact Views
    
    @ViewBuilder
    private func compactLeadingView(style: DynamicIslandStyle) -> some View {
        Image(systemName: state.nextPrayer.systemImageName)
            .foregroundColor(state.nextPrayer.color)
            .font(.title3)
            .scaleEffect(style.pulseAnimation ? 1.1 : 1.0)
            .animation(style.pulseAnimation ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .none, value: style.pulseAnimation)
    }
    
    @ViewBuilder
    private func compactTrailingView(style: DynamicIslandStyle) -> some View {
        if state.hasPassed {
            Text("Now")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(style.textColor)
        } else {
            Text(state.shortFormattedTime)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(style.textColor)
                .monospacedDigit()
        }
    }
    
    // MARK: - Minimal View
    
    @ViewBuilder
    private func minimalView(style: DynamicIslandStyle) -> some View {
        Image(systemName: state.nextPrayer.systemImageName)
            .foregroundColor(state.nextPrayer.color)
            .font(.caption)
            .scaleEffect(style.pulseAnimation ? 1.2 : 1.0)
            .animation(style.pulseAnimation ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .none, value: style.pulseAnimation)
    }
    
    // MARK: - Helper Properties
    
    private var progressValue: Double {
        // Assume maximum prayer interval is 6 hours (21600 seconds)
        let maxInterval: TimeInterval = 21600
        let elapsed = maxInterval - state.timeRemaining
        return min(1.0, max(0.0, elapsed / maxInterval))
    }
    
    private func formatPrayerTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    */
}
#endif

// MARK: - Dynamic Island Integration Service

@available(iOS 16.1, *)
public class DynamicIslandIntegrationService: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = DynamicIslandIntegrationService()
    
    private init() {
        DynamicIslandManager.shared.checkDynamicIslandSupport()
    }
    
    // MARK: - Integration Methods
    
    /// Start prayer countdown with automatic Dynamic Island integration
    internal func startPrayerCountdownWithDynamicIsland(
        prayerTime: PrayerTime,
        location: String,
        hijriDate: HijriDate,
        calculationMethod: CalculationMethod
    ) async throws {
        
        let timeRemaining = prayerTime.time.timeIntervalSince(Date())
        guard timeRemaining > 0 else {
            throw DynamicIslandError.updateFailed
        }
        
        // Convert WidgetPrayer to Prayer using the widgetRawValue initializer
        guard let convertedPrayer = Prayer(widgetRawValue: prayerTime.prayer.rawValue) else {
            throw DynamicIslandError.updateFailed
        }

        try await DynamicIslandManager.shared.startPrayerCountdownInDynamicIsland(
            for: convertedPrayer,
            prayerTime: prayerTime.time,
            location: location,
            hijriDate: hijriDate.formatted,
            calculationMethod: calculationMethod.displayName
        )
        
        // Schedule automatic updates
        scheduleAutomaticUpdates(until: prayerTime.time)
    }
    
    /// Schedule automatic updates for Dynamic Island
    private func scheduleAutomaticUpdates(until endTime: Date) {
        Task {
            while Date() < endTime {
                let timeRemaining = endTime.timeIntervalSince(Date())
                
                if timeRemaining > 0 {
                    await DynamicIslandManager.shared.updateDynamicIslandContent(timeRemaining: timeRemaining)
                    
                    // Update frequency based on time remaining
                    let updateInterval: TimeInterval
                    if timeRemaining <= 300 { // Last 5 minutes
                        updateInterval = 10 // Every 10 seconds
                    } else if timeRemaining <= 1800 { // Last 30 minutes
                        updateInterval = 30 // Every 30 seconds
                    } else {
                        updateInterval = 60 // Every minute
                    }
                    
                    try await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
                } else {
                    await DynamicIslandManager.shared.endDynamicIslandActivity()
                    break
                }
            }
        }
    }
    
    /// Check if Dynamic Island is available for prayer notifications
    public var isDynamicIslandAvailable: Bool {
        return DynamicIslandManager.shared.isDynamicIslandSupported
    }
}
