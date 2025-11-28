import SwiftUI
import CoreLocation
import UIKit
import Combine

/// Main home screen of the app
public struct HomeScreen: View {
    private let prayerTimeService: any PrayerTimeServiceProtocol
    private let locationService: any LocationServiceProtocol
    private let settingsService: any SettingsServiceProtocol
    private let prayerTrackingService: (any PrayerTrackingServiceProtocol)?
    let onCompassTapped: () -> Void
    let onGuidesTapped: () -> Void
    let onQuranSearchTapped: () -> Void
    let onSettingsTapped: () -> Void
    let onTasbihTapped: (() -> Void)?
    let onCalendarTapped: (() -> Void)?

    @State private var isRefreshing = false
    @State private var showLocationDiagnostic = false
    @State private var currentDate = Date()
    @State private var dailyProgress: DailyPrayerProgress?
    @State private var weeklyProgress: WeeklyPrayerProgress?
    @State private var completedPrayers: Set<Prayer> = []
    @State private var isUpdatingPrayers: Set<Prayer> = []
    @State private var todaysCompletedCount = 0
    @State private var currentStreakCount = 0
    @State private var prayerTimeUpdateTick = 0
    @State private var locationUpdateTick = 0
    @State private var resolvedLocationDisplay: String?
    @State private var isResolvingLocationName = false
    @State private var hasAppeared = false
    @StateObject private var timerManager = CountdownTimerManager()

    private let timeUpdateTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private let scheduleColumns: [GridItem] = [
        GridItem(.flexible(minimum: 120), alignment: .leading),
        GridItem(.fixed(80), alignment: .trailing),
        GridItem(.fixed(40), alignment: .trailing)
    ]

    public init(
        prayerTimeService: any PrayerTimeServiceProtocol,
        locationService: any LocationServiceProtocol,
        settingsService: any SettingsServiceProtocol,
        prayerTrackingService: (any PrayerTrackingServiceProtocol)? = nil,
        onCompassTapped: @escaping () -> Void,
        onGuidesTapped: @escaping () -> Void,
        onQuranSearchTapped: @escaping () -> Void,
        onSettingsTapped: @escaping () -> Void,
        onTasbihTapped: (() -> Void)? = nil,
        onCalendarTapped: (() -> Void)? = nil
    ) {
        self.prayerTimeService = prayerTimeService
        self.locationService = locationService
        self.settingsService = settingsService
        self.prayerTrackingService = prayerTrackingService
        self.onCompassTapped = onCompassTapped
        self.onGuidesTapped = onGuidesTapped
        self.onQuranSearchTapped = onQuranSearchTapped
        self.onSettingsTapped = onSettingsTapped
        self.onTasbihTapped = onTasbihTapped
        self.onCalendarTapped = onCalendarTapped
    }

    // MARK: - Environment & Computed Properties

    @Environment(\.currentTheme) private var currentTheme
    @Environment(\.colorScheme) private var colorScheme

    private var themeColors: ThemeAwareColorPalette {
        ThemeAwareColorPalette(theme: currentTheme)
    }

    private var premiumTokens: PremiumDesignTokens {
        PremiumDesignTokens(theme: currentTheme, colorScheme: colorScheme)
    }

    private var calculatedTimeRemaining: TimeInterval? {
        guard let nextPrayer = prayerTimeService.nextPrayer else { return nil }
        let remaining = nextPrayer.time.timeIntervalSince(timerManager.currentTime)
        return remaining > 0 ? remaining : nil
    }

    private var isImminent: Bool {
        guard let interval = calculatedTimeRemaining else { return false }
        return interval < 300 // Less than 5 minutes
    }

