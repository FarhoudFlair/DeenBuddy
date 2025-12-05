import SwiftUI

/// Comprehensive Quran search interface with advanced search capabilities
struct QuranSearchView: View {
    @StateObject private var searchService = QuranSearchService.shared
    @State private var searchText = ""
    @State private var showingSearchOptions = false
    @State private var searchOptions = QuranSearchOptions()
    @State private var selectedVerse: QuranVerse?
    @State private var showingVerseDetail = false

    @State private var showingHistory = false
    @State private var showingQueryExpansion = false
    @State private var isStatusExpanded = false
    
    // Search debouncing and cancellation
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                ColorPalette.backgroundPrimary.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search header with options
                    searchHeaderView

                    dataStatusBanner
                    
                    // Main content - prioritize welcome view over background loading
                    if searchService.isLoading && !searchService.lastQuery.isEmpty {
                        // Only show loading for active user searches, not background data loading
                        loadingView
                    } else if !searchService.enhancedSearchResults.isEmpty {
                        enhancedSearchResultsView
                    } else if !searchService.lastQuery.isEmpty && !searchService.isLoading {
                        emptyResultsView
                    } else {
                        // Show welcome view immediately, even during background loading
                        welcomeViewWithDataStatus
                    }
                }
            }
            .navigationTitle("Quran Search")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search verses, themes, or references...")
            .onSubmit(of: .search) {
                performSearch()
            }
            .onChange(of: searchText) { newValue in
                // Generate real-time suggestions as user types
                if newValue.isEmpty {
                    // Clear state back to welcome view when search is cleared
                    searchTask?.cancel()
                    searchService.clearSearchState()
                } else {
                    // Debounce suggestion generation to avoid excessive work during typing
                    searchTask?.cancel()
                    let pendingQuery = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    searchTask = Task {
                        do {
                            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                        } catch {
                            return // Task cancelled
                        }
                        
                        guard !Task.isCancelled else { return }
                        guard !pendingQuery.isEmpty else { return }
                        
                        await MainActor.run {
                            await searchService.generateSearchSuggestions(for: pendingQuery)
                        }
                    }
                }
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
            .onAppear {
                searchService.startBackgroundPrefetch()
            }
            .onChange(of: searchService.dataValidationResult?.hasErrors ?? false) { hasErrors in
                if hasErrors {
                    isStatusExpanded = true
                }
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

    @ViewBuilder
    private var dataStatusBanner: some View {
        if shouldShowStatusCard {
            if isStatusExpanded ||
                (searchService.dataValidationResult?.hasErrors ?? false) {
                QuranDataStatusView(searchService: searchService)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                QuranDownloadBannerView(
                    searchService: searchService,
                    isExpanded: $isStatusExpanded
                )
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
    }

    private var shouldShowStatusCard: Bool {
        searchService.isBackgroundLoading ||
        !searchService.isCompleteDataLoaded() ||
        (searchService.dataValidationResult?.hasErrors ?? false)
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            if searchService.isBackgroundLoading {
                ProgressView(value: searchService.loadingProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: ColorPalette.primary))
                    .frame(maxWidth: 200)
                
                Text("Preparing Quran data...")
                    .font(.headline)
                    .foregroundColor(ColorPalette.textPrimary)
                
                Text("\(Int(searchService.loadingProgress * 100))% complete")
                    .font(.subheadline)
                    .foregroundColor(ColorPalette.textSecondary)
                
                Text("\(searchService.getLoadedVersesCount())/\(QuranDataValidator.EXPECTED_TOTAL_VERSES) verses loaded")
                    .font(.caption)
                    .foregroundColor(ColorPalette.textSecondary)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: ColorPalette.primary))
                    .scaleEffect(1.2)
                
                Text("Searching Quran...")
                    .font(.subheadline)
                    .foregroundColor(ColorPalette.textSecondary)
            }
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
    private var enhancedSearchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Query expansion info
                if let expansion = searchService.queryExpansion {
                    QueryExpansionCard(expansion: expansion)
                }
                
                // Search results
                ForEach(searchService.enhancedSearchResults) { result in
                    EnhancedVerseResultCard(
                        result: result,
                        isBookmarked: searchService.isBookmarked(result.verse),
                        onTap: {
                            selectedVerse = result.verse
                            showingVerseDetail = true
                        },
                        onBookmark: {
                            searchService.toggleBookmark(for: result.verse)
                        },
                        onRelatedTap: { relatedVerse in
                            selectedVerse = relatedVerse
                            showingVerseDetail = true
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
                welcomeHeader(
                    title: "Search the Holy Quran",
                    subtitle: "Find verses by keywords, themes, or references"
                )
                
                // Quick access buttons
                quickAccessButtonsView
                
                // Recent searches
                recentSearchesView
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var welcomeViewWithDataStatus: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Welcome header with enhanced message
                welcomeHeader(
                    title: "What's on your mind?",
                    subtitle: "Find verses that speak to your heart and situation"
                )
                
                // Quick access buttons
                quickAccessButtonsView
                
                // Recent searches
                recentSearchesView
            }
            .padding()
        }
    }
    
    // MARK: - Reusable Components
    
    @ViewBuilder
    private func welcomeHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(ColorPalette.primary)
            
            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(ColorPalette.textPrimary)
            
            Text(subtitle)
                .font(.body)
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil) // Allow unlimited lines to prevent truncation
                .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion
        }
    }
    
    @ViewBuilder
    private var quickAccessButtonsView: some View {
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
    }
    
    @ViewBuilder
    private var recentSearchesView: some View {
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
    
    // MARK: - Actions
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            // Clear results for empty search
            searchService.searchResults = []
            searchService.enhancedSearchResults = []
            return 
        }
        
        // Cancel any existing search task
        searchTask?.cancel()
        
        // Create new debounced search task
        searchTask = Task {
            // Debounce: wait 300ms before executing search
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            } catch {
                // Task was cancelled, which is expected behavior
                return
            }
            
            // Check if task was cancelled during sleep
            guard !Task.isCancelled else { return }
            
            // Perform the actual search
            let queryToSearch = searchText // Capture current value
            
            // Check if it's a reference search (contains numbers and colons)
            if queryToSearch.contains(":") || queryToSearch.range(of: #"\d+"#, options: .regularExpression) != nil {
                await searchService.searchByReference(queryToSearch)
            } else {
                await searchService.searchVerses(query: queryToSearch, searchOptions: searchOptions)
            }
        }
    }
}

