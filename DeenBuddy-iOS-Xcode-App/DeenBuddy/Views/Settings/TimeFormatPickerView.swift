import SwiftUI

/// Time format picker view
public struct TimeFormatPickerView: View {
    private let settingsService: any SettingsServiceProtocol
    private let onDismiss: () -> Void
    @State private var currentTimeFormat: TimeFormat
    
    public init(
        settingsService: any SettingsServiceProtocol,
        onDismiss: @escaping () -> Void
    ) {
        self.settingsService = settingsService
        self.onDismiss = onDismiss
        self._currentTimeFormat = State(initialValue: settingsService.timeFormat)
    }
    
    public var body: some View {
        NavigationView {
            List {
                Section("Time Format") {
                    ForEach(TimeFormat.allCases) { format in
                        TimeFormatRow(
                            format: format,
                            isSelected: currentTimeFormat == format,
                            onSelect: {
                                // Add haptic feedback for immediate user response
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                
                                // Update state synchronously first
                                currentTimeFormat = format
                                settingsService.timeFormat = format
                                
                                // Dismiss after a short delay to show the selection
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    onDismiss()
                                }
                            }
                        )
                    }
                }
                
                Section {
                    Text("Choose how prayer times are displayed throughout the app.")
                        .bodySmall()
                        .foregroundColor(ColorPalette.textSecondary)
                }
            }
            .navigationTitle("Time Format")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundColor(ColorPalette.primary)
                }
            }
        }
    }
}

/// Individual time format row
private struct TimeFormatRow: View {
    let format: TimeFormat
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(format.displayName)
                        .titleMedium()
                        .foregroundColor(ColorPalette.textPrimary)
                    
                    Text(format.example)
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
}

#Preview {
    TimeFormatPickerView(
        settingsService: TimeFormatPreviewMockSettingsService(),
        onDismiss: {}
    )
}

// Mock for preview
private class TimeFormatPreviewMockSettingsService: SettingsServiceProtocol, ObservableObject {
    @Published var calculationMethod: CalculationMethod = .muslimWorldLeague
    @Published var madhab: Madhab = .shafi
    @Published var useAstronomicalMaghrib: Bool = false
    @Published var notificationsEnabled: Bool = true
    @Published var notificationOffset: TimeInterval = 600
    @Published var userName: String = "Test User"
    @Published var timeFormat: TimeFormat = .twelveHour
    @Published var theme: ThemeMode = .dark
    @Published var hasCompletedOnboarding: Bool = false
    @Published var overrideBatteryOptimization: Bool = false
    @Published var showArabicSymbolInWidget: Bool = true
    @Published var liveActivitiesEnabled: Bool = true

    var enableNotifications: Bool {
        get { notificationsEnabled }
        set { notificationsEnabled = newValue }
    }
    
    func saveSettings() async throws {}
    func loadSettings() async throws {}
    func resetToDefaults() async throws {}
    func saveImmediately() async throws {}
    func saveOnboardingSettings() async throws {}
}