    private static let prayerTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale.autoupdatingCurrent
        return formatter
    }()

    private func formatTimeRemaining(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 48) {
                    headerView
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                        .appAnimation(AppAnimations.staggeredEntry(delay: 0.0), value: hasAppeared)

                    quickActionsSection
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                        .appAnimation(AppAnimations.staggeredEntry(delay: 0.1), value: hasAppeared)

                    prayerTimesSection
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                        .appAnimation(AppAnimations.staggeredEntry(delay: 0.2), value: hasAppeared)

                    dashboardSummarySection
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                        .appAnimation(AppAnimations.staggeredEntry(delay: 0.3), value: hasAppeared)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .background(
                ZStack {
                    ColorPalette.backgroundPrimary
                    ConditionalIslamicPatternOverlay(enabled: settingsService.enableIslamicPatterns)
                }
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                await refreshPrayerTimes()
            }
            .task {
                await requestLocationAndRefreshPrayers()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                Task {
                    await requestLocationAndRefreshPrayers()
                }
            }
            .onReceive(timeUpdateTimer) { date in
                currentDate = date
            }
            .onReceive(trackingUpdatePublisher ?? Empty<Void, Never>().eraseToAnyPublisher()) { _ in
                Task { await loadTrackingData() }
            }
            .onReceive(prayerTimeUpdatePublisher ?? Empty<Void, Never>().eraseToAnyPublisher()) { _ in
                prayerTimeUpdateTick += 1
            }
            .onReceive(locationUpdatePublisher ?? Empty<Void, Never>().eraseToAnyPublisher()) { _ in
                locationUpdateTick += 1
                Task { await updateResolvedLocationDisplay(force: true) }
            }
        }
        .onAppear {
            hasAppeared = true
            Task { await updateResolvedLocationDisplay(force: true) }
        }
        .overlay(
            // Location diagnostic popup
            Group {
                if showLocationDiagnostic, let location = locationService.currentLocation {
                    LocationDiagnosticPopup(
                        location: location,
                        locationService: locationService,
                        isPresented: $showLocationDiagnostic
                    )
                }
            }
        )
        .onChange(of: locationService.currentLocationInfo) { _ in
            Task {
                await updateResolvedLocationDisplay(force: false)
                await loadTrackingData()
            }
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Top Navigation Bar
            HStack(alignment: .center, spacing: 12) {
                MascotTitleView.navigationTitle(titleText: "DeenBuddy")
                    .accessibilityHidden(true)

                Spacer(minLength: 0)

                Button(action: {
                    onSettingsTapped()
                }) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundColor(ColorPalette.textSecondary)
                }
                .accessibilityLabel("Open settings")
            }

            // PRAYER INFO FIRST (most prominent) - Progressive Disclosure Design
            if let nextPrayer = prayerTimeService.nextPrayer {
                VStack(alignment: .leading, spacing: 12) {
                    // Prayer name as HERO element
                    Text("\(nextPrayer.prayer.displayName) Prayer")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(themeColors.primary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)

                    // Prayer time and countdown on same line
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(Self.prayerTimeFormatter.string(from: nextPrayer.time))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(ColorPalette.textPrimary)
                            .monospacedDigit()

                        if let timeRemaining = calculatedTimeRemaining {
                            Text("•")
                                .foregroundColor(ColorPalette.textSecondary)
                                .font(.system(size: 24))

                            Text("in \(formatTimeRemaining(timeRemaining))")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(premiumTokens.countdownGradient)
                                .appAnimation(AppAnimations.timerUpdate, value: formatTimeRemaining(timeRemaining))
                        }
                    }
                    .scaleEffect(isImminent ? 1.02 : 1.0)
                    .appAnimation(
                        isImminent ?
                        Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                        AppAnimations.smooth,
                        value: isImminent
                    )
                }
            }

            // CURRENT TIME CAPSULE (secondary, clearly labeled)
            HStack(spacing: 8) {
                Text("Current time:")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ColorPalette.textSecondary)

                Text(formattedTimeString)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(ColorPalette.textPrimary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(themeColors.surfaceSecondary.opacity(0.6))
            )

            // Greeting and location
            VStack(alignment: .leading, spacing: 8) {
                Text(greetingText)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(ColorPalette.textSecondary)

                // Location badge - refined design
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .foregroundColor(themeColors.primary.opacity(0.8))
                        .font(.system(size: 11))

                    if let location = locationService.currentLocation {
                        Text(displayLocationText(for: location))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ColorPalette.textSecondary)

                        Button(action: { showLocationDiagnostic = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                                .foregroundColor(ColorPalette.textSecondary.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("View location details")
                    } else {
                        Text(locationStatusText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(locationStatusColor)
                    }

                    if locationService.isUpdatingLocation || isRefreshing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ColorPalette.primary))
                            .scaleEffect(0.6)
                    } else if locationService.currentLocation == nil {
                        Button(action: {
                            Task { await requestLocationAndRefreshPrayers() }
                        }) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundColor(ColorPalette.primary)
                                .font(.caption)
                        }
                        .accessibilityLabel("Refresh location")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(themeColors.primary.opacity(0.08))
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onReceive(timerManager.$currentTime) { _ in
            // Trigger UI updates when timer ticks
        }
        .onAppear {
            timerManager.startTimer()
        }
        .onDisappear {
            timerManager.stopTimer()
        }
    }
    
    @ViewBuilder
    private var prayerTimesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center) {
                Text("Today's Timeline")
                    .headlineSmall()
                    .foregroundColor(ColorPalette.textPrimary)

                Spacer()

                if prayerTimeService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ColorPalette.primary))
                        .scaleEffect(0.8)
                }
            }

            if prayerTimeService.todaysPrayerTimes.isEmpty && !prayerTimeService.isLoading {
                EmptyPrayerTimesView(
                    locationService: locationService,
                    onLocationRequest: {
                        if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                await MainActor.run {
                                    UIApplication.shared.open(settingsUrl)
                                }
                            }
                        } else {
                            await requestLocationAndRefreshPrayers()
                        }
                    }
                )
                .frame(maxWidth: .infinity)
            } else {
                let prayers = prayerTimeService.todaysPrayerTimes
                let nextPrayerInstance = prayerTimeService.nextPrayer

                VStack(spacing: 0) {
                    ForEach(Array(prayers.enumerated()), id: \.element.prayer) { index, prayerTime in
                        let isNext = {
                            guard let nextPrayerInstance else { return false }
                            return prayerTime.prayer == nextPrayerInstance.prayer &&
                                Calendar.current.isDate(prayerTime.time, equalTo: nextPrayerInstance.time, toGranularity: .minute)
                        }()
                        
                        let isLast = index == prayers.count - 1

                        PrayerTimelineRow(
                            prayer: prayerTime,
                            status: getPrayerStatus(for: prayerTime),
                            isNext: isNext,
                            isLast: isLast,
                            isCompleted: completedPrayers.contains(prayerTime.prayer),
                            isProcessing: isUpdatingPrayers.contains(prayerTime.prayer),
                            toggle: { togglePrayer(prayerTime.prayer) }
                        )
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PremiumDesignTokens.cornerRadius24)
                .fill(ColorPalette.surfacePrimary)
        )
        .premiumShadow(.level2)
    }

    @ViewBuilder
    private var dashboardSummarySection: some View {
        VStack(spacing: 16) {
            if prayerTrackingService != nil {
                WeeklyProgressCard(
                    progress: weeklyProgress,
                    todaysCompleted: todaysCompletedCount,
                    streakCount: currentStreakCount
                )
            }

            IslamicCalendarCard(currentDate: currentDate)
        }
    }
    
    private var greetingText: String {
        if !settingsService.userName.isEmpty {
            return "Assalamu Alaykum, \(settingsService.userName)"
        }
        return "Assalamu Alaykum"
    }

    private var formattedTimeString: String {
        Self.timeFormatter.string(from: currentDate)
    }

    private var formattedDateLine: String {
        Self.gregorianDateFormatter.string(from: currentDate)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale.autoupdatingCurrent
        return formatter
    }()

    private static let gregorianDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale.autoupdatingCurrent
        return formatter
    }()

    private var trackingUpdatePublisher: AnyPublisher<Void, Never>? {
        guard let service = prayerTrackingService else {
            return nil
        }
        // Safely cast objectWillChange and map to Void to ensure type safety
        return (service.objectWillChange as? ObservableObjectPublisher)?
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    private var prayerTimeUpdatePublisher: AnyPublisher<Void, Never>? {
        // Safely cast objectWillChange and map to Void to ensure type safety
        return (prayerTimeService.objectWillChange as? ObservableObjectPublisher)?
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    private var locationUpdatePublisher: AnyPublisher<Void, Never>? {
        // Safely cast objectWillChange and map to Void to ensure type safety
        return (locationService.objectWillChange as? ObservableObjectPublisher)?
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    @ViewBuilder
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .headlineSmall()
                .foregroundColor(ColorPalette.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ActionCard(
                    icon: "safari.fill",
                    title: "Qibla",
                    subtitle: "Find direction",
                    actionType: .qibla,
                    action: {
                        onCompassTapped()
                    }
                )

                ActionCard(
                    icon: SymbolLibrary.tasbih,
                    title: "Tasbih",
                    subtitle: onTasbihTapped != nil ? "Digital beads" : "Coming soon",
                    actionType: .tasbih,
                    action: {
                        onTasbihTapped?()
                    }
                )
                .disabled(onTasbihTapped == nil)
                .opacity(onTasbihTapped == nil ? 0.5 : 1.0)

                ActionCard(
                    icon: "calendar",
                    title: "Calendar",
                    subtitle: onCalendarTapped != nil ? "Plan prayers" : "Coming soon",
                    actionType: .calendar,
                    action: {
                        onCalendarTapped?()
                    }
                )
                .disabled(onCalendarTapped == nil)
                .opacity(onCalendarTapped == nil ? 0.5 : 1.0)
            }
        }
    }

    private var locationStatusText: String {
        switch locationService.authorizationStatus {
        case .notDetermined:
            return "Tap to enable location"
        case .denied, .restricted:
            return "Location access denied"
        case .authorizedWhenInUse, .authorizedAlways:
            return "Getting location..."
        @unknown default:
            return "Location not available"
        }
    }

    private var locationStatusColor: Color {
        switch locationService.authorizationStatus {
        case .notDetermined:
            return ColorPalette.primary
        case .denied, .restricted:
            return ColorPalette.warning
        case .authorizedWhenInUse, .authorizedAlways:
            return ColorPalette.textSecondary
        @unknown default:
            return ColorPalette.textSecondary
        }
    }
    
    private func displayLocationText(for location: CLLocation) -> String {
        if let locationInfo = locationService.currentLocationInfo {
            if let city = locationInfo.city, !city.isEmpty {
                return formattedLocationName(city: city, accuracy: location.horizontalAccuracy)
            }

            if let country = locationInfo.country, !country.isEmpty {
                return country
            }
        }

        if let resolvedLocationDisplay, !resolvedLocationDisplay.isEmpty {
            return resolvedLocationDisplay
        }

        switch locationService.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return "Locating nearby city…"
        case .denied, .restricted:
            return "Enable location for city"
        default:
            return "Location permission required"
        }
    }


    private func formattedLocationName(city: String, accuracy: CLLocationAccuracy) -> String {
        accuracy > 100 ? "Near \(city)" : city
    }

    @MainActor
    private func updateResolvedLocationDisplay(force: Bool) async {
        let activeLocation = locationService.currentLocation ?? locationService.getCachedLocation()

        guard let location = activeLocation else {
            // Keep whatever we last showed so users still see their city unless we've never resolved one.
            if force, resolvedLocationDisplay == nil {
                resolvedLocationDisplay = nil
            }
            return
        }

        if let info = locationService.currentLocationInfo {
            if let city = info.city, !city.isEmpty {
                resolvedLocationDisplay = formattedLocationName(city: city, accuracy: location.horizontalAccuracy)
                return
            } else if let country = info.country, !country.isEmpty {
                resolvedLocationDisplay = country
                return
            }
        }

        if isResolvingLocationName {
            return
        }

        if !force, let current = resolvedLocationDisplay, !current.isEmpty {
            return
        }

        isResolvingLocationName = true
        defer { isResolvingLocationName = false }

        do {
            let coordinate = LocationCoordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            let info = try await locationService.getLocationInfo(for: coordinate)

            if let city = info.city, !city.isEmpty {
                resolvedLocationDisplay = formattedLocationName(city: city, accuracy: location.horizontalAccuracy)
            } else if let country = info.country, !country.isEmpty {
                resolvedLocationDisplay = country
            }
        } catch {
            // Ignore errors; retain existing placeholder text
        }
    }


    
    private func getPrayerStatus(for prayerTime: PrayerTime) -> PrayerStatus {
        let now = Date()
        if let nextPrayer = prayerTimeService.nextPrayer,
           Calendar.current.isDate(prayerTime.time, equalTo: nextPrayer.time, toGranularity: .minute) {
            return nextPrayer.time <= now ? .active : .upcoming
        }

        return prayerTime.time > now ? .upcoming : .completed
    }
    
    private func refreshPrayerTimes() async {
        isRefreshing = true
        await prayerTimeService.refreshPrayerTimes()
        isRefreshing = false
        await loadTrackingData()
    }

    private func requestLocationAndRefreshPrayers() async {
        // Check if we need to request location permission
        if locationService.authorizationStatus == .notDetermined {
            let status = await locationService.requestLocationPermissionAsync()
            if status != .authorizedWhenInUse && status != .authorizedAlways {
                return
            }
        }

        // If we have permission, get location (preferring cached if valid)
        if locationService.authorizationStatus == .authorizedWhenInUse ||
           locationService.authorizationStatus == .authorizedAlways {
            do {
                _ = try await locationService.getLocationPreferCached()
                print("Successfully obtained location (cached or fresh)")
            } catch {
                print("Failed to get location: \(error)")
                // Continue anyway in case we have some cached location that can be used
            }
        }

        // Refresh prayer times (this will use the location if available)
        await prayerTimeService.refreshPrayerTimes()
        await loadTrackingData()
    }

    private func loadTrackingData() async {
        guard let trackingService = prayerTrackingService else { return }

        let todayProgress = await trackingService.getDailyProgress(for: Date())
        let weekProgress = await trackingService.getWeeklyProgress(for: Date())
        let streakCount = trackingService.currentStreak

        await MainActor.run {
            self.dailyProgress = todayProgress
            self.weeklyProgress = weekProgress
            self.completedPrayers = Set(todayProgress.entries.map { $0.prayer })
            self.todaysCompletedCount = todayProgress.totalCompleted
            self.currentStreakCount = streakCount
        }
    }

    private func togglePrayer(_ prayer: Prayer) {
        guard let trackingService = prayerTrackingService else { return }

        Task {
            let wasCompleted = completedPrayers.contains(prayer)

            await MainActor.run {
                isUpdatingPrayers.insert(prayer)
            }

            if wasCompleted {
                if let entry = await MainActor.run(body: { dailyProgress?.getEntry(for: prayer) }) {
                    await trackingService.removePrayerEntry(entry.id)
                }
                await MainActor.run {
                    HapticFeedback.light()
                }
            } else {
                await trackingService.markPrayerCompleted(
                    prayer,
                    at: Date(),
                    location: nil,
                    notes: nil,
                    mood: nil,
                    method: .individual,
                    duration: nil,
                    congregation: .individual,
                    isQada: false
                )
                // Success haptic and celebration animation for completion
                await MainActor.run {
                    HapticFeedback.success()
                }
            }

            await loadTrackingData()

            await MainActor.run {
                isUpdatingPrayers.remove(prayer)
            }
        }
    }
    
}

