//
//  LocalizedPrayerTimesView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-09.
//

import SwiftUI
import DeenAssistCore

struct LocalizedPrayerTimesView: View {
    @StateObject private var localizationService = LocalizationService()
    @StateObject private var prayerTimeService = PrayerTimeService()
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
                        if let schedule = prayerTimeService.currentSchedule {
                            currentPrayerCard(schedule: schedule)
                            
                            // Prayer times list
                            prayerTimesList(schedule: schedule)
                            
                            // Location info
                            locationInfoCard(schedule: schedule)
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
                
                if let location = prayerTimeService.currentSchedule?.location {
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.cyan)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            if let city = location.city {
                                Text(city)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .localizedFrameAlignment(localizationService)
                            }
                            
                            if let country = location.country {
                                Text(country)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                    .localizedFrameAlignment(localizationService)
                            }
                        }
                        .localizedFrameAlignment(localizationService)
                        
                        Spacer()
                        
                        Button(localizationService.localizedString(for: "settings.language")) {
                            showingLanguageSettings = true
                        }
                        .font(.caption)
                        .foregroundColor(.cyan)
                    }
                }
            }
            .padding()
        }
    }
    
    private func currentPrayerCard(schedule: PrayerSchedule) -> some View {
        ModernCard {
            VStack(spacing: 16) {
                if let currentPrayer = prayerTimeService.currentPrayer {
                    currentPrayerInfo(currentPrayer)
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
    
    private func prayerTimesList(schedule: PrayerSchedule) -> some View {
        ModernCard {
            VStack(spacing: 0) {
                HStack {
                    Text(localizationService.localizedString(for: .navPrayerTimes))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .localizedFrameAlignment(localizationService)
                    
                    Spacer()
                    
                    Text(localizationService.localizedDate(schedule.date))
                        .font(.subheadline)
                        .foregroundColor(.cyan)
                }
                .padding(.bottom, 16)
                
                ForEach(Array(schedule.prayerTimes.enumerated()), id: \.element.prayer) { index, prayerTime in
                    LocalizedPrayerTimeRow(
                        prayerTime: prayerTime,
                        localizationService: localizationService
                    )
                    
                    if index < schedule.prayerTimes.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding()
        }
    }
    
    private func locationInfoCard(schedule: PrayerSchedule) -> some View {
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
                        value: schedule.madhab.sectDisplayName,
                        localizationService: localizationService
                    )
                    
                    LocationInfoRow(
                        title: localizationService.localizedString(for: "calculation.method"),
                        value: schedule.calculationMethod.displayName,
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
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                        .scaleEffect(1.2)
                    
                    Text(localizationService.localizedString(for: "loading.prayer_times"))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
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
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)
                    .localizedFrameAlignment(localizationService)
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
        switch prayerTime.status {
        case .current:
            return localizationService.localizedString(for: .prayerStateCurrent)
        case .upcoming:
            return localizationService.localizedString(for: .prayerStateUpcoming)
        case .passed:
            return localizationService.localizedString(for: .prayerStatePassed)
        }
    }
    
    private var statusColor: Color {
        switch prayerTime.status {
        case .current: return .cyan
        case .upcoming: return .orange
        case .passed: return .white.opacity(0.5)
        }
    }
    
    private var timeInfo: String? {
        let now = Date()
        let timeInterval = abs(prayerTime.time.timeIntervalSince(now))
        
        guard timeInterval < 24 * 60 * 60 else { return nil } // Don't show for times more than 24h away
        
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if prayerTime.status == .upcoming && timeInterval > 0 {
            if hours > 0 {
                return "in \(localizationService.localizedNumber(hours))h \(localizationService.localizedNumber(minutes))m"
            } else {
                return "in \(localizationService.localizedNumber(minutes))m"
            }
        } else if prayerTime.status == .passed && timeInterval > 0 {
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