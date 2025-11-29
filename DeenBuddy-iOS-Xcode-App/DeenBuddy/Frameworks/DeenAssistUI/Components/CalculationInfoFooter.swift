import SwiftUI

/// Footer component displaying calculation information and required disclaimers
/// Shows calculation method, madhab, timezone, and Islamic accuracy disclaimers
public struct CalculationInfoFooter: View {

    // MARK: - Properties

    let calculationMethod: CalculationMethod
    let madhab: Madhab
    let isRamadan: Bool
    let calculationTimezone: TimeZone
    let onSettingsTapped: () -> Void

    @Environment(\.currentTheme) private var currentTheme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.timeZone) private var timeZone

    // MARK: - Initialization

    public init(
        calculationMethod: CalculationMethod,
        madhab: Madhab,
        isRamadan: Bool,
        calculationTimezone: TimeZone = .current,
        onSettingsTapped: @escaping () -> Void
    ) {
        self.calculationMethod = calculationMethod
        self.madhab = madhab
        self.isRamadan = isRamadan
        self.calculationTimezone = calculationTimezone
        self.onSettingsTapped = onSettingsTapped
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: PremiumDesignTokens.spacing12) {
            // Info rows
            infoRow(label: "Method", value: calculationMethod.displayName)
            infoRow(label: "Madhab", value: madhab.displayName)
            infoRow(label: "Timezone", value: calculationTimezone.identifier)

            Divider()
                .background(themeColors.textTertiary.opacity(0.3))

            // REQUIRED: Defer to local authority disclaimer
            disclaimerText(
                "Defer to local authority for official prayer times.",
                isStrong: true
            )

            // CONDITIONAL: Ramadan Isha footnote
            if isRamadan && usesRamadanIshaOffset {
                disclaimerText(
                    "Isha in Ramadan: 90m + 30m; errs to later for safety.",
                    isStrong: false
                )
            }

            // Link to Settings
            Button(action: onSettingsTapped) {
                HStack(spacing: PremiumDesignTokens.spacing8) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))

                    Text("Change calculation settings")
                        .font(Typography.bodyMedium)
                }
                .foregroundColor(themeColors.primary)
            }
            .buttonAccessibility(
                label: "Change calculation settings",
                hint: "Opens settings screen to modify calculation method and madhab"
            )
            .padding(.top, PremiumDesignTokens.spacing8)
        }
        .padding(PremiumDesignTokens.spacing16)
        .background(themeColors.surfaceSecondary)
        .cornerRadius(PremiumDesignTokens.cornerRadius12)
    }

    // MARK: - Components

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Typography.bodyMedium)
                .foregroundColor(themeColors.textSecondary)

            Spacer()

            Text(value)
                .font(Typography.bodyMedium)
                .foregroundColor(themeColors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private func disclaimerText(_ text: String, isStrong: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(isStrong ? .red : .orange)
                .font(.system(size: 16))

            Text(text)
                .font(isStrong ? Typography.bodyMedium : Typography.bodySmall)
                .foregroundColor(themeColors.textPrimary)
                .fontWeight(isStrong ? .semibold : .regular)
                .fixedSize(horizontal: false, vertical: true)  // Allow multi-line
        }
        .padding(PremiumDesignTokens.spacing8)
        .background(isStrong ? Color.red.opacity(0.1) : Color.orange.opacity(0.05))
        .cornerRadius(PremiumDesignTokens.cornerRadius12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Important: \(text)")
    }

    // MARK: - Helpers

    private var themeColors: ThemeAwareColorPalette {
        ThemeAwareColorPalette(theme: currentTheme)
    }

    /// Determine if the calculation method uses Ramadan Isha +30m offset
    private var usesRamadanIshaOffset: Bool {
        // Umm Al Qura and Qatar methods use the +30m Isha offset during Ramadan
        calculationMethod == .ummAlQura || calculationMethod == .qatar
    }
}

// MARK: - Preview

#Preview("Calculation Info Footer - Normal") {
    CalculationInfoFooter(
        calculationMethod: .muslimWorldLeague,
        madhab: .shafi,
        isRamadan: false,
        onSettingsTapped: {
            print("Settings tapped")
        }
    )
    .padding(PremiumDesignTokens.spacing16)
    .background(ColorPalette.backgroundPrimary)
}

#Preview("Calculation Info Footer - Ramadan Umm Al Qura") {
    CalculationInfoFooter(
        calculationMethod: .ummAlQura,
        madhab: .hanafi,
        isRamadan: true,
        onSettingsTapped: {
            print("Settings tapped")
        }
    )
    .padding(PremiumDesignTokens.spacing16)
    .background(ColorPalette.backgroundPrimary)
}

#Preview("Calculation Info Footer - Ramadan Other Method") {
    CalculationInfoFooter(
        calculationMethod: .egyptian,
        madhab: .shafi,
        isRamadan: true,
        onSettingsTapped: {
            print("Settings tapped")
        }
    )
    .padding(PremiumDesignTokens.spacing16)
    .background(ColorPalette.backgroundPrimary)
}

#Preview("Calculation Info Footer - Dark Mode") {
    CalculationInfoFooter(
        calculationMethod: .ummAlQura,
        madhab: .jafari,
        isRamadan: true,
        onSettingsTapped: {
            print("Settings tapped")
        }
    )
    .padding(PremiumDesignTokens.spacing16)
    .background(ColorPalette.backgroundPrimary)
    .environment(\.currentTheme, .dark)
    .environment(\.colorScheme, .dark)
}

#Preview("Calculation Info Footer - Islamic Green") {
    CalculationInfoFooter(
        calculationMethod: .qatar,
        madhab: .hanafi,
        isRamadan: true,
        onSettingsTapped: {
            print("Settings tapped")
        }
    )
    .padding(PremiumDesignTokens.spacing16)
    .background(Color.islamicBackgroundPrimary)
    .environment(\.currentTheme, .islamicGreen)
}
