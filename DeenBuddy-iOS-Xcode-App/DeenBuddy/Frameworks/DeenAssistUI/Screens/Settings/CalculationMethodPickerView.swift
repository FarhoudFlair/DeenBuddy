import SwiftUI

/// Calculation method picker view
public struct CalculationMethodPickerView: View {
    let selectedMethod: CalculationMethod
    let onMethodSelected: (CalculationMethod) -> Void
    
    public init(
        selectedMethod: CalculationMethod,
        onMethodSelected: @escaping (CalculationMethod) -> Void
    ) {
        self.selectedMethod = selectedMethod
        self.onMethodSelected = onMethodSelected
    }
    
    public var body: some View {
        NavigationView {
            List {
                ForEach(CalculationMethod.allCases, id: \.self) { method in
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

/// Madhab picker view
public struct MadhabPickerView: View {
    let selectedMadhab: Madhab
    let onMadhabSelected: (Madhab) -> Void
    
    public init(
        selectedMadhab: Madhab,
        onMadhabSelected: @escaping (Madhab) -> Void
    ) {
        self.selectedMadhab = selectedMadhab
        self.onMadhabSelected = onMadhabSelected
    }
    
    public var body: some View {
        NavigationView {
            List {
                ForEach(Madhab.allCases, id: \.self) { madhab in
                    MadhabRow(
                        madhab: madhab,
                        isSelected: madhab == selectedMadhab,
                        onSelect: {
                            onMadhabSelected(madhab)
                        }
                    )
                }
            }
            .navigationTitle("Madhab")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Madhab row component
private struct MadhabRow: View {
    let madhab: Madhab
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
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
                
                Text(madhab.description)
                    .bodySmall()
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(.vertical, 4)
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
        onMethodSelected: { _ in }
    )
}

#Preview("Madhab Picker") {
    MadhabPickerView(
        selectedMadhab: .sunni,
        onMadhabSelected: { _ in }
    )
}

#Preview("Theme Picker") {
    ThemePickerView(
        themeManager: ThemePreview.systemTheme,
        onDismiss: {}
    )
}
