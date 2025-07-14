import SwiftUI

/// Sheet for previewing how notifications will appear for a prayer
public struct NotificationPreviewSheet: View {
    
    // MARK: - Properties
    
    let prayer: Prayer
    let config: PrayerNotificationConfig
    
    // MARK: - State
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReminderIndex = 0
    
    // MARK: - Initialization
    
    public init(prayer: Prayer, config: PrayerNotificationConfig) {
        self.prayer = prayer
        self.config = config
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Reminder time selector
                if config.reminderTimes.count > 1 {
                    reminderSelectorSection
                }
                
                // Notification preview
                notificationPreviewSection
                
                // Islamic accuracy note
                islamicAccuracySection
                
                Spacer()
            }
            .padding()
            .navigationTitle("Notification Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: prayer.systemImageName)
                .foregroundColor(prayer.color)
                .font(.system(size: 48))
            
            VStack(spacing: 4) {
                Text(prayer.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(prayer.arabicName)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Reminder Selector Section
    
    @ViewBuilder
    private var reminderSelectorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Reminder Time:")
                .font(.headline)
            
            Picker("Reminder Time", selection: $selectedReminderIndex) {
                ForEach(0..<config.reminderTimes.count, id: \.self) { index in
                    Text(reminderTimeText(for: config.reminderTimes[index]))
                        .tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    // MARK: - Notification Preview Section
    
    @ViewBuilder
    private var notificationPreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How it will appear:")
                .font(.headline)
            
            // iOS-style notification preview
            VStack(spacing: 0) {
                // Notification header
                HStack {
                    Image(systemName: "app.badge")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text("DeenBuddy")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("now")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // Notification content
                HStack(spacing: 12) {
                    Image(systemName: prayer.systemImageName)
                        .foregroundColor(prayer.color)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(notificationTitle)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Text(notificationBody)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Islamic Accuracy Section
    
    @ViewBuilder
    private var islamicAccuracySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                
                Text("Islamic Accuracy")
                    .font(.headline)
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• Prayer times calculated using your selected method")
                Text("• Arabic names displayed with proper transliteration")
                Text("• Notifications respect your Madhab settings")
                Text("• Times automatically adjust for your location")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Properties
    
    private var currentReminderMinutes: Int {
        guard selectedReminderIndex < config.reminderTimes.count else {
            return config.reminderTimes.first ?? 0
        }
        return config.reminderTimes[selectedReminderIndex]
    }
    
    private var notificationTitle: String {
        if let customTitle = config.customTitle, !customTitle.isEmpty {
            return customTitle
        }
        
        if currentReminderMinutes == 0 {
            return "\(prayer.displayName) Prayer Time"
        } else {
            return "\(prayer.displayName) Prayer Reminder"
        }
    }
    
    private var notificationBody: String {
        if let customBody = config.customBody, !customBody.isEmpty {
            return customBody
        }
        
        if currentReminderMinutes == 0 {
            return "It's time for \(prayer.displayName) prayer (\(prayer.arabicName))"
        } else {
            return "\(prayer.displayName) prayer (\(prayer.arabicName)) in \(currentReminderMinutes) minutes"
        }
    }
    
    // MARK: - Helper Methods
    
    private func reminderTimeText(for minutes: Int) -> String {
        if minutes == 0 {
            return "At time"
        } else {
            return "\(minutes)min"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct NotificationPreviewSheet_Previews: PreviewProvider {
    static var previews: some View {
        NotificationPreviewSheet(
            prayer: .fajr,
            config: PrayerNotificationConfig(
                isEnabled: true,
                reminderTimes: [15, 5, 0],
                customTitle: nil,
                customBody: nil
            )
        )
    }
}
#endif
