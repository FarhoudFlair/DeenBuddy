import SwiftUI
import UIKit

/// Main tab view for the app with enhanced settings integration
public struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @State private var activeTasbihSheet: TasbihSheet?
    @ObservedObject private var coordinator: AppCoordinator
    
    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            // 1. Home Tab - Prayer times and main dashboard
            MainAppView(
                coordinator: coordinator,
                onSelectTab: { index in selectedTab = index }
            )
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)

            // 2. Prayer Tracking Tab - direct access to progress
            PrayerTrackingScreen(
                prayerTrackingService: coordinator.prayerTrackingService,
                prayerTimeService: coordinator.prayerTimeService,
                notificationService: coordinator.notificationService,
                prayerAnalyticsService: coordinator.prayerAnalyticsService,
                onDismiss: { } // No dismiss needed in tab mode
            )
            .tabItem {
                Image(systemName: "checkmark.circle.fill")
                Text("Tracking")
            }
            .tag(1)

            // 3. Quran Tab - access to Quran search and reading
            QuranSearchView()
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("Quran")
                }
                .tag(2)

            // 4. Tasbih Tab - Digital dhikr counter
            tasbihTab
                .tag(3)
            
            // 5. Settings Tab - Enhanced settings view with profile section
            Group {
                if let settingsService = coordinator.settingsService as? SettingsService {
                    VStack(spacing: 0) {
                        EnhancedSettingsView(
                            settingsService: settingsService,
                            themeManager: coordinator.themeManager,
                            notificationService: coordinator.notificationService,
                            onDismiss: { } // No dismiss needed in tab mode
                        )

                        // Upgrade to Premium button
                        Button {
                            coordinator.showPaywall()
                        } label: {
                            HStack {
                                Image(systemName: "crown.fill")
                                Text("Upgrade to Premium")
                                Spacer()
                            }
                            .padding()
                            .foregroundColor(.orange)
                            .font(.headline)
                            .background(Color(.systemGray6))
                        }
                    }
                } else {
                    // Fallback view in case of cast failure
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Settings Unavailable")
                            .font(.headline)
                        Text("Unable to load settings service")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(4)
        }
        .accentColor(ColorPalette.primary)
        .themed(with: coordinator.themeManager)
        .sheet(isPresented: $coordinator.showingIslamicCalendar) {
            IslamicCalendarScreen(
                prayerTimeService: coordinator.prayerTimeService,
                islamicCalendarService: coordinator.islamicCalendarService,
                locationService: coordinator.locationService,
                settingsService: coordinator.settingsService,
                onDismiss: {
                    coordinator.dismissIslamicCalendar()
                },
                onSettingsTapped: {
                    coordinator.dismissIslamicCalendar()
                    coordinator.showSettings()
                }
            )
        }
    }
}

/// Main app view wrapper for the home tab
private struct MainAppView: View {
    @ObservedObject var coordinator: AppCoordinator
    let onSelectTab: (Int) -> Void
    
    var body: some View {
        ZStack {
            HomeScreen(
                prayerTimeService: coordinator.prayerTimeService,
                locationService: coordinator.locationService,
                settingsService: coordinator.settingsService,
                prayerTrackingService: coordinator.prayerTrackingService,
                onCompassTapped: {
                    coordinator.showCompass()
                },
                onGuidesTapped: { }, // No direct action needed here
                onQuranSearchTapped: {
                    onSelectTab(2)
                },
                onSettingsTapped: {
                    coordinator.showSettings()
                },
                onTasbihTapped: {
                    onSelectTab(3)
                },
                onCalendarTapped: {
                    coordinator.showIslamicCalendar()
                }
            )

            // Loading overlay
            if coordinator.isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    LoadingView.spinner(message: "Loading...")
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(ColorPalette.backgroundSecondary)
                        )
                }
            }
        }
        // AR compass fullScreenCover removed - AR feature disabled
        .errorAlert()
        .themed(with: coordinator.themeManager)
        .sheet(isPresented: $coordinator.showingCompass) {
            QiblaCompassScreen(
                locationService: coordinator.locationService,
                onDismiss: {
                    coordinator.dismissCompass()
                }
            )
        }
        .sheet(isPresented: $coordinator.showingPaywall) {
            SubscriptionPaywallView(coordinator: coordinator)
        }
        .sheet(isPresented: $coordinator.showingSettings) {
            if let settingsService = coordinator.settingsService as? SettingsService {
                NavigationView {
                    EnhancedSettingsView(
                        settingsService: settingsService,
                        themeManager: coordinator.themeManager,
                        notificationService: coordinator.notificationService,
                        onDismiss: {
                            coordinator.dismissSettings()
                        }
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                coordinator.dismissSettings()
                            }
                        }
                    }
                }
            } else {
                NavigationView {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Settings unavailable")
                            .font(.headline)
                        Text("Unable to load settings service")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button("Close") {
                            coordinator.dismissSettings()
                        }
                    }
                    .padding()
                    .navigationTitle("Settings")
                }
            }
        }
    }
}

