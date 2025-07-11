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
    @State private var prayerTimesViewModel: PrayerTimesViewModel?
    @State private var notificationsEnabled = true
    @State private var offlineDownloadsEnabled = true
    @State private var showingAbout = false
    @State private var showingDataManagement = false
    @State private var showingPrayerTimeSettings = false
    
    var body: some View {
        NavigationStack {
            Form {
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

#Preview {
    SettingsView(viewModel: PrayerGuideViewModel(), themeManager: ThemeManager())
}
