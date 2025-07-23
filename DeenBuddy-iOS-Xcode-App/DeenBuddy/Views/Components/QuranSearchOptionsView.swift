import SwiftUI

// MARK: - Search Options View

struct SearchOptionsView: View {
    @Binding var options: QuranSearchOptions
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Search In") {
                    Toggle("Translation", isOn: $options.searchTranslation)
                    Toggle("Arabic Text", isOn: $options.searchArabic)
                    Toggle("Transliteration", isOn: $options.searchTransliteration)
                }
                
                Section("Advanced Search") {
                    Toggle("Themes", isOn: $options.searchThemes)
                    Toggle("Keywords", isOn: $options.searchKeywords)
                }
                
                Section("Results") {
                    HStack {
                        Text("Maximum Results")
                        Spacer()
                        Picker("Max Results", selection: $options.maxResults) {
                            Text("25").tag(25)
                            Text("50").tag(50)
                            Text("100").tag(100)
                            Text("All").tag(1000)
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Section("Search Tips") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Use specific keywords for better results")
                        Text("• Search by reference: '2:255' or 'Al-Fatiha 1'")
                        Text("• Try theme-based searches: 'mercy', 'guidance'")
                        Text("• Arabic search works with Arabic text")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Search Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Search History View

struct SearchHistoryView: View {
    let searchService: QuranSearchService
    let onSelectQuery: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if searchService.searchHistory.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text("No Search History")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Your recent searches will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(searchService.searchHistory, id: \.self) { query in
                        Button(action: {
                            onSelectQuery(query)
                        }) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.secondary)
                                
                                Text(query)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.left")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Delete", role: .destructive) {
                                searchService.removeFromHistory(query)
                            }
                        }
                    }
                    
                    Section {
                        Button("Clear All History", role: .destructive) {
                            searchService.clearSearchHistory()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Search History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Bookmarked Verses View

struct BookmarkedVersesView: View {
    @ObservedObject var searchService: QuranSearchService
    @State private var selectedVerse: QuranVerse?
    @State private var showingVerseDetail = false
    
    var body: some View {
        NavigationView {
            Group {
                if searchService.bookmarkedVerses.isEmpty {
                    emptyBookmarksView
                } else {
                    bookmarksListView
                }
            }
            .navigationTitle("Bookmarked Verses")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedVerse) { verse in
                VerseDetailView(verse: verse, searchService: searchService)
            }
        }
    }
    
    @ViewBuilder
    private var emptyBookmarksView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bookmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Bookmarked Verses")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Bookmark verses while searching to save them here for quick access")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var bookmarksListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(searchService.bookmarkedVerses) { verse in
                    BookmarkedVerseCard(
                        verse: verse,
                        onTap: {
                            selectedVerse = verse
                            showingVerseDetail = true
                        },
                        onRemoveBookmark: {
                            searchService.toggleBookmark(for: verse)
                        }
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Bookmarked Verse Card

struct BookmarkedVerseCard: View {
    let verse: QuranVerse
    let onTap: () -> Void
    let onRemoveBookmark: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verse.reference)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ColorPalette.primary)
                        
                        Text(verse.surahNameArabic)
                            .font(.caption)
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "bookmark.fill")
                        .foregroundColor(ColorPalette.primary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onRemoveBookmark()
                        }
                }
                
                // Arabic text (truncated)
                Text(verse.textArabic)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(ColorPalette.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .lineLimit(2)
                
                // Translation (truncated)
                Text(verse.textTranslation)
                    .font(.subheadline)
                    .foregroundColor(ColorPalette.textSecondary)
                    .lineLimit(3)
                
                // Themes
                if !verse.themes.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(verse.themes.prefix(4)), id: \.self) { theme in
                                Text(theme.capitalized)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(ColorPalette.primary.opacity(0.1))
                                    .foregroundColor(ColorPalette.primary)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
            .padding()
            .background(ColorPalette.backgroundSecondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ColorPalette.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#if DEBUG
struct SearchOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        SearchOptionsView(options: .constant(QuranSearchOptions()))
    }
}

struct SearchHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        SearchHistoryView(searchService: QuranSearchService.shared) { _ in }
    }
}
#endif
