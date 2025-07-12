import SwiftUI
import CoreLocation
import UIKit

/// Main home screen of the app
public struct HomeScreen: View {
    private let prayerTimeService: any PrayerTimeServiceProtocol
    private let locationService: any LocationServiceProtocol
    
    let onCompassTapped: () -> Void
    let onGuidesTapped: () -> Void
    let onQuranSearchTapped: () -> Void
    let onSettingsTapped: () -> Void
    
    @State private var isRefreshing = false
    
    public init(
        prayerTimeService: any PrayerTimeServiceProtocol,
        locationService: any LocationServiceProtocol,
        onCompassTapped: @escaping () -> Void,
        onGuidesTapped: @escaping () -> Void,
        onQuranSearchTapped: @escaping () -> Void,
        onSettingsTapped: @escaping () -> Void
    ) {
        self.prayerTimeService = prayerTimeService
        self.locationService = locationService
        self.onCompassTapped = onCompassTapped
        self.onGuidesTapped = onGuidesTapped
        self.onQuranSearchTapped = onQuranSearchTapped
        self.onSettingsTapped = onSettingsTapped
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Header with location
                    headerView

                    // Next prayer countdown
                    if let nextPrayer = prayerTimeService.nextPrayer {
                        CountdownTimer(
                            nextPrayer: nextPrayer,
                            timeRemaining: prayerTimeService.timeUntilNextPrayer
                        )
                    }

                    // Today's prayer times
                    prayerTimesSection

                    // Quick actions
                    quickActionsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(ColorPalette.backgroundPrimary)
            .navigationTitle("Deen Assist")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onSettingsTapped) {
                        Image(systemName: "gear")
                            .foregroundColor(ColorPalette.textPrimary)
                    }
                }
            }
            .refreshable {
                await refreshPrayerTimes()
            }
            .onAppear {
                Task {
                    await requestLocationAndRefreshPrayers()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                Task {
                    await requestLocationAndRefreshPrayers()
                }
            }
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentDateString)
                        .bodyMedium()
                        .foregroundColor(ColorPalette.textSecondary)

                    HStack(spacing: 8) {
                        if let location = locationService.currentLocation {
                            Text(locationString(for: location))
                                .titleMedium()
                                .foregroundColor(ColorPalette.textPrimary)
                        } else {
                            Text(locationStatusText)
                                .titleMedium()
                                .foregroundColor(locationStatusColor)
                        }

                        if !locationService.isUpdatingLocation && locationService.currentLocation == nil {
                            Button(action: {
                                Task {
                                    await requestLocationAndRefreshPrayers()
                                }
                            }) {
                                Image(systemName: "location.circle")
                                    .foregroundColor(ColorPalette.primary)
                                    .font(.title3)
                            }
                        }
                    }
                }

                Spacer()

                if locationService.isUpdatingLocation || isRefreshing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ColorPalette.primary))
                        .scaleEffect(0.8)
                }
            }
        }
    }
    
    @ViewBuilder
    private var prayerTimesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's Prayers")
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
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(prayerTimeService.todaysPrayerTimes, id: \.prayer) { prayerTime in
                        PrayerTimeCard(
                            prayer: prayerTime,
                            status: getPrayerStatus(for: prayerTime),
                            isNext: prayerTime.prayer == prayerTimeService.nextPrayer?.prayer
                        )
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .headlineSmall()
                .foregroundColor(ColorPalette.textPrimary)

            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    QuickActionCard(
                        icon: "safari.fill",
                        title: "Qibla Compass",
                        description: "Find direction to Kaaba",
                        color: ColorPalette.primary,
                        action: onCompassTapped
                    )

                    QuickActionCard(
                        icon: "book.fill",
                        title: "Prayer Guides",
                        description: "Step-by-step guides",
                        color: ColorPalette.secondary,
                        action: onGuidesTapped
                    )
                }

                // Quran Search - Full width
                QuickActionCard(
                    icon: "magnifyingglass",
                    title: "Search Quran",
                    description: "Find verses by keywords, themes, or references",
                    color: Color.green,
                    action: onQuranSearchTapped
                )
            }
        }
    }
    
    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: Date())
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
    
    private func locationString(for location: CLLocation) -> String {
        // In a real app, this would reverse geocode to get city name
        return String(format: "%.2f°, %.2f°", location.coordinate.latitude, location.coordinate.longitude)
    }
    
    private func getPrayerStatus(for prayerTime: PrayerTime) -> PrayerStatus {
        let now = Date()
        
        if prayerTime.time > now {
            return .upcoming
        } else if prayerTime.prayer == prayerTimeService.nextPrayer?.prayer {
            return .active
        } else {
            return .completed
        }
    }
    
    private func refreshPrayerTimes() async {
        isRefreshing = true
        await prayerTimeService.refreshPrayerTimes()
        isRefreshing = false
    }

    private func requestLocationAndRefreshPrayers() async {
        // Check if we need to request location permission
        if locationService.authorizationStatus == .notDetermined {
            let status = await locationService.requestLocationPermissionAsync()
            if status != .authorizedWhenInUse && status != .authorizedAlways {
                return
            }
        }

        // If we have permission but no current location, try to get it
        if locationService.currentLocation == nil &&
           (locationService.authorizationStatus == .authorizedWhenInUse ||
            locationService.authorizationStatus == .authorizedAlways) {
            do {
                _ = try await locationService.requestLocation()
            } catch {
                print("Failed to get location: \(error)")
            }
        }

        // Refresh prayer times (this will use the location if available)
        await prayerTimeService.refreshPrayerTimes()
    }
}

/// Quick action card component
private struct QuickActionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
                
                VStack(spacing: 4) {
                    Text(title)
                        .titleSmall()
                        .foregroundColor(ColorPalette.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text(description)
                        .labelMedium()
                        .foregroundColor(ColorPalette.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ColorPalette.surfacePrimary)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
        onCompassTapped: { print("Compass tapped") },
        onGuidesTapped: { print("Guides tapped") },
        onQuranSearchTapped: { print("Quran search tapped") },
        onSettingsTapped: { print("Settings tapped") }
    )
}
