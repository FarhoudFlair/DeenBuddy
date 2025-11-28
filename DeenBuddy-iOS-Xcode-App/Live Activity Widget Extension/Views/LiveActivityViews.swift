import SwiftUI
import ActivityKit
import WidgetKit
import AppIntents

// MARK: - Widget Settings Helper

private func shouldShowArabicSymbol() -> Bool {
    return WidgetDataManager.shared.shouldShowArabicSymbol()
}

// MARK: - Live Activity Views

@available(iOS 16.1, *)
struct LiveActivityLockScreenView: View {
    let context: ActivityViewContext<PrayerCountdownActivity>

    var body: some View {
        HStack(spacing: 12) {
            // Islamic symbol
            Image("IslamicSymbol")
                .renderingMode(.template)
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 4) {
                // Prayer name
                Text(context.state.nextPrayer.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                // Prayer time
                Text(formatTime(context.state.prayerTime))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                // Arabic symbol based on prayer
                Text("الله")
                    .font(.title2)
                    .foregroundColor(.green)

                // Countdown
                if context.state.hasPassed {
                    Text("Prayer Time")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                } else {
                    Text(timerInterval: Date()...context.state.prayerTime, countsDown: true)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(context.state.isImminent ? .red : .green)
                        .monospacedDigit()
                }

                if #available(iOS 17.0, *) {
                    PrayerCompletionIntentButton(prayer: context.state.nextPrayer)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

@available(iOS 17.0, *)
struct PrayerCompletionIntentButton: View {
    let prayer: Prayer

    var body: some View {
        if let intentOption = PrayerIntentOption(prayer: prayer) {
            Button(intent: ConfirmPrayerCompletionIntent(prayer: intentOption)) {
                Label("Completed", systemImage: "checkmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.green)
            .accessibilityLabel("Mark \(prayer.displayName) as completed")
        } else {
            Label("Unavailable", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Unable to mark \(prayer.displayName) as completed")
        }
    }
}

@available(iOS 16.1, *)
extension LiveActivityLockScreenView {
    @ViewBuilder
    func diagnosticOverlay() -> some View {
        if WidgetDataManager.shared.loadWidgetData() == nil {
            Text("Please open the app to load prayer times")
                .font(.caption2)
                .foregroundColor(.secondary)
        } else {
            EmptyView()
        }
    }
}

// MARK: - Live Activity Views (using shared PrayerCountdownLiveActivityView from DeenAssistCore)

// MARK: - Dynamic Island methods are provided by the shared PrayerCountdownLiveActivityView from DeenAssistCore

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
    
    // MARK: - TimelineProvider methods (for StaticConfiguration widgets)
    
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
        let calendar = Calendar.current
        
        print("🔧 Widget Timeline: Generating entries starting from \(currentDate)")
        
        // Strategy: Generate entries at key moments for accurate countdown display
        // 1. Immediate entry (now)
        // 2. Entries at each remaining prayer time today
        // 3. Entries every 15 minutes for countdown updates
        // 4. Entry at midnight for day transition
        
        let todaysPrayers = currentEntry.widgetData.todaysPrayerTimes
        let upcomingPrayers = todaysPrayers.filter { $0.time > currentDate }
        
        // Add immediate entry
        entries.append(currentEntry)
        
        // Generate entries every 15 minutes for the next 24 hours for smooth countdown
        var entryTime = currentDate
        let endTime = calendar.date(byAdding: .hour, value: 24, to: currentDate) ?? currentDate
        var prayerIndex = 0
        
        while entryTime < endTime && entries.count < 96 { // Max 96 entries (every 15 min for 24h)
            // Check if we've passed a prayer time - create an entry at that moment
            while prayerIndex < upcomingPrayers.count && upcomingPrayers[prayerIndex].time <= entryTime {
                let prayerTime = upcomingPrayers[prayerIndex].time
                
                // Create entry at prayer time (countdown = 0)
                var prayerMomentData = currentEntry.widgetData
                prayerMomentData.timeUntilNextPrayer = 0
                
                let prayerEntry = PrayerWidgetEntry(
                    date: prayerTime,
                    widgetData: prayerMomentData,
                    configuration: currentEntry.configuration
                )
                
                // Avoid duplicate entries
                if !entries.contains(where: { abs($0.date.timeIntervalSince(prayerTime)) < 60 }) {
                    entries.append(prayerEntry)
                }
                
                prayerIndex += 1
            }
            
            // Advance by 15 minutes
            guard let nextTime = calendar.date(byAdding: .minute, value: 15, to: entryTime) else { break }
            entryTime = nextTime
            
            // Find the current next prayer for this time
            let nextPrayerForTime = todaysPrayers.first { $0.time > entryTime }
            
            var updatedData = currentEntry.widgetData
            if let nextPrayer = nextPrayerForTime {
                updatedData.timeUntilNextPrayer = nextPrayer.time.timeIntervalSince(entryTime)
                // Update nextPrayer reference if it changed
                updatedData = WidgetData(
                    nextPrayer: nextPrayer,
                    timeUntilNextPrayer: nextPrayer.time.timeIntervalSince(entryTime),
                    todaysPrayerTimes: updatedData.todaysPrayerTimes,
                    hijriDate: updatedData.hijriDate,
                    location: updatedData.location,
                    calculationMethod: updatedData.calculationMethod,
                    lastUpdated: updatedData.lastUpdated
                )
            } else {
                // All prayers passed - set nil
                updatedData = WidgetData(
                    nextPrayer: nil,
                    timeUntilNextPrayer: nil,
                    todaysPrayerTimes: updatedData.todaysPrayerTimes,
                    hijriDate: updatedData.hijriDate,
                    location: updatedData.location,
                    calculationMethod: updatedData.calculationMethod,
                    lastUpdated: updatedData.lastUpdated
                )
            }
            
            let entry = PrayerWidgetEntry(
                date: entryTime,
                widgetData: updatedData,
                configuration: currentEntry.configuration
            )
            entries.append(entry)
        }
        
        // Sort entries by date
        entries.sort { $0.date < $1.date }
        
        // Determine next refresh time - at the next prayer time or 1 hour from last entry
        let nextRefreshDate: Date
        if let nextPrayer = upcomingPrayers.first {
            // Refresh at next prayer time to update the "next prayer" reference
            nextRefreshDate = nextPrayer.time
        } else {
            // All prayers done, refresh at midnight or 1 hour
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            let midnight = calendar.startOfDay(for: tomorrow)
            nextRefreshDate = min(midnight, calendar.date(byAdding: .hour, value: 1, to: entries.last?.date ?? currentDate) ?? currentDate)
        }
        
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
            
            // Load configuration from shared container
            let configuration = WidgetDataManager.shared.loadWidgetConfiguration()
            
            // Validate data freshness (if data is older than 24 hours, show error state)
            let dataAge = Date().timeIntervalSince(widgetData.lastUpdated)
            if dataAge > 24 * 60 * 60 { // 24 hours
                print("⚠️ Widget: Data is stale (age: \(Int(dataAge/3600)) hours), using error state")
                return PrayerWidgetEntry.errorEntry()
            }
            
            return PrayerWidgetEntry(
                date: Date(),
                widgetData: widgetData,
                configuration: configuration
            )
        } else {
            print("⚠️ Widget: No widget data available - using error state")
            print("🔍 Widget: This usually means the main app hasn't saved widget data yet")
            print("💡 Widget: User should open the DeenBuddy app to initialize widget data")
            // Return error state if no data available
            return PrayerWidgetEntry.errorEntry()
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
