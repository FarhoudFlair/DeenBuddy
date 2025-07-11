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
            Picker("Method", selection: Binding(
                get: { viewModel.settings.calculationMethod },
                set: { viewModel.settings.calculationMethod = $0 }
            )) {
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
            Picker("Madhab", selection: Binding(
                get: { viewModel.settings.madhab },
                set: { viewModel.settings.madhab = $0 }
            )) {
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
            Picker("Format", selection: Binding(
                get: { viewModel.settings.timeFormat },
                set: { viewModel.settings.timeFormat = $0 }
            )) {
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
            Toggle("Enable Prayer Notifications", isOn: Binding(
                get: { viewModel.settings.enableNotifications },
                set: { viewModel.settings.enableNotifications = $0 }
            ))

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
        PrayerTimeSettingsView(viewModel: {
            let viewModel = PrayerTimesViewModel(preview: true)
            return viewModel
        }())
    }
}
