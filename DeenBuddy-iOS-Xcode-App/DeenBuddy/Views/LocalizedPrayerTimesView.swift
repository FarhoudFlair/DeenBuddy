//
//  LocalizedPrayerTimesView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-09.
//

import SwiftUI

struct LocalizedPrayerTimesView: View {
    @StateObject private var localizationService = LocalizationService()
    @StateObject private var prayerTimeService = PrayerTimeService(
        locationService: LocationService(),
        settingsService: SettingsService(),
        apiClient: APIClient(),
        errorHandler: ErrorHandler(crashReporter: CrashReporter()),
        retryMechanism: RetryMechanism(networkMonitor: NetworkMonitor.shared),
        networkMonitor: NetworkMonitor.shared,
        islamicCacheManager: IslamicCacheManager(),
        islamicCalendarService: IslamicCalendarService()
    )
    @State private var showingLanguageSettings = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                ModernGradientBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Language and location header
                        languageLocationHeader
                        
                        // Current prayer status
                        if !prayerTimeService.todaysPrayerTimes.isEmpty {
                            currentPrayerCard()
                            
                            // Prayer times list
                            prayerTimesList()
                            
                            // Location info
                            locationInfoCard()
                        } else {
                            loadingOrErrorView
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await prayerTimeService.refreshPrayerTimes()
                }
            }
            .navigationTitle(localizationService.localizedString(for: .navPrayerTimes))
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingLanguageSettings = true
                    }) {
                        Image(systemName: "globe")
                            .foregroundColor(.cyan)
                    }
                }
            }
            .environment(\.localizationService, localizationService)
            .rtlAware(localizationService)
            .sheet(isPresented: $showingLanguageSettings) {
                LanguageSettingsView()
            }
            .task {
                await prayerTimeService.refreshPrayerTimes()
            }
        }
    }
    
    private var languageLocationHeader: some View {
        ModernCard {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizationService.currentLanguage.displayName)
                            .font(.headline)
                            .foregroundColor(.white)
                            .localizedFrameAlignment(localizationService)
                        
                        Text(localizationService.currentLanguage.region.displayName)
                            .font(.subheadline)
                            .foregroundColor(.cyan)
                            .localizedFrameAlignment(localizationService)
                    }
                    .localizedFrameAlignment(localizationService)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if localizationService.isRTL {
                            HStack {
                                Text("RTL")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Image(systemName: "arrow.right.to.line")
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Text(localizationService.currentLanguage.numberFormat.displayName)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                // Location info section temporarily disabled - no currentSchedule available
            }
            .padding()
        }
    }
    
    private func currentPrayerCard() -> some View {
        ModernCard {
            VStack(spacing: 16) {
                if let nextPrayer = prayerTimeService.nextPrayer {
                    nextPrayerInfo(nextPrayer)
                } else if let nextPrayer = prayerTimeService.nextPrayer {
                    nextPrayerInfo(nextPrayer)
                } else {
                    Text(localizationService.localizedString(for: "prayer.state.passed"))
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding()
        }
    }
    
    private func currentPrayerInfo(_ prayerTime: PrayerTime) -> some View {
        VStack(spacing: 12) {
            Text(localizationService.localizedString(for: "prayer.state.current"))
                .font(.caption)
                .foregroundColor(.cyan)
                .textCase(.uppercase)
                .tracking(1)
            
            Text(localizationService.localizedPrayerName(for: prayerTime.prayer))
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .localizedTextAlignment(localizationService)
            
            Text(localizationService.localizedTime(prayerTime.time))
                .font(.title2)
                .foregroundColor(.white.opacity(0.8))
                .localizedTextAlignment(localizationService)
        }
        .localizedFrameAlignment(localizationService)
    }
    
    private func nextPrayerInfo(_ prayerTime: PrayerTime) -> some View {
        VStack(spacing: 12) {
            Text(localizationService.localizedString(for: "prayer.state.upcoming"))
                .font(.caption)
                .foregroundColor(.orange)
                .textCase(.uppercase)
                .tracking(1)
            
            Text(localizationService.localizedPrayerName(for: prayerTime.prayer))
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .localizedTextAlignment(localizationService)
            
            Text(localizationService.localizedTime(prayerTime.time))
                .font(.title2)
                .foregroundColor(.white.opacity(0.8))
                .localizedTextAlignment(localizationService)
            
            // Time remaining
            if let timeRemaining = timeUntilPrayer(prayerTime.time) {
                Text(timeRemaining)
                    .font(.subheadline)
                    .foregroundColor(.cyan)
                    .localizedTextAlignment(localizationService)
            }
        }
        .localizedFrameAlignment(localizationService)
    }
    
    private func prayerTimesList() -> some View {
        ModernCard {
            VStack(spacing: 0) {
                HStack {
                    Text(localizationService.localizedString(for: .navPrayerTimes))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .localizedFrameAlignment(localizationService)
                    
                    Spacer()
                    
                    Text(localizationService.localizedDate(Date()))
                        .font(.subheadline)
                        .foregroundColor(.cyan)
                }
                .padding(.bottom, 16)
                
                ForEach(Array(prayerTimeService.todaysPrayerTimes.enumerated()), id: \.1.prayer) { index, prayerTime in
                    LocalizedPrayerTimeRow(
                        prayerTime: prayerTime,
                        localizationService: localizationService
                    )
                    
                    if index < prayerTimeService.todaysPrayerTimes.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding()
        }
    }
    
    private func locationInfoCard() -> some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(localizationService.localizedString(for: .settingsLocation))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .localizedFrameAlignment(localizationService)
                
                VStack(spacing: 8) {
                    LocationInfoRow(
                        title: localizationService.localizedString(for: "qibla.direction"),
                        value: String(format: "%.1f°", 45.0), // TODO: Get from Qibla service
                        localizationService: localizationService
                    )
                    
                    LocationInfoRow(
                        title: localizationService.localizedString(for: "settings.madhab"),
                        value: prayerTimeService.madhab.sectDisplayName,
                        localizationService: localizationService
                    )
                    
                    LocationInfoRow(
                        title: localizationService.localizedString(for: "calculation.method"),
                        value: prayerTimeService.calculationMethod.displayName,
                        localizationService: localizationService
                    )
                }
            }
            .padding()
        }
    }
    
    private var loadingOrErrorView: some View {
        ModernCard {
            VStack(spacing: 16) {
                if prayerTimeService.isLoading {
                    ModernContextualLoadingView(context: .prayerTimes)
                } else if let error = prayerTimeService.error {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundColor(.red)
                    
                    Text(error.localizedDescription)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .localizedTextAlignment(localizationService)
                    
                    Button(localizationService.localizedString(for: .actionRetry)) {
                        Task {
                            await prayerTimeService.refreshPrayerTimes()
                        }
                    }
                    .buttonStyle(PrimaryModernButtonStyle())
                }
            }
            .padding()
        }
    }
    
    private func timeUntilPrayer(_ prayerTime: Date) -> String? {
        let timeInterval = prayerTime.timeIntervalSinceNow
        guard timeInterval > 0 else { return nil }
        
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 0 {
            let hoursText = localizationService.localizedString(for: .timeHours)
            let minutesText = localizationService.localizedString(for: .timeMinutes)
            return "\(localizationService.localizedNumber(hours)) \(hoursText) \(localizationService.localizedNumber(minutes)) \(minutesText)"
        } else {
            let minutesText = localizationService.localizedString(for: .timeMinutes)
            return "\(localizationService.localizedNumber(minutes)) \(minutesText)"
        }
    }
}

