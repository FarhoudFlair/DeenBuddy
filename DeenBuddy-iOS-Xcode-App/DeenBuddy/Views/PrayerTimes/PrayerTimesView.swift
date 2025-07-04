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
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Mosque header image
                    MosqueHeaderView()

                    // Main content
                    VStack(spacing: 20) {
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
                                modernPrayerTimesContent(schedule: schedule)
                            } else {
                                PrayerTimesEmptyView {
                                    Task {
                                        await viewModel.requestLocationPermission()
                                    }
                                }
                                .padding()
                            }
                        }

                        // Location info at bottom
                        if viewModel.isLocationAvailable {
                            LocationInfoFooter(
                                locationName: viewModel.formattedLocation,
                                onLocationTapped: {
                                    handleLocationTapped()
                                }
                            )
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                    .padding(.top, 20)
                }
            }
            .refreshable {
                await refreshData()
            }
        }
        .preferredColorScheme(.dark)
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
    private func modernPrayerTimesContent(schedule: PrayerSchedule) -> some View {
        VStack(spacing: 0) {
            // Prayer times list
            ForEach(Array(viewModel.todaysPrayerTimes.enumerated()), id: \.element.id) { index, prayerTime in
                ModernPrayerTimeRow(
                    prayerTime: prayerTime,
                    timeFormat: viewModel.settings.timeFormat,
                    isNext: findNextPrayerIndex() == index
                )
                .padding(.horizontal, 20)

                if index < viewModel.todaysPrayerTimes.count - 1 {
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.horizontal, 20)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
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

// MARK: - Supporting Views

struct MosqueHeaderView: View {
    var body: some View {
        ZStack {
            // Mosque silhouette image placeholder
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.8),
                            Color.purple.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)

            // Mosque silhouette overlay
            VStack {
                Spacer()
                HStack(spacing: 20) {
                    // Minaret 1
                    Rectangle()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: 8, height: 60)

                    // Main dome
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: 80, height: 40)
                        .clipShape(Rectangle().offset(y: 20))

                    // Minaret 2
                    Rectangle()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: 8, height: 60)
                }
                .padding(.bottom, 20)
            }
        }
    }
}

struct ModernPrayerTimeRow: View {
    let prayerTime: PrayerTime
    let timeFormat: TimeFormat
    let isNext: Bool

    var body: some View {
        HStack {
            // Prayer name
            VStack(alignment: .leading, spacing: 2) {
                Text(prayerTime.prayer.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Text(prayerTime.prayer.arabicName)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Prayer time
            Text(prayerTime.formattedTime(format: timeFormat))
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(isNext ? .cyan : .white)

            // Next prayer indicator
            if isNext {
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 16)
        .background(
            isNext ? Color.cyan.opacity(0.1) : Color.clear
        )
    }
}

struct LocationInfoFooter: View {
    let locationName: String
    let onLocationTapped: () -> Void

    var body: some View {
        Button(action: onLocationTapped) {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(.cyan)

                Text(locationName)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))

                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
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
