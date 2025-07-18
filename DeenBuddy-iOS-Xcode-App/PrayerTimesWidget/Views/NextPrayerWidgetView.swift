import SwiftUI
import WidgetKit

/// Widget view showing the next upcoming prayer with countdown
struct NextPrayerWidgetView: View {
    let entry: PrayerWidgetEntry
    
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            VStack(spacing: 0) {
                if family == .systemSmall {
                    smallWidgetContent
                } else {
                    mediumWidgetContent
                }
            }
            .padding()
        }
        .widgetBackground(backgroundGradient)
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark ? 
                [Color(red: 0.1, green: 0.2, blue: 0.3), Color(red: 0.05, green: 0.1, blue: 0.2)] :
                [Color(red: 0.95, green: 0.97, blue: 1.0), Color(red: 0.9, green: 0.95, blue: 0.98)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Small Widget Content
    
    private var smallWidgetContent: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Text("Next Prayer")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
                islamicSymbol
            }
            
            Spacer()
            
            // Prayer name and time
            if let nextPrayer = entry.widgetData.nextPrayer {
                VStack(spacing: 4) {
                    // Arabic name
                    if entry.configuration.showArabicText {
                        Text(nextPrayer.arabicName)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    // English name
                    Text(nextPrayer.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    // Prayer time
                    Text(formatTime(nextPrayer.time))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                noDataView
            }
            
            Spacer()
            
            // Countdown
            if entry.configuration.showCountdown {
                countdownView
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
    
    // MARK: - Medium Widget Content
    
    private var mediumWidgetContent: some View {
        HStack(spacing: 16) {
            // Left side - Prayer info
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text("Next Prayer")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                if let nextPrayer = entry.widgetData.nextPrayer {
                    VStack(alignment: .leading, spacing: 4) {
                        // Arabic name
                        if entry.configuration.showArabicText {
                            Text(nextPrayer.arabicName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        // English name
                        Text(nextPrayer.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        // Prayer time
                        Text(formatTime(nextPrayer.time))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                } else {
                    noDataView
                }
                
                Spacer()
            }
            
            Spacer()
            
            // Right side - Countdown and symbol
            VStack(spacing: 12) {
                islamicSymbol
                    .font(.title)
                
                if entry.configuration.showCountdown {
                    countdownView
                }
                
                // Hijri date
                VStack(spacing: 2) {
                    Text("Hijri")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(entry.widgetData.hijriDate.formatted)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
    
    // MARK: - Subviews
    
    private var islamicSymbol: some View {
        Text("☪")
            .font(.title2)
            .foregroundColor(.green)
    }
    
    private var countdownView: some View {
        VStack(spacing: 2) {
            if let timeUntil = entry.widgetData.timeUntilNextPrayer, timeUntil > 0 {
                Text(entry.widgetData.formattedTimeUntilNext)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .monospacedDigit()
            } else {
                Text("Now")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            
            Text("remaining")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var noDataView: some View {
        VStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title3)
                .foregroundColor(.orange)
            
            Text("No Data")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private var accessibilityLabel: String {
        if let nextPrayer = entry.widgetData.nextPrayer {
            let timeString = formatTime(nextPrayer.time)
            let countdownString = entry.widgetData.formattedTimeUntilNext
            return "Next prayer: \(nextPrayer.displayName) at \(timeString), \(countdownString) remaining"
        } else {
            return "No prayer data available"
        }
    }
}

// MARK: - Widget Background Extension

extension View {
    func widgetBackground(_ backgroundView: some View) -> some View {
        if #available(iOS 17.0, *) {
            return containerBackground(for: .widget) {
                backgroundView
            }
        } else {
            return background(backgroundView)
        }
    }
}

// MARK: - Preview

struct NextPrayerWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NextPrayerWidgetView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small")
            
            NextPrayerWidgetView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium")
        }
    }
}