/// Prayer timeline row with vertical connecting line
private struct PrayerTimelineRow: View {
    let prayer: PrayerTime
    let status: PrayerStatus
    let isNext: Bool
    let isLast: Bool
    let isCompleted: Bool
    let isProcessing: Bool
    let toggle: () -> Void

    @Environment(\.currentTheme) private var currentTheme
    @Environment(\.colorScheme) private var colorScheme
    @State private var celebrationScale: CGFloat = 1.0

    private var themeColors: ThemeAwareColorPalette {
        ThemeAwareColorPalette(theme: currentTheme)
    }
    
    private var premiumTokens: PremiumDesignTokens {
        PremiumDesignTokens(theme: currentTheme, colorScheme: colorScheme)
    }

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .top, spacing: 16) {
                // 1. Timeline Column
                VStack(spacing: 0) {
                    // Top connector (invisible for first item if we wanted, but usually we want a continuous line or just from center)
                    // For this design, we'll draw the line behind the node
                    
                    ZStack {
                        // Vertical Line
                        if !isLast {
                            Rectangle()
                                .fill(lineColor)
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                                .offset(y: 14) // Start from center of node
                        }
                        
                        // Node
                        ZStack {
                            if isCompleted {
                                Circle()
                                    .fill(themeColors.primary)
                                    .frame(width: 28, height: 28)
                                    .premiumShadow(.level1)
                                
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                if isNext {
                                    Circle()
                                        .fill(nodeFillColor)
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(nodeStrokeColor, lineWidth: 3)
                                        )
                                        .premiumShadow(.level1)
                                } else {
                                    Circle()
                                        .fill(nodeFillColor)
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(nodeStrokeColor, lineWidth: 2)
                                        )
                                }
                            }
                        }
                    }
                    .frame(width: 28)
                }
                .frame(maxHeight: .infinity, alignment: .top)

                // 2. Content Column
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(prayer.prayer.displayName)
                            .font(.system(size: 17, weight: isNext || isCompleted ? .semibold : .medium, design: .rounded))
                            .foregroundColor(primaryTextColor)
                        
                        if isNext {
                            Text("Next")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(themeColors.nextPrayerHighlight)
                                )
                        }
                        
                        Spacer()
                        
                        // Time
                        Text(Self.timeFormatter.string(from: prayer.time))
                            .font(.system(size: 17, weight: isNext ? .semibold : .regular, design: .rounded))
                            .foregroundColor(timeColor)
                            .monospacedDigit()
                    }
                    
                    HStack {
                        // Rakah Badge
                        HStack(spacing: 4) {
                            Text("\(prayer.prayer.defaultRakahCount)")
                                .font(.system(size: 12, weight: .bold))
                            Text("Rakah")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(ColorPalette.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(ColorPalette.surfaceSecondary)
                        )
                        
                        Spacer()
                        
                        // Relative Time
                        if let relative = relativeTimeString {
                            Text(relative)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(isNext ? themeColors.primary : ColorPalette.textSecondary)
                        }
                    }
                }
                .padding(.bottom, 24) // Spacing between rows
                .contentShape(Rectangle()) // Make entire area tappable
            }
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
        .opacity(isProcessing ? 0.6 : 1.0)
        .scaleEffect(celebrationScale)
        .appAnimation(AppAnimations.cardPress, value: celebrationScale)
        .accessibilityLabel(labelText)
        .accessibilityHint("Double tap to toggle completion")
        .onChange(of: isCompleted) { newValue in
            if newValue {
                celebrationScale = 1.05
                withAnimation(AppAnimations.cardPress.delay(0.1)) {
                    celebrationScale = 1.0
                }
            }
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale.autoupdatingCurrent
        return formatter
    }()
    
    // MARK: - Visual Helpers
    
    private var lineColor: Color {
        if isCompleted {
            return themeColors.primary.opacity(0.3)
        }
        return ColorPalette.surfaceSecondary.opacity(0.8) // Subtle line
    }
    
    private var nodeFillColor: Color {
        if isNext {
            return themeColors.primary.opacity(0.1)
        }
        return ColorPalette.surfacePrimary
    }
    
    private var nodeStrokeColor: Color {
        if isNext {
            return themeColors.primary
        }
        return ColorPalette.textSecondary.opacity(0.3)
    }

    private var primaryTextColor: Color {
        if isCompleted {
            return ColorPalette.textSecondary // Dim completed items
        }
        return isNext ? ColorPalette.textPrimary : ColorPalette.textPrimary.opacity(0.9)
    }

    private var timeColor: Color {
        if isCompleted {
            return ColorPalette.textSecondary
        }
        return isNext ? themeColors.primary : ColorPalette.textPrimary
    }

    private var relativeTimeString: String? {
        guard isNext else { return nil }

        let interval = prayer.time.timeIntervalSince(Date())
        guard interval > 0 else { return "Now" }

        let totalMinutes = Int(interval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if totalMinutes == 0 {
            return "<1m"
        }

        if hours > 0 {
            return "in \(hours)h \(minutes)m"
        }
        return "in \(minutes)m"
    }

    private var labelText: String {
        let statusText = isCompleted ? "completed" : "not completed"
        return "\(prayer.prayer.displayName), \(statusText)"
    }
}

