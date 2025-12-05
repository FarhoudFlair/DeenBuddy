import SwiftUI

// MARK: - Verse Result Card

struct VerseResultCard: View {
    let result: QuranSearchResult
    let isBookmarked: Bool
    let onTap: () -> Void
    let onBookmark: () -> Void

    @State private var cachedHighlightedText: AttributedString?

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with reference and bookmark
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.verse.reference)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ColorPalette.primary)
                        
                        Text(result.verse.surahNameArabic)
                            .font(.caption)
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        // Match type indicator
                        MatchTypeIndicator(matchType: result.matchType)
                        
                        // Bookmark button
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .foregroundColor(isBookmarked ? ColorPalette.primary : ColorPalette.textTertiary)
                            .onTapGesture(perform: onBookmark)
                            .accessibilityLabel(isBookmarked ? "Remove Bookmark" : "Add Bookmark")
                            .accessibilityAddTraits(.isButton)
                    }
                }
                
                // Arabic text
                Text(result.verse.textArabic)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(ColorPalette.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.vertical, 4)
                
                // Translation with highlighting (supports bold+italic markdown)
                Text(cachedHighlightedText ?? AttributedString(result.highlightedText))
                    .font(.body)
                    .foregroundColor(ColorPalette.textPrimary)
                    .multilineTextAlignment(.leading)
                
                // Transliteration if available
                if let transliteration = result.verse.textTransliteration {
                    Text(transliteration)
                        .font(.caption)
                        .italic()
                        .foregroundColor(ColorPalette.textSecondary)
                }
                
                // Context suggestions
                if !result.contextSuggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(result.contextSuggestions, id: \.self) { suggestion in
                                Text(suggestion)
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
                
                // Relevance score (for debugging - can be hidden in production)
                #if DEBUG
                HStack {
                    Spacer()
                    Text("Score: \(result.relevanceScore, specifier: "%.1f")")
                        .font(.caption2)
                        .foregroundColor(ColorPalette.textTertiary)
                }
                #endif
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
        .task(id: result.highlightedText) {
            cachedHighlightedText = attributedHighlight(from: result.highlightedText)
        }
    }
}

// MARK: - Match Type Indicator

struct MatchTypeIndicator: View {
    let matchType: MatchType
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(matchType.color)
                .frame(width: 6, height: 6)
            
            Text(matchType.displayName)
                .font(.caption2)
                .foregroundColor(matchType.color)
        }
    }
}

extension MatchType {
    var color: Color {
        switch self {
        case .exact:
            return .green
        case .partial:
            return .orange
        case .semantic:
            return .cyan
        case .thematic:
            return .blue
        case .keyword:
            return .purple
        }
    }
}

// MARK: - Highlight Utility

private func attributedHighlight(from text: String) -> AttributedString {
    var options = AttributedString.MarkdownParsingOptions()
    options.interpretedSyntax = .full
    options.allowsExtendedAttributes = true

    if let attributed = try? AttributedString(markdown: text, options: options) {
        return attributed
    }
    return AttributedString(text)
}

// MARK: - Verse Detail View

struct VerseDetailView: View {
    let verse: QuranVerse
    let searchService: QuranSearchService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verse.reference)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ColorPalette.primary)
                        
                        Text(verse.surahNameArabic)
                            .font(.title3)
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    
                    Divider()
                    
                    // Arabic text
                    VStack(alignment: .trailing, spacing: 12) {
                        Text("Arabic Text")
                            .font(.headline)
                            .foregroundColor(ColorPalette.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(verse.textArabic)
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(ColorPalette.textPrimary)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding()
                            .background(ColorPalette.backgroundSecondary)
                            .cornerRadius(12)
                    }
                    
                    // Translation
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Translation")
                            .font(.headline)
                            .foregroundColor(ColorPalette.textPrimary)
                        
                        Text(verse.textTranslation)
                            .font(.body)
                            .foregroundColor(ColorPalette.textPrimary)
                            .padding()
                            .background(ColorPalette.backgroundSecondary)
                            .cornerRadius(12)
                    }
                    
                    // Transliteration
                    if let transliteration = verse.textTransliteration {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Transliteration")
                                .font(.headline)
                                .foregroundColor(ColorPalette.textPrimary)
                            
                            Text(transliteration)
                                .font(.body)
                                .italic()
                                .foregroundColor(ColorPalette.textSecondary)
                                .padding()
                                .background(ColorPalette.backgroundSecondary)
                                .cornerRadius(12)
                        }
                    }
                    
                    // Verse Information
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Verse Information")
                            .font(.headline)
                            .foregroundColor(ColorPalette.textPrimary)
                        
                        VStack(spacing: 8) {
                            InfoRow(label: "Revelation", value: verse.revelationPlace.displayName)
                            InfoRow(label: "Juz", value: "\(verse.juzNumber)")
                            InfoRow(label: "Page", value: "\(verse.pageNumber)")
                            InfoRow(label: "Ruku", value: "\(verse.rukuNumber)")
                        }
                        .padding()
                        .background(ColorPalette.backgroundSecondary)
                        .cornerRadius(12)
                    }
                    
                    // Themes
                    if !verse.themes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Themes")
                                .font(.headline)
                                .foregroundColor(ColorPalette.textPrimary)
                            
                            FlowLayout(items: verse.themes) { theme in
                                Text(theme.capitalized)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(ColorPalette.primary.opacity(0.1))
                                    .foregroundColor(ColorPalette.primary)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    
                    // Keywords
                    if !verse.keywords.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Keywords")
                                .font(.headline)
                                .foregroundColor(ColorPalette.textPrimary)
                            
                            FlowLayout(items: verse.keywords) { keyword in
                                Text(keyword.capitalized)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(ColorPalette.secondary.opacity(0.1))
                                    .foregroundColor(ColorPalette.secondary)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(ColorPalette.backgroundPrimary)
            .navigationTitle("Verse Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        searchService.toggleBookmark(for: verse)
                    }) {
                        Image(systemName: searchService.isBookmarked(verse) ? "bookmark.fill" : "bookmark")
                            .foregroundColor(ColorPalette.primary)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Components

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(ColorPalette.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ColorPalette.textPrimary)
        }
    }
}

