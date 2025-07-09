import Foundation
import Combine

// MARK: - Islamic Knowledge Service

/// Service for Islamic knowledge base including Quran, Hadith, and AI-powered search
@MainActor
public class IslamicKnowledgeService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isLoading = false
    @Published public var error: Error?
    @Published public var searchResults: [IslamicKnowledgeResult] = []
    @Published public var isAIEnabled = true
    @Published public var lastQuery: String = ""
    
    // MARK: - Private Properties
    
    private let apiClient: APIClientProtocol
    private let cache: IslamicKnowledgeCache
    private let openAIService: OpenAIService
    private var cancellables = Set<AnyCancellable>()
    
    // Sample data for development
    private var quranVerses: [QuranVerse] = []
    private var hadiths: [Hadith] = []
    
    // MARK: - Initialization
    
    public init(apiClient: APIClientProtocol, openAIService: OpenAIService? = nil) {
        self.apiClient = apiClient
        self.cache = IslamicKnowledgeCache()
        self.openAIService = openAIService ?? OpenAIService()
        
        setupSampleData()
    }
    
    // MARK: - Public Methods
    
    /// Search Islamic knowledge using natural language
    public func searchKnowledge(query: String, includeQuran: Bool = true, includeHadith: Bool = true, useAI: Bool = true) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isLoading = true
        error = nil
        lastQuery = query
        
        do {
            // Check cache first
            if let cachedResults = cache.getCachedResults(for: query) {
                searchResults = cachedResults
                isLoading = false
                return
            }
            
            var results: [IslamicKnowledgeResult] = []
            
            // Search Quran
            if includeQuran {
                let quranResults = await searchQuran(query: query)
                results.append(contentsOf: quranResults)
            }
            
            // Search Hadith
            if includeHadith {
                let hadithResults = await searchHadith(query: query)
                results.append(contentsOf: hadithResults)
            }
            
            // Use AI for enhanced search if enabled
            if useAI && isAIEnabled {
                let aiResults = await searchWithAI(query: query)
                results.append(contentsOf: aiResults)
            }
            
            // Sort by relevance and limit results
            results.sort { $0.relevanceScore > $1.relevanceScore }
            results = Array(results.prefix(20))
            
            searchResults = results
            
            // Cache results
            cache.cacheResults(results, for: query)
            
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    /// Get detailed explanation for a specific verse or hadith
    public func getDetailedExplanation(for result: IslamicKnowledgeResult) async -> String? {
        guard isAIEnabled else { return nil }
        
        do {
            return try await openAIService.getDetailedExplanation(for: result)
        } catch {
            print("Failed to get detailed explanation: \(error)")
            return nil
        }
    }
    
    /// Get related content for a specific result
    public func getRelatedContent(for result: IslamicKnowledgeResult) async -> [IslamicKnowledgeResult] {
        var relatedResults: [IslamicKnowledgeResult] = []
        
        // Get related verses and hadiths
        switch result.type {
        case .quranVerse:
            // Find related verses by theme
            if let verse = result.quranVerse {
                let relatedVerses = quranVerses.filter { otherVerse in
                    otherVerse.id != verse.id && 
                    !Set(verse.themes).intersection(Set(otherVerse.themes)).isEmpty
                }
                
                relatedResults.append(contentsOf: relatedVerses.prefix(3).map { verse in
                    IslamicKnowledgeResult(
                        type: .quranVerse,
                        relevanceScore: 0.8,
                        quranVerse: verse,
                        hadith: nil,
                        explanation: "Related by theme: \(verse.themes.joined(separator: ", "))"
                    )
                })
            }
            
        case .hadith:
            // Find related hadiths
            if let hadith = result.hadith {
                let relatedHadiths = hadiths.filter { otherHadith in
                    otherHadith.id != hadith.id && 
                    !Set(hadith.themes).intersection(Set(otherHadith.themes)).isEmpty
                }
                
                relatedResults.append(contentsOf: relatedHadiths.prefix(3).map { hadith in
                    IslamicKnowledgeResult(
                        type: .hadith,
                        relevanceScore: 0.8,
                        quranVerse: nil,
                        hadith: hadith,
                        explanation: "Related by theme: \(hadith.themes.joined(separator: ", "))"
                    )
                })
            }
            
        case .explanation:
            // For AI explanations, find related content based on themes
            break
        }
        
        return relatedResults
    }
    
    /// Clear search results
    public func clearResults() {
        searchResults = []
        lastQuery = ""
        error = nil
    }
    
    /// Toggle AI features
    public func toggleAI() {
        isAIEnabled.toggle()
    }
    
    // MARK: - Private Methods
    
    private func searchQuran(query: String) async -> [IslamicKnowledgeResult] {
        let searchResults = quranVerses.search(query: query)
        
        return searchResults.map { result in
            IslamicKnowledgeResult(
                type: .quranVerse,
                relevanceScore: result.relevanceScore,
                quranVerse: result.verse,
                hadith: nil,
                explanation: "Found in Quran: \(result.matchType.displayName)"
            )
        }
    }
    
    private func searchHadith(query: String) async -> [IslamicKnowledgeResult] {
        let searchResults = hadiths.search(query: query)
        
        return searchResults.map { result in
            IslamicKnowledgeResult(
                type: .hadith,
                relevanceScore: result.relevanceScore,
                quranVerse: nil,
                hadith: result.hadith,
                explanation: "Found in Hadith: \(result.matchType.displayName)"
            )
        }
    }
    
    private func searchWithAI(query: String) async -> [IslamicKnowledgeResult] {
        guard isAIEnabled else { return [] }
        
        do {
            let aiResponse = try await openAIService.searchIslamicKnowledge(query: query)
            
            return [IslamicKnowledgeResult(
                type: .explanation,
                relevanceScore: 0.9,
                quranVerse: nil,
                hadith: nil,
                explanation: aiResponse
            )]
            
        } catch {
            print("AI search failed: \(error)")
            return []
        }
    }
    
    private func setupSampleData() {
        // Sample Quran verses
        quranVerses = [
            QuranVerse(
                surahNumber: 1,
                surahName: "Al-Fatiha",
                surahNameArabic: "الفاتحة",
                verseNumber: 1,
                textArabic: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
                textTranslation: "In the name of Allah, the Entirely Merciful, the Especially Merciful.",
                textTransliteration: "Bismillahi r-rahmani r-raheem",
                revelationPlace: .mecca,
                juzNumber: 1,
                hizbNumber: 1,
                rukuNumber: 1,
                manzilNumber: 1,
                pageNumber: 1,
                themes: ["mercy", "compassion", "beginning", "prayer"],
                keywords: ["Allah", "Rahman", "Raheem", "mercy", "compassion"]
            ),
            QuranVerse(
                surahNumber: 2,
                surahName: "Al-Baqarah",
                surahNameArabic: "البقرة",
                verseNumber: 255,
                textArabic: "اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ",
                textTranslation: "Allah - there is no deity except Him, the Ever-Living, the Sustainer of existence. Neither drowsiness overtakes Him nor sleep.",
                textTransliteration: "Allahu la ilaha illa huwa al-hayyu al-qayyum",
                revelationPlace: .medina,
                juzNumber: 3,
                hizbNumber: 5,
                rukuNumber: 35,
                manzilNumber: 1,
                pageNumber: 42,
                themes: ["monotheism", "attributes of Allah", "power", "eternal"],
                keywords: ["Allah", "eternal", "living", "sustainer", "sleep"]
            ),
            QuranVerse(
                surahNumber: 17,
                surahName: "Al-Isra",
                surahNameArabic: "الإسراء",
                verseNumber: 110,
                textArabic: "قُلِ ادْعُوا اللَّهَ أَوِ ادْعُوا الرَّحْمَٰنَ ۖ أَيًّا مَّا تَدْعُوا فَلَهُ الْأَسْمَاءُ الْحُسْنَىٰ",
                textTranslation: "Say, 'Call upon Allah or call upon the Most Merciful. Whichever [name] you call - to Him belong the best names.'",
                textTransliteration: "Qul ud'u Allaha aw ud'u ar-Rahman",
                revelationPlace: .mecca,
                juzNumber: 15,
                hizbNumber: 30,
                rukuNumber: 12,
                manzilNumber: 5,
                pageNumber: 290,
                themes: ["prayer", "names of Allah", "worship", "mercy"],
                keywords: ["Allah", "Rahman", "prayer", "worship", "names"]
            )
        ]
        
        // Sample Hadiths
        hadiths = [
            Hadith(
                book: .sahihBukhari,
                bookNumber: 1,
                chapterNumber: 1,
                chapterName: "How the Divine Inspiration started",
                hadithNumber: 1,
                textArabic: "إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ",
                textTranslation: "Actions are but by intention and every man shall have but that which he intended.",
                textTransliteration: "Innama al-a'malu bil-niyyat",
                narrator: "Umar ibn al-Khattab",
                grade: .sahih,
                themes: ["intention", "actions", "sincerity", "worship"],
                keywords: ["intention", "actions", "niyyah", "worship", "sincerity"]
            ),
            Hadith(
                book: .sahihMuslim,
                bookNumber: 1,
                chapterNumber: 1,
                chapterName: "The Book of Faith",
                hadithNumber: 8,
                textArabic: "الْإِسْلَامُ أَنْ تَشْهَدَ أَنْ لَا إِلَهَ إِلَّا اللَّهُ وَأَنَّ مُحَمَّدًا رَسُولُ اللَّهِ",
                textTranslation: "Islam is to testify that there is no god but Allah and Muhammad is the Messenger of Allah, to perform the prayers, to pay the zakat, to fast in Ramadan, and to make the pilgrimage to the House if you are able to do so.",
                textTransliteration: "Al-Islam an tashhada an la ilaha illa Allah wa anna Muhammadan rasul Allah",
                narrator: "Abdullah ibn Umar",
                grade: .sahih,
                themes: ["Islam", "pillars", "faith", "testimony", "prayer", "zakat", "fasting", "hajj"],
                keywords: ["Islam", "shahada", "prayer", "zakat", "fasting", "hajj", "pillars"]
            ),
            Hadith(
                book: .jamilTirmidhi,
                bookNumber: 5,
                chapterNumber: 48,
                chapterName: "What has been related about Supplications",
                hadithNumber: 3429,
                textArabic: "الدُّعَاءُ مُخُّ الْعِبَادَةِ",
                textTranslation: "Supplication is the essence of worship.",
                textTransliteration: "Ad-du'a mukhkh al-'ibadah",
                narrator: "Anas ibn Malik",
                grade: .hasan,
                themes: ["prayer", "supplication", "worship", "essence"],
                keywords: ["dua", "supplication", "worship", "essence", "prayer"]
            )
        ]
    }
}

