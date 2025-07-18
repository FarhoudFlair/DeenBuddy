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
                set: { newValue in
                    // Add haptic feedback for immediate user response
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                    // Update the value synchronously first
                    viewModel.settings.calculationMethod = newValue
                }
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
                set: { newValue in
                    // Add haptic feedback for immediate user response
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                    // Update the value synchronously first
                    viewModel.settings.madhab = newValue
                }
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
                set: { newValue in
                    // Add haptic feedback for immediate user response
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                    // Update the value synchronously first
                    viewModel.settings.timeFormat = newValue
                }
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
                set: { newValue in
                    // Add haptic feedback for immediate user response
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                    // Update the value synchronously first
                    viewModel.settings.enableNotifications = newValue
                }
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
                                set: { newValue in
                                    // Add haptic feedback for immediate user response
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                    
                                    // Update the value synchronously first
                                    viewModel.settings.notificationOffset = newValue * 60
                                }
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