struct FlowLayout<Item: Hashable, ItemView: View>: View {
    let items: [Item]
    let itemView: (Item) -> ItemView
    
    // Minimum width for each item (can be adjusted as needed)
    private let minItemWidth: CGFloat = 100
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let itemsPerRow = max(1, Int(width / minItemWidth))
            let rows = chunked(items: items, into: itemsPerRow)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, chunk in
                    HStack(spacing: 8) {
                        ForEach(chunk, id: \.self) { item in
                            itemView(item)
                        }
                        Spacer()
                    }
                }
            }
        }
    }
    
    // Helper to chunk items into rows
    private func chunked(items: [Item], into size: Int) -> [[Item]] {
        guard size > 0 else { return [items] }
        return stride(from: 0, to: items.count, by: size).map {
            Array(items[$0..<Swift.min($0 + size, items.count)])
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Enhanced Search Components

/// Enhanced verse result card with semantic search features
struct EnhancedVerseResultCard: View {
    let result: EnhancedSearchResult
    let isBookmarked: Bool
    let onTap: () -> Void
    let onBookmark: () -> Void
    let onRelatedTap: (QuranVerse) -> Void

    @State private var cachedHighlightedText: AttributedString?

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with reference and metrics
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.verse.reference)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ColorPalette.primary)
                        
                        Text(result.verse.surahNameArabic)
                            .font(.caption)
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        // Match type indicator
                        MatchTypeIndicator(matchType: result.matchType)
                        
                        // Bookmark button
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .foregroundColor(isBookmarked ? ColorPalette.primary : ColorPalette.textTertiary)
                            .onTapGesture(perform: onBookmark)
                            .accessibilityLabel(isBookmarked ? "Remove Bookmark" : "Add Bookmark")
                            .accessibilityAddTraits(.isButton)
                    }
                }
                
                // Arabic text
                Text(result.verse.textArabic)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(ColorPalette.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.vertical, 4)
                
                // Highlighted translation
                Text(cachedHighlightedText ?? AttributedString(result.highlightedText))
                    .font(.body)
                    .foregroundColor(ColorPalette.textPrimary)
                    .multilineTextAlignment(.leading)
                
                // Transliteration if available
                if let transliteration = result.verse.textTransliteration {
                    Text(transliteration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
                
                // Context suggestions
                if !result.contextSuggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(result.contextSuggestions.prefix(4), id: \.self) { suggestion in
                                Text(suggestion)
                                    .font(.caption)
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
                
                // Related verses
                if !result.relatedVerses.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Related Verses")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(ColorPalette.textSecondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(result.relatedVerses.prefix(3)) { relatedVerse in
                                    Button(action: {
                                        onRelatedTap(relatedVerse)
                                    }) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(relatedVerse.shortReference)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(ColorPalette.primary)
                                            
                                            Text(relatedVerse.textTranslation)
                                                .font(.caption2)
                                                .foregroundColor(ColorPalette.textSecondary)
                                                .lineLimit(2)
                                        }
                                        .frame(width: 120, alignment: .leading)
                                        .padding(6)
                                        .background(ColorPalette.surfaceSecondary)
                                        .cornerRadius(6)
                                    }
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                    }
                }
            }
            .padding()
            .background(ColorPalette.surface)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .task(id: result.highlightedText) {
            cachedHighlightedText = attributedHighlight(from: result.highlightedText)
        }
    }
}

/// Query expansion card showing search intelligence
struct QueryExpansionCard: View {
    let expansion: QueryExpansion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(ColorPalette.primary)
                
                Text("Search Intelligence")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ColorPalette.textPrimary)
                
                Spacer()
                
                Text(expansion.queryType.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ColorPalette.primary.opacity(0.1))
                    .foregroundColor(ColorPalette.primary)
                    .cornerRadius(4)
            }
            
            // Typo correction
            if let correctedQuery = expansion.correctedQuery {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text("Corrected to: \"\(correctedQuery)\"")
                        .font(.caption)
                        .foregroundColor(ColorPalette.textSecondary)
                }
            }
            
            // Expanded terms
            if !expansion.expandedTerms.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Also searching for:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(expansion.expandedTerms.prefix(6), id: \.self) { term in
                                Text(term)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(ColorPalette.accent.opacity(0.1))
                                    .foregroundColor(ColorPalette.accent)
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
            
            // Related concepts
            if !expansion.relatedConcepts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Related concepts:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(expansion.relatedConcepts.prefix(4), id: \.self) { concept in
                                Text(concept)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(ColorPalette.secondary.opacity(0.1))
                                    .foregroundColor(ColorPalette.secondary)
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
        }
        .padding()
        .background(ColorPalette.backgroundSecondary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ColorPalette.primary.opacity(0.2), lineWidth: 1)
        )
    }
}
