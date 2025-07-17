import SwiftUI
import UserNotifications

/// Enhanced notification settings screen with per-prayer customization
public struct NotificationSettingsScreen: View {
    
    // MARK: - Dependencies
    
    private let notificationService: any NotificationServiceProtocol
    private let settingsService: any SettingsServiceProtocol
    
    // MARK: - State
    
    @State private var notificationSettings: NotificationSettings
    @State private var showingPermissionAlert = false
    @State private var showingPreview = false
    @State private var selectedPrayerForPreview: Prayer = .fajr
    @State private var isLoading = false
    
    // MARK: - Initialization
    
    public init(
        notificationService: any NotificationServiceProtocol,
        settingsService: any SettingsServiceProtocol
    ) {
        self.notificationService = notificationService
        self.settingsService = settingsService
        self._notificationSettings = State(initialValue: notificationService.getNotificationSettings())
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            List {
                // Global notification settings
                globalSettingsSection
                
                // Per-prayer settings
                prayerSettingsSection
                
                // Preview section
                previewSection
                
                // Permission status
                permissionStatusSection
            }
            .navigationTitle("Prayer Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                    .disabled(isLoading)
                }
            }
            .alert("Notification Permission Required", isPresented: $showingPermissionAlert) {
                Button("Open Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable notifications in Settings to receive prayer reminders.")
            }
            .sheet(isPresented: $showingPreview) {
                NotificationPreviewSheet(
                    prayer: selectedPrayerForPreview,
                    config: notificationSettings.configForPrayer(selectedPrayerForPreview)
                )
            }
        }
        .onAppear {
            checkPermissionStatus()
        }
    }
    
    // MARK: - Global Settings Section
    
    @ViewBuilder
    private var globalSettingsSection: some View {
        Section("Global Settings") {
            Toggle("Enable Prayer Notifications", isOn: Binding(
                get: { notificationSettings.isEnabled },
                set: { enabled in
                    notificationSettings = NotificationSettings(
                        isEnabled: enabled,
                        globalSoundEnabled: notificationSettings.globalSoundEnabled,
                        globalBadgeEnabled: notificationSettings.globalBadgeEnabled,
                        prayerConfigs: notificationSettings.prayerConfigs
                    )
                }
            ))
            .disabled(notificationService.authorizationStatus != .authorized)
            
            if notificationSettings.isEnabled {
                Toggle("Sound", isOn: Binding(
                    get: { notificationSettings.globalSoundEnabled },
                    set: { enabled in
                        notificationSettings = NotificationSettings(
                            isEnabled: notificationSettings.isEnabled,
                            globalSoundEnabled: enabled,
                            globalBadgeEnabled: notificationSettings.globalBadgeEnabled,
                            prayerConfigs: notificationSettings.prayerConfigs
                        )
                    }
                ))
                
                Toggle("Badge", isOn: Binding(
                    get: { notificationSettings.globalBadgeEnabled },
                    set: { enabled in
                        notificationSettings = NotificationSettings(
                            isEnabled: notificationSettings.isEnabled,
                            globalSoundEnabled: notificationSettings.globalSoundEnabled,
                            globalBadgeEnabled: enabled,
                            prayerConfigs: notificationSettings.prayerConfigs
                        )
                    }
                ))
            }
        }
    }
    
    // MARK: - Prayer Settings Section
    
    @ViewBuilder
    private var prayerSettingsSection: some View {
        if notificationSettings.isEnabled {
            Section("Prayer-Specific Settings") {
                ForEach(Prayer.allCases, id: \.self) { prayer in
                    NavigationLink(destination: PrayerNotificationDetailView(
                        prayer: prayer,
                        config: Binding(
                            get: { notificationSettings.configForPrayer(prayer) },
                            set: { newConfig in
                                notificationSettings = notificationSettings.updatingConfig(for: prayer, config: newConfig)
                            }
                        )
                    )) {
                        PrayerNotificationRow(
                            prayer: prayer,
                            config: notificationSettings.configForPrayer(prayer)
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Preview Section
    
    @ViewBuilder
    private var previewSection: some View {
        if notificationSettings.isEnabled {
            Section("Preview") {
                Button("Preview Notifications") {
                    showingPreview = true
                }
                .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Permission Status Section
    
    @ViewBuilder
    private var permissionStatusSection: some View {
        Section("Permission Status") {
            HStack {
                Image(systemName: permissionStatusIcon)
                    .foregroundColor(permissionStatusColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(permissionStatusText)
                        .font(.body)
                    
                    if notificationService.authorizationStatus != .authorized {
                        Text(permissionStatusDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if notificationService.authorizationStatus == .denied {
                    Button("Settings") {
                        showingPermissionAlert = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var permissionStatusIcon: String {
        switch notificationService.authorizationStatus {
        case .authorized, .provisional:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        case .ephemeral:
            return "clock.circle.fill"
        @unknown default:
            return "questionmark.circle"
        }
    }
    
    private var permissionStatusColor: Color {
        switch notificationService.authorizationStatus {
        case .authorized, .provisional:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        case .ephemeral:
            return .blue
        @unknown default:
            return .gray
        }
    }
    
    private var permissionStatusText: String {
        switch notificationService.authorizationStatus {
        case .authorized:
            return "Notifications Enabled"
        case .provisional:
            return "Provisional Access"
        case .denied:
            return "Notifications Disabled"
        case .notDetermined:
            return "Permission Not Requested"
        case .ephemeral:
            return "Temporary Access"
        @unknown default:
            return "Unknown Status"
        }
    }
    
    private var permissionStatusDescription: String {
        switch notificationService.authorizationStatus {
        case .denied:
            return "Enable in Settings to receive prayer reminders"
        case .notDetermined:
            return "Tap to request notification permission"
        case .provisional:
            return "Notifications delivered quietly"
        case .ephemeral:
            return "Limited notification access"
        default:
            return ""
        }
    }
    
    // MARK: - Methods
    
    private func checkPermissionStatus() {
        if notificationService.authorizationStatus == .notDetermined {
            Task {
                do {
                    _ = try await notificationService.requestNotificationPermission()
                } catch {
                    print("Failed to request notification permission: \(error)")
                }
            }
        }
    }
    
    private func saveSettings() {
        isLoading = true
        
        Task {
            do {
                notificationService.updateNotificationSettings(notificationSettings)
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    print("Failed to save notification settings: \(error)")
                }
            }
        }
    }
}
