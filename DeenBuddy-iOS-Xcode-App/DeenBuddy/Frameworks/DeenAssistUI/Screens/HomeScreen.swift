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
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerView

                    quickActionsSection

                    CountdownTimer(
                        nextPrayer: prayerTimeService.nextPrayer,
                        timeRemaining: prayerTimeService.timeUntilNextPrayer
                    )

                    prayerTimesSection

                    dashboardSummarySection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(ColorPalette.backgroundPrimary)
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
        VStack(alignment: .leading, spacing: 20) {
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

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(ColorPalette.primary)
                        .font(.headline)

                    if let location = locationService.currentLocation {
                        Text(displayLocationText(for: location))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ColorPalette.textPrimary)

                        Button(action: { showLocationDiagnostic = true }) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(ColorPalette.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("View location details")
                    } else {
                        Text(locationStatusText)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(locationStatusColor)
                    }

                    Spacer(minLength: 0)

                    if locationService.isUpdatingLocation || isRefreshing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ColorPalette.primary))
                            .scaleEffect(0.8)
                    } else if locationService.currentLocation == nil {
                        Button(action: {
                            Task { await requestLocationAndRefreshPrayers() }
                        }) {
                            Image(systemName: "location.circle")
                                .foregroundColor(ColorPalette.primary)
                                .font(.title3)
                        }
                        .accessibilityLabel("Refresh location")
                    }
                }

                Text(formattedTimeString)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(ColorPalette.textPrimary)
                    .minimumScaleFactor(0.8)

                Text(formattedDateLine)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ColorPalette.textSecondary)
                    .lineLimit(1)
            }

            Text(greetingText)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ColorPalette.textSecondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(ColorPalette.surfacePrimary)
                .shadow(color: Color.black.opacity(0.05), radius: 22, x: 0, y: 10)
        )
    }
    
    @ViewBuilder
    private var prayerTimesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text("Today's Prayer Schedule")
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
                    LazyVGrid(columns: scheduleColumns, spacing: 8) {
                        Text("Prayer")
                            .font(.caption)
                            .foregroundColor(ColorPalette.textSecondary)

                        Text("Time")
                            .font(.caption)
                            .foregroundColor(ColorPalette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text("Rakah")
                            .font(.caption)
                            .foregroundColor(ColorPalette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.bottom, 8)

                    Divider()

                    ForEach(Array(prayers.enumerated()), id: \.element.prayer) { index, prayerTime in
                        let isNext = {
                            guard let nextPrayerInstance else { return false }
                            return prayerTime.prayer == nextPrayerInstance.prayer &&
                                Calendar.current.isDate(prayerTime.time, equalTo: nextPrayerInstance.time, toGranularity: .minute)
                        }()

                        PrayerScheduleRow(
                            prayer: prayerTime,
                            status: getPrayerStatus(for: prayerTime),
                            isNext: isNext,
                            isCompleted: completedPrayers.contains(prayerTime.prayer),
                            isProcessing: isUpdatingPrayers.contains(prayerTime.prayer),
                            columns: scheduleColumns,
                            toggle: { togglePrayer(prayerTime.prayer) }
                        )

                        if index < prayers.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(ColorPalette.surfacePrimary)
                .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 8)
        )
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
                    action: {
                        onCompassTapped()
                    }
                )

                ActionCard(
                    icon: SymbolLibrary.tasbih,
                    title: "Tasbih",
                    subtitle: onTasbihTapped != nil ? "Digital beads" : "Coming soon",
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
            await MainActor.run {
                isUpdatingPrayers.insert(prayer)
            }

            if completedPrayers.contains(prayer) {
                if let entry = await MainActor.run(body: { dailyProgress?.getEntry(for: prayer) }) {
                    await trackingService.removePrayerEntry(entry.id)
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
            }

            await MainActor.run {
                HapticFeedback.light()
            }

            await loadTrackingData()

            await MainActor.run {
                isUpdatingPrayers.remove(prayer)
            }
        }
    }
    
}

