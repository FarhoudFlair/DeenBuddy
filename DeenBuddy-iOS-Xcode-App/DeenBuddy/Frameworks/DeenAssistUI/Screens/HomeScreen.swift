import SwiftUI
import CoreLocation

/// Main home screen of the app
public struct HomeScreen: View {
    private let prayerTimeService: any PrayerTimeServiceProtocol
    private let locationService: any LocationServiceProtocol
    
    let onCompassTapped: () -> Void
    let onGuidesTapped: () -> Void
    let onSettingsTapped: () -> Void
    
    @State private var isRefreshing = false
    
    public init(
        prayerTimeService: any PrayerTimeServiceProtocol,
        locationService: any LocationServiceProtocol,
        onCompassTapped: @escaping () -> Void,
        onGuidesTapped: @escaping () -> Void,
        onSettingsTapped: @escaping () -> Void
    ) {
        self.prayerTimeService = prayerTimeService
        self.locationService = locationService
        self.onCompassTapped = onCompassTapped
        self.onGuidesTapped = onGuidesTapped
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
                    
                    if let location = locationService.currentLocation {
                        Text(locationString(for: location))
                            .titleMedium()
                            .foregroundColor(ColorPalette.textPrimary)
                    } else {
                        Text("Location not available")
                            .titleMedium()
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                }
                
                Spacer()
                
                if locationService.isUpdatingLocation {
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
                EmptyPrayerTimesView()
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
        }
    }
    
    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: Date())
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
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(ColorPalette.textTertiary)
            
            Text("Prayer times not available")
                .titleMedium()
                .foregroundColor(ColorPalette.textPrimary)
            
            Text("Please check your location settings and try again")
                .bodyMedium()
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorPalette.surfaceSecondary)
        )
    }
}

// MARK: - Preview

#Preview("Home Screen") {
    HomeScreen(
        prayerTimeService: MockPrayerTimeService(),
        locationService: MockLocationService(),
        onCompassTapped: { print("Compass tapped") },
        onGuidesTapped: { print("Guides tapped") },
        onSettingsTapped: { print("Settings tapped") }
    )
}
