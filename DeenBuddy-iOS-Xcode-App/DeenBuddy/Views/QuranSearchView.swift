import SwiftUI

/// Comprehensive Quran search interface with advanced search capabilities
struct QuranSearchView: View {
    @StateObject private var searchService = QuranSearchService()
    @State private var searchText = ""
    @State private var showingSearchOptions = false
    @State private var searchOptions = QuranSearchOptions()
    @State private var selectedVerse: QuranVerse?
    @State private var showingVerseDetail = false
    @State private var showingHistory = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                ColorPalette.backgroundPrimary.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search header with options
                    searchHeaderView
                    
                    // Main content
                    if searchService.isLoading {
                        loadingView
                    } else if !searchService.searchResults.isEmpty {
                        searchResultsView
                    } else if !searchService.lastQuery.isEmpty {
                        emptyResultsView
                    } else {
                        welcomeView
                    }
                }
            }
            .navigationTitle("Quran Search")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search verses, themes, or references...")
            .onSubmit(of: .search) {
                performSearch()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Search Options", systemImage: "slider.horizontal.3") {
                            showingSearchOptions = true
                        }
                        
                        Button("Search History", systemImage: "clock") {
                            showingHistory = true
                        }
                        
                        Button("Bookmarked Verses", systemImage: "bookmark") {
                            // Navigate to bookmarks
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(ColorPalette.primary)
                    }
                }
            }
            .sheet(isPresented: $showingSearchOptions) {
                SearchOptionsView(options: $searchOptions)
            }
            .sheet(isPresented: $showingHistory) {
                SearchHistoryView(searchService: searchService) { query in
                    searchText = query
                    showingHistory = false
                    performSearch()
                }
            }
            .sheet(item: $selectedVerse) { verse in
                VerseDetailView(verse: verse, searchService: searchService)
            }
        }
    }
    
    // MARK: - Search Header
    
    @ViewBuilder
    private var searchHeaderView: some View {
        VStack(spacing: 12) {
            // Quick search suggestions
            if searchText.isEmpty && !searchService.searchHistory.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(searchService.searchHistory.prefix(5)), id: \.self) { query in
                            Button(query) {
                                searchText = query
                                performSearch()
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(ColorPalette.primary.opacity(0.1))
                            .foregroundColor(ColorPalette.primary)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Search type indicators
            if !searchService.searchResults.isEmpty {
                HStack {
                    Text("\(searchService.searchResults.count) results")
                        .font(.caption)
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    Spacer()
                    
                    Text("for '\(searchService.lastQuery)'")
                        .font(.caption)
                        .foregroundColor(ColorPalette.textSecondary)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ColorPalette.primary))
                .scaleEffect(1.2)
            
            Text("Searching Quran...")
                .font(.subheadline)
                .foregroundColor(ColorPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(searchService.searchResults) { result in
                    VerseResultCard(
                        result: result,
                        isBookmarked: searchService.isBookmarked(result.verse),
                        onTap: {
                            selectedVerse = result.verse
                            showingVerseDetail = true
                        },
                        onBookmark: {
                            searchService.toggleBookmark(for: result.verse)
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var emptyResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(ColorPalette.textTertiary)
            
            Text("No Results Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(ColorPalette.textPrimary)
            
            Text("Try searching with different keywords or check your spelling")
                .font(.body)
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Search suggestions
            VStack(alignment: .leading, spacing: 8) {
                Text("Try searching for:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ColorPalette.textPrimary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Keywords: 'mercy', 'guidance', 'prayer'")
                    Text("• Themes: 'forgiveness', 'patience', 'gratitude'")
                    Text("• References: '2:255', 'Al-Fatiha 1'")
                    Text("• Surah names: 'Al-Baqarah', 'Al-Ikhlas'")
                }
                .font(.caption)
                .foregroundColor(ColorPalette.textSecondary)
            }
            .padding()
            .background(ColorPalette.backgroundSecondary)
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var welcomeView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Welcome header
                VStack(spacing: 12) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 60))
                        .foregroundColor(ColorPalette.primary)
                    
                    Text("Search the Holy Quran")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(ColorPalette.textPrimary)
                    
                    Text("Find verses by keywords, themes, or references")
                        .font(.body)
                        .foregroundColor(ColorPalette.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                // Quick access buttons
                VStack(spacing: 12) {
                    QuickSearchButton(
                        title: "Search by Reference",
                        subtitle: "e.g., 2:255, Al-Fatiha 1",
                        icon: "number.circle",
                        color: .blue
                    ) {
                        searchText = "2:255"
                        performSearch()
                    }
                    
                    QuickSearchButton(
                        title: "Search by Theme",
                        subtitle: "mercy, guidance, prayer",
                        icon: "tag.circle",
                        color: .green
                    ) {
                        searchText = "mercy"
                        performSearch()
                    }
                    
                    QuickSearchButton(
                        title: "Popular Verses",
                        subtitle: "Ayat al-Kursi, Al-Ikhlas",
                        icon: "star.circle",
                        color: .orange
                    ) {
                        searchText = "Ayat al-Kursi"
                        performSearch()
                    }
                }
                
                // Recent searches
                if !searchService.searchHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Searches")
                            .font(.headline)
                            .foregroundColor(ColorPalette.textPrimary)
                        
                        ForEach(Array(searchService.searchHistory.prefix(3)), id: \.self) { query in
                            Button(action: {
                                searchText = query
                                performSearch()
                            }) {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(ColorPalette.textTertiary)
                                    
                                    Text(query)
                                        .foregroundColor(ColorPalette.textPrimary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.left")
                                        .foregroundColor(ColorPalette.textTertiary)
                                }
                                .padding()
                                .background(ColorPalette.backgroundSecondary)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Actions
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        Task {
            // Check if it's a reference search (contains numbers and colons)
            if searchText.contains(":") || searchText.range(of: #"\d+"#, options: .regularExpression) != nil {
                await searchService.searchByReference(searchText)
            } else {
                await searchService.searchVerses(query: searchText, searchOptions: searchOptions)
            }
        }
    }
}

// MARK: - Supporting Views

struct QuickSearchButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ColorPalette.textPrimary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(ColorPalette.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(ColorPalette.textTertiary)
            }
            .padding()
            .background(ColorPalette.backgroundSecondary)
            .cornerRadius(12)
        }
    }
}