// MARK: - Supporting Types

/// Result from Islamic knowledge search
public struct IslamicKnowledgeResult: Codable, Identifiable, Equatable {
    public let id: String
    public let type: IslamicKnowledgeType
    public let relevanceScore: Double
    public let quranVerse: QuranVerse?
    public let hadith: Hadith?
    public let explanation: String
    public let dateCreated: Date
    
    public init(
        id: String = UUID().uuidString,
        type: IslamicKnowledgeType,
        relevanceScore: Double,
        quranVerse: QuranVerse? = nil,
        hadith: Hadith? = nil,
        explanation: String,
        dateCreated: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.relevanceScore = relevanceScore
        self.quranVerse = quranVerse
        self.hadith = hadith
        self.explanation = explanation
        self.dateCreated = dateCreated
    }
    
    public var displayTitle: String {
        switch type {
        case .quranVerse:
            return quranVerse?.reference ?? "Quran Verse"
        case .hadith:
            return hadith?.reference ?? "Hadith"
        case .explanation:
            return "AI Explanation"
        }
    }
    
    public var displayText: String {
        switch type {
        case .quranVerse:
            return quranVerse?.displayText ?? ""
        case .hadith:
            return hadith?.displayText ?? ""
        case .explanation:
            return explanation
        }
    }
}

