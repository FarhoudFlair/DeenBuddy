//
//  Live_Activity_Widget_Extension.swift
//  Live Activity Widget Extension
//
//  Created by Farhoud Talebi on 2025-08-01.
//

import Foundation
import SwiftUI
import WidgetKit
import ActivityKit

// MARK: - App Launch Live Activity Definition (Widget Extension)

@available(iOS 16.1, *)
public struct AppLaunchActivity: ActivityAttributes {
    
    // MARK: - Content State
    
    public struct ContentState: Codable, Hashable {
        public let greeting: String
        public let subGreeting: String
        public let isLoading: Bool
        public let progress: Double
        
        public init(
            greeting: String = "بسم الله",
            subGreeting: String = "Welcome to DeenBuddy",
            isLoading: Bool = true,
            progress: Double = 0.0
        ) {
            self.greeting = greeting
            self.subGreeting = subGreeting
            self.isLoading = isLoading
            self.progress = progress
        }
    }
    
    // Fixed attributes that don't change during the activity
    public let launchId: String
    public let startTime: Date
    public let appVersion: String?
    
    public init(launchId: String = UUID().uuidString, startTime: Date = Date(), appVersion: String? = nil) {
        self.launchId = launchId
        self.startTime = startTime
        self.appVersion = appVersion
    }
}

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
            AppLaunchLiveActivity()
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

// MARK: - App Launch Live Activity Widget

@available(iOS 16.1, *)
struct AppLaunchLiveActivity: Widget {
    var body: ActivityConfiguration<AppLaunchActivity> {
        ActivityConfiguration(for: AppLaunchActivity.self) { context in
            // Lock screen/banner UI for app launch
            AppLaunchLockScreenView(state: context.state)
        } dynamicIsland: { context in
            // Dynamic Island implementation with Allah symbol on app launch
            return DynamicIsland {
                // Expanded view - full launch experience
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("الله")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("DeenBuddy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        if context.state.isLoading {
                            ProgressView(value: context.state.progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                                .frame(width: 60)
                            
                            Text("\(Int(context.state.progress * 100))%")
                                .font(.caption2)
                                .foregroundColor(.white)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("Ready")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.subGreeting)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                }
            } compactLeading: {
                HStack(spacing: 2) {
                    Text("الله")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if context.state.isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
            } compactTrailing: {
                if context.state.isLoading {
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } minimal: {
                // Persistent Allah symbol in minimal view
                Text("الله")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
    }
}

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
