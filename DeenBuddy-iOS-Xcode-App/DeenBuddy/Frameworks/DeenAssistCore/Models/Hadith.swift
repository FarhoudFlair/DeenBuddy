import Foundation

// MARK: - Hadith Models

/// Represents a Hadith (Prophetic tradition)
public struct Hadith: Codable, Identifiable, Equatable {
    public let id: String
    public let book: HadithBook
    public let bookNumber: Int
    public let chapterNumber: Int?
    public let chapterName: String?
    public let hadithNumber: Int
    public let textArabic: String
    public let textTranslation: String
    public let textTransliteration: String?
    public let narrator: String
    public let chainOfNarration: String?
    public let grade: HadithGrade
    public let gradeComment: String?
    public let scholar: String?
    public let themes: [String]
    public let keywords: [String]
    public let relatedVerses: [String]
    public let relatedHadiths: [String]
    public let context: String?
    public let explanation: String?
    public let dateCreated: Date
    public let dateUpdated: Date
    
    public init(
        id: String = UUID().uuidString,
        book: HadithBook,
        bookNumber: Int,
        chapterNumber: Int? = nil,
        chapterName: String? = nil,
        hadithNumber: Int,
        textArabic: String,
        textTranslation: String,
        textTransliteration: String? = nil,
        narrator: String,
        chainOfNarration: String? = nil,
        grade: HadithGrade,
        gradeComment: String? = nil,
        scholar: String? = nil,
        themes: [String] = [],
        keywords: [String] = [],
        relatedVerses: [String] = [],
        relatedHadiths: [String] = [],
        context: String? = nil,
        explanation: String? = nil,
        dateCreated: Date = Date(),
        dateUpdated: Date = Date()
    ) {
        self.id = id
        self.book = book
        self.bookNumber = bookNumber
        self.chapterNumber = chapterNumber
        self.chapterName = chapterName
        self.hadithNumber = hadithNumber
        self.textArabic = textArabic
        self.textTranslation = textTranslation
        self.textTransliteration = textTransliteration
        self.narrator = narrator
        self.chainOfNarration = chainOfNarration
        self.grade = grade
        self.gradeComment = gradeComment
        self.scholar = scholar
        self.themes = themes
        self.keywords = keywords
        self.relatedVerses = relatedVerses
        self.relatedHadiths = relatedHadiths
        self.context = context
        self.explanation = explanation
        self.dateCreated = dateCreated
        self.dateUpdated = dateUpdated
    }
    
    /// Full reference string (e.g., "Sahih Bukhari 1:1")
    public var reference: String {
        return "\(book.displayName) \(bookNumber):\(hadithNumber)"
    }
    
    /// Short reference (e.g., "Bukhari 1:1")
    public var shortReference: String {
        return "\(book.shortName) \(bookNumber):\(hadithNumber)"
    }
    
    /// Check if hadith is authentic
    public var isAuthentic: Bool {
        return grade == .sahih || grade == .hasan
    }
    
    /// Check if hadith is weak
    public var isWeak: Bool {
        return grade == .daif || grade == .veryWeak
    }
    
    /// Get hadith in formatted display text
    public var displayText: String {
        var text = textTranslation
        if let transliteration = textTransliteration {
            text += "\n\nTransliteration: \(transliteration)"
        }
        text += "\n\nArabic: \(textArabic)"
        text += "\n\nNarrator: \(narrator)"
        text += "\n\nGrade: \(grade.displayName)"
        if let comment = gradeComment {
            text += " - \(comment)"
        }
        text += "\n\nReference: \(reference)"
        return text
    }
    
    /// Get chapter reference if available
    public var chapterReference: String? {
        guard let chapterNumber = chapterNumber,
              let chapterName = chapterName else { return nil }
        return "Chapter \(chapterNumber): \(chapterName)"
    }
}

/// Represents a Hadith collection book
public enum HadithBook: String, Codable, CaseIterable {
    case sahihBukhari = "sahih_bukhari"
    case sahihMuslim = "sahih_muslim"
    case sunanAbuDawud = "sunan_abu_dawud"
    case jamiTirmidhi = "jami_tirmidhi"
    case sunanNasai = "sunan_nasai"
    case sunanIbnMajah = "sunan_ibn_majah"
    case musnadAhmad = "musnad_ahmad"
    case muwattaMalik = "muwatta_malik"
    case sahihIbnKhuzaymah = "sahih_ibn_khuzaymah"
    case sahihIbnHibban = "sahih_ibn_hibban"
    case sunanDarimi = "sunan_darimi"
    case sunanBayhaqi = "sunan_bayhaqi"
    case mishkatMasabih = "mishkat_masabih"
    case riyadzSalihin = "riyadz_salihin"
    case adabMufrad = "adab_mufrad"
    case fortressMuslim = "fortress_muslim"
    
