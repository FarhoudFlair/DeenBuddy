import SwiftUI
import WidgetKit

// MARK: - Next Prayer Lock Screen Views

/// Circular lock screen widget for next prayer
struct NextPrayerCircularView: View {
    let entry: PrayerWidgetEntry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            VStack(spacing: 2) {
                if let nextPrayer = entry.widgetData.nextPrayer {
                    // Prayer name
                    Text(nextPrayer.prayer.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                    
                    // Countdown
                    Text(entry.widgetData.formattedTimeUntilNext)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                } else {
                    Text("No Prayer")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }
        }
    }
}

/// Rectangular lock screen widget for next prayer
struct NextPrayerRectangularView: View {
    let entry: PrayerWidgetEntry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            VStack(alignment: .leading, spacing: 2) {
                if let nextPrayer = entry.widgetData.nextPrayer {
                    // Header with next prayer
                    HStack {
                        Text("Next:")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .opacity(0.8)
                        
                        Text(nextPrayer.prayer.displayName)
                            .font(.caption2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Text(formatTime(nextPrayer.time))
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    
                    // Countdown
                    Text("in \(entry.widgetData.formattedTimeUntilNext)")
                        .font(.caption2)
                        .opacity(0.8)
                } else {
                    Text("No upcoming prayers")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Inline lock screen widget for next prayer
struct NextPrayerInlineView: View {
    let entry: PrayerWidgetEntry
    
    var body: some View {
        HStack(spacing: 4) {
            if let nextPrayer = entry.widgetData.nextPrayer {
                Text("Next:")
                    .font(.caption2)
                    .opacity(0.8)
                
                Text(nextPrayer.prayer.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                
                Text("in \(entry.widgetData.formattedTimeUntilNext)")
                    .font(.caption2)
                    .opacity(0.8)
            } else {
                Text("No upcoming prayers")
                    .font(.caption2)
            }
        }
    }
}

// MARK: - Today's Prayer Times Lock Screen Views

/// Rectangular lock screen widget showing next 3 prayers
struct TodaysPrayerTimesRectangularView: View {
    let entry: PrayerWidgetEntry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            VStack(alignment: .leading, spacing: 1) {
                let upcomingPrayers = getUpcomingPrayers()
                
                if !upcomingPrayers.isEmpty {
                    ForEach(upcomingPrayers.prefix(3), id: \.prayer) { prayerTime in
                        HStack {
                            Text(prayerTime.prayer.displayName)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Spacer()
                            
                            Text(formatTime(prayerTime.time))
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                    }
                } else {
                    Text("No upcoming prayers")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
    }
    
    private func getUpcomingPrayers() -> [PrayerTime] {
        let now = Date()
        return entry.widgetData.todaysPrayerTimes.filter { $0.time > now }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Prayer Countdown Lock Screen Views

/// Circular lock screen widget for prayer countdown
struct PrayerCountdownCircularView: View {
    let entry: PrayerWidgetEntry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            VStack(spacing: 1) {
                if let nextPrayer = entry.widgetData.nextPrayer {
                    // Time until next prayer
                    Text(entry.widgetData.formattedTimeUntilNext)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    
                    // Prayer name
                    Text(nextPrayer.prayer.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                        .opacity(0.8)
                } else {
                    Text("—")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
            }
        }
    }
}

/// Inline lock screen widget for prayer countdown
struct PrayerCountdownInlineView: View {
    let entry: PrayerWidgetEntry
    
    var body: some View {
        HStack(spacing: 4) {
            if let nextPrayer = entry.widgetData.nextPrayer {
                Text(nextPrayer.prayer.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                
                Text("in \(entry.widgetData.formattedTimeUntilNext)")
                    .font(.caption2)
                    .opacity(0.8)
            } else {
                Text("No upcoming prayers")
                    .font(.caption2)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LockScreenWidgetViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NextPrayerCircularView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                .previewDisplayName("Next Prayer - Circular")
            
            NextPrayerRectangularView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("Next Prayer - Rectangular")
            
            NextPrayerInlineView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .accessoryInline))
                .previewDisplayName("Next Prayer - Inline")
            
            TodaysPrayerTimesRectangularView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("Today's Prayers - Rectangular")
            
            PrayerCountdownCircularView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                .previewDisplayName("Prayer Countdown - Circular")
            
            PrayerCountdownInlineView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .accessoryInline))
                .previewDisplayName("Prayer Countdown - Inline")
        }
    }
}
#endif