// MARK: - Supporting Views

private struct QuranDownloadBannerView: View {
    @ObservedObject var searchService: QuranSearchService
    @Binding var isExpanded: Bool

    private var progressValue: Double {
        max(0.0, min(searchService.loadingProgress, 1.0))
    }

    private var loadedVerseText: String {
        let loaded = searchService.getLoadedVersesCount()
        let total = QuranDataValidator.EXPECTED_TOTAL_VERSES
        return "\(loaded)/\(total) verses"
    }

    var body: some View {
        if searchService.isBackgroundLoading {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    ProgressView(value: progressValue == 0 ? nil : progressValue)
                        .progressViewStyle(.circular)
                        .scaleEffect(0.9)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Downloading Quran • \(Int(progressValue * 100))%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ColorPalette.textPrimary)
                            .lineLimit(1) // Prevent text truncation
                            .minimumScaleFactor(0.8) // Shrink if needed on small devices

                        Text(loadedVerseText)
                            .font(.caption)
                            .foregroundColor(ColorPalette.textSecondary)
                            .lineLimit(1) // Prevent text truncation
                    }
                    .layoutPriority(1) // Give text priority over Spacer

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(ColorPalette.textSecondary)
                }
                .padding()
                .background(ColorPalette.backgroundSecondary)
                .cornerRadius(12)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Quran download progress \(Int(progressValue * 100)) percent. \(loadedVerseText)")
                .accessibilityHint("Double tap to see detailed loading information and validation status.")
            }
            .buttonStyle(.plain)
            .transition(.move(edge: .top).combined(with: .opacity))
        } else if !searchService.isCompleteDataLoaded() {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded = true
                }
                searchService.refreshQuranData()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quran data incomplete")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ColorPalette.textPrimary)
                            .lineLimit(1)

                        Text("Tap to retry download and view details.")
                            .font(.caption)
                            .foregroundColor(ColorPalette.textSecondary)
                            .lineLimit(1)
                    }
                    .layoutPriority(1)

                    Spacer()

                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(ColorPalette.textSecondary)
                        .font(.subheadline)
                }
                .padding()
                .background(ColorPalette.backgroundSecondary)
                .cornerRadius(12)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Quran data incomplete. Double tap to retry download and view details.")
            }
            .buttonStyle(.plain)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

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