private enum TasbihSheet: Identifiable {
    case history
    case preferences

    var id: String {
        switch self {
        case .history: return "history"
        case .preferences: return "preferences"
        }
    }
}

extension MainTabView {
    @ViewBuilder
    private var tasbihTab: some View {
        if let tasbihService = coordinator.tasbihService as? TasbihService {
            TasbihView(
                tasbihService: tasbihService,
                onShowHistory: {
                    activeTasbihSheet = .history
                },
                onShowSettings: {
                    activeTasbihSheet = .preferences
                }
            )
            .sheet(item: $activeTasbihSheet) { sheet in
                switch sheet {
                case .history:
                    TasbihHistoryView(tasbihService: tasbihService)
                case .preferences:
                    TasbihPreferencesView(tasbihService: tasbihService)
                }
            }
            .tabItem {
                Image(systemName: SymbolLibrary.tasbih)
                Text("Tasbih")
            }
        } else {
            TasbihUnavailableView()
                .tabItem {
                    Image(systemName: SymbolLibrary.tasbih)
                    Text("Tasbih")
                }
        }
    }
}

private let tasbihHistoryDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()



private struct TasbihHistoryView<Service: TasbihServiceProtocol>: View {
    @ObservedObject var tasbihService: Service
    @Environment(\.dismiss) private var dismiss

    private var sessions: [TasbihSession] {
        tasbihService.recentSessions.sorted { $0.startTime > $1.startTime }
    }

    private var statistics: TasbihStatistics {
        tasbihService.statistics
    }

    init(tasbihService: Service) {
        self._tasbihService = ObservedObject(wrappedValue: tasbihService)
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundColor(ColorPalette.primary)
                        Text("No Sessions Yet")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(ColorPalette.textPrimary)
                        Text("Start a tasbih session to see your progress history here.")
                            .font(.system(size: 14))
                            .foregroundColor(ColorPalette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ColorPalette.backgroundPrimary)
                } else {
                    List {
                        Section("Overview") {
                            historySummary
                                .listRowBackground(ColorPalette.surfacePrimary)
                        }

                        Section("Recent Sessions") {
                            ForEach(sessions) { session in
                                historyRow(for: session)
                                    .listRowBackground(ColorPalette.surfacePrimary)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Tasbih History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .background(ColorPalette.backgroundPrimary.ignoresSafeArea())
        }
    }

    private var historySummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                summaryMetric(title: "Total Sessions", value: formatNumber(statistics.totalSessions))
                summaryMetric(title: "Completed", value: formatNumber(statistics.completedSessions))
                summaryMetric(title: "Dhikr Count", value: formatNumber(statistics.totalDhikrCount))
                summaryMetric(title: "Completion Rate", value: formatPercentage(statistics.completionRate))
            }

            if statistics.averageDailyCount > 0 {
                Text("Average \(formatDailyAverage(statistics.averageDailyCount)) dhikr per day")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ColorPalette.textSecondary)
            }
        }
        .padding(.vertical, 8)
    }

    private func historyRow(for session: TasbihSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.dhikr.transliteration)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ColorPalette.textPrimary)
                Spacer()
                statusBadge(for: session)
            }

            if !session.dhikr.translation.isEmpty {
                Text(session.dhikr.translation)
                    .font(.system(size: 12))
                    .foregroundColor(ColorPalette.textSecondary)
            }

            HStack(spacing: 16) {
                Label("\(session.currentCount)/\(session.targetCount)", systemImage: "number")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ColorPalette.textSecondary)

                Label(formatDuration(session.totalDuration), systemImage: "timer")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ColorPalette.textSecondary)
            }

            Text(format(date: session.startTime))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(ColorPalette.textSecondary)
        }
        .padding(.vertical, 6)
    }

    private func statusBadge(for session: TasbihSession) -> some View {
        Text(session.isCompleted ? "Completed" : "In Progress")
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(session.isCompleted ? ColorPalette.primary.opacity(0.15) : ColorPalette.surfaceSecondary)
            )
            .foregroundColor(session.isCompleted ? ColorPalette.primary : ColorPalette.textSecondary)
    }

    private func summaryMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ColorPalette.textSecondary)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ColorPalette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorPalette.surfaceSecondary)
        )
    }


    private func format(date: Date) -> String {
        tasbihHistoryDateFormatter.string(from: date)
    }

    private func formatDuration(_ interval: TimeInterval) -> String { SharedUtilities.formatDuration(interval) }
    private func formatNumber(_ value: Int) -> String { SharedUtilities.formatNumber(value) }
    private func formatPercentage(_ value: Double) -> String { SharedUtilities.formatPercentage(value) }
    private func formatDailyAverage(_ value: Double) -> String { SharedUtilities.formatDailyAverage(value) }
}

