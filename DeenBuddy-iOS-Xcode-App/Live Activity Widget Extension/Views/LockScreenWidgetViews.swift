import SwiftUI
import WidgetKit

// MARK: - Lock Screen Widget Views (iOS 16+)

@available(iOS 16.0, *)
struct NextPrayerLockScreenView: View {
    let entry: PrayerWidgetEntry
    
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularNextPrayerView(entry: entry)
        case .accessoryRectangular:
            RectangularNextPrayerView(entry: entry)
        case .accessoryInline:
            InlineNextPrayerView(entry: entry)
        default:
            EmptyView()
        }
    }
}

@available(iOS 16.0, *)
struct PrayerCountdownLockScreenView: View {
    let entry: PrayerWidgetEntry
    
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularCountdownView(entry: entry)
        case .accessoryRectangular:
            RectangularCountdownView(entry: entry)
        case .accessoryInline:
            InlineCountdownView(entry: entry)
        default:
            EmptyView()
        }
    }
}

// MARK: - Circular Lock Screen Views

@available(iOS 16.0, *)
struct CircularNextPrayerView: View {
    let entry: PrayerWidgetEntry
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(.quaternary)
                .frame(width: 42, height: 42)
            
            VStack(spacing: 1) {
                // Islamic symbol
                Text("☪")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                
                // Next prayer info
                if let nextPrayer = entry.widgetData.nextPrayer {
                    Text(nextPrayer.displayName.prefix(3))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text(formatTime(nextPrayer.time))
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("--")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }
    
    private var accessibilityLabel: String {
        if let nextPrayer = entry.widgetData.nextPrayer {
            return "Next prayer: \(nextPrayer.displayName) at \(formatTime(nextPrayer.time))"
        } else {
            return "No prayer data available"
        }
    }
}

@available(iOS 16.0, *)
struct CircularCountdownView: View {
    let entry: PrayerWidgetEntry
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(.quaternary)
                .frame(width: 42, height: 42)
            
            VStack(spacing: 1) {
                // Islamic symbol
                Text("☪")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                
                // Countdown
                if let timeUntil = entry.widgetData.timeUntilNextPrayer, timeUntil > 0 {
                    let (hours, minutes) = parseTimeInterval(timeUntil)
                    
                    if hours > 0 {
                        Text("\(hours)h")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.primary)
                        
                        Text("\(minutes)m")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(minutes)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.primary)
                        
                        Text("min")
                            .font(.system(size: 7))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Now")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.orange)
                }
            }
        }
        .accessibilityLabel(countdownAccessibilityLabel)
    }
    
    private var countdownAccessibilityLabel: String {
        if let timeUntil = entry.widgetData.timeUntilNextPrayer, timeUntil > 0 {
            let (hours, minutes) = parseTimeInterval(timeUntil)
            let timeString = hours > 0 ? "\(hours) hours and \(minutes) minutes" : "\(minutes) minutes"
            return "Time until next prayer: \(timeString)"
        } else {
            return "Prayer time now"
        }
    }
}

// MARK: - Rectangular Lock Screen Views

@available(iOS 16.0, *)
struct RectangularNextPrayerView: View {
    let entry: PrayerWidgetEntry
    