struct LocalizedPrayerTimeRow: View {
    let prayerTime: PrayerTime
    let localizationService: LocalizationService
    
    var body: some View {
        HStack {
            // Prayer icon
            Image(systemName: prayerTime.prayer.systemImageName)
                .font(.title3)
                .foregroundColor(prayerTime.prayer.color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(localizationService.localizedPrayerName(for: prayerTime.prayer))
                    .font(.headline)
                    .foregroundColor(.white)
                    .localizedFrameAlignment(localizationService)

                HStack(spacing: 8) {
                    Text("\(prayerTime.prayer.defaultRakahCount) rakahs")
                        .font(.caption)
                        .foregroundColor(ColorPalette.rakahText)
                        .localizedFrameAlignment(localizationService)

                    if !statusText.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))

                        Text(statusText)
                            .font(.caption)
                            .foregroundColor(statusColor)
                            .localizedFrameAlignment(localizationService)
                    }
                }
            }
            .localizedFrameAlignment(localizationService)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(localizationService.localizedTime(prayerTime.time))
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                if let timeInfo = timeInfo {
                    Text(timeInfo)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusText: String {
        switch calculateStatus(for: prayerTime) {
        case .active:
            return localizationService.localizedString(for: .prayerStateCurrent)
        case .upcoming:
            return localizationService.localizedString(for: .prayerStateUpcoming)
        case .passed:
            return localizationService.localizedString(for: .prayerStatePassed)
        case .completed:
            return ""
        }
    }
    
    private func calculateStatus(for prayerTime: PrayerTime) -> PrayerStatus {
        let now = Date()
        let timeDiff = prayerTime.time.timeIntervalSince(now)
        
        if abs(timeDiff) < 30 * 60 { // Within 30 minutes
            return .active
        } else if timeDiff > 0 {
            return .upcoming
        } else {
            return .passed
        }
    }
    
    private var statusColor: Color {
        switch calculateStatus(for: prayerTime) {
        case .active: return .cyan
        case .upcoming: return .orange
        case .passed: return .white.opacity(0.5)
        case .completed: return .green
        }
    }
    
    private var timeInfo: String? {
        let now = Date()
        let timeInterval = abs(prayerTime.time.timeIntervalSince(now))
        
        guard timeInterval < 24 * 60 * 60 else { return nil } // Don't show for times more than 24h away
        
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if calculateStatus(for: prayerTime) == .upcoming && timeInterval > 0 {
            if hours > 0 {
                return "in \(localizationService.localizedNumber(hours))h \(localizationService.localizedNumber(minutes))m"
            } else {
                return "in \(localizationService.localizedNumber(minutes))m"
            }
        } else if calculateStatus(for: prayerTime) == .passed && timeInterval > 0 {
            if hours > 0 {
                return "\(localizationService.localizedNumber(hours))h \(localizationService.localizedNumber(minutes))m ago"
            } else {
                return "\(localizationService.localizedNumber(minutes))m ago"
            }
        }
        
        return nil
    }
}

struct LocationInfoRow: View {
    let title: String
    let value: String
    let localizationService: LocalizationService
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .localizedFrameAlignment(localizationService)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.cyan)
        }
    }
}

// MARK: - Preview
#Preview {
    LocalizedPrayerTimesView()
}
