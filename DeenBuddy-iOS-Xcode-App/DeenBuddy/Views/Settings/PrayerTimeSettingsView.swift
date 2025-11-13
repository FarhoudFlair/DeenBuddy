//
//  PrayerTimeSettingsView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-04.
//

import SwiftUI

struct PrayerTimeSettingsView: View {
    @ObservedObject var viewModel: PrayerTimesViewModel
    @State private var showingCalculationMethodPicker = false
    @State private var showingMadhabPicker = false

    var body: some View {
        Form {
            madhabSection
            calculationMethodSection
            timeFormatSection
            notificationsSection
        }
        .navigationTitle("Prayer Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCalculationMethodPicker) {
            CalculationMethodPickerView(
                selectedMethod: viewModel.settings.calculationMethod,
                selectedMadhab: viewModel.settings.madhab,
                onMethodSelected: { newMethod in
                    // Add haptic feedback for immediate user response
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                    // Update the calculation method
                    viewModel.settings.calculationMethod = newMethod
                    
                    // Auto-select preferred madhab if the current one is incompatible
                    if !newMethod.isCompatible(with: viewModel.settings.madhab) {
                        if let preferredMadhab = newMethod.preferredMadhab {
                            viewModel.settings.madhab = preferredMadhab
                        }
                    }
                    
                    // CRITICAL FIX: Add delay to ensure UI updates before dismissing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showingCalculationMethodPicker = false
                    }
                }
            )
        }
        .sheet(isPresented: $showingMadhabPicker) {
            MadhabPickerView(
                selectedMadhab: viewModel.settings.madhab,
                calculationMethod: viewModel.settings.calculationMethod,
                onMadhabSelected: { newMadhab in
                    // Add haptic feedback for immediate user response
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                    // Update the madhab
                    viewModel.settings.madhab = newMadhab
                    showingMadhabPicker = false
                }
            )
        }
    }

    private var calculationMethodSection: some View {
        Section("Calculation Method") {
            // Full-row tappable method selection
            Button(action: {
                showingCalculationMethodPicker = true
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.settings.calculationMethod.displayName)
                            .foregroundColor(.primary)
                            .font(.body)
                        
                        Text(viewModel.settings.calculationMethod.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3) // Allow up to 3 lines for long descriptions
                            .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .contentShape(Rectangle()) // Makes entire row tappable
            }
            .buttonStyle(PlainButtonStyle())
            
            // Show preferred madhab information
            if let preferredMadhab = viewModel.settings.calculationMethod.preferredMadhab {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("This method is designed for the \(preferredMadhab.displayName) school")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.top, 4)
            }
        }
    }

    private var madhabSection: some View {
        Section("Madhab (Sect)") {
            // Full-row tappable madhab selection
            Button(action: {
                showingMadhabPicker = true
            }) {
                HStack {
                    // Madhab color indicator
                    Circle()
                        .fill(viewModel.settings.madhab.color)
                        .frame(width: 12, height: 12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        // CRITICAL FIX: Use explicit binding to ensure updates
                        Text(viewModel.settings.madhab.displayName)
                            .foregroundColor(.primary)
                            .font(.body)
                            .id("madhab-\(viewModel.settings.madhab.rawValue)") // Force refresh
                        
                        Text(viewModel.settings.madhab.prayerTimingNotes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3) // Allow up to 3 lines for long timing notes
                            .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion
                    }
                    
                    Spacer()
                    
                    // Show compatibility indicator
                    let compatibility = viewModel.settings.calculationMethod.compatibilityStatus(with: viewModel.settings.madhab)
                    if compatibility != .neutral {
                        Circle()
                            .fill(compatibility.displayColor)
                            .frame(width: 8, height: 8)
                    }
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .contentShape(Rectangle()) // Makes entire row tappable
            }
            .buttonStyle(PlainButtonStyle())
            
            // Show compatibility status and warnings
            let currentCompatibility = viewModel.settings.calculationMethod.compatibilityStatus(with: viewModel.settings.madhab)
            
            if let warningMessage = currentCompatibility.warningMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(warningMessage)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.top, 4)
            }
            
            // Show positive compatibility feedback
            if currentCompatibility == .recommended {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Perfect match - this combination ensures accurate prayer times")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.top, 4)
            }
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