/// Quick action button used in the dashboard
private struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionType: PremiumDesignTokens.ActionType
    let action: () -> Void

    @Environment(\.currentTheme) private var currentTheme
    @Environment(\.colorScheme) private var colorScheme

    private var premiumTokens: PremiumDesignTokens {
        PremiumDesignTokens(theme: currentTheme, colorScheme: colorScheme)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Icon with gradient background
                ZStack {
                    Circle()
                        .fill(premiumTokens.actionGradient(actionType))
                        .frame(width: 52, height: 52)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ColorPalette.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ColorPalette.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: PremiumDesignTokens.cornerRadius20)
                    .fill(ColorPalette.surfacePrimary)
            )
            .premiumShadow(.level1)
        }
        .buttonStyle(.plain)
    }
}

/// Weekly summary card displayed on the dashboard
private struct WeeklyProgressCard: View {
    let progress: WeeklyPrayerProgress?
    let todaysCompleted: Int
    let streakCount: Int

    private var completionRate: Double {
        min(max(progress?.completionRate ?? 0.0, 0.0), 1.0)
    }

    private var completionPercentage: Int {
        Int(completionRate * 100)
    }

    var body: some View {
        HStack(spacing: 24) {
            // Circular Progress Ring
            ZStack {
                AnimatedProgressRing(progress: completionRate, lineWidth: 10)
                    .frame(width: 80, height: 80)

                VStack(spacing: 2) {
                    Text("\(completionPercentage)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ColorPalette.textPrimary)

                    Text("%")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ColorPalette.textSecondary)
                }
            }

            // Metrics
            VStack(alignment: .leading, spacing: 12) {
                Text("This Week's Progress")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ColorPalette.textPrimary)

                HStack(spacing: 16) {
                    MetricPill(
                        icon: "flame.fill",
                        title: "Streak",
                        value: "\(streakCount)"
                    )

                    MetricPill(
                        icon: "checkmark.circle.fill",
                        title: "Today",
                        value: "\(todaysCompleted)/5"
                    )
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PremiumDesignTokens.cornerRadius24)
                .fill(ColorPalette.surfacePrimary)
        )
        .premiumShadow(.level2)
    }
}

