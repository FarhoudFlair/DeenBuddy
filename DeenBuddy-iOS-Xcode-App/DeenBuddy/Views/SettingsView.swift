//
//  SettingsView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-03.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: PrayerGuideViewModel
    @ObservedObject var themeManager: ThemeManager
    @StateObject private var settingsService = SettingsService()
    @State private var prayerTimesViewModel: PrayerTimesViewModel?
    @State private var notificationsEnabled = true
    @State private var offlineDownloadsEnabled = true
    @State private var showingAbout = false
    @State private var showingDataManagement = false
    @State private var showingPrayerTimeSettings = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Personal Information Section
                Section {
                    profileSection
                } header: {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.islamicPrimaryGreen)
                        Text("Personal Information")
                    }
                } footer: {
                    Text("Your name will be used for personalized Islamic greetings and prayer notifications.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Prayer Settings
                Section("Prayer Settings") {
                    Picker("Default Tradition", selection: $viewModel.selectedMadhab) {
                        ForEach(Madhab.allCases, id: \.self) { madhab in
                            Text(madhab.sectDisplayName).tag(madhab)
                        }
                    }

                    NavigationLink("Prayer Time Settings") {
                        if let prayerTimesViewModel = prayerTimesViewModel {
                            PrayerTimeSettingsView(viewModel: prayerTimesViewModel)
                        } else {
                            LoadingView()
                        }
                    }

                    Toggle("Prayer Notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { newValue in
                            // TODO: Handle notification permission
                        }
                }

                // App Settings
                Section("App Settings") {
                    
                    Picker("Theme", selection: $themeManager.currentTheme) {
                        ForEach(ThemeMode.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .onChange(of: themeManager.currentTheme) { newTheme in
                        // Update both theme manager and settings service
                        themeManager.setTheme(newTheme)
                        settingsService.theme = newTheme
                    }

                    Toggle("Offline Downloads", isOn: $offlineDownloadsEnabled)
                        .onChange(of: offlineDownloadsEnabled) { newValue in
                            // TODO: Handle offline download settings
                        }
                }
                
                // Data Management
                Section("Data Management") {
                    Button("Manage Offline Content") {
                        showingDataManagement = true
                    }
                    
                    Button("Sync with Server") {
                        Task {
                            await viewModel.refreshData()
                        }
                    }
                    
                    Button("Clear Cache") {
                        clearCache()
                    }
                    .foregroundColor(.orange)
                }
                
                // Statistics
                Section("Statistics") {
                    StatRowView(title: "Total Guides", value: "\(viewModel.totalGuides)")
                    StatRowView(title: "Sunni Guides", value: "\(viewModel.shafiGuides)")
                    StatRowView(title: "Shia Guides", value: "\(viewModel.hanafiGuides)")
                    StatRowView(title: "Offline Available", value: "\(offlineGuidesCount)")
                }
                
                // Support
                Section("Support") {
                    Button("About DeenBuddy") {
                        showingAbout = true
                    }
                    
                    Button("Contact Support") {
                        openSupportEmail()
                    }
                    
                    Button("Rate App") {
                        openAppStore()
                    }
                }
                
                // Version Info
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .preferredColorScheme(themeManager.getColorScheme())
            .task {
                if prayerTimesViewModel == nil {
                    prayerTimesViewModel = PrayerTimesViewModel(preview: true)
                }
            }
            .sheet(isPresented: $showingAbout) {
                AboutView { 
                    showingAbout = false
                }
            }
            .sheet(isPresented: $showingDataManagement) {
                DataManagementView(viewModel: viewModel)
            }
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundColor(.islamicPrimaryGreen)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text("Used for personalized greetings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField("Enter your full name", text: $settingsService.userName)
                    .textFieldStyle(IslamicTextFieldStyle())
                    .submitLabel(.done)
                    .onSubmit {
                        // Validate and save when user submits
                        validateAndSaveName()
                    }

                if settingsService.userName.isEmpty {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(.islamicSecondaryGreen)

                        Text("Adding your name enables personalized Islamic greetings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if !settingsService.userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.islamicPrimaryGreen)

                        Text("Assalamu alaikum, \(settingsService.userName.trimmingCharacters(in: .whitespacesAndNewlines))!")
                            .font(.caption)
                            .foregroundColor(.islamicTextSecondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Computed Properties

    private var offlineGuidesCount: Int {
        viewModel.prayerGuides.filter { $0.isAvailableOffline }.count
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private func clearCache() {
        // TODO: Implement cache clearing
        print("Cache cleared")
    }
    
    private func openSupportEmail() {
        // TODO: Open email app with support address
        print("Opening support email")
    }
    
    private func openAppStore() {
        // TODO: Open App Store for rating
        print("Opening App Store")
    }

    // MARK: - Profile Validation

    private func validateAndSaveName() {
        // Trim whitespace and validate
        let trimmedName = settingsService.userName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Update the settings service with the trimmed name
        if trimmedName != settingsService.userName {
            settingsService.userName = trimmedName
        }

        // The SettingsService automatically saves when userName changes
        print("Name validated and saved: '\(trimmedName)'")
    }
}

struct StatRowView: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.blue)
        }
    }
}

struct DataManagementView: View {
    @ObservedObject var viewModel: PrayerGuideViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Offline Content") {
                    ForEach(viewModel.prayerGuides) { guide in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(guide.title)
                                    .font(.headline)
                                Text(guide.sectDisplayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if guide.isAvailableOffline {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Button("Download") {
                                    // TODO: Download guide for offline use
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Offline Content")
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
}

// MARK: - Custom Text Field Style

struct IslamicTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.islamicPrimaryGreen.opacity(0.3), lineWidth: 1)
            )
            .font(.body)
    }
}

#Preview {
    SettingsView(viewModel: PrayerGuideViewModel(), themeManager: ThemeManager())
}
