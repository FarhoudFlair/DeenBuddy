import SwiftUI
import WidgetKit

// MARK: - Prayer Countdown Small Widget View

struct PrayerCountdownSmallView: View {
    let entry: PrayerWidgetEntry
    
    var body: some View {
        ZStack {
            // Background with prayer-specific gradient
            backgroundGradient
            
            VStack(spacing: 0) {
                // Top section - Prayer name
                HStack {
                    if let nextPrayer = entry.widgetData.nextPrayer {
                        Image(systemName: nextPrayer.prayer.systemImageName)
                            .foregroundColor(.white)
                            .font(.caption)
                        
                        Text(nextPrayer.prayer.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    } else {
                        Text("No Prayer")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
                .padding(.top, 12)
                .padding(.horizontal, 12)
                
                Spacer()
                
                // Center section - Countdown
                VStack(spacing: 4) {
                    if let timeUntil = entry.widgetData.timeUntilNextPrayer,
                       timeUntil > 0 {
                        
                        // Large countdown display
                        Text(formatCountdown(timeUntil))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("remaining")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    } else {
                        VStack(spacing: 2) {
                            Text("Prayer")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            Text("Time")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                    }
                }
                
                Spacer()
                
                // Bottom section - Prayer time
                HStack {
                    Spacer()
                    
                    if let nextPrayer = entry.widgetData.nextPrayer {
                        Text(formatTime(nextPrayer.time))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.bottom, 12)
                .padding(.horizontal, 12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var backgroundGradient: some View {
        let prayer = entry.widgetData.nextPrayer?.prayer ?? .fajr
        
        return ZStack {
            // Base gradient
            LinearGradient(
                gradient: Gradient(colors: prayer.gradientColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Overlay pattern for visual interest
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.1),
                    Color.clear
                ]),
                center: .topTrailing,
                startRadius: 20,
                endRadius: 80
            )
        }
    }
    
    private func formatCountdown(_ timeInterval: TimeInterval) -> String {
        let totalMinutes = Int(timeInterval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h\n\(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)\nmin"
        } else {
            return "Now"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Alternative Countdown View with Circular Progress

struct PrayerCountdownCircularView: View {
    let entry: PrayerWidgetEntry
    
    var body: some View {
        ZStack {
            // Background
            backgroundGradient
            
            VStack(spacing: 8) {
                // Prayer name
                if let nextPrayer = entry.widgetData.nextPrayer {
                    HStack(spacing: 4) {
                        Image(systemName: nextPrayer.prayer.systemImageName)
                            .foregroundColor(.white)
                            .font(.caption)
                        
                        Text(nextPrayer.prayer.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                }
                
                // Circular progress with countdown
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: progressValue)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1), value: progressValue)
                    
                    // Countdown text
                    VStack(spacing: 2) {
                        if let timeUntil = entry.widgetData.timeUntilNextPrayer,
                           timeUntil > 0 {
                            Text(formatShortCountdown(timeUntil))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        } else {
                            Text("Now")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                }
                
                // Prayer time
                if let nextPrayer = entry.widgetData.nextPrayer {
                    Text(formatTime(nextPrayer.time))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
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
    
    private var progressValue: Double {
        guard let timeUntil = entry.widgetData.timeUntilNextPrayer,
              timeUntil > 0 else { return 1.0 }
        
        // Assume maximum time between prayers is 6 hours (21600 seconds)
        let maxTime: TimeInterval = 21600
        let progress = 1.0 - (timeUntil / maxTime)
        return max(0.0, min(1.0, progress))
    }
    
    private func formatShortCountdown(_ timeInterval: TimeInterval) -> String {
        let totalMinutes = Int(timeInterval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "Now"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#if DEBUG
struct PrayerCountdownWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PrayerCountdownSmallView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Prayer Countdown - Standard")
            
            PrayerCountdownCircularView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Prayer Countdown - Circular")
        }
    }
}
#endif
