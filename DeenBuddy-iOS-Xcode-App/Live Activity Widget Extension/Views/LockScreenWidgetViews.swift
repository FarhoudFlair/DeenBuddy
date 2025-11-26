import SwiftUI
import WidgetKit

// MARK: - Lock Screen Widget Views (iOS 16+)

@available(iOS 16.0, *)
struct NextPrayerLockScreenView: View {
    let entry: PrayerWidgetEntry
    
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.isLuminanceReduced) var isLuminanceReduced
    
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
    @Environment(\.isLuminanceReduced) var isLuminanceReduced
    
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
    @Environment(\.isLuminanceReduced) var isLuminanceReduced
    
    var body: some View {
        ZStack {
            VStack(spacing: 1) {
                // Always-On Display optimized Islamic symbol with fallback
                Group {
                    if UIImage(named: isLuminanceReduced ? "IslamicSymbolAlwaysOn" : "IslamicSymbolCircular") != nil {
                        Image(isLuminanceReduced ? "IslamicSymbolAlwaysOn" : "IslamicSymbolCircular")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 12, height: 12)
                            .foregroundStyle(isLuminanceReduced ? .primary : .secondary)
                            .opacity(isLuminanceReduced ? 0.8 : 1.0)
                    } else {
                        // Fallback to system icon if custom asset is missing
                        Image(systemName: "moon.stars")
                            .font(.system(size: 10))
                            .foregroundStyle(isLuminanceReduced ? .primary : .secondary)
                            .opacity(isLuminanceReduced ? 0.8 : 1.0)
                    }
                }
                
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
                    Text("No Data")
                        .font(.system(size: 8))
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
            }
        }
        .accessoryWidgetBackground()
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
    @Environment(\.isLuminanceReduced) var isLuminanceReduced
    
    var body: some View {
        ZStack {
            VStack(spacing: 1) {
                // Always-On Display optimized Islamic symbol with fallback
                Group {
                    if UIImage(named: isLuminanceReduced ? "IslamicSymbolAlwaysOn" : "IslamicSymbolCircular") != nil {
                        Image(isLuminanceReduced ? "IslamicSymbolAlwaysOn" : "IslamicSymbolCircular")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 10, height: 10)
                            .foregroundStyle(isLuminanceReduced ? .primary : .secondary)
                            .opacity(isLuminanceReduced ? 0.8 : 1.0)
                    } else {
                        // Fallback to system icon if custom asset is missing
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                            .foregroundStyle(isLuminanceReduced ? .primary : .secondary)
                            .opacity(isLuminanceReduced ? 0.8 : 1.0)
                    }
                }
                
                // Countdown
                if let timeUntil = entry.widgetData.timeUntilNextPrayer, timeUntil > 0 {
                    let (hours, minutes) = parseTimeInterval(timeUntil)
                    
                    if hours > 0 {
                        Text("\(hours)h")
                            .font(.system(size: 9, weight: isLuminanceReduced ? .bold : .medium))
                            .foregroundStyle(isLuminanceReduced ? Color.primary.opacity(0.9) : Color.primary)
                        
                        Text("\(minutes)m")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(minutes)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(isLuminanceReduced ? Color.primary.opacity(0.9) : Color.primary)
                        
                        Text("min")
                            .font(.system(size: 7))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Error")
                        .font(.system(size: 8))
                        .foregroundStyle(.red)
                }
            }
        }
        .accessoryWidgetBackground()
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                LockScreenIconView()

                Text("Next Prayer")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Text(countdownSummary(from: entry.widgetData.timeUntilNextPrayer))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if let nextPrayer = entry.widgetData.nextPrayer {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(nextPrayer.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text(formatTime(nextPrayer.time))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }

                if !entry.widgetData.location.isEmpty {
                    Text(entry.widgetData.location)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            } else {
                Text("Open DeenBuddy to update")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
        .accessoryWidgetBackground()
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                LockScreenIconView(systemFallback: "clock")

                Text("Countdown")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Text(optionalFormattedTime(entry.widgetData.nextPrayer?.time))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if let nextPrayer = entry.widgetData.nextPrayer,
               let timeUntil = entry.widgetData.timeUntilNextPrayer,
               timeUntil > 0 {
                Text(nextPrayer.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(countdownDetail(from: timeUntil))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            } else {
                Text("Prayer time now")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
        .accessoryWidgetBackground()
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

    private func countdownDetail(from interval: TimeInterval) -> String {
        let (hours, minutes) = parseTimeInterval(interval)
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Shared Helpers

@available(iOS 16.0, *)
private struct LockScreenIconView: View {
    var systemFallback: String = "moon.stars"

    var body: some View {
        Group {
            if UIImage(named: "IslamicSymbol") != nil {
                Image("IslamicSymbol")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: systemFallback)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

@available(iOS 16.0, *)
private func countdownSummary(from interval: TimeInterval?) -> String {
    guard let interval else { return "—" }
    let (hours, minutes) = parseTimeInterval(interval)
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }
    return "\(minutes)m"
}

// MARK: - Inline Lock Screen Views

@available(iOS 16.0, *)
struct InlineNextPrayerView: View {
    let entry: PrayerWidgetEntry
    
    var body: some View {
        HStack(spacing: 4) {
            // Islamic symbol with fallback
            Group {
                if UIImage(named: "IslamicSymbolInline") != nil {
                    Image("IslamicSymbolInline")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(.secondary)
                } else {
                    // Fallback to system icon if custom asset is missing
                    Image(systemName: "moon.stars")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            
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
        .accessoryWidgetBackground()
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
            // Islamic symbol with fallback
            Group {
                if UIImage(named: "IslamicSymbolInline") != nil {
                    Image("IslamicSymbolInline")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(.secondary)
                } else {
                    // Fallback to system icon if custom asset is missing
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            
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
        .accessoryWidgetBackground()
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

private func optionalFormattedTime(_ date: Date?) -> String {
    guard let date else { return "--" }
    return formatTime(date)
}

private func parseTimeInterval(_ interval: TimeInterval) -> (hours: Int, minutes: Int) {
    let totalMinutes = Int(interval) / 60
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    return (hours, minutes)
}

// MARK: - Debug Helper View

@available(iOS 16.0, *)
struct DebugLockScreenView: View {
    let error: String
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 12))
                .foregroundStyle(.red)
            
            Text("Debug")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.red)
            
            Text(error)
                .font(.system(size: 6))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
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
