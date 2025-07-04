//
//  PrayerTimesView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-04.
//

import SwiftUI

/// Main view for displaying daily prayer times
struct PrayerTimesView: View {
    @StateObject private var viewModel = PrayerTimesViewModel()
    @State private var showingRefreshAnimation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Date Header
                        DateHeaderView(
                            dualCalendarDate: viewModel.dualCalendarDate,
                            todaysEvents: viewModel.todaysEvents
                        )
                        .padding(.horizontal)
                        
                        // Ramadan Banner (if applicable)
                        if viewModel.isRamadan {
                            RamadanBanner()
                                .padding(.horizontal)
                        }
                        
                        // Location Header
                        LocationHeaderView(
                            locationName: viewModel.formattedLocation,
                            isLocationAvailable: viewModel.isLocationAvailable,
                            onLocationTapped: {
                                handleLocationTapped()
                            }
                        )
                        .padding(.horizontal)
                        
                        // Main Content
                        Group {
                            if viewModel.isLoading {
                                PrayerTimesLoadingView()
                                    .padding()
                            } else if let error = viewModel.error {
                                PrayerTimesErrorView(
                                    error: error,
                                    onRetry: {
                                        Task {
                                            await viewModel.refreshPrayerTimes()
                                        }
                                    },
                                    onRequestLocation: {
                                        Task {
                                            await viewModel.requestLocationPermission()
                                        }
                                    }
                                )
                                .padding()
                            } else if let schedule = viewModel.currentSchedule {
                                prayerTimesContent(schedule: schedule)
                            } else {
                                PrayerTimesEmptyView {
                                    Task {
                                        await viewModel.requestLocationPermission()
                                    }
                                }
                                .padding()
                            }
                        }
                        
