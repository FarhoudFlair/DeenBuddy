import SwiftUI
import WidgetKit

/// Widget view focused on countdown to next prayer
struct PrayerCountdownWidgetView: View {
    let entry: PrayerWidgetEntry
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            VStack(spacing: 12) {
                // Islamic symbol header
                HStack {
                    Text("☪")
                        .font(.title3)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    Text("Prayer")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Main content
                if let nextPrayer = entry.widgetData.nextPrayer {
                    mainCountdownContent(for: nextPrayer)
                } else {
                    noDataView
                }
                
                Spacer()
                
                // Bottom info
                bottomInfoView
            }
            .padding()
        }
        .widgetBackground(backgroundGradient)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        RadialGradient(
            colors: colorScheme == .dark ? 
                [Color(red: 0.15, green: 0.25, blue: 0.35), Color(red: 0.05, green: 0.1, blue: 0.2)] :
                [Color(red: 0.98, green: 0.99, blue: 1.0), Color(red: 0.92, green: 0.96, blue: 0.99)],
            center: .center,
            startRadius: 20,
            endRadius: 100
        )
    }
    
    // MARK: - Main Content
    
    private func mainCountdownContent(for prayer: PrayerTime) -> some View {
        VStack(spacing: 8) {
            // Arabic prayer name (if enabled)
            if entry.configuration.showArabicText {
                Text(prayer.arabicName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            
            // English prayer name
            Text(prayer.displayName)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .minimumScaleFactor(0.9)
                .lineLimit(1)
            
            // Prayer time
            Text(formatTime(prayer.time))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .monospacedDigit()
            
            // Countdown display
            countdownDisplay
        }
    }
    
    private var countdownDisplay: some View {
        VStack(spacing: 4) {
            if let timeUntil = entry.widgetData.timeUntilNextPrayer, timeUntil > 0 {
                // Time remaining
                let (hours, minutes) = parseTimeInterval(timeUntil)
                
                HStack(spacing: 4) {
                    if hours > 0 {
                        VStack(spacing: 2) {
                            Text("\(hours)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                                .monospacedDigit()
                            
                            Text("hr")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(":")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 2) {
                        Text("\(minutes)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                            .monospacedDigit()
                        
                        Text("min")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                // Prayer time has arrived
                VStack(spacing: 4) {
                    Text("🕌")
                        .font(.title)
                    
                    Text("Prayer Time")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("Now")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var bottomInfoView: some View {
        VStack(spacing: 2) {
            // Hijri date
            Text(entry.widgetData.hijriDate.formatted)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            // Location (if available)
            if !entry.widgetData.location.isEmpty {
                Text(entry.widgetData.location)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
    
    private var noDataView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.title2)
                .foregroundColor(.orange)
            
            Text("No Data")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("Open app to load")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Helper Methods
    
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
    
    private var accessibilityLabel: String {
        if let nextPrayer = entry.widgetData.nextPrayer {
            let timeString = formatTime(nextPrayer.time)
            
            if let timeUntil = entry.widgetData.timeUntilNextPrayer, timeUntil > 0 {
                let (hours, minutes) = parseTimeInterval(timeUntil)
                let countdownString = hours > 0 ? 
                    "\(hours) hours and \(minutes) minutes" : 
                    "\(minutes) minutes"
                return "Next prayer: \(nextPrayer.displayName) at \(timeString), \(countdownString) remaining"
            } else {
                return "Prayer time now: \(nextPrayer.displayName) at \(timeString)"
            }
        } else {
            return "No prayer data available"
        }
    }
}

// MARK: - Preview

struct PrayerCountdownWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PrayerCountdownWidgetView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small - Light")
            
            PrayerCountdownWidgetView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .preferredColorScheme(.dark)
                .previewDisplayName("Small - Dark")
            
            // Preview with no data
            PrayerCountdownWidgetView(entry: PrayerWidgetEntry(
                date: Date(),
                widgetData: WidgetData(
                    nextPrayer: nil,
                    timeUntilNextPrayer: nil,
                    todaysPrayerTimes: [],
                    hijriDate: HijriDate(from: Date()),
                    location: "",
                    calculationMethod: .muslimWorldLeague,
                    lastUpdated: Date()
                ),
                configuration: .default
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small - No Data")
        }
    }
}
