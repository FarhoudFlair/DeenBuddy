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
            VStack {
                // Search results
                if viewModel.isLoading {
                    LoadingView(message: "Searching prayer guides...")
                } else if filteredGuides.isEmpty {
                    EmptyStateView(
                        title: "No Results",
                        message: hasActiveFilters ? 
                            "No guides match your search criteria" : 
                            "Start typing to search prayer guides",
                        systemImage: "magnifyingglass"
                    )
                } else {
                    List {
                        // Active filters section
                        if hasActiveFilters {
                            Section("Active Filters") {
                                activeFiltersView
                            }
                        }
                        
                        // Search results
                        Section("Results (\(filteredGuides.count))") {
                            ForEach(filteredGuides) { guide in
                                NavigationLink(destination: PrayerGuideDetailView(guide: guide)) {
                                    PrayerGuideRowView(guide: guide)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search prayer guides...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Filters") {
                        showingFilters = true
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                FilterView(
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Filters")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Clear All") {
                    clearAllFilters()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let selectedPrayer = selectedPrayer {
                        FilterChip(
                            title: selectedPrayer.displayName,
                            color: selectedPrayer.color
                        ) {
                            self.selectedPrayer = nil
                        }
                    }
                    
                    if let selectedMadhab = selectedMadhab {
                        FilterChip(
                            title: selectedMadhab.sectDisplayName,
                            color: selectedMadhab.color
                        ) {
                            self.selectedMadhab = nil
                        }
                    }
                    
                    if let selectedDifficulty = selectedDifficulty {
                        FilterChip(
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

struct FilterChip: View {
    let title: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(12)
    }
}

struct FilterView: View {
    @Binding var selectedPrayer: Prayer?
    @Binding var selectedMadhab: Madhab?
    @Binding var selectedDifficulty: PrayerGuide.Difficulty?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Prayer Time") {
                    Picker("Prayer", selection: $selectedPrayer) {
                        Text("All Prayers").tag(Prayer?.none)
                        ForEach(Prayer.allCases, id: \.self) { prayer in
                            Text(prayer.displayName).tag(Prayer?.some(prayer))
                        }
                    }
                }
                
                Section("Tradition") {
                    Picker("Tradition", selection: $selectedMadhab) {
                        Text("All Traditions").tag(Madhab?.none)
                        ForEach(Madhab.allCases, id: \.self) { madhab in
                            Text(madhab.sectDisplayName).tag(Madhab?.some(madhab))
                        }
                    }
                }
                
                Section("Difficulty") {
                    Picker("Difficulty", selection: $selectedDifficulty) {
                        Text("All Levels").tag(PrayerGuide.Difficulty?.none)
                        ForEach(PrayerGuide.Difficulty.allCases, id: \.self) { difficulty in
                            Text(difficulty.displayName).tag(PrayerGuide.Difficulty?.some(difficulty))
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        selectedPrayer = nil
                        selectedMadhab = nil
                        selectedDifficulty = nil
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SearchView(viewModel: PrayerGuideViewModel())
}
