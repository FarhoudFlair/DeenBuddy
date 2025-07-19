import SwiftUI

/// Main tab view for the app with enhanced settings integration
public struct MainTabView: View {
    private let coordinator: AppCoordinator
    
    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }
    
    public var body: some View {
        TabView {
            // 1. Home Tab - Prayer times and main dashboard
            MainAppView(coordinator: coordinator)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            // 2. Qibla Tab - Direct access to compass
            QiblaCompassScreen(
                locationService: coordinator.locationService,
                onDismiss: { }, // No dismiss needed in tab mode
                onShowAR: {
                    coordinator.showARCompass()
                }
            )
            .tabItem {
                Image(systemName: "safari.fill")
                Text("Qibla")
            }
            
            // 3. Prayer Tracking Tab - Direct access to prayer tracking
            PrayerTrackingScreen(
                prayerTrackingService: coordinator.prayerTrackingService,
                prayerTimeService: coordinator.prayerTimeService,
                notificationService: coordinator.notificationService,
                onDismiss: { } // No dismiss needed in tab mode
            )
            .tabItem {
                Image(systemName: "checkmark.circle.fill")
                Text("Tracking")
            }
            
            // 4. Quran Tab - Direct access to QuranSearchView
            QuranSearchView()
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("Quran")
                }
            
            // 5. Settings Tab - Enhanced settings view with profile section
            Group {
                if let settingsService = coordinator.settingsService as? SettingsService {
                    EnhancedSettingsView(
                        settingsService: settingsService,
                        themeManager: coordinator.themeManager,
                        onDismiss: { } // No dismiss needed in tab mode
                    )
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
        }
        .accentColor(ColorPalette.primary)
        .themed(with: coordinator.themeManager)
    }
}

/// Main app view wrapper for the home tab
private struct MainAppView: View {
    @ObservedObject var coordinator: AppCoordinator
    
    var body: some View {
        ZStack {
            HomeScreen(
                prayerTimeService: coordinator.prayerTimeService,
                locationService: coordinator.locationService,
                settingsService: coordinator.settingsService,
                notificationService: coordinator.notificationService,
                onCompassTapped: { }, // No action needed - available as tab
                onGuidesTapped: { }, // No action needed - available as tab
                onQuranSearchTapped: { }, // No action needed - available as tab
                onSettingsTapped: { }, // No action needed - available as tab
                onNotificationsTapped: {
                    // Bell icon tapped - notification settings functionality
                    print("Notification bell tapped")
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
        .fullScreenCover(isPresented: $coordinator.showingARCompass) {
            ARQiblaCompassScreen(
                locationService: coordinator.locationService,
                onDismiss: {
                    coordinator.dismissARCompass()
                }
            )
        }
        .errorAlert()
        .themed(with: coordinator.themeManager)
    }
}

#Preview {
    MainTabView(coordinator: AppCoordinator.mock())
}