/// Type of Islamic knowledge content
public enum IslamicKnowledgeType: String, Codable, CaseIterable {
    case quranVerse = "quran_verse"
    case hadith = "hadith"
    case explanation = "explanation"
    
    public var displayName: String {
        switch self {
        case .quranVerse: return "Quran Verse"
        case .hadith: return "Hadith"
        case .explanation: return "AI Explanation"
        }
    }
}

// MARK: - Cache Implementation

private class IslamicKnowledgeCache {
    private let cache = NSCache<NSString, CachedSearchResult>()
    
    init() {
        cache.countLimit = 100
        cache.totalCostLimit = 1024 * 1024 * 10 // 10 MB
    }
    
    func getCachedResults(for query: String) -> [IslamicKnowledgeResult]? {
        let key = NSString(string: query.lowercased())
        guard let cachedResult = cache.object(forKey: key) else { return nil }
        
        // Check if cache is still valid (1 hour)
        if Date().timeIntervalSince(cachedResult.timestamp) > 3600 {
            cache.removeObject(forKey: key)
            return nil
        }
        
        return cachedResult.results
    }
    
    func cacheResults(_ results: [IslamicKnowledgeResult], for query: String) {
        let key = NSString(string: query.lowercased())
        let cachedResult = CachedSearchResult(results: results, timestamp: Date())
        cache.setObject(cachedResult, forKey: key)
    }
}