/// Islamic calendar summary card
private struct IslamicCalendarCard: View {
    let currentDate: Date

    @Environment(\.currentTheme) private var currentTheme
    @Environment(\.colorScheme) private var colorScheme

    private var hijriDate: HijriDate {
        HijriDate(from: currentDate)
    }

    private var hijriString: String {
        "\(hijriDate.day) \(hijriDate.month.displayName) \(hijriDate.year)"
    }

    private var gregorianString: String {
        Self.gregorianFormatter.string(from: currentDate)
    }

    private var premiumTokens: PremiumDesignTokens {
        PremiumDesignTokens(theme: currentTheme, colorScheme: colorScheme)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Calendar icon with gradient background
            ZStack {
                Circle()
                    .fill(premiumTokens.actionGradient(.calendar))
                    .frame(width: 48, height: 48)

                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            .premiumShadow(.level1)

            // Calendar content
            VStack(alignment: .leading, spacing: 8) {
                Text("Islamic Calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ColorPalette.textSecondary)
                    .textCase(.uppercase)

                Text(hijriString)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(ColorPalette.textPrimary)

                Text("Corresponding to \(gregorianString)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ColorPalette.textSecondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PremiumDesignTokens.cornerRadius24)
                .fill(ColorPalette.surfacePrimary)
        )
        .premiumShadow(.level2)
    }

    private static let gregorianFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale.autoupdatingCurrent
        return formatter
    }()
}

/// Small pill-style metric display
private struct MetricPill: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ColorPalette.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ColorPalette.textPrimary)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ColorPalette.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(ColorPalette.primary.opacity(0.08))
        )
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

