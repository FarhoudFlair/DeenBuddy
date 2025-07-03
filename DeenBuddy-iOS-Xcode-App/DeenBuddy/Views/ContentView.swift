//
//  ContentView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-03.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PrayerGuideViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Prayer Guides Tab
            NavigationStack {
                PrayerGuideListView(viewModel: viewModel)
            }
            .tabItem {
                Image(systemName: "book.closed")
                Text("Guides")
            }
            .tag(0)

            // Search Tab
            NavigationStack {
                SearchView(viewModel: viewModel)
            }
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Search")
            }
            .tag(1)

            // Bookmarks Tab
            NavigationStack {
                BookmarksView(viewModel: viewModel)
            }
            .tabItem {
                Image(systemName: "bookmark")
                Text("Bookmarks")
            }
            .tag(2)

            // Settings Tab
            NavigationStack {
                SettingsView(viewModel: viewModel)
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(3)
        }
        .task {
            await viewModel.fetchPrayerGuides()
        }
    }
}

#Preview {
    ContentView()
}
