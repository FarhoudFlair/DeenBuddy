import WidgetKit
import SwiftUI

/// Main widget bundle containing all prayer time widgets
@main
struct PrayerTimesWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextPrayerWidget()
        TodaysPrayerTimesWidget()
        PrayerCountdownWidget()
    }
}

// MARK: - Next Prayer Widget

/// Widget showing the next upcoming prayer with countdown
struct NextPrayerWidget: Widget {
    let kind: String = "NextPrayerWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimeProvider()) { entry in
            NextPrayerWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Prayer")
        .description("Shows the next upcoming prayer time with countdown")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Today's Prayer Times Widget

/// Widget showing all prayer times for today
struct TodaysPrayerTimesWidget: Widget {
    let kind: String = "TodaysPrayerTimesWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimeProvider()) { entry in
            TodaysPrayerTimesWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Prayer Times")
        .description("Shows all prayer times for today")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Prayer Countdown Widget

/// Widget showing countdown to next prayer
struct PrayerCountdownWidget: Widget {
    let kind: String = "PrayerCountdownWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimeProvider()) { entry in
            PrayerCountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("Prayer Countdown")
        .description("Shows countdown to next prayer")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Timeline Provider

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
        let currentEntry = getCurrentEntry()
        let entries = generateTimelineEntries(from: currentEntry)
        
        // Determine next refresh time
        let nextRefreshDate = getNextRefreshDate(from: currentEntry)
        
        let timeline = Timeline(
            entries: entries,
            policy: .after(nextRefreshDate)
        )
        
        completion(timeline)
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentEntry() -> PrayerWidgetEntry {
        // Load widget data from shared container
        if let widgetData = WidgetDataManager.shared.loadWidgetData() {
            let configuration = WidgetDataManager.shared.loadWidgetConfiguration()
            return PrayerWidgetEntry(
                date: Date(),
                widgetData: widgetData,
                configuration: configuration
            )
        } else {
            // Return placeholder if no data available
            return .placeholder()
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

// MARK: - Widget Views

/// View for Next Prayer Widget (Small/Medium)
struct NextPrayerWidgetView: View {
    let entry: PrayerWidgetEntry
    
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width < 200 {
                // Small widget
                NextPrayerSmallView(entry: entry)
            } else {
                // Medium widget
                NextPrayerMediumView(entry: entry)
            }
        }
    }
}

/// View for Today's Prayer Times Widget (Medium/Large)
struct TodaysPrayerTimesWidgetView: View {
    let entry: PrayerWidgetEntry
    
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.height > 300 {
                // Large widget
                TodaysPrayerTimesLargeView(entry: entry)
            } else {
                // Medium widget
                TodaysPrayerTimesMediumView(entry: entry)
            }
        }
    }
}

/// View for Prayer Countdown Widget (Small)
struct PrayerCountdownWidgetView: View {
    let entry: PrayerWidgetEntry
    
    var body: some View {
        PrayerCountdownSmallView(entry: entry)
    }
}

// MARK: - Preview

#if DEBUG
struct PrayerTimesWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NextPrayerWidgetView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Next Prayer - Small")
            
            NextPrayerWidgetView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Next Prayer - Medium")
            
            TodaysPrayerTimesWidgetView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Today's Prayers - Large")
        }
    }
}
#endif
