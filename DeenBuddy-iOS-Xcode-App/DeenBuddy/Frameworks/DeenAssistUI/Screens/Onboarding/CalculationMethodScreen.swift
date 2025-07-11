import SwiftUI

/// Calculation method and madhab selection screen
public struct CalculationMethodScreen: View {
    private let settingsService: any SettingsServiceProtocol
    let onContinue: () -> Void
    
    @State private var selectedMethod: CalculationMethod
    @State private var selectedMadhab: Madhab
    
    public init(
        settingsService: any SettingsServiceProtocol,
        onContinue: @escaping () -> Void
    ) {
        self.settingsService = settingsService
        self.onContinue = onContinue
        self._selectedMethod = State(initialValue: settingsService.calculationMethod)
        self._selectedMadhab = State(initialValue: settingsService.madhab)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "globe.asia.australia.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ColorPalette.primary)
                
                Text("Prayer Calculation")
                    .headlineLarge()
                    .foregroundColor(ColorPalette.textPrimary)
                
                Text("Choose the calculation method and madhab that matches your region or preference")
                    .bodyLarge()
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 40)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Calculation Method Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Calculation Method")
                            .headlineSmall()
                            .foregroundColor(ColorPalette.textPrimary)
                        
                        LazyVStack(spacing: 12) {
                            ForEach(CalculationMethod.allCases, id: \.self) { method in
                                MethodSelectionCard(
                                    method: method,
                                    isSelected: selectedMethod == method,
                                    onSelect: {
                                        selectedMethod = method
                                    }
                                )
                            }
                        }
                    }
                    
                    // Madhab Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Madhab (Asr Calculation)")
                            .headlineSmall()
                            .foregroundColor(ColorPalette.textPrimary)
                        
                        VStack(spacing: 12) {
                            ForEach(Madhab.allCases, id: \.self) { madhab in
                                MadhabSelectionCard(
                                    madhab: madhab,
                                    isSelected: selectedMadhab == madhab,
                                    onSelect: {
                                        selectedMadhab = madhab
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            
            // Continue button
            VStack(spacing: 16) {
                CustomButton.primary("Continue") {
                    saveSelections()
                    onContinue()
                }
                
                Text("You can change these settings later")
                    .labelMedium()
                    .foregroundColor(ColorPalette.textTertiary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(ColorPalette.backgroundPrimary)
    }
    
    private func saveSelections() {
        settingsService.calculationMethod = selectedMethod
        settingsService.madhab = selectedMadhab
        
        Task {
            try? await settingsService.saveSettings()
        }
    }
}

/// Method selection card component
private struct MethodSelectionCard: View {
    let method: CalculationMethod
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(method.displayName)
                        .titleMedium()
                        .foregroundColor(ColorPalette.textPrimary)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ColorPalette.primary)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(ColorPalette.textTertiary)
                    }
                }
                
                Text(method.description)
                    .bodySmall()
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorPalette.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? ColorPalette.primary : ColorPalette.textTertiary.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Madhab selection card component
private struct MadhabSelectionCard: View {
    let madhab: Madhab
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(madhab.displayName)
                        .titleMedium()
                        .foregroundColor(ColorPalette.textPrimary)
                    
                    Text(madhab.description)
                        .bodySmall()
                        .foregroundColor(ColorPalette.textSecondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ColorPalette.primary)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(ColorPalette.textTertiary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorPalette.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? ColorPalette.primary : ColorPalette.textTertiary.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview("Calculation Method Screen") {
    CalculationMethodScreen(
        settingsService: MockSettingsService(),
        onContinue: { print("Continue") }
    )
}
