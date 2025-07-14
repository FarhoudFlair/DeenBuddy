import SwiftUI
import WidgetKit

// MARK: - Next Prayer Small Widget View

struct NextPrayerSmallView: View {
    let entry: PrayerWidgetEntry
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            VStack(spacing: 8) {
                // Prayer name and icon
                HStack(spacing: 6) {
                    if let nextPrayer = entry.widgetData.nextPrayer {
                        Image(systemName: nextPrayer.prayer.systemImageName)
                            .foregroundColor(.white)
                            .font(.title3)
                        
                        Text(nextPrayer.prayer.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    } else {
                        Text("No Prayer")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
                
                Spacer()
                
                // Time and countdown
                VStack(alignment: .leading, spacing: 4) {
                    if let nextPrayer = entry.widgetData.nextPrayer {
                        // Prayer time
                        Text(formatTime(nextPrayer.time))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        // Countdown
                        Text("in \(entry.widgetData.formattedTimeUntilNext)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    } else {
                        Text("—")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                // Hijri date (if enabled)
                if entry.configuration.showHijriDate {
                    Text(entry.widgetData.hijriDate.formatted)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding()
        }
    }
    
    private var backgroundGradient: some View {
        let prayer = entry.widgetData.nextPrayer?.prayer ?? .fajr
        return LinearGradient(
            gradient: Gradient(colors: prayer.gradientColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Next Prayer Medium Widget View

struct NextPrayerMediumView: View {
    let entry: PrayerWidgetEntry
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            HStack(spacing: 16) {
                // Left side - Next prayer info
                VStack(alignment: .leading, spacing: 8) {
                    // Prayer name with icon
                    HStack(spacing: 8) {
                        if let nextPrayer = entry.widgetData.nextPrayer {
                            Image(systemName: nextPrayer.prayer.systemImageName)
                                .foregroundColor(.white)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(nextPrayer.prayer.displayName)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                Text(nextPrayer.prayer.arabicName)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Time and countdown
                    if let nextPrayer = entry.widgetData.nextPrayer {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(formatTime(nextPrayer.time))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("in \(entry.widgetData.formattedTimeUntilNext)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    Spacer()
                    
                    // Location and Hijri date
                    VStack(alignment: .leading, spacing: 2) {
                        if entry.configuration.showLocation {
                            Text(entry.widgetData.location)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        if entry.configuration.showHijriDate {
                            Text(entry.widgetData.hijriDate.formatted)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                
                Spacer()
                
                // Right side - Remaining prayers preview
                VStack(alignment: .trailing, spacing: 6) {
                    Text("Today")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                    
                    ForEach(remainingPrayers.prefix(3), id: \.prayer) { prayerTime in
                        HStack(spacing: 8) {
                            Text(prayerTime.prayer.displayName)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text(formatTime(prayerTime.time))
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding()
        }
    }
    
    private var backgroundGradient: some View {
        let prayer = entry.widgetData.nextPrayer?.prayer ?? .fajr
        return LinearGradient(
            gradient: Gradient(colors: prayer.gradientColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var remainingPrayers: [PrayerTime] {
        let now = Date()
        return entry.widgetData.todaysPrayerTimes.filter { $0.time > now }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#if DEBUG
struct NextPrayerWidgetViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NextPrayerSmallView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Next Prayer - Small")
            
            NextPrayerMediumView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Next Prayer - Medium")
        }
    }
}
#endif
