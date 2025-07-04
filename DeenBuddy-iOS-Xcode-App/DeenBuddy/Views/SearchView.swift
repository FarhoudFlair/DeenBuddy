//
//  SearchView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-03.
//

import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: PrayerGuideViewModel
    @State private var searchText = ""
    @State private var selectedPrayer: Prayer?
    @State private var selectedMadhab: Madhab?
    @State private var selectedDifficulty: PrayerGuide.Difficulty?
    @State private var showingFilters = false
    
    private var filteredGuides: [PrayerGuide] {
        var guides = viewModel.prayerGuides
        
        // Apply text search
        if !searchText.isEmpty {
            guides = guides.filter { guide in
                guide.title.localizedCaseInsensitiveContains(searchText) ||
                guide.prayer.displayName.localizedCaseInsensitiveContains(searchText) ||
                guide.description.localizedCaseInsensitiveContains(searchText) ||
                guide.sectDisplayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply prayer filter
        if let selectedPrayer = selectedPrayer {
            guides = guides.filter { $0.prayer == selectedPrayer }
        }
        
        // Apply madhab filter
        if let selectedMadhab = selectedMadhab {
            guides = guides.filter { $0.madhab == selectedMadhab }
        }
        
        // Apply difficulty filter
        if let selectedDifficulty = selectedDifficulty {
            guides = guides.filter { $0.difficulty == selectedDifficulty }
        }
        
        return guides.sorted { $0.prayer.rawValue < $1.prayer.rawValue }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark background
                ModernGradientBackground()

                VStack {
                    // Search results
                    if viewModel.isLoading {
                        ModernLoadingView(message: "Searching prayer guides...")
                    } else if filteredGuides.isEmpty {
                        ModernEmptyState(
                            title: "No Results",
                            message: hasActiveFilters ?
                                "No guides match your search criteria" :
                                "Start typing to search prayer guides",
                            systemImage: "magnifyingglass"
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                // Active filters section
                                if hasActiveFilters {
                                    ModernCard {
                                        VStack(alignment: .leading, spacing: 12) {
                                            HStack {
                                                ModernTitle("Active Filters")
                                                Spacer()
                                                Button("Clear All") {
                                                    clearAllFilters()
                                                }
                                                .buttonStyle(SecondaryModernButtonStyle())
                                            }

                                            activeFiltersView
                                        }
                                        .padding()
                                    }
                                    .padding(.horizontal)
                                }

                                // Search results
                                ModernCard {
                                    VStack(spacing: 0) {
                                        HStack {
                                            ModernTitle("Results (\(filteredGuides.count))")
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
                            }
                            .padding(.vertical)
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .searchable(text: $searchText, prompt: "Search prayer guides...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Filters") {
                        showingFilters = true
                    }
                    .foregroundColor(.cyan)
                }
            }
            .sheet(isPresented: $showingFilters) {
                ModernFilterView(
                    selectedPrayer: $selectedPrayer,
                    selectedMadhab: $selectedMadhab,
                    selectedDifficulty: $selectedDifficulty
                )
            }
        }
    }
    
    private var hasActiveFilters: Bool {
        selectedPrayer != nil || selectedMadhab != nil || selectedDifficulty != nil
    }
    
    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let selectedPrayer = selectedPrayer {
                    ModernFilterChip(
                        title: selectedPrayer.displayName,
                        color: selectedPrayer.color
                    ) {
                        self.selectedPrayer = nil
                    }
                }

                if let selectedMadhab = selectedMadhab {
                    ModernFilterChip(
                        title: selectedMadhab.sectDisplayName,
                        color: selectedMadhab.color
                    ) {
                        self.selectedMadhab = nil
                    }
                }

                if let selectedDifficulty = selectedDifficulty {
                    ModernFilterChip(
                        title: selectedDifficulty.displayName,
                        color: difficultyColor(selectedDifficulty)
                    ) {
                        self.selectedDifficulty = nil
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }
    
    private func clearAllFilters() {
        selectedPrayer = nil
        selectedMadhab = nil
        selectedDifficulty = nil
    }
    
    private func difficultyColor(_ difficulty: PrayerGuide.Difficulty) -> Color {
        switch difficulty {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
}

struct ModernFilterChip: View {
    let title: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(16)
    }
}

struct ModernPrayerGuideRow: View {
    let guide: PrayerGuide

    var body: some View {
        HStack(spacing: 12) {
            // Prayer icon
            Image(systemName: guide.prayer.systemImageName)
                .font(.title3)
                .foregroundColor(guide.prayer.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(guide.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    ModernStatusIndicator(
                        status: guide.prayer.displayName,
                        color: guide.prayer.color
                    )

                    ModernStatusIndicator(
                        status: guide.madhab.sectDisplayName,
                        color: guide.madhab.color
                    )
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding()
    }
}

struct ModernFilterView: View {
    @Binding var selectedPrayer: Prayer?
    @Binding var selectedMadhab: Madhab?
    @Binding var selectedDifficulty: PrayerGuide.Difficulty?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ModernGradientBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                ModernTitle("Prayer Time")

                                Picker("Prayer", selection: $selectedPrayer) {
                                    Text("All Prayers").tag(Prayer?.none)
                                    ForEach(Prayer.allCases, id: \.self) { prayer in
                                        Text(prayer.displayName).tag(Prayer?.some(prayer))
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.cyan)
                            }
                            .padding()
                        }

                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                ModernTitle("Tradition")

                                Picker("Tradition", selection: $selectedMadhab) {
                                    Text("All Traditions").tag(Madhab?.none)
                                    ForEach(Madhab.allCases, id: \.self) { madhab in
                                        Text(madhab.sectDisplayName).tag(Madhab?.some(madhab))
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.cyan)
                            }
                            .padding()
                        }

                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                ModernTitle("Difficulty")

                                Picker("Difficulty", selection: $selectedDifficulty) {
                                    Text("All Levels").tag(PrayerGuide.Difficulty?.none)
                                    ForEach(PrayerGuide.Difficulty.allCases, id: \.self) { difficulty in
                                        Text(difficulty.displayName).tag(PrayerGuide.Difficulty?.some(difficulty))
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.cyan)
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        selectedPrayer = nil
                        selectedMadhab = nil
                        selectedDifficulty = nil
                    }
                    .foregroundColor(.cyan)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
        }
    }
}

#Preview {
    SearchView(viewModel: PrayerGuideViewModel())
}