private class CachedSearchResult {
    let results: [IslamicKnowledgeResult]
    let timestamp: Date
    
    init(results: [IslamicKnowledgeResult], timestamp: Date) {
        self.results = results
        self.timestamp = timestamp
    }
}

// MARK: - OpenAI Service

public class OpenAIService {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    
    public init(apiKey: String = "") {
        self.apiKey = apiKey
    }
    
    public func searchIslamicKnowledge(query: String) async throws -> String {
        // For now, return a simulated response
        // In production, this would call OpenAI API
        
        let prompt = """
        You are an Islamic scholar assistant. Please provide a comprehensive answer to the following question based on the Quran and authentic Hadith. Always cite your sources and provide references.

        Question: \(query)

        Please provide:
        1. A direct answer to the question
        2. Relevant Quranic verses (with references)
        3. Relevant authentic Hadiths (with references)
        4. Brief explanation of the Islamic perspective
        5. Any important context or nuances

        Keep the response clear, accurate, and respectful.
        """
        
        // Simulate AI response
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        return """
        Based on Islamic teachings, here's what the Quran and Hadith say about your question:

        This is a simulated AI response. In the full implementation, this would:
        - Connect to OpenAI API
        - Send the formatted prompt
        - Return the AI-generated response with proper citations
        - Include relevant Quranic verses and Hadith references
        - Provide scholarly context and explanations

        The response would be comprehensive, accurate, and cite authentic sources.
        """
    }
    
    public func getDetailedExplanation(for result: IslamicKnowledgeResult) async throws -> String {
        let context: String
        
        switch result.type {
        case .quranVerse:
            context = "Please provide a detailed explanation of this Quranic verse: \(result.quranVerse?.displayText ?? "")"
        case .hadith:
            context = "Please provide a detailed explanation of this Hadith: \(result.hadith?.displayText ?? "")"
        case .explanation:
            context = "Please expand on this explanation: \(result.explanation)"
        }
        
        // Simulate AI response
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        return """
        Detailed Islamic Explanation:

        This is a simulated detailed explanation. In the full implementation, this would:
        - Provide in-depth scholarly commentary
        - Include historical context
        - Explain the linguistic aspects
        - Discuss different scholarly interpretations
        - Relate to other verses or hadiths
        - Provide practical applications

        The explanation would be thorough, accurate, and educational.
        """
    }
}