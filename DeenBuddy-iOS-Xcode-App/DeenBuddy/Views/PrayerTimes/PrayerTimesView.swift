//
//  PrayerTimesView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-04.
//

import SwiftUI

/// Main view for displaying daily prayer times
struct PrayerTimesView: View {
    @StateObject private var viewModel: PrayerTimesViewModel
    
    init(container: DependencyContainer) {
        _viewModel = StateObject(wrappedValue: PrayerTimesViewModel(container: container))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Custom title with mascot
            MascotTitleView.homeTitle(titleText: "Prayer Times")
                .padding(.top)
            if viewModel.isLoading {
                ContextualLoadingView(context: .prayerTimes)
                    .padding()
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    
                    Text("Prayer Times Unavailable")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Show battery optimization warning if applicable
                    if ProcessInfo.processInfo.isLowPowerModeEnabled {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "battery.25")
                                    .foregroundColor(.orange)
                                Text("Low Power Mode Active")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            
                            Text("Location services are restricted due to Low Power Mode. Try disabling Low Power Mode or use the override setting.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Button("Try Again") {
                        Task {
                            await viewModel.fetchPrayerTimes()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                }
                .padding()
            } else if let prayerTimes = viewModel.prayerTimes {
                // Display prayer times
                VStack(spacing: 16) {
                    Text("Prayer Times")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Today - \(prayerTimes.date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 12) {
                        ForEach(prayerTimes.allPrayers, id: \.0) { prayerType, prayerTime in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(prayerType.displayName)
                                        .font(.headline)
                                    if let prayer = Prayer(rawValue: prayerType.rawValue.lowercased()) {
                                        Text("\(prayer.defaultRakahCount) rakahs")
                                            .font(.caption)
                                            .foregroundColor(ColorPalette.rakahText)
                                    }
                                }
                                Spacer()
                                Text(prayerTime.formatted(date: .omitted, time: .shortened))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding()
            } else {
                Text("No prayer times available")
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            Task {
                await viewModel.fetchPrayerTimes()
            }
        }
    }
}

// MARK: - Prayer Times Settings View

struct PrayerTimesSettingsView: View {
    @ObservedObject var viewModel: PrayerTimesViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                calculationMethodSection
                madhabSection
                timeFormatSection
                batteryOptimizationSection
                recommendationsSection
                resetSection
            }
            .navigationTitle("Prayer Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var calculationMethodSection: some View {
        Section("Calculation Method") {
            calculationMethodPicker
        }
    }
    
    private var calculationMethodPicker: some View {
        Picker("Method", selection: $viewModel.settingsService.calculationMethod) {
            ForEach(CalculationMethod.allCases) { method in
                VStack(alignment: .leading) {
                    Text(method.displayName)
                        .font(.body)
                    Text(method.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .tag(method)
            }
        }
        .pickerStyle(.navigationLink)
    }
    
    private var madhabSection: some View {
        Section("School of Thought (Madhab)") {
            madhabPicker
        }
    }
    
    private var madhabPicker: some View {
        Picker("Madhab", selection: $viewModel.settingsService.madhab) {
            ForEach(Madhab.allCases) { madhab in
                Text(madhab.displayName)
                    .tag(madhab)
            }
        }
        .pickerStyle(.navigationLink)
    }
    
    private var timeFormatSection: some View {
        Section("Time Format") {
            timeFormatPicker
        }
    }
    
    private var timeFormatPicker: some View {
        Picker("Format", selection: $viewModel.settingsService.timeFormat) {
            ForEach(TimeFormat.allCases) { format in
                HStack {
                    Text(format.displayName)
                    Spacer()
                    Text(format.example)
                        .foregroundColor(.secondary)
                }
                .tag(format)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var recommendationsSection: some View {
        Section("Recommendations") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Most calculation methods work globally. For best accuracy, choose based on your region's Islamic authority.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    private var batteryOptimizationSection: some View {
        Section("Battery Optimization") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Override Battery Optimization", isOn: $viewModel.settingsService.overrideBatteryOptimization)
                
                Text("When enabled, location services will work even when your device is in Low Power Mode. This may impact battery life.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    private var resetSection: some View {
        Section {
            Button("Reset to Defaults") {
                Task {
                    try? await viewModel.settingsService.resetToDefaults()
                }
            }
            .foregroundColor(.red)
        }
    }
}

// MARK: - Supporting Views

struct MosqueHeaderView: View {
    var body: some View {
        ZStack {
            // Mosque silhouette image placeholder
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.8),
                            Color.purple.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)

            // Mosque silhouette overlay
            VStack {
                Spacer()
                HStack(spacing: 20) {
                    // Minaret 1
                    Rectangle()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: 8, height: 60)

                    // Main dome
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: 80, height: 40)
                        .clipShape(Rectangle().offset(y: 20))

                    // Minaret 2
                    Rectangle()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: 8, height: 60)
                }
                .padding(.bottom, 20)
            }
        }
    }
}

struct ModernPrayerTimeRow: View {
    let prayerTime: PrayerTime
    let timeFormat: TimeFormat
    let isNext: Bool

    var body: some View {
        HStack {
            // Prayer name
            VStack(alignment: .leading, spacing: 2) {
                Text(prayerTime.prayer.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Text(prayerTime.prayer.arabicName)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Prayer time
            Text(prayerTime.time.formatted(date: .omitted, time: .shortened))
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(isNext ? .cyan : .white)

            // Next prayer indicator
            if isNext {
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 16)
        .background(
            isNext ? Color.cyan.opacity(0.1) : Color.clear
        )
    }
}

struct LocationInfoFooter: View {
    let locationName: String
    let onLocationTapped: () -> Void

    var body: some View {
        Button(action: onLocationTapped) {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundColor(.cyan)

                Text(locationName)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))

                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Color Extensions

extension Color {
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
}

#if DEBUG
@MainActor
private final class PreviewUserAccountService: UserAccountServiceProtocol {
    var currentUser: AccountUser? = AccountUser(uid: "preview-user", email: "preview@deenbuddy.app")

    func sendSignInLink(to email: String) async throws {}
    func isSignInWithEmailLink(_ url: URL) -> Bool { false }
    func signIn(withEmail email: String, linkURL: URL) async throws {}
    func createUser(email: String, password: String) async throws {}
    func signIn(email: String, password: String) async throws {}
    func sendPasswordResetEmail(to email: String) async throws {}
    func confirmPasswordReset(code: String, newPassword: String) async throws {}
    func signOut() async throws {}
    func deleteAccount() async throws {}
    func updateMarketingOptIn(_ enabled: Bool) async throws {}
    func syncSettingsSnapshot(_ snapshot: SettingsSnapshot) async throws {}
    func fetchSettingsSnapshot() async throws -> SettingsSnapshot? { nil }
}
#endif

// MARK: - Preview

#Preview {
    PrayerTimesView(container: DependencyContainer(
        locationService: MockLocationService(),
        apiClient: MockAPIClient(),
        notificationService: MockNotificationService(),
        prayerTimeService: MockPrayerTimeService(),
        settingsService: MockSettingsService(),
        prayerTrackingService: PrayerTrackingService(
            prayerTimeService: MockPrayerTimeService(),
            settingsService: MockSettingsService(),
            locationService: MockLocationService()
        ),
        prayerAnalyticsService: PrayerAnalyticsService(
            prayerTrackingService: PrayerTrackingService(
                prayerTimeService: MockPrayerTimeService(),
                settingsService: MockSettingsService(),
                locationService: MockLocationService()
            )
        ),
        prayerTrackingCoordinator: PrayerTrackingCoordinator(
            prayerTimeService: MockPrayerTimeService(),
            prayerTrackingService: PrayerTrackingService(
                prayerTimeService: MockPrayerTimeService(),
                settingsService: MockSettingsService(),
                locationService: MockLocationService()
            ),
            notificationService: MockNotificationService(),
            settingsService: MockSettingsService()
        ),
        tasbihService: TasbihService(),
        islamicCalendarService: IslamicCalendarService(),
        backgroundTaskManager: BackgroundTaskManager(),
        backgroundPrayerRefreshService: BackgroundPrayerRefreshService(
            prayerTimeService: MockPrayerTimeService(),
            locationService: MockLocationService()
        ),
        islamicCacheManager: IslamicCacheManager(),
        userAccountService: PreviewUserAccountService(),
        notificationScheduler: NotificationScheduler(
            notificationService: MockNotificationService(),
            prayerTimeService: MockPrayerTimeService(),
            settingsService: MockSettingsService()
        ),
        apiConfiguration: .default,
        isTestEnvironment: true
    ))
}
