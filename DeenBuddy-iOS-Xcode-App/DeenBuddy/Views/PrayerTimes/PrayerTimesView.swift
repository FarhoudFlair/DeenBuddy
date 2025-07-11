//
//  PrayerTimesView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-04.
//

import SwiftUI

/// Main view for displaying daily prayer times
struct PrayerTimesView: View {
    @StateObject private var viewModel: PrayerTimesViewModel
    
    init(container: DependencyContainer) {
        _viewModel = StateObject(wrappedValue: PrayerTimesViewModel(container: container))
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Loading prayer times...")
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            } else if let prayerTimes = viewModel.prayerTimes {
                // Display prayer times
                Text("Prayer Times")
                    .font(.largeTitle)
                ForEach(prayerTimes.allPrayers, id: \.0) { prayerType, prayerTime in
                    Text("\(prayerType.displayName): \(prayerTime.formatted(date: .omitted, time: .shortened))")
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.fetchPrayerTimes()
            }
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
                calculationMethodSection
                madhabSection
                timeFormatSection
                recommendationsSection
                resetSection
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
    
    private var calculationMethodSection: some View {
        Section("Calculation Method") {
            calculationMethodPicker
        }
    }
    
    private var calculationMethodPicker: some View {
        Picker("Method", selection: $viewModel.settingsService.calculationMethod) {
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
    
    private var madhabSection: some View {
        Section("School of Jurisprudence") {
            madhabPicker
        }
    }
    
    private var madhabPicker: some View {
        Picker("Madhab", selection: $viewModel.settingsService.madhab) {
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
    
    private var timeFormatSection: some View {
        Section("Time Format") {
            timeFormatPicker
        }
    }
    
    private var timeFormatPicker: some View {
        Picker("Format", selection: $viewModel.settingsService.timeFormat) {
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
    
    private var recommendationsSection: some View {
        Section("Recommendations") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Most calculation methods work globally. For best accuracy, choose based on your region's Islamic authority.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    private var resetSection: some View {
        Section {
            Button("Reset to Defaults") {
                Task {
                    try? await viewModel.settingsService.resetToDefaults()
                }
            }
            .foregroundColor(.red)
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
            Text(prayerTime.time.formatted(date: .omitted, time: .shortened))
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
    PrayerTimesView(container: DependencyContainer(
        locationService: MockLocationService(),
        apiClient: MockAPIClient(),
        notificationService: MockNotificationService(),
        prayerTimeService: MockPrayerTimeService(),
        settingsService: MockSettingsService(),
        isTestEnvironment: true
    ))
}
