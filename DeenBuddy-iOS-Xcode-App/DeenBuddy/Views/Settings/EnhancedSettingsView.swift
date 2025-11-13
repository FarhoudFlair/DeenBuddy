import SwiftUI

/// Enhanced settings view with profile section and improved UI state synchronization
public struct EnhancedSettingsView: View {
    @ObservedObject private var settingsService: SettingsService
    @ObservedObject private var themeManager: ThemeManager
    private let notificationService: (any NotificationServiceProtocol)?
    private let userAccountService: (any UserAccountServiceProtocol)?
    private let onDismiss: () -> Void

    @State private var showingCalculationMethodPicker = false
    @State private var showingMadhabPicker = false
    @State private var showingThemePicker = false
    @State private var showingAbout = false
    @State private var showingCalculationSources = false
    @State private var showingResetConfirmation = false
    @State private var showingNotificationSettings = false
    @State private var showingPerPrayerNotificationSettings = false
    @State private var showingTimeFormatPicker = false
    @State private var showingAccountSettings = false
    @State private var editingUserName = false
    @State private var tempUserName = ""
    @State private var criticalAlertsEnabled = false
    @State private var showingCriticalAlertError = false
    @State private var criticalAlertErrorMessage = ""

    public init(
        settingsService: SettingsService,
        themeManager: ThemeManager,
        notificationService: (any NotificationServiceProtocol)? = nil,
        userAccountService: (any UserAccountServiceProtocol)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self._settingsService = ObservedObject(wrappedValue: settingsService)
        self._themeManager = ObservedObject(wrappedValue: themeManager)
        self.notificationService = notificationService
        self.userAccountService = userAccountService
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
                
                // Account Section
                if let userAccountService = userAccountService {
                    Section("Account") {
                        SettingsRow(
                            icon: "person.circle.fill",
                            title: "Account Settings",
                            value: userAccountService.currentUser?.email ?? "Not signed in",
                            action: { showingAccountSettings = true }
                        )
                    }
                }
                
                Section("Prayer Settings") {
                    SettingsRow(
                        icon: "book.closed.fill",
                        title: "School of Thought (Madhab)",
                        value: settingsService.madhab.displayName,
                        action: { showingMadhabPicker = true }
                    )
                    
                    SettingsRow(
                        icon: "moon.stars.fill",
                        title: "Calculation Method",
                        value: settingsService.calculationMethod.displayName,
                        action: { showingCalculationMethodPicker = true }
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
                    
                    if notificationService != nil {
                        SettingsRow(
                            icon: "bell.badge.fill",
                            title: "Prayer Notifications (Per-prayer)",
                            value: "",
                            action: { showingPerPrayerNotificationSettings = true }
                        )
                        
                        SettingsToggle(
                            icon: "exclamationmark.triangle.fill",
                            title: "Critical Alerts",
                            description: "Allow time-sensitive prayer alerts even when Do Not Disturb is on",
                            isOn: $criticalAlertsEnabled
                        )
                        .onChange(of: criticalAlertsEnabled) { newValue in
                            if newValue {
                                requestCriticalAlertPermission()
                            }
                        }
                    }
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

                // Widget & Live Activities Section
                Section("Widget & Live Activities") {
                    SettingsToggle(
                        icon: "textformat",
                        title: "Show Arabic Symbol",
                        description: "Display 'الله' in widgets and Live Activities",
                        isOn: $settingsService.showArabicSymbolInWidget
                    )
                    
                    if #available(iOS 16.1, *) {
                        SettingsToggle(
                            icon: "apps.iphone",
                            title: "Live Activities",
                            description: "Show prayer countdown in Dynamic Island and Lock Screen. Enable in Settings > Face ID & Passcode > Allow Access When Locked",
                            isOn: Binding(
                                get: { settingsService.liveActivitiesEnabled },
                                set: { settingsService.liveActivitiesEnabled = $0 }
                            )
                        )
                    }
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
                selectedMadhab: settingsService.madhab,
                onMethodSelected: { method in
                    settingsService.calculationMethod = method
                    showingCalculationMethodPicker = false
                }
            )
        }
        .sheet(isPresented: $showingMadhabPicker) {
            MadhabPickerView(
                selectedMadhab: settingsService.madhab,
                calculationMethod: settingsService.calculationMethod,
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
            NotificationSettingsView(
                settingsService: settingsService,
                onDismiss: { showingNotificationSettings = false }
            )
        }
        .sheet(isPresented: $showingTimeFormatPicker) {
            TimeFormatPickerView(
                settingsService: settingsService,
                onDismiss: { showingTimeFormatPicker = false }
            )
        }
        .sheet(isPresented: $showingPerPrayerNotificationSettings) {
            if let notificationService = notificationService {
                NotificationSettingsScreen(
                    notificationService: notificationService,
                    settingsService: settingsService
                )
            }
        }
        .sheet(isPresented: $showingAccountSettings) {
            if let userAccountService = userAccountService {
                AccountSettingsScreen(userAccountService: userAccountService)
            }
        }
        .alert("Reset Settings", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetSettings()
            }
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
        .alert("Critical Alert Permission", isPresented: $showingCriticalAlertError) {
            Button("OK", role: .cancel) {
                criticalAlertErrorMessage = ""
            }
        } message: {
            Text(criticalAlertErrorMessage)
        }
        .task {
            await loadCriticalAlertStatus()
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
        }
    }
    
    private func requestCriticalAlertPermission() {
        Task {
            guard let notificationService = notificationService else {
                print("⚠️ Critical alert permission request failed: notification service unavailable")
                await MainActor.run {
                    criticalAlertsEnabled = false
                    criticalAlertErrorMessage = "Prayer notification services are unavailable. Please try again later."
                    showingCriticalAlertError = true
                }
                return
            }

            do {
                let granted = try await notificationService.requestCriticalAlertPermission()
                
                await MainActor.run {
                    if !granted {
                        // User denied permission, revert toggle
                        criticalAlertsEnabled = false
                    }
                }
            } catch {
                print("Failed to request critical alert permission: \(error)")
                await MainActor.run {
                    criticalAlertsEnabled = false
                    criticalAlertErrorMessage = "We couldn't enable critical alerts. Please review your Notification Settings and try again."
                    showingCriticalAlertError = true
                }
            }
        }
    }
    
    private func loadCriticalAlertStatus() async {
        guard let notificationService = notificationService else {
            await MainActor.run {
                criticalAlertsEnabled = false
            }
            return
        }

        let isCriticalAlertAuthorized = await notificationService.getCriticalAlertAuthorizationStatus()

        await MainActor.run {
            criticalAlertsEnabled = isCriticalAlertAuthorized
            print("📊 Loaded critical alert status: \(isCriticalAlertAuthorized)")
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
                        .lineLimit(nil) // Allow unlimited lines for long descriptions (e.g., Live Activities 125-char text)
                        .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}
