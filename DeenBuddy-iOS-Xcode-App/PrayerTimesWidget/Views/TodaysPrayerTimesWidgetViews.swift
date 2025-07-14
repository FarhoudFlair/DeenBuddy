import SwiftUI
import WidgetKit

// MARK: - Today's Prayer Times Medium Widget View

struct TodaysPrayerTimesMediumView: View {
    let entry: PrayerWidgetEntry
    
    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            VStack(spacing: 12) {
                // Header
                headerView
                
                // Prayer times list
                VStack(spacing: 8) {
                    ForEach(displayedPrayers.prefix(3), id: \.prayer) { prayerTime in
                        PrayerTimeRow(
                            prayerTime: prayerTime,
                            isNext: prayerTime.prayer == entry.widgetData.nextPrayer?.prayer,
                            isPassed: prayerTime.time < Date()
                        )
                    }
                }
                
                Spacer()
                
                // Footer
                footerView
            }
            .padding()
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Prayer Times")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if entry.configuration.showHijriDate {
                    Text(entry.widgetData.hijriDate.formatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Next prayer indicator
            if let nextPrayer = entry.widgetData.nextPrayer {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Next")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(entry.widgetData.formattedTimeUntilNext)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(nextPrayer.prayer.color)
                }
            }
        }
    }
    
    private var footerView: some View {
        HStack {
            if entry.configuration.showLocation {
                Text(entry.widgetData.location)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if entry.configuration.showCalculationMethod {
                Text(entry.widgetData.calculationMethod.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(Color(.systemBackground))
    }
    
    private var displayedPrayers: [PrayerTime] {
        switch entry.configuration.preferredPrayerDisplay {
        case .nextPrayerFocus:
            return entry.widgetData.todaysPrayerTimes
        case .allPrayersToday:
            return entry.widgetData.todaysPrayerTimes
        case .remainingPrayers:
            let now = Date()
            return entry.widgetData.todaysPrayerTimes.filter { $0.time > now }
        }
    }
}

// MARK: - Today's Prayer Times Large Widget View

struct TodaysPrayerTimesLargeView: View {
    let entry: PrayerWidgetEntry
    
    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            VStack(spacing: 16) {
                // Header with Islamic greeting
                headerView
                
                // All prayer times
                VStack(spacing: 10) {
                    ForEach(entry.widgetData.todaysPrayerTimes, id: \.prayer) { prayerTime in
                        PrayerTimeRow(
                            prayerTime: prayerTime,
                            isNext: prayerTime.prayer == entry.widgetData.nextPrayer?.prayer,
                            isPassed: prayerTime.time < Date(),
                            showArabicName: true
                        )
                    }
                }
                
                Spacer()
                
                // Footer with additional info
                footerView
            }
            .padding()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Prayer Times")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(entry.widgetData.hijriDate.formatted)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Next prayer countdown
                if let nextPrayer = entry.widgetData.nextPrayer {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: nextPrayer.prayer.systemImageName)
                                .foregroundColor(nextPrayer.prayer.color)
                                .font(.caption)
                            
                            Text("Next: \(nextPrayer.prayer.displayName)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        
                        Text("in \(entry.widgetData.formattedTimeUntilNext)")
                            .font(.caption)
                            .foregroundColor(nextPrayer.prayer.color)
                    }
                }
            }
            
            Divider()
        }
    }
    
    private var footerView: some View {
        VStack(spacing: 4) {
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if entry.configuration.showLocation {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(entry.widgetData.location)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if entry.configuration.showCalculationMethod {
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(entry.widgetData.calculationMethod.displayName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Islamic accuracy indicator
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    
                    Text("Islamic Accurate")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(Color(.systemBackground))
    }
}

// MARK: - Prayer Time Row Component

struct PrayerTimeRow: View {
    let prayerTime: PrayerTime
    let isNext: Bool
    let isPassed: Bool
    let showArabicName: Bool
    
    init(prayerTime: PrayerTime, isNext: Bool, isPassed: Bool, showArabicName: Bool = false) {
        self.prayerTime = prayerTime
        self.isNext = isNext
        self.isPassed = isPassed
        self.showArabicName = showArabicName
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Prayer icon
            Image(systemName: prayerTime.prayer.systemImageName)
                .foregroundColor(isNext ? prayerTime.prayer.color : (isPassed ? .secondary : .primary))
                .font(.title3)
                .frame(width: 24)
            
            // Prayer name
            VStack(alignment: .leading, spacing: 2) {
                Text(prayerTime.prayer.displayName)
                    .font(.subheadline)
                    .fontWeight(isNext ? .semibold : .regular)
                    .foregroundColor(isNext ? prayerTime.prayer.color : (isPassed ? .secondary : .primary))
                
                if showArabicName {
                    Text(prayerTime.prayer.arabicName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Prayer time
            Text(formatTime(prayerTime.time))
                .font(.subheadline)
                .fontWeight(isNext ? .semibold : .regular)
                .foregroundColor(isNext ? prayerTime.prayer.color : (isPassed ? .secondary : .primary))
            
            // Status indicator
            if isNext {
                Circle()
                    .fill(prayerTime.prayer.color)
                    .frame(width: 8, height: 8)
            } else if isPassed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#if DEBUG
struct TodaysPrayerTimesWidgetViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TodaysPrayerTimesMediumView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Today's Prayers - Medium")
            
            TodaysPrayerTimesLargeView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Today's Prayers - Large")
        }
    }
}
#endif
