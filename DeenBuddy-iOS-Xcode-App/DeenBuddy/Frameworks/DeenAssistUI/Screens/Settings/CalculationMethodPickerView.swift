import SwiftUI

/// Calculation method picker view
public struct CalculationMethodPickerView: View {
    let selectedMethod: CalculationMethod
    let selectedMadhab: Madhab
    let onMethodSelected: (CalculationMethod) -> Void
    
    private var compatibleMethods: [CalculationMethod] {
        CalculationMethod.allCases.filter { method in
            method.isCompatible(with: selectedMadhab)
        }
    }
    
    public init(
        selectedMethod: CalculationMethod,
        selectedMadhab: Madhab,
        onMethodSelected: @escaping (CalculationMethod) -> Void
    ) {
        self.selectedMethod = selectedMethod
        self.selectedMadhab = selectedMadhab
        self.onMethodSelected = onMethodSelected
    }
    
    public var body: some View {
        NavigationView {
            List {
                ForEach(compatibleMethods, id: \.self) { method in
                    MethodRow(
                        method: method,
                        isSelected: method == selectedMethod,
                        onSelect: {
                            onMethodSelected(method)
                        }
                    )
                }
            }
            .navigationTitle("Calculation Method")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Method row component
private struct MethodRow: View {
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
                        Image(systemName: "checkmark")
                            .foregroundColor(ColorPalette.primary)
                    }
                }
                
                Text(method.description)
                    .bodySmall()
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Madhab picker view with calculation method compatibility
public struct MadhabPickerView: View {
    let selectedMadhab: Madhab
    let calculationMethod: CalculationMethod
    let onMadhabSelected: (Madhab) -> Void
    
    public init(
        selectedMadhab: Madhab,
        calculationMethod: CalculationMethod,
        onMadhabSelected: @escaping (Madhab) -> Void
    ) {
        self.selectedMadhab = selectedMadhab
        self.calculationMethod = calculationMethod
        self.onMadhabSelected = onMadhabSelected
    }
    
    public var body: some View {
        NavigationView {
            List {
                // Show compatibility info section
                if let preferredMadhab = calculationMethod.preferredMadhab {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Method Guidance")
                                    .font(.headline)
                            }
                            
                            Text("\(calculationMethod.displayName) is designed for \(preferredMadhab.displayName) jurisprudence.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Madhab selection section
                Section("Select Madhab (Sect)") {
                    ForEach(Madhab.allCases, id: \.self) { madhab in
                        EnhancedMadhabRow(
                            madhab: madhab,
                            calculationMethod: calculationMethod,
                            isSelected: madhab == selectedMadhab,
                            onSelect: {
                                onMadhabSelected(madhab)
                            }
                        )
                    }
                }
            }
            .navigationTitle("Madhab (Sect)")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Enhanced madhab row with compatibility indicators
private struct EnhancedMadhabRow: View {
    let madhab: Madhab
    let calculationMethod: CalculationMethod
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var compatibility: MethodMadhabCompatibility {
        calculationMethod.compatibilityStatus(with: madhab)
    }
    
    private var isCompatible: Bool {
        calculationMethod.isCompatible(with: madhab)
    }
    
    var body: some View {
        Button(action: isCompatible ? onSelect : {}) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Madhab color indicator
                    Circle()
                        .fill(madhab.color)
                        .frame(width: 12, height: 12)
                    
                    Text(madhab.displayName)
                        .titleMedium()
                        .foregroundColor(isCompatible ? ColorPalette.textPrimary : ColorPalette.textSecondary)
                    
                    Spacer()
                    
                    // Compatibility status indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(compatibility.displayColor)
                            .frame(width: 8, height: 8)
                        
                        Text(compatibility.displayText)
                            .font(.caption)
                            .foregroundColor(compatibility.displayColor)
                    }
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundColor(ColorPalette.primary)
                    }
                }
                
                // Show warning message if needed
                if let warningMessage = compatibility.warningMessage {
                    Text(warningMessage)
                        .bodySmall()
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.leading)
                }
                
                // Show incompatible reason if needed
                if !isCompatible {
                    Text("This madhab is not compatible with \(calculationMethod.displayName)")
                        .bodySmall()
                        .foregroundColor(.red)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.vertical, 4)
            .opacity(isCompatible ? 1.0 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isCompatible)
    }
}

/// Legacy madhab row component (kept for backward compatibility)
private struct MadhabRow: View {
    let madhab: Madhab
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(madhab.displayName)
                    .titleMedium()
                    .foregroundColor(ColorPalette.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(ColorPalette.primary)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Theme picker view
public struct ThemePickerView: View {
    @ObservedObject private var themeManager: ThemeManager
    let onDismiss: () -> Void
    
    public init(themeManager: ThemeManager, onDismiss: @escaping () -> Void) {
        self.themeManager = themeManager
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationView {
            List {
                ForEach(ThemeMode.allCases, id: \.self) { theme in
                    ThemeRow(
                        theme: theme,
                        isSelected: theme == themeManager.currentTheme,
                        onSelect: {
                            themeManager.setTheme(theme)
                            onDismiss()
                        }
                    )
                }
            }
            .navigationTitle("Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

/// Theme row component
private struct ThemeRow: View {
    let theme: ThemeMode
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Theme preview
                HStack(spacing: 4) {
                    Circle()
                        .fill(themePreviewColor)
                        .frame(width: 16, height: 16)
                    
                    Circle()
                        .fill(themePreviewColor.opacity(0.6))
                        .frame(width: 12, height: 12)
                    
                    Circle()
                        .fill(themePreviewColor.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.displayName)
                        .titleMedium()
                        .foregroundColor(ColorPalette.textPrimary)
                    
                    Text(theme.description)
                        .bodySmall()
                        .foregroundColor(ColorPalette.textSecondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(ColorPalette.primary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var themePreviewColor: Color {
        switch theme {
        case .islamicGreen:
            return .white
        case .dark:
            return .black
        default:
            return ColorPalette.primary
        }
    }
}

// MARK: - Preview

#Preview("Calculation Method Picker") {
    CalculationMethodPickerView(
        selectedMethod: .muslimWorldLeague,
        selectedMadhab: .shafi,
        onMethodSelected: { _ in }
    )
}

#Preview("Madhab Picker") {
    MadhabPickerView(
        selectedMadhab: .shafi,
        calculationMethod: .jafariTehran,
        onMadhabSelected: { _ in }
    )
}

#Preview("Theme Picker") {
    ThemePickerView(
        themeManager: ThemePreview.systemTheme,
        onDismiss: {}
    )
}