private struct TasbihPreferencesView<Service: TasbihServiceProtocol>: View {
    @ObservedObject var tasbihService: Service
    @Environment(\.dismiss) private var dismiss

    @State private var hapticsEnabled = true
    @State private var soundEnabled = false
    @State private var selectedPattern: VibrationPattern = .light

    init(tasbihService: Service) {
        self._tasbihService = ObservedObject(wrappedValue: tasbihService)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Feedback")) {
                    Toggle("Haptic Feedback", isOn: $hapticsEnabled)
                        .onChange(of: hapticsEnabled) { newValue in
                            guard tasbihService.currentCounter.hapticFeedback != newValue else { return }
                            Task { await tasbihService.setHapticFeedback(newValue) }
                        }

                    Toggle("Sound Effects", isOn: $soundEnabled)
                        .onChange(of: soundEnabled) { newValue in
                            guard tasbihService.currentCounter.soundFeedback != newValue else { return }
                            Task { await tasbihService.setSoundFeedback(newValue) }
                        }

                    Picker("Vibration Pattern", selection: $selectedPattern) {
                        ForEach(VibrationPattern.allCases, id: \.self) { pattern in
                            Text(pattern.displayName)
                                .tag(pattern)
                        }
                    }
                    .onChange(of: selectedPattern) { newValue in
                        guard tasbihService.currentCounter.vibrationPattern != newValue else { return }
                        Task { await tasbihService.setVibrationPattern(newValue) }
                    }
                }

                Section(header: Text("Configuration"), footer: Text("Each tap adds +\(max(1, tasbihService.currentCounter.countIncrement)) beads.")) {
                    Picker("Active Counter", selection: Binding(
                        get: { tasbihService.currentCounter.id },
                        set: { newId in
                            if let counter = tasbihService.availableCounters.first(where: { $0.id == newId }) {
                                Task { await tasbihService.setActiveCounter(counter) }
                            }
                        }
                    )) {
                        ForEach(tasbihService.availableCounters) { counter in
                            Text(counter.name).tag(counter.id)
                        }
                    }
                    
                    if let session = tasbihService.currentSession {
                        VStack(alignment: .leading) {
                            Stepper("Target Count: \(session.targetCount)", value: Binding(
                                get: { session.targetCount },
                                set: { newValue in
                                    Task { await tasbihService.updateTargetCount(newValue) }
                                }
                            ), in: 1...9999)
                            
                            // Quick presets
                            HStack {
                                Text("Presets:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("33") {
                                    Task { await tasbihService.updateTargetCount(33) }
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                                
                                Button("99") {
                                    Task { await tasbihService.updateTargetCount(99) }
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                                
                                Button("100") {
                                    Task { await tasbihService.updateTargetCount(100) }
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }
            .navigationTitle("Tasbih Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { syncWithService() }
            .onChange(of: tasbihService.currentCounter) { _ in
                syncWithService()
            }
        }
    }

    private func syncWithService() {
        hapticsEnabled = tasbihService.currentCounter.hapticFeedback
        soundEnabled = tasbihService.currentCounter.soundFeedback
        selectedPattern = tasbihService.currentCounter.vibrationPattern
    }
}

private struct TasbihUnavailableView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: SymbolLibrary.tasbih)
                .font(.system(size: 28))
                .foregroundColor(ColorPalette.textSecondary)
            Text("Tasbih Unavailable")
                .font(.headline)
                .foregroundColor(ColorPalette.textPrimary)
            Text("Tasbih service is not configured for this build")
                .font(.caption)
                .foregroundColor(ColorPalette.textSecondary)
        }
    }
}

private enum SymbolLibrary {
    static var tasbih: String {
        if UIImage(systemName: "rosary") != nil {
            return "rosary"
        }
        return "hands.sparkles"
    }
}

#Preview {
    MainTabView(coordinator: AppCoordinator.mock())
}
