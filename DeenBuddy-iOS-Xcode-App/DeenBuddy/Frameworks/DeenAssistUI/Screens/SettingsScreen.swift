import SwiftUI

/// Settings screen for app configuration
public struct SettingsScreen: View {
    @ObservedObject private var settingsService: SettingsService
    @ObservedObject private var themeManager: ThemeManager

    let onDismiss: () -> Void

    @State private var showingCalculationMethodPicker = false
    @State private var showingMadhabPicker = false
    @State private var showingThemePicker = false
    @State private var showingAbout = false
    @State private var showingCalculationSources = false
    @State private var showingResetConfirmation = false
    @State private var showingNotificationSettings = false
    @State private var showingTimeFormatPicker = false
    @State private var editingUserName = false
    @State private var tempUserName = ""

    public init(
        settingsService: SettingsService,
        themeManager: ThemeManager,
        onDismiss: @escaping () -> Void
    ) {
        self._settingsService = ObservedObject(wrappedValue: settingsService)
        self._themeManager = ObservedObject(wrappedValue: themeManager)
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationView {
            List {
                // Profile Section
                Section("Profile") {
                    ProfileRow(
                        userName: settingsService.userName,
                        isEditing: editingUserName,
                        tempUserName: $tempUserName,
                        onEditTapped: {
                            tempUserName = settingsService.userName
                            editingUserName = true
                        },
                        onSave: {
                            let trimmedName = tempUserName.trimmingCharacters(in: .whitespacesAndNewlines)
                            settingsService.userName = trimmedName
                            editingUserName = false
                        },
                        onCancel: {
                            editingUserName = false
                            tempUserName = ""
                        }
                    )
                }

                // Prayer Settings Section
                Section("Prayer Settings") {
                    SettingsRow(
                        icon: "globe.asia.australia.fill",
                        title: "Calculation Method",
                        value: settingsService.calculationMethod.displayName,
                        action: { showingCalculationMethodPicker = true }
                    )
                    
                    SettingsRow(
                        icon: "clock.arrow.2.circlepath",
                        title: "Madhab (Asr Time)",
                        value: settingsService.madhab.displayName,
                        action: { showingMadhabPicker = true }
                    )
                }
                
                // Notification Settings Section
                Section("Notifications") {
                    SettingsToggle(
                        icon: "bell.fill",
                        title: "Prayer Reminders",
                        description: "Get notified before each prayer",
                        isOn: Binding(
                            get: { settingsService.notificationsEnabled },
                            set: { settingsService.notificationsEnabled = $0 }
                        )
                    )

                    SettingsRow(
                        icon: "clock.badge",
                        title: "Notification Timing",
                        value: "\(Int(settingsService.notificationOffset / 60)) min before",
                        action: { showingNotificationSettings = true }
                    )
                }
                
                // Appearance Section
                Section("Appearance") {
                    SettingsRow(
                        icon: "paintbrush.fill",
                        title: "Theme",
                        value: themeManager.currentTheme.displayName,
                        action: { showingThemePicker = true }
                    )

                    SettingsRow(
                        icon: "clock.fill",
                        title: "Time Format",
                        value: settingsService.timeFormat.displayName,
                        action: { showingTimeFormatPicker = true }
                    )
                }
                
                // Data Management Section
                Section("Data Management") {
                    SettingsButton(
                        icon: "arrow.clockwise",
                        title: "Reset Settings",
                        description: "Reset all settings to defaults",
                        style: .destructive,
                        action: { showingResetConfirmation = true }
                    )
                }
                
                // About Section
                Section("About") {
                    SettingsRow(
                        icon: "info.circle.fill",
                        title: "About DeenBuddy",
                        value: "",
                        action: { showingAbout = true }
                    )

                    SettingsRow(
                        icon: "doc.text.magnifyingglass",
                        title: "Calculation Methods & Sources",
                        value: "",
                        action: { showingCalculationSources = true }
                    )

                    SettingsRow(
                        icon: "doc.text.fill",
                        title: "Version",
                        value: appVersion,
                        action: nil
                    )
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveSettings()
                        onDismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingCalculationMethodPicker) {
            CalculationMethodPickerView(
                selectedMethod: settingsService.calculationMethod,
                onMethodSelected: { method in
                    settingsService.calculationMethod = method
                    showingCalculationMethodPicker = false
                }
            )
        }
        .sheet(isPresented: $showingMadhabPicker) {
            MadhabPickerView(
                selectedMadhab: settingsService.madhab,
                onMadhabSelected: { madhab in
                    settingsService.madhab = madhab
                    showingMadhabPicker = false
                }
            )
        }
        .sheet(isPresented: $showingThemePicker) {
            ThemePickerView(
                themeManager: themeManager,
                onDismiss: { showingThemePicker = false }
            )
        }
        .sheet(isPresented: $showingAbout) {
            AboutView(onDismiss: { showingAbout = false })
        }
        .sheet(isPresented: $showingCalculationSources) {
            CalculationMethodsSourcesView()
        }
        .sheet(isPresented: $showingNotificationSettings) {
            // Note: NotificationSettingsView is now in the main app
            Text("Notification Settings")
                .navigationTitle("Notification Settings")
        }
        .sheet(isPresented: $showingTimeFormatPicker) {
            // Note: TimeFormatPickerView is now in the main app
            Text("Time Format Settings")
                .navigationTitle("Time Format")
        }
        .alert("Reset Settings", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetSettings()
            }
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private func saveSettings() {
        Task {
            try? await settingsService.saveSettings()
        }
    }
    
    private func resetSettings() {
        Task {
            try? await settingsService.resetToDefaults()
            themeManager.setTheme(.dark)
        }
    }
}

/// Settings row component
private struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String
    let action: (() -> Void)?
    
    var body: some View {
        Button(action: action ?? {}) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(ColorPalette.primary)
                    .frame(width: 24)
                
                Text(title)
                    .foregroundColor(ColorPalette.textPrimary)
                
                Spacer()
                
                if !value.isEmpty {
                    Text(value)
                        .foregroundColor(ColorPalette.textSecondary)
                }
                
                if action != nil {
                    Image(systemName: "chevron.right")
                        .foregroundColor(ColorPalette.textTertiary)
                        .font(.system(size: 12))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil)
    }
}

/// Settings toggle component
private struct SettingsToggle: View {
    let icon: String
    let title: String
    let description: String?
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ColorPalette.primary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(ColorPalette.textPrimary)
                
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(ColorPalette.textSecondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

/// Settings button component
private struct SettingsButton: View {
    let icon: String
    let title: String
    let description: String?
    let style: ButtonStyle
    let action: () -> Void
    
    enum ButtonStyle {
        case normal
        case destructive
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(style == .destructive ? ColorPalette.error : ColorPalette.primary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(style == .destructive ? ColorPalette.error : ColorPalette.textPrimary)
                    
                    if let description = description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                }
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview("Settings Screen") {
    SettingsScreen(
        settingsService: SettingsService(),
        themeManager: ThemePreview.systemTheme,
        onDismiss: { print("Dismiss") }
    )
}
