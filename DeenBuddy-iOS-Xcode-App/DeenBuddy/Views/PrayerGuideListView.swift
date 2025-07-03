//
//  PrayerGuideListView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-03.
//

import SwiftUI

struct PrayerGuideListView: View {
    @ObservedObject var viewModel: PrayerGuideViewModel
    @State private var searchText = ""
    
    private var filteredGuides: [PrayerGuide] {
        let guides = viewModel.filteredGuides
        
        if searchText.isEmpty {
            return guides
        } else {
            return guides.filter { guide in
                guide.title.localizedCaseInsensitiveContains(searchText) ||
                guide.prayer.displayName.localizedCaseInsensitiveContains(searchText) ||
                guide.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.prayerGuides.isEmpty {
                LoadingView(message: "Loading prayer guides...")
            } else if let errorMessage = viewModel.errorMessage, viewModel.prayerGuides.isEmpty {
                ErrorView(
                    message: errorMessage,
                    onRetry: {
                        Task {
                            await viewModel.refreshData()
                        }
                    }
                )
            } else if filteredGuides.isEmpty {
                EmptyStateView(
                    title: "No Prayer Guides",
                    message: searchText.isEmpty ? 
                        "No guides found for \(viewModel.selectedMadhab.sectDisplayName) tradition" :
                        "No guides match your search",
                    systemImage: searchText.isEmpty ? "book.closed" : "magnifyingglass"
                )
            } else {
                List {
                    // Offline mode indicator
                    if viewModel.isOffline {
                        Section {
                            HStack {
                                Image(systemName: "wifi.slash")
                                    .foregroundColor(.orange)
                                Text("Offline Mode - Using cached content")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // Prayer guides section
                    Section("Prayer Guides (\(filteredGuides.count))") {
                        ForEach(filteredGuides) { guide in
                            NavigationLink(destination: PrayerGuideDetailView(guide: guide)) {
                                PrayerGuideRowView(guide: guide)
                            }
                        }
                    }
                    
                    // Summary section
                    if searchText.isEmpty {
                        Section("Summary") {
                            SummaryRowView(
                                title: "Total Guides",
                                value: "\(viewModel.totalGuides)",
                                color: .primary
                            )
                            
                            SummaryRowView(
                                title: "Sunni Guides",
                                value: "\(viewModel.shafiGuides)",
                                color: .green
                            )
                            
                            SummaryRowView(
                                title: "Shia Guides", 
                                value: "\(viewModel.hanafiGuides)",
                                color: .purple
                            )
                        }
                    }
                }
                .refreshable {
                    await viewModel.refreshData()
                }
                .searchable(text: $searchText, prompt: "Search prayer guides...")
            }
        }
        .navigationTitle("Prayer Guides")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Picker("Tradition", selection: $viewModel.selectedMadhab) {
                    ForEach(Madhab.allCases, id: \.self) { madhab in
                        Text(madhab.sectDisplayName)
                            .tag(madhab)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
}

struct SummaryRowView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

#Preview {
    NavigationStack {
        PrayerGuideListView(viewModel: PrayerGuideViewModel())
    }
}
