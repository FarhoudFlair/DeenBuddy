//
//  ContentView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-03.
//

import SwiftUI
import CoreLocation
import CoreMotion

struct ContentView: View {
    @StateObject private var viewModel = PrayerGuideViewModel()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var performanceMonitor = IslamicAppPerformanceMonitor()
    @StateObject private var backgroundRefreshService = BackgroundPrayerRefreshService(
        prayerTimeService: PrayerTimeService(),
        locationManager: LocationManager()
    )
    @StateObject private var dataPrefetcher = PrayerDataPrefetcher(
        prayerTimeService: PrayerTimeService(),
        qiblaCache: QiblaDirectionCache()
    )

    @State private var selectedTab = 0
    @State private var showingQiblaCompass = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // Prayer Times Tab
            NavigationStack {
                PrayerTimesView()
            }
            .tabItem {
                Image(systemName: "clock.fill")
                Text("Prayer Times")
            }
            .tag(0)

            // Prayer Guides Tab
            NavigationStack {
                PrayerGuideListView(viewModel: viewModel)
            }
            .tabItem {
                Image(systemName: "book.closed")
                Text("Guides")
            }
            .tag(1)

            // Islamic Knowledge Search Tab
            NavigationStack {
                IslamicKnowledgeSearchView()
            }
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Knowledge")
            }
            .tag(2)

            // Prayer Journal Tab
            NavigationStack {
                PrayerJournalView()
            }
            .tabItem {
                Image(systemName: "book.pages")
                Text("Journal")
            }
            .tag(3)

            // Qibla Compass Tab
            NavigationStack {
                QiblaTabView(showingQiblaCompass: $showingQiblaCompass)
            }
            .tabItem {
                Image(systemName: "safari.fill")
                Text("Qibla")
            }
            .tag(4)

            // Settings Tab
            NavigationStack {
                SettingsView(viewModel: viewModel, themeManager: themeManager)
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(5)
        }
        .tint(themeManager.currentTheme == .dark ? .cyan : .islamicAccentGold)
        .themed(with: themeManager)
        .task {
            // Start performance monitoring for sub-400ms targets
            performanceMonitor.startMonitoring()
            performanceMonitor.startTiming(feature: .appLaunch)

            // Start background services for optimal performance
            backgroundRefreshService.startBackgroundRefresh()

            // Prefetch critical Islamic data for instant access
            await dataPrefetcher.prefetchCriticalData()

            // Load prayer guides
            await viewModel.fetchPrayerGuides()

            // Record app launch performance
            performanceMonitor.endTiming(feature: .appLaunch)

            print("🕌 DeenBuddy optimized for sub-400ms Islamic app performance")
        }
        .sheet(isPresented: $showingQiblaCompass) {
            QiblaCompassView(onDismiss: {
                showingQiblaCompass = false
            })
        }
    }
}

// MARK: - Qibla Tab View

struct QiblaTabView: View {
    @Binding var showingQiblaCompass: Bool

    var body: some View {
        ZStack {
            ModernGradientBackground()

            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.cyan)

                    ModernTitle("Qibla Compass")
                        .font(.largeTitle)

                    ModernSubtitle("Find the direction to Kaaba for prayer")
                        .multilineTextAlignment(.center)
                }

                // Quick Info
                VStack(spacing: 16) {
                    ModernInfoCard(
                        icon: "location.fill",
                        title: "Location Required",
                        description: "We need your location to calculate the accurate direction to Kaaba in Mecca."
                    )

                    ModernInfoCard(
                        icon: "compass.drawing",
                        title: "Compass Calibration",
                        description: "For best results, calibrate your device compass by moving it in a figure-8 pattern."
                    )
                }

                Spacer()

                // Open Compass Button
                Button(action: {
                    showingQiblaCompass = true
                }) {
                    HStack {
                        Image(systemName: "safari.fill")
                            .font(.title2)
                        Text("Open Qibla Compass")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(PrimaryModernButtonStyle(backgroundColor: .cyan, foregroundColor: .black))
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle("Qibla Compass")
        .navigationBarTitleDisplayMode(.large)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Modern Info Card Component

struct ModernInfoCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        ModernCard {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.cyan)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    ModernTitle(title)
                        .font(.headline)

                    ModernSubtitle(description)
                        .font(.body)
                }

                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
