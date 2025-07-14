import SwiftUI

/// Row component for displaying prayer notification settings
public struct PrayerNotificationRow: View {
    
    // MARK: - Properties
    
    let prayer: Prayer
    let config: PrayerNotificationConfig
    
    // MARK: - Initialization
    
    public init(prayer: Prayer, config: PrayerNotificationConfig) {
        self.prayer = prayer
        self.config = config
    }
    
    // MARK: - Body
    
    public var body: some View {
        HStack(spacing: 16) {
            // Prayer icon and name
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: prayer.systemImageName)
                        .foregroundColor(prayer.color)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(prayer.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(prayer.arabicName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Status and reminder info
                HStack(spacing: 12) {
                    // Enabled/Disabled status
                    HStack(spacing: 4) {
                        Image(systemName: config.isEnabled ? "bell.fill" : "bell.slash.fill")
                            .foregroundColor(config.isEnabled ? .green : .red)
                            .font(.caption)
                        
                        Text(config.isEnabled ? "Enabled" : "Disabled")
                            .font(.caption)
                            .foregroundColor(config.isEnabled ? .green : .red)
                    }
                    
                    if config.isEnabled {
                        // Reminder times
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                                .font(.caption)
                            
                            Text(reminderTimesText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Quick toggle
            Toggle("", isOn: .constant(config.isEnabled))
                .labelsHidden()
                .disabled(true) // Read-only in row view
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helper Properties
    
    private var reminderTimesText: String {
        if config.reminderTimes.isEmpty {
            return "No reminders"
        } else if config.reminderTimes.count == 1 {
            let minutes = config.reminderTimes[0]
            return minutes == 0 ? "At prayer time" : "\(minutes)min before"
        } else {
            let timesText = config.reminderTimes.map { minutes in
                minutes == 0 ? "0min" : "\(minutes)min"
            }.joined(separator: ", ")
            return timesText
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PrayerNotificationRow_Previews: PreviewProvider {
    static var previews: some View {
        List {
            PrayerNotificationRow(
                prayer: .fajr,
                config: PrayerNotificationConfig(
                    isEnabled: true,
                    reminderTimes: [15, 5, 0]
                )
            )
            
            PrayerNotificationRow(
                prayer: .dhuhr,
                config: PrayerNotificationConfig(
                    isEnabled: false,
                    reminderTimes: [10]
                )
            )
            
            PrayerNotificationRow(
                prayer: .asr,
                config: PrayerNotificationConfig(
                    isEnabled: true,
                    reminderTimes: [0]
                )
            )
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
