import Foundation

// MARK: - Quranic Verse Models

/// Represents a verse from the Quran
public struct QuranVerse: Codable, Identifiable, Equatable {
    public let id: String
    public let surahNumber: Int
    public let surahName: String
    public let surahNameArabic: String
    public let verseNumber: Int
    public let textArabic: String
    public let textTranslation: String
    public let textTransliteration: String?
    public let revelationPlace: RevelationPlace
    public let juzNumber: Int
    public let hizbNumber: Int
    public let rukuNumber: Int
    public let manzilNumber: Int
    public let pageNumber: Int
    public let contextBefore: String?
    public let contextAfter: String?
    public let themes: [String]
    public let keywords: [String]
    
    public init(
        id: String = UUID().uuidString,
        surahNumber: Int,
        surahName: String,
        surahNameArabic: String,
        verseNumber: Int,
        textArabic: String,
        textTranslation: String,
        textTransliteration: String? = nil,
        revelationPlace: RevelationPlace,
        juzNumber: Int,
        hizbNumber: Int,
        rukuNumber: Int,
        manzilNumber: Int,
        pageNumber: Int,
        contextBefore: String? = nil,
        contextAfter: String? = nil,
        themes: [String] = [],
        keywords: [String] = []
    ) {
        self.id = id
        self.surahNumber = surahNumber
        self.surahName = surahName
        self.surahNameArabic = surahNameArabic
        self.verseNumber = verseNumber
        self.textArabic = textArabic
        self.textTranslation = textTranslation
        self.textTransliteration = textTransliteration
        self.revelationPlace = revelationPlace
        self.juzNumber = juzNumber
        self.hizbNumber = hizbNumber
        self.rukuNumber = rukuNumber
        self.manzilNumber = manzilNumber
        self.pageNumber = pageNumber
        self.contextBefore = contextBefore
        self.contextAfter = contextAfter
        self.themes = themes
        self.keywords = keywords
    }
    
    /// Full reference string (e.g., "Al-Fatiha 1:1")
    public var reference: String {
        return "\(surahName) \(surahNumber):\(verseNumber)"
    }
    
    /// Arabic reference string
    public var referenceArabic: String {
        return "\(surahNameArabic) \(surahNumber):\(verseNumber)"
    }
    
    /// Short reference (e.g., "1:1")
    public var shortReference: String {
        return "\(surahNumber):\(verseNumber)"
    }
    
    /// Check if verse is Meccan or Medinan
    public var isMeccan: Bool {
        return revelationPlace == .mecca
    }
    
    /// Get verse in formatted display text
    public var displayText: String {
        var text = textTranslation
        if let transliteration = textTransliteration {
            text += "\n\nTransliteration: \(transliteration)"
        }
        text += "\n\nArabic: \(textArabic)"
        text += "\n\nReference: \(reference)"
        return text
    }
}

/// Represents where a verse was revealed
public enum RevelationPlace: String, Codable, CaseIterable {
    case mecca = "Mecca"
    case medina = "Medina"
    
    public var displayName: String {
        return self.rawValue
    }
}

/// Represents a Surah (Chapter) from the Quran
public struct QuranSurah: Codable, Identifiable, Equatable {
    public let id: String
    public let number: Int
    public let name: String
    public let nameArabic: String
    public let nameTransliteration: String
    public let meaning: String
    public let verseCount: Int
    public let revelationPlace: RevelationPlace
    public let revelationOrder: Int
    public let bismillahPre: Bool
    public let description: String
    public let themes: [String]
    public let verses: [QuranVerse]
    
    public init(
        id: String = UUID().uuidString,
        number: Int,
        name: String,
        nameArabic: String,
        nameTransliteration: String,
        meaning: String,
        verseCount: Int,
        revelationPlace: RevelationPlace,
        revelationOrder: Int,
        bismillahPre: Bool = true,
        description: String = "",
        themes: [String] = [],
        verses: [QuranVerse] = []
    ) {
        self.id = id
        self.number = number
        self.name = name
        self.nameArabic = nameArabic
        self.nameTransliteration = nameTransliteration
        self.meaning = meaning
        self.verseCount = verseCount
        self.revelationPlace = revelationPlace
        self.revelationOrder = revelationOrder
        self.bismillahPre = bismillahPre
        self.description = description
        self.themes = themes
        self.verses = verses
    }
    
    /// Full display name with meaning
    public var displayName: String {
        return "\(name) (\(meaning))"
    }
    
    /// Arabic display name
    public var displayNameArabic: String {
        return nameArabic
    }
    
    /// Check if Surah is Meccan or Medinan
    public var isMeccan: Bool {
        return revelationPlace == .mecca
    }
}

/// Represents a Juz (Part) from the Quran
public struct QuranJuz: Codable, Identifiable, Equatable {
    public let id: String
    public let number: Int
    public let name: String
    public let nameArabic: String
    public let startSurah: Int
    public let startVerse: Int
    public let endSurah: Int
    public let endVerse: Int
    public let verses: [QuranVerse]
    
