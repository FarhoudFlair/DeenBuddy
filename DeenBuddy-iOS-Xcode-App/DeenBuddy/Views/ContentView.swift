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

            // Search Tab
            NavigationStack {
                SearchView(viewModel: viewModel)
            }
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Search")
            }
            .tag(2)

            // Bookmarks Tab
            NavigationStack {
                BookmarksView(viewModel: viewModel)
            }
            .tabItem {
                Image(systemName: "bookmark")
                Text("Bookmarks")
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
                SettingsView(viewModel: viewModel)
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(5)
        }
        .task {
            await viewModel.fetchPrayerGuides()
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
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "safari.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)

                Text("Qibla Compass")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Find the direction to Kaaba for prayer")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Quick Info
            VStack(spacing: 16) {
                InfoCard(
                    icon: "location.fill",
                    title: "Location Required",
                    description: "We need your location to calculate the accurate direction to Kaaba in Mecca."
                )

                InfoCard(
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
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
        .navigationTitle("Qibla Compass")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Info Card Component

struct InfoCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    ContentView()
}
