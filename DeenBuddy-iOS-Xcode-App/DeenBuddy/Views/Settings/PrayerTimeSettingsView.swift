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
            timeFormatSection
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

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Enable Prayer Notifications", isOn: $viewModel.settings.enableNotifications)

            if viewModel.settings.enableNotifications {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notification Timing")
                        .font(.headline)

                    HStack {
                        Text("Notify")
                        Spacer()
                        Stepper(
                            value: Binding(
                                get: { viewModel.settings.notificationOffset / 60 },
                                set: { viewModel.settings.notificationOffset = $0 * 60 }
                            ),
                            in: 0...30,
                            step: 1
                        ) {
                            Text("\(Int(viewModel.settings.notificationOffset / 60)) min before")
                                .foregroundColor(.secondary)
                        }
                    }
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