    public var displayName: String {
        switch self {
        case .sahihBukhari: return "Sahih al-Bukhari"
        case .sahihMuslim: return "Sahih Muslim"
        case .sunanAbuDawud: return "Sunan Abu Dawud"
        case .jamiTirmidhi: return "Jami' at-Tirmidhi"
        case .sunanNasai: return "Sunan an-Nasa'i"
        case .sunanIbnMajah: return "Sunan Ibn Majah"
        case .musnadAhmad: return "Musnad Ahmad"
        case .muwattaMalik: return "Muwatta Malik"
        case .sahihIbnKhuzaymah: return "Sahih Ibn Khuzaymah"
        case .sahihIbnHibban: return "Sahih Ibn Hibban"
        case .sunanDarimi: return "Sunan ad-Darimi"
        case .sunanBayhaqi: return "Sunan al-Bayhaqi"
        case .mishkatMasabih: return "Mishkat al-Masabih"
        case .riyadzSalihin: return "Riyadz as-Salihin"
        case .adabMufrad: return "Al-Adab al-Mufrad"
        case .fortressMuslim: return "Fortress of the Muslim"
        }
    }
    
    public var shortName: String {
        switch self {
        case .sahihBukhari: return "Bukhari"
        case .sahihMuslim: return "Muslim"
        case .sunanAbuDawud: return "Abu Dawud"
        case .jamiTirmidhi: return "Tirmidhi"
        case .sunanNasai: return "Nasa'i"
        case .sunanIbnMajah: return "Ibn Majah"
        case .musnadAhmad: return "Ahmad"
        case .muwattaMalik: return "Malik"
        case .sahihIbnKhuzaymah: return "Ibn Khuzaymah"
        case .sahihIbnHibban: return "Ibn Hibban"
        case .sunanDarimi: return "Darimi"
        case .sunanBayhaqi: return "Bayhaqi"
        case .mishkatMasabih: return "Mishkat"
        case .riyadzSalihin: return "Riyadz"
        case .adabMufrad: return "Adab"
        case .fortressMuslim: return "Fortress"
        }
    }
    
    public var arabicName: String {
        switch self {
        case .sahihBukhari: return "صحيح البخاري"
        case .sahihMuslim: return "صحيح مسلم"
        case .sunanAbuDawud: return "سنن أبي داود"
        case .jamiTirmidhi: return "جامع الترمذي"
        case .sunanNasai: return "سنن النسائي"
        case .sunanIbnMajah: return "سنن ابن ماجه"
        case .musnadAhmad: return "مسند أحمد"
        case .muwattaMalik: return "موطأ مالك"
        case .sahihIbnKhuzaymah: return "صحيح ابن خزيمة"
        case .sahihIbnHibban: return "صحيح ابن حبان"
        case .sunanDarimi: return "سنن الدارمي"
        case .sunanBayhaqi: return "سنن البيهقي"
        case .mishkatMasabih: return "مشكاة المصابيح"
        case .riyadzSalihin: return "رياض الصالحين"
        case .adabMufrad: return "الأدب المفرد"
        case .fortressMuslim: return "حصن المسلم"
        }
    }
    
    public var authority: Int {
        switch self {
        case .sahihBukhari, .sahihMuslim: return 5
        case .sunanAbuDawud, .jamiTirmidhi, .sunanNasai, .sunanIbnMajah: return 4
        case .musnadAhmad, .muwattaMalik: return 3
        case .sahihIbnKhuzaymah, .sahihIbnHibban: return 3
        case .sunanDarimi, .sunanBayhaqi: return 2
        case .mishkatMasabih, .riyadzSalihin, .adabMufrad, .fortressMuslim: return 1
        }
    }
}

/// Represents the authenticity grade of a Hadith
public enum HadithGrade: String, Codable, CaseIterable {
    case sahih = "sahih"
    case hasan = "hasan"
    case daif = "daif"
    case veryWeak = "very_weak"
    case fabricated = "fabricated"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .sahih: return "Sahih (Authentic)"
        case .hasan: return "Hasan (Good)"
        case .daif: return "Da'if (Weak)"
        case .veryWeak: return "Very Weak"
        case .fabricated: return "Fabricated"
        case .unknown: return "Unknown"
        }
    }
    
    public var arabicName: String {
        switch self {
        case .sahih: return "صحيح"
        case .hasan: return "حسن"
        case .daif: return "ضعيف"
        case .veryWeak: return "ضعيف جداً"
        case .fabricated: return "موضوع"
        case .unknown: return "غير معروف"
        }
    }
    
    public var reliability: Int {
        switch self {
        case .sahih: return 5
        case .hasan: return 4
        case .daif: return 2
        case .veryWeak: return 1
        case .fabricated: return 0
        case .unknown: return 0
        }
    }
}

