import SwiftUI
import WidgetKit

// MARK: - Widget Configuration View

/// Configuration interface for prayer time widgets
struct WidgetConfigurationView: View {
    @State private var configuration = WidgetDataManager.shared.loadWidgetConfiguration()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // Display Options Section
                displayOptionsSection
                
                // Prayer Display Section
                prayerDisplaySection
                
                // Color Scheme Section
                colorSchemeSection
                
                // Information Display Section
                informationDisplaySection
                
                // Preview Section
                previewSection
            }
            .navigationTitle("Widget Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveConfiguration()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Display Options Section
    
    @ViewBuilder
    private var displayOptionsSection: some View {
        Section("Display Options") {
            Toggle("Show Hijri Date", isOn: Binding(
                get: { configuration.showHijriDate },
                set: { newValue in
                    configuration = WidgetConfiguration(
                        showHijriDate: newValue,
                        showLocation: configuration.showLocation,
                        showCalculationMethod: configuration.showCalculationMethod,
                        preferredPrayerDisplay: configuration.preferredPrayerDisplay,
                        colorScheme: configuration.colorScheme
                    )
                }
            ))
            .help("Display Islamic calendar date in widgets")
            
            Toggle("Show Location", isOn: Binding(
                get: { configuration.showLocation },
                set: { newValue in
                    configuration = WidgetConfiguration(
                        showHijriDate: configuration.showHijriDate,
                        showLocation: newValue,
                        showCalculationMethod: configuration.showCalculationMethod,
                        preferredPrayerDisplay: configuration.preferredPrayerDisplay,
                        colorScheme: configuration.colorScheme
                    )
                }
            ))
            .help("Display current location in widgets")
            
            Toggle("Show Calculation Method", isOn: Binding(
                get: { configuration.showCalculationMethod },
                set: { newValue in
                    configuration = WidgetConfiguration(
                        showHijriDate: configuration.showHijriDate,
                        showLocation: configuration.showLocation,
                        showCalculationMethod: newValue,
                        preferredPrayerDisplay: configuration.preferredPrayerDisplay,
                        colorScheme: configuration.colorScheme
                    )
                }
            ))
            .help("Display prayer calculation method in large widgets")
        }
    }
    
    // MARK: - Prayer Display Section
    
    @ViewBuilder
    private var prayerDisplaySection: some View {
        Section("Prayer Display Style") {
            Picker("Display Style", selection: Binding(
                get: { configuration.preferredPrayerDisplay },
                set: { newValue in
                    configuration = WidgetConfiguration(
                        showHijriDate: configuration.showHijriDate,
                        showLocation: configuration.showLocation,
                        showCalculationMethod: configuration.showCalculationMethod,
                        preferredPrayerDisplay: newValue,
                        colorScheme: configuration.colorScheme
                    )
                }
            )) {
                ForEach(PrayerDisplayStyle.allCases, id: \.self) { style in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(style.displayName)
                            .font(.headline)
                        
                        Text(style.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(style)
                }
            }
            .pickerStyle(.navigationLink)
        }
    }
    
    // MARK: - Color Scheme Section
    
    @ViewBuilder
    private var colorSchemeSection: some View {
        Section("Color Scheme") {
            Picker("Color Scheme", selection: Binding(
                get: { configuration.colorScheme },
                set: { newValue in
                    configuration = WidgetConfiguration(
                        showHijriDate: configuration.showHijriDate,
                        showLocation: configuration.showLocation,
                        showCalculationMethod: configuration.showCalculationMethod,
                        preferredPrayerDisplay: configuration.preferredPrayerDisplay,
                        colorScheme: newValue
                    )
                }
            )) {
                ForEach(WidgetColorScheme.allCases, id: \.self) { scheme in
                    HStack {
                        colorSchemePreview(for: scheme)
                        Text(scheme.displayName)
                    }
                    .tag(scheme)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    // MARK: - Information Display Section
    
    @ViewBuilder
    private var informationDisplaySection: some View {
        Section("Information Display") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Widget Size Recommendations")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    recommendationRow(size: "Small", content: "Next prayer with countdown")
                    recommendationRow(size: "Medium", content: "Next prayer + upcoming prayers")
                    recommendationRow(size: "Large", content: "All prayers + Islamic calendar")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Preview Section
    
    @ViewBuilder
    private var previewSection: some View {
        Section("Preview") {
            VStack(spacing: 12) {
                Text("Widget Preview")
                    .font(.headline)
                
                // Mock widget preview
                WidgetPreviewCard(configuration: configuration)
            }
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func colorSchemePreview(for scheme: WidgetColorScheme) -> some View {
        Circle()
            .fill(colorForScheme(scheme))
            .frame(width: 16, height: 16)
    }
    
    @ViewBuilder
    private func recommendationRow(size: String, content: String) -> some View {
        HStack {
            Text("• \(size):")
                .fontWeight(.medium)
            
            Text(content)
            
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    
    private func colorForScheme(_ scheme: WidgetColorScheme) -> Color {
        switch scheme {
        case .adaptive:
            return .primary
        case .light:
            return .black
        case .dark:
            return .white
        case .islamic:
            return .green
        }
    }
    
    private func saveConfiguration() {
        WidgetDataManager.shared.saveWidgetConfiguration(configuration)
        
        // Trigger widget refresh with new configuration
        WidgetBackgroundRefreshManager.shared.refreshAllWidgets()
        
        print("✅ Widget configuration saved and widgets refreshed")
    }
}

// MARK: - Widget Preview Card

struct WidgetPreviewCard: View {
    let configuration: WidgetConfiguration
    
    var body: some View {
        VStack(spacing: 8) {
            // Mock widget content based on configuration
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fajr Prayer")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("5:30 AM")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("in 2h 15m")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    if configuration.showHijriDate {
                        Text("15 Ramadan 1445 AH")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if configuration.showLocation {
                        Text("New York, NY")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Prayer display style indicator
            HStack {
                Text("Style: \(configuration.preferredPrayerDisplay.displayName)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Scheme: \(configuration.colorScheme.displayName)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Widget Configuration Intent (for iOS 17+)

@available(iOS 17.0, *)
struct PrayerWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configure Prayer Widget"
    static var description = IntentDescription("Customize your prayer time widget display options.")
    
    @Parameter(title: "Show Hijri Date")
    var showHijriDate: Bool
    
    @Parameter(title: "Show Location")
    var showLocation: Bool
    
    @Parameter(title: "Prayer Display Style")
    var prayerDisplayStyle: PrayerDisplayStyleIntent
    
    @Parameter(title: "Color Scheme")
    var colorScheme: WidgetColorSchemeIntent
    
    init() {
        self.showHijriDate = true
        self.showLocation = true
        self.prayerDisplayStyle = .nextPrayerFocus
        self.colorScheme = .adaptive
    }
}

@available(iOS 17.0, *)
enum PrayerDisplayStyleIntent: String, AppEnum {
    case nextPrayerFocus
    case allPrayersToday
    case remainingPrayers
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Prayer Display Style")
    
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .nextPrayerFocus: "Next Prayer Focus",
        .allPrayersToday: "All Prayers Today",
        .remainingPrayers: "Remaining Prayers"
    ]
}

@available(iOS 17.0, *)
enum WidgetColorSchemeIntent: String, AppEnum {
    case adaptive
    case light
    case dark
    case islamic
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Color Scheme")
    
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .adaptive: "Adaptive",
        .light: "Light",
        .dark: "Dark",
        .islamic: "Islamic Green"
    ]
}

// MARK: - Preview

#if DEBUG
struct WidgetConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetConfigurationView()
    }
}
#endif
