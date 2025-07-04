//
//  PrayerTimeSettingsView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-04.
//

import SwiftUI

struct PrayerTimeSettingsView: View {
    @ObservedObject var viewModel: PrayerTimesViewModel

    var body: some View {
        Form {
            calculationMethodSection
            madhabSection
            adjustmentsSection
            locationSection
            notificationsSection
        }
        .navigationTitle("Prayer Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var calculationMethodSection: some View {
        Section("Calculation Method") {
            Picker("Method", selection: $viewModel.settings.calculationMethod) {
                ForEach(CalculationMethod.allCases) { method in
                    Text(method.displayName)
                        .tag(method)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var madhabSection: some View {
        Section("Madhab") {
            Picker("Madhab", selection: $viewModel.settings.madhab) {
                ForEach(Madhab.allCases) { madhab in
                    HStack {
                        Circle()
                            .fill(madhab.color)
                            .frame(width: 12, height: 12)
                        Text(madhab.displayName)
                    }
                    .tag(madhab)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var timeFormatSection: some View {
        Section("Time Format") {
            Picker("Format", selection: $viewModel.settings.timeFormat) {
                ForEach(TimeFormat.allCases) { format in
                    VStack(alignment: .leading) {
                        Text(format.displayName)
                        Text(format.example)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(format)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var locationSection: some View {
        Section("Location") {
            HStack {
                Text("Current Location")
                Spacer()
                if viewModel.isLoadingLocation {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button("Update") {
                        Task {
                            await viewModel.refreshLocation()
                        }
                    }
                }
            }

            if let location = viewModel.currentLocation {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Latitude: \(location.coordinate.latitude, specifier: "%.4f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Longitude: \(location.coordinate.longitude, specifier: "%.4f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Enable Prayer Notifications", isOn: $viewModel.settings.notificationsEnabled)

            if viewModel.settings.notificationsEnabled {
                ForEach(Prayer.allCases, id: \.self) { prayer in
                    Toggle(prayer.displayName, isOn: Binding(
                        get: { viewModel.settings.notificationSettings[prayer] ?? false },
                        set: { viewModel.settings.notificationSettings[prayer] = $0 }
                    ))
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        PrayerTimeSettingsView(viewModel: PrayerTimesViewModel())
    }
}