    var body: some View {
        HStack(spacing: 8) {
            // Islamic symbol
            Text("☪")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 1) {
                if let nextPrayer = entry.widgetData.nextPrayer {
                    // Prayer name
                    Text(nextPrayer.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    // Time and location
                    HStack(spacing: 4) {
                        Text(formatTime(nextPrayer.time))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        
                        if !entry.widgetData.location.isEmpty {
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                            
                            Text(entry.widgetData.location)
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                } else {
                    Text("No Prayer Data")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 4)
        .accessibilityLabel(rectangularAccessibilityLabel)
    }
    
    private var rectangularAccessibilityLabel: String {
        if let nextPrayer = entry.widgetData.nextPrayer {
            return "Next prayer: \(nextPrayer.displayName) at \(formatTime(nextPrayer.time))"
        } else {
            return "No prayer data available"
        }
    }
}

@available(iOS 16.0, *)
struct RectangularCountdownView: View {
    let entry: PrayerWidgetEntry
    
    var body: some View {
        HStack(spacing: 8) {
            // Islamic symbol
            Text("☪")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 1) {
                if let nextPrayer = entry.widgetData.nextPrayer {
                    // Prayer name
                    Text(nextPrayer.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    // Countdown
                    if let timeUntil = entry.widgetData.timeUntilNextPrayer, timeUntil > 0 {
                        let (hours, minutes) = parseTimeInterval(timeUntil)
                        
                        if hours > 0 {
                            Text("\(hours)h \(minutes)m remaining")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(minutes) minutes remaining")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Prayer time now")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                } else {
                    Text("No Prayer Data")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 4)
        .accessibilityLabel(rectangularCountdownAccessibilityLabel)
    }
    
    private var rectangularCountdownAccessibilityLabel: String {
        if let nextPrayer = entry.widgetData.nextPrayer {
            if let timeUntil = entry.widgetData.timeUntilNextPrayer, timeUntil > 0 {
                let (hours, minutes) = parseTimeInterval(timeUntil)
                let timeString = hours > 0 ? "\(hours) hours and \(minutes) minutes" : "\(minutes) minutes"
                return "Next prayer: \(nextPrayer.displayName), \(timeString) remaining"
            } else {
                return "Prayer time now: \(nextPrayer.displayName)"
            }
        } else {
            return "No prayer data available"
        }
    }
}

// MARK: - Inline Lock Screen Views

@available(iOS 16.0, *)
struct InlineNextPrayerView: View {
    let entry: PrayerWidgetEntry
    
    var body: some View {
        HStack(spacing: 4) {
            // Islamic symbol
            Text("☪")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            
            if let nextPrayer = entry.widgetData.nextPrayer {
                Text(nextPrayer.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                
                Text("•")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                
                Text(formatTime(nextPrayer.time))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                Text("No data")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel(inlineAccessibilityLabel)
    }
    
    private var inlineAccessibilityLabel: String {
        if let nextPrayer = entry.widgetData.nextPrayer {
            return "Next prayer: \(nextPrayer.displayName) at \(formatTime(nextPrayer.time))"
        } else {
            return "No prayer data available"
        }
    }
}

@available(iOS 16.0, *)
struct InlineCountdownView: View {
    let entry: PrayerWidgetEntry
    
    var body: some View {
        HStack(spacing: 4) {
            // Islamic symbol
            Text("☪")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            
            if let timeUntil = entry.widgetData.timeUntilNextPrayer, timeUntil > 0 {
                let (hours, minutes) = parseTimeInterval(timeUntil)
                
                if hours > 0 {
                    Text("\(hours)h \(minutes)m")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                } else {
                    Text("\(minutes)m")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                }
                
                Text("left")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                Text("Prayer time now")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.orange)
            }
        }
        .accessibilityLabel(inlineCountdownAccessibilityLabel)
    }
    
    private var inlineCountdownAccessibilityLabel: String {
        if let timeUntil = entry.widgetData.timeUntilNextPrayer, timeUntil > 0 {
            let (hours, minutes) = parseTimeInterval(timeUntil)
            let timeString = hours > 0 ? "\(hours) hours and \(minutes) minutes" : "\(minutes) minutes"
            return "Time until next prayer: \(timeString)"
        } else {
            return "Prayer time now"
        }
    }
}

// MARK: - Helper Functions

private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

private func parseTimeInterval(_ interval: TimeInterval) -> (hours: Int, minutes: Int) {
    let totalMinutes = Int(interval) / 60
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    return (hours, minutes)
}

// MARK: - Previews

@available(iOS 16.0, *)
struct LockScreenWidgetViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Circular previews
            NextPrayerLockScreenView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                .previewDisplayName("Next Prayer - Circular")
            
            PrayerCountdownLockScreenView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                .previewDisplayName("Countdown - Circular")
            
            // Rectangular previews
            NextPrayerLockScreenView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("Next Prayer - Rectangular")
            
            PrayerCountdownLockScreenView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("Countdown - Rectangular")
            
            // Inline previews
            NextPrayerLockScreenView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .accessoryInline))
                .previewDisplayName("Next Prayer - Inline")
            
            PrayerCountdownLockScreenView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .accessoryInline))
                .previewDisplayName("Countdown - Inline")
        }
    }
}