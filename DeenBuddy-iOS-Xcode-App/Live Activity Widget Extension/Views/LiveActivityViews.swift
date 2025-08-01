import SwiftUI
import ActivityKit
import WidgetKit

// MARK: - Widget Settings Helper

private func shouldShowArabicSymbol() -> Bool {
    return WidgetDataManager.shared.shouldShowArabicSymbol()
}

// MARK: - Live Activity Views

@available(iOS 16.1, *)
struct LiveActivityLockScreenView: View {
    // Temporarily disabled until we can resolve ActivityViewContext
    // let context: ActivityViewContext<PrayerCountdownActivity>

    var body: some View {
        // Placeholder view until ActivityViewContext is resolved
        HStack(spacing: 12) {
            // Islamic symbol
            Text("☪")
                .font(.title2)
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 4) {
                // Prayer name
                Text("Next Prayer")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                // Prayer time
                Text("Live Activity Placeholder")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                // Arabic symbol
                Text("🕌")
                    .font(.title2)
                    .foregroundColor(.green)

                // Countdown
                Text("--:--")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .monospacedDigit()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // Helper methods temporarily disabled
    // private func formatTime(_ date: Date) -> String {
    //     let formatter = DateFormatter()
    //     formatter.timeStyle = .short
    //     return formatter.string(from: date)
    // }
    //
    // private func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
    //     let hours = Int(timeInterval) / 3600
    //     let minutes = Int(timeInterval) % 3600 / 60
    //
    //     if hours > 0 {
    //         return "\(hours)h \(minutes)m"
    //     } else {
    //         return "\(minutes)m"
    //     }
    // }
}

// MARK: - Live Activity Views

@available(iOS 16.1, *)
struct PrayerCountdownLiveActivityView: View {
    let state: PrayerCountdownActivity.ContentState
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.prayerSymbol)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text(state.nextPrayer.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(state.formattedTimeRemaining)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(timeString(from: state.nextPrayer.time))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

@available(iOS 16.1, *)
extension PrayerCountdownLiveActivityView {
    
    func dynamicIslandCompactLeading() -> some View {
        VStack(alignment: .leading, spacing: 1) {
            // Configurable Arabic prayer symbol
            if shouldShowArabicSymbol() {
                Text(state.prayerSymbol)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .accessibilityLabel("Prayer symbol")
                    .accessibilityHint("Islamic symbol indicating prayer time")
            }

            Text(state.nextPrayer.displayName)
                .font(.caption2)
                .foregroundColor(.primary)
        }
        .padding(4)
    }
    
    func dynamicIslandCompactTrailing() -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(state.formattedTimeRemaining)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(timeString(from: state.nextPrayer.time))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(4)
    }
    
    func dynamicIslandMinimal() -> some View {
        HStack(spacing: 2) {
            // Configurable Arabic prayer symbol for minimal persistent display
            if shouldShowArabicSymbol() {
                Text(state.prayerSymbol)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .accessibilityLabel("Prayer symbol")
                    .accessibilityHint("Islamic symbol indicating prayer time")
            }

            Text(state.formattedTimeRemaining)
                .font(.caption2)
                .foregroundColor(.primary)
        }
        .padding(2)
    }
    
    func dynamicIslandExpanded() -> some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    // Use only the prayer symbol for consistency
                    if shouldShowArabicSymbol() {
                        Text(state.prayerSymbol)
                            .font(.title)
                            .foregroundColor(.accentColor)
                            .accessibilityLabel("Prayer symbol")
                            .accessibilityHint("Islamic symbol indicating prayer time")
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(state.nextPrayer.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(timeString(from: state.nextPrayer.time))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Prayer countdown progress
            VStack(spacing: 4) {
                HStack {
                    Text("Time Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(state.formattedTimeRemaining)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                // Progress bar (conceptual - would need actual prayer time data)
                ProgressView(value: 0.7) // Placeholder value
                    .progressViewStyle(LinearProgressViewStyle())
                    .accentColor(.accentColor)
            }
            
            // Islamic quote or verse
            Text("\"And establish prayer and give zakah and bow with those who bow.\"")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .italic()
        }
        .padding()
    }
}

// MARK: - App Launch Lock Screen View

@available(iOS 16.1, *)
struct AppLaunchLockScreenView: View {
    let state: AppLaunchActivity.ContentState
    
    var body: some View {
        VStack(spacing: 12) {
            // Main Allah symbol
            Text(state.greeting)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .scaleEffect(state.isLoading ? 1.0 : 1.1)
                .animation(.easeInOut(duration: 0.5), value: state.isLoading)
            
            // Subtitle greeting
            Text(state.subGreeting)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Progress indicator
            if state.isLoading {
                ProgressView(value: state.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                    .frame(maxWidth: 200)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Dynamic Island Extensions

@available(iOS 16.1, *)
extension View {
    func dynamicIslandStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .cornerRadius(8)
    }
}

// MARK: - Timeline Provider for Widget Extension

/// Timeline provider for prayer time widgets
struct PrayerTimeProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> PrayerWidgetEntry {
        return .placeholder()
    }
    
    func getSnapshot(in context: Context, completion: @escaping (PrayerWidgetEntry) -> Void) {
        let entry: PrayerWidgetEntry
        
        if context.isPreview {
            entry = .placeholder()
        } else {
            entry = getCurrentEntry()
        }
        
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerWidgetEntry>) -> Void) {
        print("📅 Widget Timeline: getTimeline() called for context: \(context.family)")
        
        let currentEntry = getCurrentEntry()
        var entries: [PrayerWidgetEntry] = []
        let currentDate = Date()
        
        print("🔧 Widget Timeline: Generating entries starting from \(currentDate)")
        
        // Generate a timeline for the next 60 minutes, updating every minute
        for minuteOffset in 0..<60 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            var updatedData = currentEntry.widgetData
            
            // Recalculate time until next prayer for the entry's date
            if let nextPrayerTime = updatedData.nextPrayer?.time {
                updatedData.timeUntilNextPrayer = nextPrayerTime.timeIntervalSince(entryDate)
            }
            
            let entry = PrayerWidgetEntry(
                date: entryDate,
                widgetData: updatedData,
                configuration: currentEntry.configuration
            )
            entries.append(entry)
        }

        // Set the refresh policy to update after the last generated entry
        let nextRefreshDate = entries.last?.date ?? Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        
        let timeline = Timeline(
            entries: entries,
            policy: .after(nextRefreshDate)
        )
        
        print("✅ Widget Timeline: Generated \(entries.count) entries, next refresh: \(nextRefreshDate)")
        completion(timeline)
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentEntry() -> PrayerWidgetEntry {
        print("🔧 Widget Timeline Provider: getCurrentEntry() called")
        
        // Load widget data from shared container
        if let widgetData = WidgetDataManager.shared.loadWidgetData() {
            print("✅ Widget: Successfully loaded widget data from shared container")
            print("🔍 Widget: Next prayer: \(widgetData.nextPrayer?.prayer.displayName ?? "None")")
            print("🔍 Widget: Location: \(widgetData.location)")
            
            let configuration = WidgetDataManager.shared.loadWidgetConfiguration()
            return PrayerWidgetEntry(
                date: Date(),
                widgetData: widgetData,
                configuration: configuration
            )
        } else {
            print("⚠️ Widget: No widget data available - using placeholder")
            print("🔍 Widget: This usually means the main app hasn't saved widget data yet")
            // Return placeholder if no data available
            return PrayerWidgetEntry.placeholder()
        }
    }
    
    private func generateTimelineEntries(from currentEntry: PrayerWidgetEntry) -> [PrayerWidgetEntry] {
        var entries: [PrayerWidgetEntry] = []
        let now = Date()
        
        // Add current entry
        entries.append(currentEntry)
        
        // Generate entries for next few hours to handle countdown updates
        for minuteOffset in stride(from: 5, through: 60, by: 5) {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: now) ?? now
            
            // Update time until next prayer
            var updatedWidgetData = currentEntry.widgetData
            if let nextPrayerTime = updatedWidgetData.nextPrayer?.time {
                let timeUntilNext = nextPrayerTime.timeIntervalSince(entryDate)
                if timeUntilNext > 0 {
                    updatedWidgetData = WidgetData(
                        nextPrayer: updatedWidgetData.nextPrayer,
                        timeUntilNextPrayer: timeUntilNext,
                        todaysPrayerTimes: updatedWidgetData.todaysPrayerTimes,
                        hijriDate: updatedWidgetData.hijriDate,
                        location: updatedWidgetData.location,
                        calculationMethod: updatedWidgetData.calculationMethod,
                        lastUpdated: updatedWidgetData.lastUpdated
                    )
                }
            }
            
            let entry = PrayerWidgetEntry(
                date: entryDate,
                widgetData: updatedWidgetData,
                configuration: currentEntry.configuration
            )
            
            entries.append(entry)
        }
        
        return entries
    }
    
    private func getNextRefreshDate(from entry: PrayerWidgetEntry) -> Date {
        let now = Date()
        
        // Refresh at strategic times:
        // 1. At the next prayer time
        if let nextPrayerTime = entry.widgetData.nextPrayer?.time,
           nextPrayerTime > now {
            return nextPrayerTime
        }
        
        // 2. At midnight for new day
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let midnight = calendar.startOfDay(for: tomorrow)
        
        // 3. Default to 15 minutes from now
        let defaultRefresh = calendar.date(byAdding: .minute, value: 15, to: now) ?? now
        
        return min(midnight, defaultRefresh)
    }
}