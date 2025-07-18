//
//  PrayerTimesWidget.swift
//  PrayerTimesWidget
//
//  Created by Farhoud Talebi on 2025-07-17.
//

import Foundation
import SwiftUI
import WidgetKit
import ActivityKit

// MARK: - Widget Bundle

@main
struct PrayerTimesWidgetBundle: WidgetBundle {
    var body: some Widget {
        // iOS 14+ Home Screen Widgets
        NextPrayerWidget()
        TodaysPrayerTimesWidget()
        PrayerCountdownWidget()
        
        // iOS 16+ Lock Screen Widgets
        if #available(iOS 16.0, *) {
            NextPrayerLockScreenWidget()
            PrayerCountdownLockScreenWidget()
        }
        
        // iOS 17+ Interactive Widgets (future)
        if #available(iOS 17.0, *) {
            // InteractivePrayerWidget() // For future implementation
        }

        // iOS 16.1+ Live Activities
        if #available(iOS 16.1, *) {
            PrayerCountdownLiveActivity()
        }
    }
}



// MARK: - Next Prayer Widget

/// Widget showing the next upcoming prayer with countdown
struct NextPrayerWidget: Widget {
    let kind: String = "NextPrayerWidget"

    var body: StaticConfiguration<NextPrayerWidgetView> {
        StaticConfiguration(kind: kind, provider: PrayerTimeProvider()) { entry in
            NextPrayerWidgetView(entry: entry)
        }
    }
}

// MARK: - Today's Prayer Times Widget

/// Widget showing all prayer times for today
struct TodaysPrayerTimesWidget: Widget {
    let kind: String = "TodaysPrayerTimesWidget"

    var body: StaticConfiguration<TodaysPrayerTimesWidgetView> {
        StaticConfiguration(kind: kind, provider: PrayerTimeProvider()) { entry in
            TodaysPrayerTimesWidgetView(entry: entry)
        }
    }
}

// MARK: - Prayer Countdown Widget

/// Widget showing countdown to next prayer
struct PrayerCountdownWidget: Widget {
    let kind: String = "PrayerCountdownWidget"

    var body: StaticConfiguration<PrayerCountdownWidgetView> {
        StaticConfiguration(kind: kind, provider: PrayerTimeProvider()) { entry in
            PrayerCountdownWidgetView(entry: entry)
        }
    }
}

// MARK: - Lock Screen Widget

@available(iOS 16.0, *)
struct NextPrayerLockScreenWidget: Widget {
    let kind: String = "NextPrayerLockScreenWidget"
    
    var body: StaticConfiguration<NextPrayerLockScreenView> {
        StaticConfiguration(kind: kind, provider: PrayerTimeProvider()) { entry in
            NextPrayerLockScreenView(entry: entry)
        }
    }
}

@available(iOS 16.0, *)
struct PrayerCountdownLockScreenWidget: Widget {
    let kind: String = "PrayerCountdownLockScreenWidget"
    
    var body: StaticConfiguration<PrayerCountdownLockScreenView> {
        StaticConfiguration(kind: kind, provider: PrayerTimeProvider()) { entry in
            PrayerCountdownLockScreenView(entry: entry)
        }
    }
}

// MARK: - Live Activity Widget

@available(iOS 16.1, *)
struct PrayerCountdownLiveActivity: Widget {
    var body: ActivityConfiguration<PrayerCountdownActivity> {
        ActivityConfiguration(for: PrayerCountdownActivity.self) { context in
            // Lock screen/banner UI goes here
            LiveActivityLockScreenView()
        } dynamicIsland: { context in
            // Dynamic Island implementation with white Arabic Allah symbol
            return DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        // White Arabic Allah symbol
                        Text("الله")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Image(systemName: context.state.nextPrayer.prayer.systemImageName.isEmpty ? "exclamationmark.triangle" : context.state.nextPrayer.prayer.systemImageName)
                            .foregroundColor(context.state.nextPrayer.prayer.color)
                            .font(.title3)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.formattedTimeRemaining)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(context.state.isImminent ? .red : .white)
                            .monospacedDigit()
                        
                        Text(formatPrayerTime(context.state.nextPrayer.time))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.nextPrayer.location ?? "Current Location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(context.state.arabicSymbol)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    // White Arabic Allah symbol
                    Text("الله")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Image(systemName: context.state.nextPrayer.prayer.systemImageName.isEmpty ? "exclamationmark.triangle" : context.state.nextPrayer.prayer.systemImageName)
                        .foregroundColor(context.state.nextPrayer.prayer.color)
                        .font(.title3)
                }
            } compactTrailing: {
                Text(context.state.shortFormattedTime)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(context.state.isImminent ? .red : .white)
                    .monospacedDigit()
            } minimal: {
                HStack(spacing: 1) {
                    // White Arabic Allah symbol in top-left for minimal persistent display
                    Text("الله")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Image(systemName: context.state.nextPrayer.prayer.systemImageName.isEmpty ? "exclamationmark.triangle" : context.state.nextPrayer.prayer.systemImageName)
                        .foregroundColor(context.state.nextPrayer.prayer.color)
                        .font(.caption)
                }
            }
        }
    }
    
    private func formatPrayerTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Creates a fallback Dynamic Island view when data is invalid
    private func createFallbackDynamicIsland() -> DynamicIsland {
        DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                HStack(spacing: 6) {
                    Text("الله")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.title3)
                }
            }
            
            DynamicIslandExpandedRegion(.trailing) {
                Text("Error")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }
        } compactLeading: {
            HStack(spacing: 4) {
                Text("الله")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                    .font(.title3)
            }
        } compactTrailing: {
            Text("Error")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.red)
        } minimal: {
            HStack(spacing: 1) {
                Text("الله")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Live Activity Configuration (Disabled for now)
// Live Activities can be added later once basic widgets are working

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

// MARK: - Widget Views (Defined in WidgetViews.swift)

// MARK: - Preview

#if DEBUG
struct PrayerTimesWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Home Screen Widgets
            NextPrayerWidgetView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Next Prayer - Small")
            
            NextPrayerWidgetView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Next Prayer - Medium")
            
            TodaysPrayerTimesWidgetView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Today's Prayers - Large")
            
            // Lock Screen Widgets
            if #available(iOS 16.0, *) {
                NextPrayerLockScreenView(entry: .placeholder())
                    .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                    .previewDisplayName("Next Prayer - Lock Screen Circular")
                
                NextPrayerLockScreenView(entry: .placeholder())
                    .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                    .previewDisplayName("Next Prayer - Lock Screen Rectangular")
                
                NextPrayerLockScreenView(entry: .placeholder())
                    .previewContext(WidgetPreviewContext(family: .accessoryInline))
                    .previewDisplayName("Next Prayer - Lock Screen Inline")
                
                PrayerCountdownLockScreenView(entry: .placeholder())
                    .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                    .previewDisplayName("Countdown - Lock Screen Circular")
                
                PrayerCountdownLockScreenView(entry: .placeholder())
                    .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                    .previewDisplayName("Countdown - Lock Screen Rectangular")
                
                PrayerCountdownLockScreenView(entry: .placeholder())
                    .previewContext(WidgetPreviewContext(family: .accessoryInline))
                    .previewDisplayName("Countdown - Lock Screen Inline")
            }
        }
    }
}
#endif