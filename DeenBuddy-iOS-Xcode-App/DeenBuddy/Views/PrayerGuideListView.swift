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
        ZStack {
            ModernGradientBackground()

            Group {
                if viewModel.isLoading && viewModel.prayerGuides.isEmpty {
                    ModernLoadingView(message: "Loading prayer guides...")
                } else if let errorMessage = viewModel.errorMessage, viewModel.prayerGuides.isEmpty {
                    ModernErrorView(
                        title: "Error Loading Guides",
                        message: errorMessage,
                        onRetry: {
                            Task {
                                await viewModel.refreshData()
                            }
                        }
                    )
                } else if filteredGuides.isEmpty {
                    ModernEmptyState(
                        title: "No Prayer Guides",
                        message: searchText.isEmpty ?
                            "No guides found for \(viewModel.selectedMadhab.sectDisplayName) tradition" :
                            "No guides match your search",
                        systemImage: searchText.isEmpty ? "book.closed" : "magnifyingglass"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Offline mode indicator
                            if viewModel.isOffline {
                                ModernCard(backgroundColor: Color.orange.opacity(0.2), borderColor: Color.orange.opacity(0.3)) {
                                    HStack {
                                        Image(systemName: "wifi.slash")
                                            .foregroundColor(.orange)
                                        ModernCaption("Offline Mode - Using cached content", color: .orange)
                                        Spacer()
                                    }
                                    .padding()
                                }
                                .padding(.horizontal)
                            }

                            // Prayer guides section
                            ModernCard {
                                VStack(spacing: 0) {
                                    HStack {
                                        ModernTitle("Prayer Guides (\(filteredGuides.count))")
                                        Spacer()
                                    }
                                    .padding()

                                    ForEach(Array(filteredGuides.enumerated()), id: \.element.id) { index, guide in
                                        NavigationLink(destination: PrayerGuideDetailView(guide: guide)) {
                                            ModernPrayerGuideRow(guide: guide)
                                        }
                                        .buttonStyle(PlainButtonStyle())

                                        if index < filteredGuides.count - 1 {
                                            Divider()
                                                .background(Color.white.opacity(0.1))
                                                .padding(.horizontal)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)

                            // Summary section
                            if searchText.isEmpty {
                                ModernCard {
                                    VStack(spacing: 16) {
                                        HStack {
                                            ModernTitle("Summary")
                                            Spacer()
                                        }

                                        VStack(spacing: 12) {
                                            ModernSummaryRow(
                                                title: "Total Guides",
                                                value: "\(viewModel.totalGuides)",
                                                color: .white
                                            )

                                            ModernSummaryRow(
                                                title: "Sunni Guides",
                                                value: "\(viewModel.shafiGuides)",
                                                color: .green
                                            )

                                            ModernSummaryRow(
                                                title: "Shia Guides",
                                                value: "\(viewModel.hanafiGuides)",
                                                color: .purple
                                            )
                                        }
                                    }
                                    .padding()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        await viewModel.refreshData()
                    }
                }
            }
        }
        .navigationTitle("Prayer Guides")
        .navigationBarTitleDisplayMode(.large)
        .preferredColorScheme(.dark)
        .searchable(text: $searchText, prompt: "Search prayer guides...")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Picker("Tradition", selection: $viewModel.selectedMadhab) {
                    ForEach(Madhab.allCases, id: \.self) { madhab in
                        Text(madhab.sectDisplayName)
                            .tag(madhab)
                    }
                }
                .pickerStyle(.menu)
                .tint(.cyan)
            }
        }
    }
}

struct ModernSummaryRow: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            ModernSubtitle(title)
            Spacer()
            Text(value)
                .font(.body)
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