/// Represents a search result from Hadith
public struct HadithSearchResult: Codable, Identifiable, Equatable {
    public let id: String
    public let hadith: Hadith
    public let relevanceScore: Double
    public let matchedText: String
    public let matchType: HadithMatchType
    public let highlightedText: String
    public let contextSuggestions: [String]
    
    public init(
        id: String = UUID().uuidString,
        hadith: Hadith,
        relevanceScore: Double,
        matchedText: String,
        matchType: HadithMatchType,
        highlightedText: String,
        contextSuggestions: [String] = []
    ) {
        self.id = id
        self.hadith = hadith
        self.relevanceScore = relevanceScore
        self.matchedText = matchedText
        self.matchType = matchType
        self.highlightedText = highlightedText
        self.contextSuggestions = contextSuggestions
    }
}

/// Type of match found in Hadith search
public enum HadithMatchType: String, Codable, CaseIterable {
    case exact = "exact"
    case partial = "partial"
    case semantic = "semantic"
    case thematic = "thematic"
    case keyword = "keyword"
    case narrator = "narrator"
    case book = "book"
    
    public var displayName: String {
        switch self {
        case .exact: return "Exact Match"
        case .partial: return "Partial Match"
        case .semantic: return "Semantic Match"
        case .thematic: return "Thematic Match"
        case .keyword: return "Keyword Match"
        case .narrator: return "Narrator Match"
        case .book: return "Book Match"
        }
    }
    
    public var priority: Int {
        switch self {
        case .exact: return 6
        case .partial: return 5
        case .semantic: return 4
        case .thematic: return 3
        case .keyword: return 2
        case .narrator: return 1
        case .book: return 1
        }
    }
}

// MARK: - Extensions

extension Hadith {
    /// Check if hadith contains specific text
    public func contains(text: String) -> Bool {
        let searchText = text.lowercased()
        return textTranslation.lowercased().contains(searchText) ||
               textArabic.lowercased().contains(searchText) ||
               (textTransliteration?.lowercased().contains(searchText) ?? false) ||
               narrator.lowercased().contains(searchText) ||
               themes.contains { $0.lowercased().contains(searchText) } ||
               keywords.contains { $0.lowercased().contains(searchText) } ||
               book.displayName.lowercased().contains(searchText)
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
        
        // Narrator match
        if narrator.lowercased().contains(queryLower) {
            score += 0.3
        }
        
        // Book match
        if book.displayName.lowercased().contains(queryLower) {
            score += 0.2
        }
        
        // Boost score based on authenticity
        switch grade {
        case .sahih:
            score *= 1.2
        case .hasan:
            score *= 1.1
        case .daif:
            score *= 0.9
        case .veryWeak:
            score *= 0.8
        case .fabricated:
            score *= 0.5
        case .unknown:
            score *= 0.7
        }
        
        return min(score, 1.0)
    }
}

extension Array where Element == Hadith {
    /// Search hadiths by text
    public func search(query: String) -> [HadithSearchResult] {
        return self.compactMap { hadith in
            guard hadith.contains(text: query) else { return nil }
            
            let score = hadith.relevanceScore(for: query)
            guard score > 0 else { return nil }
            
            let matchType: HadithMatchType
            if hadith.textTranslation.lowercased().contains(query.lowercased()) {
                matchType = .exact
            } else if hadith.themes.contains(where: { $0.lowercased().contains(query.lowercased()) }) {
                matchType = .thematic
            } else if hadith.keywords.contains(where: { $0.lowercased().contains(query.lowercased()) }) {
                matchType = .keyword
            } else if hadith.narrator.lowercased().contains(query.lowercased()) {
                matchType = .narrator
            } else if hadith.book.displayName.lowercased().contains(query.lowercased()) {
                matchType = .book
            } else {
                matchType = .partial
            }
            
            return HadithSearchResult(
                hadith: hadith,
                relevanceScore: score,
                matchedText: query,
                matchType: matchType,
                highlightedText: hadith.textTranslation
            )
        }
        .sorted { 
            if $0.relevanceScore == $1.relevanceScore {
                return $0.hadith.grade.reliability > $1.hadith.grade.reliability
            }
            return $0.relevanceScore > $1.relevanceScore
        }
    }
    
    /// Filter by authenticity grade
    public func filtered(by grade: HadithGrade) -> [Hadith] {
        return self.filter { $0.grade == grade }
    }
    
    /// Filter by book
    public func filtered(by book: HadithBook) -> [Hadith] {
        return self.filter { $0.book == book }
    }
    
    /// Get only authentic hadiths
    public var authentic: [Hadith] {
        return self.filter { $0.isAuthentic }
    }
}