/// Prayer schedule row styled for the home screen list
private struct PrayerScheduleRow: View {
    let prayer: PrayerTime
    let status: PrayerStatus
    let isNext: Bool
    let isCompleted: Bool
    let isProcessing: Bool
    let columns: [GridItem]
    let toggle: () -> Void

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale.autoupdatingCurrent
        return formatter
    }()

    var body: some View {
        Button(action: toggle) {
            LazyVGrid(columns: columns, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isCompleted ? ColorPalette.primary : ColorPalette.textSecondary)

                        Text(prayer.prayer.displayName)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(primaryTextColor)

                        if isNext {
                            Text("Next")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(ColorPalette.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ColorPalette.primary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    if let relative = relativeTimeString {
                        Text(relative)
                            .font(.caption)
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                }

                Text(timeString)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(timeColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .monospacedDigit()

                Text("\(prayer.prayer.defaultRakahCount)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ColorPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
        .opacity(isProcessing ? 0.6 : 1.0)
        .accessibilityLabel(labelText)
        .accessibilityHint("Double tap to toggle completion for this prayer")
    }

    private var timeString: String {
        Self.timeFormatter.string(from: prayer.time)
    }

    private var primaryTextColor: Color {
        if isCompleted {
            return ColorPalette.primary
        }
        switch status {
        case .completed:
            return ColorPalette.textSecondary
        default:
            return isNext ? ColorPalette.primary : ColorPalette.textPrimary
        }
    }

    private var timeColor: Color {
        if isCompleted {
            return ColorPalette.primary
        }
        switch status {
        case .completed:
            return ColorPalette.textSecondary
        case .active:
            return ColorPalette.primary
        default:
            return ColorPalette.textPrimary
        }
    }

    private var relativeTimeString: String? {
        guard isNext else { return nil }

        let interval = prayer.time.timeIntervalSince(Date())
        guard interval > 0 else { return "Starting now" }

        let totalMinutes = Int(interval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if totalMinutes == 0 {
            return "In <1m"
        }

        var components: [String] = []
        if hours > 0 {
            components.append("\(hours)h")
        }
        components.append("\(minutes)m")

        return "In \(components.joined(separator: " "))"
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                isCompleted ? ColorPalette.primary.opacity(0.12) :
                    (isNext ? ColorPalette.primary.opacity(0.08) : ColorPalette.surfaceSecondary.opacity(0.6))
            )
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(ColorPalette.primary.opacity(0.12))
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(ColorPalette.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ColorPalette.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ColorPalette.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(ColorPalette.surfacePrimary)
                    .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
            )
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(ColorPalette.primary)
                Text("This Week's Progress")
                    .font(.headline)
                    .foregroundColor(ColorPalette.textPrimary)
            }

            HStack(spacing: 12) {
                MetricPill(title: "Completed", value: "\(completionPercentage)%")
                MetricPill(title: "Day Streak", value: "\(streakCount)")
                MetricPill(title: "Today", value: "\(todaysCompleted)/5")
            }

            ProgressView(value: completionRate)
                .progressViewStyle(LinearProgressViewStyle(tint: ColorPalette.primary))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(ColorPalette.surfacePrimary)
                .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 8)
        )
    }
}

/// Islamic calendar summary card
private struct IslamicCalendarCard: View {
    let currentDate: Date

    private var hijriDate: HijriDate {
        HijriDate(from: currentDate)
    }

    private var hijriString: String {
        "\(hijriDate.day) \(hijriDate.month.displayName) \(hijriDate.year)"
    }

    private var gregorianString: String {
        Self.gregorianFormatter.string(from: currentDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundColor(ColorPalette.primary)
                Text("Islamic Calendar")
                    .font(.headline)
                    .foregroundColor(ColorPalette.textPrimary)
            }

            Text(hijriString)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(ColorPalette.textPrimary)

            Text("Corresponding to \(gregorianString)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ColorPalette.textSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(ColorPalette.surfacePrimary)
                .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 8)
        )
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
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(ColorPalette.primary)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ColorPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
