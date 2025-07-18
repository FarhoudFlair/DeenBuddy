import SwiftUI
import WidgetKit

/// Widget view showing all prayer times for today
struct TodaysPrayerTimesWidgetView: View {
    let entry: PrayerWidgetEntry
    
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            VStack(spacing: 0) {
                if family == .systemMedium {
                    mediumWidgetContent
                } else {
                    largeWidgetContent
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
    
    // MARK: - Medium Widget Content
    
    private var mediumWidgetContent: some View {
        VStack(spacing: 12) {
            // Header
            headerView
            
            // Prayer times grid
            if !entry.widgetData.todaysPrayerTimes.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(Array(entry.widgetData.todaysPrayerTimes.enumerated()), id: \.offset) { index, prayer in
                        prayerTimeRow(prayer: prayer, isCompact: true)
                    }
                }
            } else {
                noDataView
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
    
    // MARK: - Large Widget Content
    
    private var largeWidgetContent: some View {
        VStack(spacing: 16) {
            // Header with date info
            VStack(spacing: 8) {
                headerView
                
                // Date information
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatDate(Date()))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Hijri")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(entry.widgetData.hijriDate.formatted)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
            }
            
            // Prayer times list
            if !entry.widgetData.todaysPrayerTimes.isEmpty {
                VStack(spacing: 6) {
                    ForEach(entry.widgetData.todaysPrayerTimes) { prayer in
                        prayerTimeRow(prayer: prayer, isCompact: false)
                    }
                }
            } else {
                Spacer()
                noDataView
                Spacer()
            }
            
            // Location and calculation method
            footerView
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Prayer Times")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if entry.configuration.showArabicText {
                    Text("أوقات الصلاة")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text("☪")
                .font(.title2)
                .foregroundColor(.green)
        }
    }
    
    private func prayerTimeRow(prayer: PrayerTime, isCompact: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                // Arabic name (if enabled)
                if entry.configuration.showArabicText && !isCompact {
                    Text(prayer.arabicName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // English name
                Text(prayer.displayName)
                    .font(isCompact ? .caption : .subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Prayer time
            Text(formatTime(prayer.time))
                .font(isCompact ? .caption : .subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isCurrentPrayer(prayer) ? .green : .primary)
                .monospacedDigit()
        }
        .padding(.horizontal, isCompact ? 4 : 8)
        .padding(.vertical, isCompact ? 2 : 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isCurrentPrayer(prayer) ? 
                      Color.green.opacity(0.1) : 
                      Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isCurrentPrayer(prayer) ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    private var footerView: some View {
        VStack(spacing: 4) {
            if !entry.widgetData.location.isEmpty {
                HStack {
                    Image(systemName: "location")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(entry.widgetData.location)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                }
            }
            
            HStack {
                Text("Method: \(entry.widgetData.calculationMethod.displayName)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                Text("Updated: \(formatUpdateTime(entry.widgetData.lastUpdated))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var noDataView: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(.orange)
            
            Text("No Prayer Data")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("Please open the app to load prayer times")
                .font(.caption)
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatUpdateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func isCurrentPrayer(_ prayer: PrayerTime) -> Bool {
        guard let nextPrayer = entry.widgetData.nextPrayer else { return false }
        return prayer.prayer == nextPrayer.prayer
    }
    
    private var accessibilityLabel: String {
        let prayerTimes = entry.widgetData.todaysPrayerTimes
            .map { "\($0.displayName) at \(formatTime($0.time))" }
            .joined(separator: ", ")
        
        if prayerTimes.isEmpty {
            return "No prayer times available"
        } else {
            return "Today's prayer times: \(prayerTimes)"
        }
    }
}

// MARK: - Preview

struct TodaysPrayerTimesWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TodaysPrayerTimesWidgetView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium")
            
            TodaysPrayerTimesWidgetView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Large")
        }
    }
}
