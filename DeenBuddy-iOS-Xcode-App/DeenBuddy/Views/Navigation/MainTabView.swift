import SwiftUI
import UIKit

/// Main tab view for the app with enhanced settings integration
public struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @State private var activeTasbihSheet: TasbihSheet?
    private let coordinator: AppCoordinator
    
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
                    onSelectTab(1)
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
            TasbihScreenView(
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

// MARK: - Tasbih Screen Implementation

private struct TasbihScreenView<Service: TasbihServiceProtocol>: View {
    @StateObject private var viewModel: TasbihViewModel<Service>
    private let onShowHistory: () -> Void
    private let onShowSettings: () -> Void

    private var currentSession: TasbihSession? { viewModel.currentSession }
    private var currentDhikr: Dhikr? {
        if let session = currentSession { return session.dhikr }
        if let selected = viewModel.selectedDhikrID {
            return viewModel.availableDhikr.first { $0.id == selected }
        }
        return viewModel.availableDhikr.first
    }

    private var isCompleted: Bool {
        guard let session = currentSession else { return false }
        return session.isCompleted || viewModel.currentCount >= session.targetCount
    }

    private var progress: Double {
        guard let session = currentSession, session.targetCount > 0 else { return 0 }
        return min(Double(viewModel.currentCount) / Double(session.targetCount), 1.0)
    }

    private var formattedProgress: String {
        String(format: "%.0f%%", progress * 100)
    }

    private var sessionDurationText: String {
        guard let session = currentSession else { return "0s" }
        return formatDuration(session.totalDuration)
    }

    private var sessionRemainingText: String {
        let remaining: Int
        if let session = currentSession {
            remaining = session.remainingCount
        } else {
            remaining = max(0, viewModel.targetCount - viewModel.currentCount)
        }
        return remaining > 0 ? "\(remaining)" : "Complete"
    }

    private var countIncrement: Int {
        max(1, viewModel.service.currentCounter.countIncrement)
    }

    private var metricColumns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible())]
    }

    init(
        tasbihService: Service,
        onShowHistory: @escaping () -> Void,
        onShowSettings: @escaping () -> Void
    ) {
        self._viewModel = StateObject(wrappedValue: TasbihViewModel(service: tasbihService))
        self.onShowHistory = onShowHistory
        self.onShowSettings = onShowSettings
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    dhikrSelector
                    currentDhikrCard
                    counterCard
                    actionButtons
                    insightsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(ColorPalette.backgroundPrimary.ignoresSafeArea())

            if viewModel.service.isLoading || viewModel.isLoadingSelection {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ColorPalette.primary))
            }
        }
        .task { await viewModel.ensureSession() }
        .onChange(of: viewModel.currentSession?.id) { _ in
            viewModel.syncStateWithSession()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tasbih")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(ColorPalette.textPrimary)

                Text("Digital Dhikr Counter")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ColorPalette.textSecondary)
            }

            Spacer()

            HStack(spacing: 16) {
                Button(action: onShowHistory) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(ColorPalette.textPrimary)
                }
                .accessibilityLabel("Tasbih history")

                Button(action: onShowSettings) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(ColorPalette.textPrimary)
                }
                .accessibilityLabel("Tasbih settings")
            }
        }
    }

    private var dhikrSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Dhikr")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ColorPalette.textPrimary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                ForEach(viewModel.availableDhikr) { dhikr in
                    Button {
                        Task { await viewModel.changeDhikr(to: dhikr) }
                    } label: {
                        Text(dhikr.transliteration)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(tagBackground(for: dhikr))
                            .foregroundColor(tagForeground(for: dhikr))
                            .clipShape(Capsule())
                    }
                    .disabled(viewModel.isLoadingSelection)
                }
            }
        }
    }

    private var currentDhikrCard: some View {
        VStack(spacing: 12) {
            if let dhikr = currentDhikr {
                Text(dhikr.arabicText)
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(ColorPalette.textPrimary)

                Text(dhikr.transliteration)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ColorPalette.primary)

                Text(dhikr.translation)
                    .font(.system(size: 14))
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)

                if let reward = dhikr.reward, !reward.isEmpty {
                    infoRow(icon: "sparkles", text: reward)
                }

                if let source = dhikr.source, !source.isEmpty {
                    infoRow(icon: "book", text: source)
                }
            } else {
                Text("Select a dhikr to begin")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ColorPalette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(ColorPalette.surfacePrimary)
                .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 8)
        )
    }

    private var counterCard: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                metadataPill(icon: "number.square", title: "Remaining", value: sessionRemainingText)
                metadataPill(icon: "clock", title: "Duration", value: sessionDurationText)
            }

            HStack(alignment: .center) {
                Text("Current Count")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ColorPalette.textSecondary)
                Spacer()
                Text(formattedProgress)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ColorPalette.primary)
            }

            Text("\(viewModel.currentCount)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(isCompleted ? ColorPalette.primary : ColorPalette.textPrimary)

            targetAdjuster

            Text("Each tap adds +\(countIncrement)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ColorPalette.textSecondary)

            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: ColorPalette.primary))
                .animation(.easeInOut, value: viewModel.currentCount)

            if isCompleted {
                Text("Target completed—great work!")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ColorPalette.primary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(ColorPalette.surfacePrimary)
                .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 8)
        )
    }

    private var targetAdjuster: some View {
        HStack(spacing: 16) {
            adjustmentButton(icon: "minus") {
                Task { await adjustTarget(by: -1) }
            }

            VStack(spacing: 4) {
                Text("Target")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ColorPalette.textSecondary)

                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ColorPalette.primary)
                    Text("\(viewModel.targetCount)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(ColorPalette.textPrimary)
                }
            }

            adjustmentButton(icon: "plus") {
                Task { await adjustTarget(by: 1) }
            }
        }
    }

    private func adjustmentButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 36, height: 36)
                .background(ColorPalette.surfaceSecondary)
                .foregroundColor(ColorPalette.textPrimary)
                .clipShape(Circle())
        }
        .disabled(viewModel.service.isLoading || viewModel.isLoadingSelection)
    }

    private var insightsSection: some View {
        let stats = viewModel.statistics

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Progress")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ColorPalette.textPrimary)
                Spacer()
                if stats.totalSessions > 0 {
                    Text("Updated")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ColorPalette.textSecondary)
                }
            }

            LazyVGrid(columns: metricColumns, spacing: 12) {
                metricCard(
                    title: "Total Dhikr",
                    value: formatNumber(stats.totalDhikrCount)
                )

                metricCard(
                    title: "Completed",
                    value: formatNumber(stats.completedSessions)
                )

                metricCard(
                    title: "Completion Rate",
                    value: formatPercentage(stats.completionRate)
                )

                metricCard(
                    title: "Current Streak",
                    value: formatNumber(stats.currentStreak),
                    subtitle: stats.currentStreak == 1 ? "day" : "days"
                )

                metricCard(
                    title: "Avg / Day",
                    value: formatDailyAverage(stats.averageDailyCount)
                )

                metricCard(
                    title: "Total Time",
                    value: formatDuration(stats.totalDuration)
                )
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(ColorPalette.surfacePrimary)
                .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 6)
        )
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: {
                Task {
                    await viewModel.service.resetSession()
                    await viewModel.ensureSession()
                }
            }) {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ColorPalette.surfaceSecondary)
                    .foregroundColor(ColorPalette.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(viewModel.currentSession == nil && viewModel.currentCount == 0)

            if viewModel.currentCount > 0 {
                Button(action: {
                    Task {
                        await viewModel.completeSession()
                    }
                }) {
                    Label("Save Session", systemImage: "tray.full")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ColorPalette.primary.opacity(0.1))
                        .foregroundColor(ColorPalette.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            Button(action: {
                Task {
                    await viewModel.increment(by: countIncrement)
                }
            }) {
                Text("Tap to Count")
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ColorPalette.primary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .accessibilityLabel("Increment counter by \(countIncrement)")
        }
    }

    private func tagBackground(for dhikr: Dhikr) -> Color {
        let isSelected = dhikr.id == (currentDhikr?.id ?? viewModel.selectedDhikrID)
        return isSelected ? ColorPalette.primary : ColorPalette.surfaceSecondary
    }

    private func tagForeground(for dhikr: Dhikr) -> Color {
        let isSelected = dhikr.id == (currentDhikr?.id ?? viewModel.selectedDhikrID)
        return isSelected ? Color.white : ColorPalette.textPrimary
    }

    private func adjustTarget(by delta: Int) async {
        await viewModel.adjustTarget(by: delta)
    }


    private func metadataPill(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ColorPalette.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ColorPalette.textSecondary)
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ColorPalette.textPrimary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorPalette.surfaceSecondary)
        )
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ColorPalette.primary)
                .padding(.top, 2)

            Text(text)
                .font(.system(size: 13))
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricCard(title: String, value: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ColorPalette.textSecondary)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(ColorPalette.textPrimary)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ColorPalette.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(ColorPalette.surfaceSecondary)
        )
    }

    private func formatDuration(_ interval: TimeInterval) -> String { SharedUtilities.formatDuration(interval) }
    private func formatPercentage(_ value: Double) -> String { SharedUtilities.formatPercentage(value) }
    private func formatNumber(_ value: Int) -> String { SharedUtilities.formatNumber(value) }
    private func formatDailyAverage(_ value: Double) -> String { SharedUtilities.formatDailyAverage(value) }
}

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

                Section(footer: Text("Each tap currently adds +\(max(1, tasbihService.currentCounter.countIncrement)) beads.")) {
                    HStack {
                        Text("Active Counter")
                        Spacer()
                        Text(tasbihService.currentCounter.name)
                            .foregroundColor(ColorPalette.textSecondary)
                    }

                    if let target = tasbihService.currentSession?.targetCount {
                        HStack {
                            Text("Current Target")
                            Spacer()
                            Text("\(target)")
                                .foregroundColor(ColorPalette.textSecondary)
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
