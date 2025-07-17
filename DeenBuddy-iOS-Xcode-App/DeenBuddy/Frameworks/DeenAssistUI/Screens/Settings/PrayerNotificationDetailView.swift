import SwiftUI

/// Detailed view for configuring individual prayer notifications
public struct PrayerNotificationDetailView: View {
    
    // MARK: - Properties
    
    let prayer: Prayer
    @Binding var config: PrayerNotificationConfig
    
    // MARK: - State
    
    @State private var reminderTimes: [Int]
    @State private var customTitle: String
    @State private var customBody: String
    @State private var showingAddReminder = false
    @State private var newReminderMinutes = 10
    
    // MARK: - Initialization
    
    public init(prayer: Prayer, config: Binding<PrayerNotificationConfig>) {
        self.prayer = prayer
        self._config = config
        self._reminderTimes = State(initialValue: config.wrappedValue.reminderTimes)
        self._customTitle = State(initialValue: config.wrappedValue.customTitle ?? "")
        self._customBody = State(initialValue: config.wrappedValue.customBody ?? "")
    }
    
    // MARK: - Body
    
    public var body: some View {
        List {
            // Prayer header
            prayerHeaderSection
            
            // Enable/Disable toggle
            enableToggleSection
            
            if config.isEnabled {
                // Reminder times
                reminderTimesSection
                
                // Custom content
                customContentSection
                
                // Sound settings
                soundSettingsSection
                
                // Preview
                previewSection
            }
        }
        .navigationTitle("\(prayer.displayName) Notifications")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveChanges()
                }
            }
        }
        .sheet(isPresented: $showingAddReminder) {
            AddReminderSheet(
                minutes: $newReminderMinutes,
                onAdd: { minutes in
                    addReminderTime(minutes)
                }
            )
        }
    }
    
    // MARK: - Prayer Header Section
    
    @ViewBuilder
    private var prayerHeaderSection: some View {
        Section {
            HStack(spacing: 16) {
                Image(systemName: prayer.systemImageName)
                    .foregroundColor(prayer.color)
                    .font(.largeTitle)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(prayer.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(prayer.arabicName)
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text(prayer.timingDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Enable Toggle Section
    
    @ViewBuilder
    private var enableToggleSection: some View {
        Section("Notification Settings") {
            Toggle("Enable Notifications", isOn: Binding(
                get: { config.isEnabled },
                set: { enabled in
                    config = PrayerNotificationConfig(
                        isEnabled: enabled,
                        reminderTimes: config.reminderTimes,
                        customTitle: config.customTitle,
                        customBody: config.customBody,
                        soundName: config.soundName,
                        soundEnabled: config.soundEnabled,
                        badgeEnabled: config.badgeEnabled
                    )
                }
            ))
        }
    }
    
    // MARK: - Reminder Times Section
    
    @ViewBuilder
    private var reminderTimesSection: some View {
        Section("Reminder Times") {
            ForEach(reminderTimes.sorted(by: >), id: \.self) { minutes in
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                    
                    Text(reminderTimeText(for: minutes))
                    
                    Spacer()
                    
                    Button("Remove") {
                        removeReminderTime(minutes)
                    }
                    .foregroundColor(.red)
                    .font(.caption)
                }
            }
            .onDelete(perform: deleteReminderTimes)
            
            Button("Add Reminder") {
                showingAddReminder = true
            }
            .foregroundColor(.blue)
        }
    }
    
    // MARK: - Custom Content Section
    
    @ViewBuilder
    private var customContentSection: some View {
        Section("Custom Content") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Title (Optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Default: \(prayer.displayName) Prayer Time", text: $customTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Message (Optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Default: It's time for \(prayer.displayName) prayer", text: $customBody, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(2...4)
            }
        }
    }
    
    // MARK: - Sound Settings Section
    
    @ViewBuilder
    private var soundSettingsSection: some View {
        Section("Sound & Badge") {
            Toggle("Sound", isOn: Binding(
                get: { config.soundEnabled },
                set: { enabled in
                    config = PrayerNotificationConfig(
                        isEnabled: config.isEnabled,
                        reminderTimes: config.reminderTimes,
                        customTitle: config.customTitle,
                        customBody: config.customBody,
                        soundName: config.soundName,
                        soundEnabled: enabled,
                        badgeEnabled: config.badgeEnabled
                    )
                }
            ))
            
            Toggle("Badge", isOn: Binding(
                get: { config.badgeEnabled },
                set: { enabled in
                    config = PrayerNotificationConfig(
                        isEnabled: config.isEnabled,
                        reminderTimes: config.reminderTimes,
                        customTitle: config.customTitle,
                        customBody: config.customBody,
                        soundName: config.soundName,
                        soundEnabled: config.soundEnabled,
                        badgeEnabled: enabled
                    )
                }
            ))
        }
    }
    
    // MARK: - Preview Section
    
    @ViewBuilder
    private var previewSection: some View {
        Section("Preview") {
            ForEach(reminderTimes.sorted(by: >), id: \.self) { minutes in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(reminderTimeText(for: minutes))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    NotificationPreviewCard(
                        title: customTitle.isEmpty ? getDefaultTitle(for: minutes) : customTitle,
                        bodyText: customBody.isEmpty ? getDefaultBody(for: minutes) : customBody,
                        prayer: prayer
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func reminderTimeText(for minutes: Int) -> String {
        if minutes == 0 {
            return "At prayer time"
        } else {
            return "\(minutes) minutes before"
        }
    }
    
    private func getDefaultTitle(for minutes: Int) -> String {
        if minutes == 0 {
            return "\(prayer.displayName) Prayer Time"
        } else {
            return "\(prayer.displayName) Prayer Reminder"
        }
    }
    
    private func getDefaultBody(for minutes: Int) -> String {
        if minutes == 0 {
            return "It's time for \(prayer.displayName) prayer (\(prayer.arabicName))"
        } else {
            return "\(prayer.displayName) prayer (\(prayer.arabicName)) in \(minutes) minutes"
        }
    }
    
    private func addReminderTime(_ minutes: Int) {
        if !reminderTimes.contains(minutes) {
            reminderTimes.append(minutes)
            reminderTimes.sort(by: >)
        }
    }
    
    private func removeReminderTime(_ minutes: Int) {
        reminderTimes.removeAll { $0 == minutes }
    }
    
    private func deleteReminderTimes(offsets: IndexSet) {
        let sortedTimes = reminderTimes.sorted(by: >)
        for index in offsets {
            if index < sortedTimes.count {
                removeReminderTime(sortedTimes[index])
            }
        }
    }
    
    private func saveChanges() {
        config = PrayerNotificationConfig(
            isEnabled: config.isEnabled,
            reminderTimes: reminderTimes,
            customTitle: customTitle.isEmpty ? nil : customTitle,
            customBody: customBody.isEmpty ? nil : customBody,
            soundName: config.soundName,
            soundEnabled: config.soundEnabled,
            badgeEnabled: config.badgeEnabled
        )
    }
}

// MARK: - Supporting Components

/// Sheet for adding new reminder times
struct AddReminderSheet: View {
    @Binding var minutes: Int
    let onAdd: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Add Reminder")
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Minutes before prayer:")
                        .font(.headline)

                    Stepper(value: $minutes, in: 0...60, step: 5) {
                        Text(minutes == 0 ? "At prayer time" : "\(minutes) minutes before")
                    }
                }

                Spacer()

                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.red)

                    Button("Add") {
                        onAdd(minutes)
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

/// Preview card showing how notification will appear
struct NotificationPreviewCard: View {
    let title: String
    let bodyText: String
    let prayer: Prayer

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: prayer.systemImageName)
                .foregroundColor(prayer.color)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(bodyText)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
