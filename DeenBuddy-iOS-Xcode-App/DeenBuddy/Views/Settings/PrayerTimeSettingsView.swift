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
            Section("Calculation Method") {
                Picker("Method", selection: $viewModel.settings.calculationMethod) {
                    ForEach(CalculationMethod.allCases) { method in
                        Text(method.displayName)
                            .tag(method)
                    }
                }
                .pickerStyle(.menu)
            }
            
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
            
            Section("Adjustments") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(PrayerType.allCases, id: \.self) { prayer in
                        HStack {
                            Text(prayer.displayName)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Stepper(
                                value: Binding(
                                    get: { viewModel.settings.adjustments[prayer] ?? 0 },
                                    set: { viewModel.settings.adjustments[prayer] = $0 }
                                ),
                                in: -30...30,
                                step: 1
                            ) {
                                Text("\(viewModel.settings.adjustments[prayer] ?? 0) min")
                                    .foregroundColor(.secondary)
                                    .frame(width: 50)
                            }
                        }
                    }
                }
            }
            
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
            
            Section("Notifications") {
                Toggle("Enable Prayer Notifications", isOn: $viewModel.settings.notificationsEnabled)
                
                if viewModel.settings.notificationsEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(PrayerType.allCases, id: \.self) { prayer in
                            Toggle(prayer.displayName, isOn: Binding(
                                get: { viewModel.settings.notificationSettings[prayer] ?? false },
                                set: { viewModel.settings.notificationSettings[prayer] = $0 }
                            ))
                        }
                    }
                }
            }
        }
        .navigationTitle("Prayer Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        PrayerTimeSettingsView(viewModel: PrayerTimesViewModel())
    }
}
