import SwiftUI
import Combine

/// Detailed notification settings view
public struct NotificationSettingsView: View {
    @ObservedObject private var settingsService: SettingsService
    private let onDismiss: () -> Void

    @State private var selectedOffset: TimeInterval

    private let offsetOptions: [(String, TimeInterval)] = [
        ("5 minutes", 5 * 60),
        ("10 minutes", 10 * 60),
        ("15 minutes", 15 * 60),
        ("20 minutes", 20 * 60),
        ("30 minutes", 30 * 60)
    ]

    public init(
        settingsService: SettingsService,
        onDismiss: @escaping () -> Void
    ) {
        self._settingsService = ObservedObject(wrappedValue: settingsService)
        self.onDismiss = onDismiss
        self._selectedOffset = State(initialValue: settingsService.notificationOffset)
    }
    
    public var body: some View {
        NavigationView {
            List {
                Section("Notification Timing") {
                    ForEach(offsetOptions, id: \.1) { option in
                        HStack {
                            Text(option.0)
                                .bodyMedium()
                                .foregroundColor(ColorPalette.textPrimary)
                            
                            Spacer()
                            
                            if selectedOffset == option.1 {
                                Image(systemName: "checkmark")
                                    .foregroundColor(ColorPalette.primary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Add haptic feedback for immediate user response
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            
                            // Update state synchronously first
                            selectedOffset = option.1
                            
                            // Then update the service (this triggers async save)
                            settingsService.notificationOffset = option.1
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(selectedOffset == option.1 ? Color.blue.opacity(0.1) : Color.clear)
                        .animation(.easeInOut(duration: 0.2), value: selectedOffset)
                    }
                }
                
                Section {
                    Text("Choose how many minutes before each prayer time you'd like to receive a notification.")
                        .bodySmall()
                        .foregroundColor(ColorPalette.textSecondary)
                        .lineLimit(nil) // Allow unlimited lines to prevent truncation
                        .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion
                }
            }
            .navigationTitle("Notification Settings")
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

#Preview {
    NotificationSettingsView(
        settingsService: SettingsService(),
        onDismiss: {}
    )
}

// Mock for preview
private class NotificationPreviewMockSettingsService: SettingsServiceProtocol, ObservableObject {
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
    @Published var enableIslamicPatterns: Bool = false
    @Published var maxLookaheadMonths: Int = 12
    @Published var useRamadanIshaOffset: Bool = false
    @Published var showLongRangePrecision: Bool = true

    var enableNotifications: Bool {
        get { notificationsEnabled }
        set { notificationsEnabled = newValue }
    }

    var notificationsEnabledPublisher: AnyPublisher<Bool, Never> {
        $notificationsEnabled.eraseToAnyPublisher()
    }

    var notificationOffsetPublisher: AnyPublisher<TimeInterval, Never> {
        $notificationOffset.eraseToAnyPublisher()
    }
    
    func saveSettings() async throws {}
    func loadSettings() async throws {}
    func resetToDefaults() async throws {}
    func saveImmediately() async throws {}
    func saveOnboardingSettings() async throws {}
    func applySnapshot(_ snapshot: SettingsSnapshot) async throws {
        calculationMethod = CalculationMethod(rawValue: snapshot.calculationMethod) ?? calculationMethod
        madhab = Madhab(rawValue: snapshot.madhab) ?? madhab
        timeFormat = TimeFormat(rawValue: snapshot.timeFormat) ?? timeFormat
        notificationsEnabled = snapshot.notificationsEnabled
        notificationOffset = snapshot.notificationOffset
        liveActivitiesEnabled = snapshot.liveActivitiesEnabled
        showArabicSymbolInWidget = snapshot.showArabicSymbolInWidget
        maxLookaheadMonths = snapshot.maxLookaheadMonths
        useRamadanIshaOffset = snapshot.useRamadanIshaOffset
        showLongRangePrecision = snapshot.showLongRangePrecision
        userName = snapshot.userName
        hasCompletedOnboarding = snapshot.hasCompletedOnboarding
    }
}
