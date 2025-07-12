import Foundation
import Combine

/// Comprehensive Quran search service with advanced search capabilities
@MainActor
public class QuranSearchService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var searchResults: [QuranSearchResult] = []
    @Published public var isLoading = false
    @Published public var error: Error?
    @Published public var lastQuery = ""
    @Published public var searchHistory: [String] = []
    @Published public var bookmarkedVerses: [QuranVerse] = []
    
    // MARK: - Private Properties
    
    private var allVerses: [QuranVerse] = []
    private var allSurahs: [QuranSurah] = []
    private let userDefaults = UserDefaults.standard
    private let maxHistoryItems = 20
    
    // MARK: - Cache Keys
    
    private enum CacheKeys {
        static let searchHistory = "QuranSearchHistory"
        static let bookmarkedVerses = "BookmarkedQuranVerses"
    }
    
    // MARK: - Initialization
    
    public init() {
        loadSampleData()
        loadSearchHistory()
        loadBookmarkedVerses()
    }

    // MARK: - Sample Data Loading

    private func loadSampleData() {
        // Load comprehensive sample Quran data
        allVerses = createSampleVerses()
        allSurahs = createSampleSurahs()
    }

    private func createSampleVerses() -> [QuranVerse] {
        return [
            // Al-Fatiha (Chapter 1)
            QuranVerse(
                surahNumber: 1, surahName: "Al-Fatiha", surahNameArabic: "الفاتحة",
                verseNumber: 1, textArabic: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
                textTranslation: "In the name of Allah, the Entirely Merciful, the Especially Merciful.",
                textTransliteration: "Bismillahi r-rahmani r-raheem",
                revelationPlace: .mecca, juzNumber: 1, hizbNumber: 1, rukuNumber: 1, manzilNumber: 1, pageNumber: 1,
                themes: ["mercy", "compassion", "beginning", "prayer", "Allah"],
                keywords: ["Allah", "Rahman", "Raheem", "mercy", "compassion", "name"]
            ),
            QuranVerse(
                surahNumber: 1, surahName: "Al-Fatiha", surahNameArabic: "الفاتحة",
                verseNumber: 2, textArabic: "الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ",
                textTranslation: "All praise is due to Allah, Lord of the worlds.",
                textTransliteration: "Alhamdu lillahi rabbi l-alameen",
                revelationPlace: .mecca, juzNumber: 1, hizbNumber: 1, rukuNumber: 1, manzilNumber: 1, pageNumber: 1,
                themes: ["praise", "gratitude", "lordship", "creation", "worlds"],
                keywords: ["praise", "Allah", "Lord", "worlds", "creation", "gratitude"]
            ),

            // Al-Baqarah (Chapter 2) - Famous verses
            QuranVerse(
                surahNumber: 2, surahName: "Al-Baqarah", surahNameArabic: "البقرة",
                verseNumber: 255, textArabic: "اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ",
                textTranslation: "Allah - there is no deity except Him, the Ever-Living, the Sustainer of existence.",
                textTransliteration: "Allahu la ilaha illa huwa l-hayyu l-qayyoom",
                revelationPlace: .medina, juzNumber: 3, hizbNumber: 5, rukuNumber: 35, manzilNumber: 1, pageNumber: 42,
                themes: ["monotheism", "Allah", "life", "sustenance", "throne", "protection"],
                keywords: ["Allah", "deity", "living", "sustainer", "throne", "Ayat al-Kursi"]
            ),
            QuranVerse(
                surahNumber: 2, surahName: "Al-Baqarah", surahNameArabic: "البقرة",
                verseNumber: 286, textArabic: "لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا",
                textTranslation: "Allah does not charge a soul except with that within its capacity.",
                textTransliteration: "La yukallifu llahu nafsan illa wus'aha",
                revelationPlace: .medina, juzNumber: 3, hizbNumber: 6, rukuNumber: 40, manzilNumber: 1, pageNumber: 49,
                themes: ["mercy", "capacity", "burden", "justice", "forgiveness"],
                keywords: ["Allah", "soul", "capacity", "burden", "mercy", "justice"]
            ),

            // Al-Ikhlas (Chapter 112) - Complete chapter
            QuranVerse(
                surahNumber: 112, surahName: "Al-Ikhlas", surahNameArabic: "الإخلاص",
                verseNumber: 1, textArabic: "قُلْ هُوَ اللَّهُ أَحَدٌ",
                textTranslation: "Say, He is Allah, the One!",
                textTransliteration: "Qul huwa llahu ahad",
                revelationPlace: .mecca, juzNumber: 30, hizbNumber: 60, rukuNumber: 1, manzilNumber: 7, pageNumber: 604,
                themes: ["monotheism", "unity", "oneness", "Allah"],
                keywords: ["Allah", "one", "unity", "monotheism", "say"]
            ),
            QuranVerse(
                surahNumber: 112, surahName: "Al-Ikhlas", surahNameArabic: "الإخلاص",
                verseNumber: 2, textArabic: "اللَّهُ الصَّمَدُ",
                textTranslation: "Allah, the Eternal Refuge.",
                textTransliteration: "Allahu s-samad",
                revelationPlace: .mecca, juzNumber: 30, hizbNumber: 60, rukuNumber: 1, manzilNumber: 7, pageNumber: 604,
                themes: ["eternity", "refuge", "independence", "Allah"],
                keywords: ["Allah", "eternal", "refuge", "samad", "independent"]
            ),

            // More verses for comprehensive search testing
            QuranVerse(
                surahNumber: 3, surahName: "Ali 'Imran", surahNameArabic: "آل عمران",
                verseNumber: 185, textArabic: "كُلُّ نَفْسٍ ذَائِقَةُ الْمَوْتِ",
                textTranslation: "Every soul will taste death.",
                textTransliteration: "Kullu nafsin dha'iqatu l-mawt",
                revelationPlace: .medina, juzNumber: 4, hizbNumber: 8, rukuNumber: 19, manzilNumber: 2, pageNumber: 75,
                themes: ["death", "mortality", "soul", "certainty", "afterlife"],
                keywords: ["soul", "death", "taste", "mortality", "certainty"]
            ),
            QuranVerse(
                surahNumber: 24, surahName: "An-Nur", surahNameArabic: "النور",
                verseNumber: 35, textArabic: "اللَّهُ نُورُ السَّمَاوَاتِ وَالْأَرْضِ",
                textTranslation: "Allah is the light of the heavens and the earth.",
                textTransliteration: "Allahu nuru s-samawati wa l-ard",
                revelationPlace: .medina, juzNumber: 18, hizbNumber: 36, rukuNumber: 5, manzilNumber: 4, pageNumber: 353,
                themes: ["light", "guidance", "heavens", "earth", "divine", "illumination"],
                keywords: ["Allah", "light", "heavens", "earth", "guidance", "divine"]
            ),
            QuranVerse(
                surahNumber: 55, surahName: "Ar-Rahman", surahNameArabic: "الرحمن",
                verseNumber: 13, textArabic: "فَبِأَيِّ آلَاءِ رَبِّكُمَا تُكَذِّبَانِ",
                textTranslation: "So which of the favors of your Lord would you deny?",
                textTransliteration: "Fabi-ayyi ala'i rabbikuma tukadhdhibaan",
                revelationPlace: .mecca, juzNumber: 27, hizbNumber: 53, rukuNumber: 2, manzilNumber: 6, pageNumber: 531,
                themes: ["blessings", "gratitude", "favors", "Lord", "denial"],
                keywords: ["favors", "Lord", "deny", "blessings", "gratitude"]
            )
        ]
    }

    private func createSampleSurahs() -> [QuranSurah] {
        return [
            QuranSurah(
                number: 1, name: "Al-Fatiha", nameArabic: "الفاتحة",
                nameTransliteration: "Al-Faatihah", meaning: "The Opening",
                verseCount: 7, revelationPlace: .mecca, revelationOrder: 5,
                description: "The opening chapter of the Quran, recited in every prayer.",
                themes: ["prayer", "guidance", "mercy", "worship"]
            ),
            QuranSurah(
                number: 2, name: "Al-Baqarah", nameArabic: "البقرة",
                nameTransliteration: "Al-Baqarah", meaning: "The Cow",
                verseCount: 286, revelationPlace: .medina, revelationOrder: 87,
                description: "The longest chapter, covering law, guidance, and stories.",
                themes: ["law", "guidance", "stories", "faith"]
            ),
            QuranSurah(
                number: 112, name: "Al-Ikhlas", nameArabic: "الإخلاص",
                nameTransliteration: "Al-Ikhlaas", meaning: "The Sincerity",
                verseCount: 4, revelationPlace: .mecca, revelationOrder: 22,
                description: "Declaration of Allah's absolute unity and uniqueness.",
                themes: ["monotheism", "unity", "sincerity"]
            )
        ]
    }
    
    // MARK: - Public Search Methods
    
    /// Perform comprehensive search across Quran verses
    public func searchVerses(query: String, searchOptions: QuranSearchOptions = QuranSearchOptions()) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        error = nil
        lastQuery = query
        
        do {
            // Add to search history
            addToSearchHistory(query)
            
            // Perform search with slight delay to simulate processing
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            let results = performSearch(query: query, options: searchOptions)
            searchResults = results.sorted { $0.relevanceScore > $1.relevanceScore }
            
        } catch {
            self.error = error
            searchResults = []
        }
        
        isLoading = false
    }
    
    /// Search by Surah and verse reference (e.g., "2:255" or "Al-Baqarah 255")
    public func searchByReference(_ reference: String) async {
        isLoading = true
        error = nil
        
        let results = searchByVerseReference(reference)
        searchResults = results
        
        isLoading = false
    }
    
    /// Get verses from a specific Surah
    public func getVersesFromSurah(_ surahNumber: Int, verseRange: ClosedRange<Int>? = nil) -> [QuranVerse] {
        let surahVerses = allVerses.filter { $0.surahNumber == surahNumber }
        
        if let range = verseRange {
            return surahVerses.filter { range.contains($0.verseNumber) }
        }
        
        return surahVerses.sorted { $0.verseNumber < $1.verseNumber }
    }
    
    /// Get all Surahs with basic information
    public func getAllSurahs() -> [QuranSurah] {
        return allSurahs.sorted { $0.number < $1.number }
    }
    
    // MARK: - Bookmark Management
    
    public func toggleBookmark(for verse: QuranVerse) {
        if let index = bookmarkedVerses.firstIndex(where: { $0.id == verse.id }) {
            bookmarkedVerses.remove(at: index)
        } else {
            bookmarkedVerses.append(verse)
        }
        saveBookmarkedVerses()
    }
    
    public func isBookmarked(_ verse: QuranVerse) -> Bool {
        return bookmarkedVerses.contains { $0.id == verse.id }
    }
    
    // MARK: - Search History Management
    
    public func clearSearchHistory() {
        searchHistory.removeAll()
        userDefaults.removeObject(forKey: CacheKeys.searchHistory)
    }
    
    public func removeFromHistory(_ query: String) {
        searchHistory.removeAll { $0 == query }
        saveSearchHistory()
    }
    
    // MARK: - Private Methods
    
    private func performSearch(query: String, options: QuranSearchOptions) -> [QuranSearchResult] {
        let lowercasedQuery = query.lowercased()
        var results: [QuranSearchResult] = []
        
        for verse in allVerses {
            if let result = evaluateVerse(verse, for: lowercasedQuery, options: options) {
                results.append(result)
            }
        }
        
        return results
    }
    
    private func evaluateVerse(_ verse: QuranVerse, for query: String, options: QuranSearchOptions) -> QuranSearchResult? {
        var score: Double = 0
        var matchType: MatchType = .partial
        var matchedText = query
        var highlightedText = verse.textTranslation
        
        // Check translation match
        if options.searchTranslation && verse.textTranslation.lowercased().contains(query) {
            score += calculateTranslationScore(verse.textTranslation, query: query)
            matchType = .exact
            highlightedText = highlightMatches(in: verse.textTranslation, query: query)
        }
        
        // Check Arabic text match
        if options.searchArabic && verse.textArabic.lowercased().contains(query) {
            score += 10.0 // Higher score for Arabic matches
            matchType = .exact
        }
        
        // Check transliteration match
        if options.searchTransliteration,
           let transliteration = verse.textTransliteration,
           transliteration.lowercased().contains(query) {
            score += 8.0
            matchType = .exact
        }
        
        // Check theme match
        if options.searchThemes && verse.themes.contains(where: { $0.lowercased().contains(query) }) {
            score += 6.0
            matchType = .thematic
        }
        
        // Check keyword match
        if options.searchKeywords && verse.keywords.contains(where: { $0.lowercased().contains(query) }) {
            score += 5.0
            matchType = .keyword
        }
        
        // Check Surah name match
        if verse.surahName.lowercased().contains(query) || verse.surahNameArabic.contains(query) {
            score += 4.0
            matchType = .semantic
        }
        
        guard score > 0 else { return nil }
        
        return QuranSearchResult(
            verse: verse,
            relevanceScore: score,
            matchedText: matchedText,
            matchType: matchType,
            highlightedText: highlightedText,
            contextSuggestions: generateContextSuggestions(for: verse)
        )
    }
    
    private func calculateTranslationScore(_ text: String, query: String) -> Double {
        let words = query.components(separatedBy: .whitespacesAndNewlines)
        let textWords = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        var score: Double = 0
        
        for word in words {
            if textWords.contains(word.lowercased()) {
                score += 2.0
            }
            
            // Partial word matches
            for textWord in textWords {
                if textWord.contains(word.lowercased()) {
                    score += 1.0
                }
            }
        }
        
        // Bonus for phrase matches
        if text.lowercased().contains(query) {
            score += 5.0
        }
        
        return score
    }
    
    private func highlightMatches(in text: String, query: String) -> String {
        // Simple highlighting - in a real app, this would use AttributedString
        return text.replacingOccurrences(
            of: query,
            with: "**\(query)**",
            options: .caseInsensitive
        )
    }
    
    private func generateContextSuggestions(for verse: QuranVerse) -> [String] {
        var suggestions: [String] = []
        
        // Add theme-based suggestions
        suggestions.append(contentsOf: verse.themes.prefix(3))
        
        // Add Surah-based suggestion
        suggestions.append("More from \(verse.surahName)")
        
        // Add Juz-based suggestion
        suggestions.append("Juz \(verse.juzNumber)")
        
        return Array(suggestions.prefix(5))
    }
    
    private func searchByVerseReference(_ reference: String) -> [QuranSearchResult] {
        // Parse reference like "2:255" or "Al-Baqarah 255"
        let components = reference.components(separatedBy: CharacterSet(charactersIn: ": "))
        
        if components.count >= 2 {
            // Try numeric reference first (e.g., "2:255")
            if let surahNum = Int(components[0]), let verseNum = Int(components[1]) {
                if let verse = allVerses.first(where: { $0.surahNumber == surahNum && $0.verseNumber == verseNum }) {
                    return [QuranSearchResult(
                        verse: verse,
                        relevanceScore: 10.0,
                        matchedText: reference,
                        matchType: .exact,
                        highlightedText: verse.textTranslation
                    )]
                }
            }
            
            // Try Surah name reference
            let surahName = components[0]
            if let verseNum = Int(components[1]) {
                if let verse = allVerses.first(where: { 
                    ($0.surahName.lowercased().contains(surahName.lowercased()) || 
                     $0.surahNameArabic.contains(surahName)) && 
                    $0.verseNumber == verseNum 
                }) {
                    return [QuranSearchResult(
                        verse: verse,
                        relevanceScore: 10.0,
                        matchedText: reference,
                        matchType: .exact,
                        highlightedText: verse.textTranslation
                    )]
                }
            }
        }
        
        return []
    }
    
    private func addToSearchHistory(_ query: String) {
        // Remove if already exists
        searchHistory.removeAll { $0 == query }
        
        // Add to beginning
        searchHistory.insert(query, at: 0)
        
        // Limit history size
        if searchHistory.count > maxHistoryItems {
            searchHistory = Array(searchHistory.prefix(maxHistoryItems))
        }
        
        saveSearchHistory()
    }
    
    private func saveSearchHistory() {
        userDefaults.set(searchHistory, forKey: CacheKeys.searchHistory)
    }
    
    private func loadSearchHistory() {
        searchHistory = userDefaults.stringArray(forKey: CacheKeys.searchHistory) ?? []
    }
    
    private func saveBookmarkedVerses() {
        if let data = try? JSONEncoder().encode(bookmarkedVerses) {
            userDefaults.set(data, forKey: CacheKeys.bookmarkedVerses)
        }
    }
    
    private func loadBookmarkedVerses() {
        if let data = userDefaults.data(forKey: CacheKeys.bookmarkedVerses),
           let verses = try? JSONDecoder().decode([QuranVerse].self, from: data) {
            bookmarkedVerses = verses
        }
    }
}

// MARK: - Search Options

public struct QuranSearchOptions {
    public var searchTranslation: Bool = true
    public var searchArabic: Bool = true
    public var searchTransliteration: Bool = true
    public var searchThemes: Bool = true
    public var searchKeywords: Bool = true
    public var maxResults: Int = 50
    
    public init() {}
}
