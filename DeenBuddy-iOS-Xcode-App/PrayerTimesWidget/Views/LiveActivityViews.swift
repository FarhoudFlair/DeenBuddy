import SwiftUI
import ActivityKit

// MARK: - Live Activity Views

@available(iOS 16.1, *)
struct LiveActivityLockScreenView: View {
    // Temporarily disabled until we can resolve ActivityViewContext
    // let context: ActivityViewContext<PrayerCountdownActivity>

    var body: some View {
        // Placeholder view until ActivityViewContext is resolved
        HStack(spacing: 12) {
            // Islamic symbol
            Text("☪")
                .font(.title2)
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 4) {
                // Prayer name
                Text("Next Prayer")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                // Prayer time
                Text("Live Activity Placeholder")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                // Arabic symbol
                Text("🕌")
                    .font(.title2)
                    .foregroundColor(.green)

                // Countdown
                Text("--:--")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .monospacedDigit()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // Helper methods temporarily disabled
    // private func formatTime(_ date: Date) -> String {
    //     let formatter = DateFormatter()
    //     formatter.timeStyle = .short
    //     return formatter.string(from: date)
    // }
    //
    // private func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
    //     let hours = Int(timeInterval) / 3600
    //     let minutes = Int(timeInterval) % 3600 / 60
    //
    //     if hours > 0 {
    //         return "\(hours)h \(minutes)m"
    //     } else {
    //         return "\(minutes)m"
    //     }
    // }
}

// MARK: - Live Activity Views

@available(iOS 16.1, *)
struct PrayerCountdownLiveActivityView: View {
    let state: PrayerCountdownActivity.ContentState
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.prayerSymbol)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text(state.nextPrayer.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(state.formattedTimeRemaining)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(timeString(from: state.nextPrayer.time))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

@available(iOS 16.1, *)
extension PrayerCountdownLiveActivityView {
    
    func dynamicIslandCompactLeading() -> some View {
        VStack(alignment: .leading, spacing: 1) {
            // White Arabic Allah symbol
            Text("الله")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text(state.nextPrayer.displayName)
                .font(.caption2)
                .foregroundColor(.primary)
        }
        .padding(4)
    }
    
    func dynamicIslandCompactTrailing() -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(state.formattedTimeRemaining)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(timeString(from: state.nextPrayer.time))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(4)
    }
    
    func dynamicIslandMinimal() -> some View {
        HStack(spacing: 2) {
            // White Arabic Allah symbol for minimal persistent display
            Text("الله")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(state.formattedTimeRemaining)
                .font(.caption2)
                .foregroundColor(.primary)
        }
        .padding(2)
    }
    
    func dynamicIslandExpanded() -> some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    // White Arabic Allah symbol
                    Text("الله")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(state.prayerSymbol)
                        .font(.title)
                        .foregroundColor(.accentColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(state.nextPrayer.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(timeString(from: state.nextPrayer.time))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Prayer countdown progress
            VStack(spacing: 4) {
                HStack {
                    Text("Time Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(state.formattedTimeRemaining)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                // Progress bar (conceptual - would need actual prayer time data)
                ProgressView(value: 0.7) // Placeholder value
                    .progressViewStyle(LinearProgressViewStyle())
                    .accentColor(.accentColor)
            }
            
            // Islamic quote or verse
            Text("\"And establish prayer and give zakah and bow with those who bow.\"")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .italic()
        }
        .padding()
    }
}

// MARK: - Dynamic Island Extensions

@available(iOS 16.1, *)
extension View {
    func dynamicIslandStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .cornerRadius(8)
    }
}