                        // Settings Quick Access
                        if viewModel.currentSchedule != nil {
                            PrayerTimesSettingsBar(
                                calculationMethod: viewModel.settings.calculationMethod,
                                madhab: viewModel.settings.madhab,
                                timeFormat: viewModel.settings.timeFormat,
                                onSettingsTapped: {
                                    viewModel.showSettings()
                                }
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await refreshData()
                }
            }
            .navigationTitle("Prayer Times")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Refresh", systemImage: "arrow.clockwise") {
                            Task {
                                await refreshData()
                            }
                        }
                        
                        Button("Settings", systemImage: "gear") {
                            viewModel.showSettings()
                        }
                        
                        Button("Clear Cache", systemImage: "trash") {
                            viewModel.clearCache()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showingSettings) {
            PrayerTimesSettingsView(viewModel: viewModel)
        }
        .alert("Location Permission Required", isPresented: $viewModel.showingLocationPermissionAlert) {
            Button("Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("DeenBuddy needs location access to calculate accurate prayer times. Please enable location access in Settings.")
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil && !viewModel.showingLocationPermissionAlert)) {
            if let error = viewModel.error {
                switch error {
                case .networkError:
                    Button("Retry") {
                        Task {
                            await viewModel.retryWithBackoff()
                        }
                    }
                    Button("Use Offline Data") {
                        // Try to use cached data
                        viewModel.error = nil
                    }
                    Button("Cancel", role: .cancel) {
                        viewModel.error = nil
                    }
                case .calculationFailed:
                    Button("Retry") {
                        Task {
                            await viewModel.refreshPrayerTimes()
                        }
                    }
                    if viewModel.hasExtremeLatitudeIssues() {
                        Button("Fix for High Latitude") {
                            Task {
                                await viewModel.handleExtremeLatitude()
                            }
                        }
                    }
                    Button("Reset Settings") {
                        viewModel.updateSettings(PrayerTimeSettings())
                        Task {
                            await viewModel.refreshPrayerTimes()
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        viewModel.error = nil
                    }
                case .cacheError:
                    Button("Clear Cache") {
                        viewModel.clearCache()
                    }
                    Button("Cancel", role: .cancel) {
                        viewModel.error = nil
                    }
                default:
                    Button("Retry") {
                        Task {
                            await viewModel.refreshPrayerTimes()
                        }
                    }
                    Button("OK", role: .cancel) {
                        viewModel.error = nil
                    }
                }
            }
        } message: {
            if let error = viewModel.error {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error.localizedDescription)
                    if let suggestion = error.recoverySuggestion {
                        Text(suggestion)
                            .font(.caption)
                    }
                }
            }
        }
        .onAppear {
            handleAppearance()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            viewModel.handleAppBecameActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            viewModel.handleSignificantTimeChange()
        }
    }
    
    // MARK: - Prayer Times Content
    
    @ViewBuilder
    private func prayerTimesContent(schedule: PrayerSchedule) -> some View {
        VStack(spacing: 20) {
            // Next Prayer Highlight
            if let nextPrayer = viewModel.nextPrayer {
                NextPrayerCard(
                    prayerTime: nextPrayer,
                    timeFormat: viewModel.settings.timeFormat
                )
                .padding(.horizontal)
            }
            
            // All Prayer Times
            VStack(spacing: 16) {
                HStack {
                    Text("Today's Prayer Times")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                PrayerTimesList(
                    prayerTimes: viewModel.todaysPrayerTimes,
                    timeFormat: viewModel.settings.timeFormat,
                    nextPrayerIndex: findNextPrayerIndex()
                )
                .padding(.horizontal)
            }
            
            // Additional Info
            if viewModel.isSacredMonth {
                sacredMonthBanner()
                    .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private func sacredMonthBanner() -> some View {
        HStack(spacing: 12) {
            Image(systemName: "star.crescent.fill")
                .font(.title2)
                .foregroundColor(.gold)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Sacred Month")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("This is one of the four sacred months in Islam")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gold.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gold.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Helper Methods
    
    private func findNextPrayerIndex() -> Int? {
        guard let nextPrayer = viewModel.nextPrayer else { return nil }
        return viewModel.todaysPrayerTimes.firstIndex { $0.id == nextPrayer.id }
    }
    
    private func handleLocationTapped() {
        if !viewModel.isLocationAvailable {
            Task {
                await viewModel.requestLocationPermission()
            }
        }
    }
    
    private func handleAppearance() {
        // Request location permission if not determined
        if viewModel.locationPermissionStatus == .notDetermined {
            Task {
                await viewModel.requestLocationPermission()
            }
        }
    }
    
    private func refreshData() async {
        showingRefreshAnimation = true
        await viewModel.refreshPrayerTimes()
        
        // Add a small delay for better UX
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        showingRefreshAnimation = false
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Prayer Times Settings View

struct PrayerTimesSettingsView: View {
    @ObservedObject var viewModel: PrayerTimesViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Calculation Method") {
                    Picker("Method", selection: $viewModel.settings.calculationMethod) {
                        ForEach(CalculationMethod.allCases) { method in
                            VStack(alignment: .leading) {
                                Text(method.displayName)
                                    .font(.body)
                                Text(method.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(method)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                Section("School of Jurisprudence") {
                    Picker("Madhab", selection: $viewModel.settings.madhab) {
                        ForEach(Madhab.allCases) { madhab in
                            VStack(alignment: .leading) {
                                Text(madhab.displayName)
                                    .font(.body)
                                Text(madhab.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(madhab)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                Section("Time Format") {
                    Picker("Format", selection: $viewModel.settings.timeFormat) {
                        ForEach(TimeFormat.allCases) { format in
                            HStack {
                                Text(format.displayName)
                                Spacer()
                                Text(format.example)
                                    .foregroundColor(.secondary)
                            }
                            .tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Recommendations") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recommended for your location:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(viewModel.getRecommendedCalculationMethods(), id: \.self) { method in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                
                                Text(method.displayName)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    Button("Reset to Defaults") {
                        viewModel.updateSettings(PrayerTimeSettings())
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Prayer Settings")
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

// MARK: - Color Extensions

extension Color {
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
}

// MARK: - Preview

#Preview {
    PrayerTimesView()
}