/// Empty state for prayer times
private struct EmptyPrayerTimesView: View {
    let locationService: any LocationServiceProtocol
    let onLocationRequest: () async -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: locationIconName)
                .font(.system(size: 48))
                .foregroundColor(ColorPalette.textTertiary)

            Text(titleText)
                .titleMedium()
                .foregroundColor(ColorPalette.textPrimary)

            Text(messageText)
                .bodyMedium()
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)

            if showLocationButton {
                CustomButton.primary(buttonText) {
                    Task {
                        await onLocationRequest()
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorPalette.surfaceSecondary)
        )
    }

    private var locationIconName: String {
        switch locationService.authorizationStatus {
        case .denied, .restricted:
            return "location.slash"
        case .notDetermined:
            return "location.circle"
        default:
            return "clock.badge.questionmark"
        }
    }

    private var titleText: String {
        switch locationService.authorizationStatus {
        case .denied, .restricted:
            return "Location Access Required"
        case .notDetermined:
            return "Enable Location Services"
        default:
            return "Prayer times not available"
        }
    }

    private var messageText: String {
        switch locationService.authorizationStatus {
        case .denied, .restricted:
            return "Please enable location access in Settings to calculate accurate prayer times for your area."
        case .notDetermined:
            return "We need your location to calculate accurate prayer times for your area."
        default:
            return "Please check your location settings and try again."
        }
    }

    private var showLocationButton: Bool {
        switch locationService.authorizationStatus {
        case .notDetermined:
            return true
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    private var buttonText: String {
        switch locationService.authorizationStatus {
        case .notDetermined:
            return "Allow Location Access"
        case .denied, .restricted:
            return "Open Settings"
        default:
            return "Retry"
        }
    }
}

// MARK: - Timer Manager

@MainActor
private class CountdownTimerManager: ObservableObject {
    @Published var currentTime = Date()

    private let timerManager = BatteryAwareTimerManager.shared
    private let timerID = "homescreen-countdown-timer-\(UUID().uuidString)"

    func startTimer() {
        timerManager.scheduleTimer(id: timerID, type: .countdownUI) { [weak self] in
            Task { @MainActor in
                self?.currentTime = Date()
            }
        }
    }

    func stopTimer() {
        timerManager.cancelTimer(id: timerID)
    }

    deinit {
        // Use the synchronous timer cancellation method designed for deinit
        timerManager.cancelTimerSync(id: timerID)
    }
}

// MARK: - Preview

#Preview("Home Screen") {
    HomeScreen(
        prayerTimeService: MockPrayerTimeService(),
        locationService: MockLocationService(),
        settingsService: MockSettingsService(),
        prayerTrackingService: nil,
        onCompassTapped: { print("Compass tapped") },
        onGuidesTapped: { print("Guides tapped") },
        onQuranSearchTapped: { print("Quran search tapped") },
        onSettingsTapped: { print("Settings tapped") },
        onTasbihTapped: { print("Tasbih tapped") },
        onCalendarTapped: { print("Calendar tapped") }
    )
}