    public init(
        id: String = UUID().uuidString,
        number: Int,
        name: String,
        nameArabic: String,
        startSurah: Int,
        startVerse: Int,
        endSurah: Int,
        endVerse: Int,
        verses: [QuranVerse] = []
    ) {
        self.id = id
        self.number = number
        self.name = name
        self.nameArabic = nameArabic
        self.startSurah = startSurah
        self.startVerse = startVerse
        self.endSurah = endSurah
        self.endVerse = endVerse
        self.verses = verses
    }
    
    /// Range description
    public var rangeDescription: String {
        return "\(startSurah):\(startVerse) - \(endSurah):\(endVerse)"
    }
}

// MARK: - Search Result Models

/// Represents a search result from Quran
public struct QuranSearchResult: Codable, Identifiable, Equatable {
    public let id: String
    public let verse: QuranVerse
    public let relevanceScore: Double
    public let matchedText: String
    public let matchType: MatchType
    public let highlightedText: String
    public let contextSuggestions: [String]
    
    public init(
        id: String = UUID().uuidString,
        verse: QuranVerse,
        relevanceScore: Double,
        matchedText: String,
        matchType: MatchType,
        highlightedText: String,
        contextSuggestions: [String] = []
    ) {
        self.id = id
        self.verse = verse
        self.relevanceScore = relevanceScore
        self.matchedText = matchedText
        self.matchType = matchType
        self.highlightedText = highlightedText
        self.contextSuggestions = contextSuggestions
    }
}

/// Type of match found in search
public enum MatchType: String, Codable, CaseIterable {
    case exact = "exact"
    case partial = "partial"
    case semantic = "semantic"
    case thematic = "thematic"
    case keyword = "keyword"
    
    public var displayName: String {
        switch self {
        case .exact: return "Exact Match"
        case .partial: return "Partial Match"
        case .semantic: return "Semantic Match"
        case .thematic: return "Thematic Match"
        case .keyword: return "Keyword Match"
        }
    }
    
    public var priority: Int {
        switch self {
        case .exact: return 5
        case .partial: return 4
        case .semantic: return 3
        case .thematic: return 2
        case .keyword: return 1
        }
    }
}

// MARK: - Extensions

extension QuranVerse {
    /// Check if verse contains specific text
    public func contains(text: String) -> Bool {
        let searchText = text.lowercased()
        return textTranslation.lowercased().contains(searchText) ||
               textArabic.lowercased().contains(searchText) ||
               (textTransliteration?.lowercased().contains(searchText) ?? false) ||
               themes.contains { $0.lowercased().contains(searchText) } ||
               keywords.contains { $0.lowercased().contains(searchText) }
    }
    
    /// Get relevance score for search query
    public func relevanceScore(for query: String) -> Double {
        let queryLower = query.lowercased()
        var score = 0.0
        
        // Exact match in translation
        if textTranslation.lowercased().contains(queryLower) {
            score += 1.0
        }
        
        // Partial match in translation
        let words = queryLower.split(separator: " ")
        for word in words {
            if textTranslation.lowercased().contains(word) {
                score += 0.3
            }
        }
        
        // Theme match
        for theme in themes {
            if theme.lowercased().contains(queryLower) {
                score += 0.5
            }
        }
        
        // Keyword match
        for keyword in keywords {
            if keyword.lowercased().contains(queryLower) {
                score += 0.4
            }
        }
        
        return min(score, 1.0)
    }
}

extension Array where Element == QuranVerse {
    /// Search verses by text
    public func search(query: String) -> [QuranSearchResult] {
        let lowercasedQuery = query.lowercased()
        
        return self.compactMap { verse in
            guard verse.contains(text: lowercasedQuery) else { return nil }
            
            let score = verse.relevanceScore(for: lowercasedQuery)
            guard score > 0 else { return nil }
            
            var matchType: MatchType
            
            if verse.textTranslation.lowercased().contains(lowercasedQuery) {
                matchType = .exact
            } else if verse.textArabic.contains(lowercasedQuery) {
                matchType = .exact // Arabic exact match
            } else if verse.textTransliteration?.lowercased().contains(lowercasedQuery) ?? false {
                matchType = .exact // Transliteration exact match
            } else if verse.themes.contains(where: { $0.lowercased().contains(lowercasedQuery) }) {
                matchType = .thematic
            } else if verse.keywords.contains(where: { $0.lowercased().contains(lowercasedQuery) }) {
                matchType = .keyword
            } else {
                matchType = .partial
            }
            
            return QuranSearchResult(
                verse: verse,
                relevanceScore: score,
                matchedText: query,
                matchType: matchType,
                highlightedText: verse.textTranslation
            )
        }
        .sorted { $0.relevanceScore > $1.relevanceScore }
    }
}