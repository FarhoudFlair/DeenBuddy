import Foundation

/// Semantic search engine for intelligent Quran search with synonym mapping and theme expansion
public class SemanticSearchEngine {
    
    // MARK: - Singleton
    
    public static let shared = SemanticSearchEngine()
    
    private init() {
        buildSemanticMappings()
    }
    
    // MARK: - Properties
    
    /// Dictionary mapping core concepts to related terms and synonyms
    private var synonymDictionary: [String: Set<String>] = [:]
    
    /// Dictionary mapping themes to related themes
    private var themeRelationships: [String: Set<String>] = [:]
    
    /// Dictionary mapping Arabic terms to their English equivalents
    private var arabicToEnglishMap: [String: Set<String>] = [:]
    
    /// Dictionary mapping common misspellings to correct terms
    private var typoCorrections: [String: String] = [:]
    
    // MARK: - Public Methods
    
    /// Expand a search query with synonyms and related terms
    public func expandQuery(_ query: String) -> [String] {
        let cleanQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var expandedTerms: Set<String> = [cleanQuery]
        
        // Add synonyms
        if let synonyms = synonymDictionary[cleanQuery] {
            expandedTerms.formUnion(synonyms)
        }
        
        // Add theme relationships
        if let relatedThemes = themeRelationships[cleanQuery] {
            expandedTerms.formUnion(relatedThemes)
        }
        
        // Add Arabic translations
        if let arabicTerms = arabicToEnglishMap[cleanQuery] {
            expandedTerms.formUnion(arabicTerms)
        }
        
        // Check for partial matches in synonyms
        for (key, values) in synonymDictionary {
            if key.contains(cleanQuery) || values.contains(where: { $0.contains(cleanQuery) }) {
                expandedTerms.insert(key)
                expandedTerms.formUnion(values)
            }
        }
        
        return Array(expandedTerms)
    }
    
    /// Get related concepts for a given theme
    public func getRelatedConcepts(for theme: String) -> [String] {
        let cleanTheme = theme.lowercased()
        return Array(themeRelationships[cleanTheme] ?? [])
    }
    
    /// Calculate semantic similarity between two terms
    public func semanticSimilarity(between term1: String, term2: String) -> Double {
        let cleanTerm1 = term1.lowercased()
        let cleanTerm2 = term2.lowercased()
        
        // Exact match
        if cleanTerm1 == cleanTerm2 {
            return 1.0
        }
        
        // Check if they're in the same synonym group
        if let synonyms1 = synonymDictionary[cleanTerm1],
           synonyms1.contains(cleanTerm2) {
            return 0.9
        }
        
        // Check if they're related themes
        if let relatedThemes1 = themeRelationships[cleanTerm1],
           relatedThemes1.contains(cleanTerm2) {
            return 0.8
        }
        
        // Check substring similarity
        if cleanTerm1.contains(cleanTerm2) || cleanTerm2.contains(cleanTerm1) {
            let longer = cleanTerm1.count > cleanTerm2.count ? cleanTerm1 : cleanTerm2
            let shorter = cleanTerm1.count <= cleanTerm2.count ? cleanTerm1 : cleanTerm2
            return Double(shorter.count) / Double(longer.count) * 0.7
        }
        
        // Check Levenshtein distance for fuzzy matching
        let distance = levenshteinDistance(cleanTerm1, cleanTerm2)
        let maxLength = max(cleanTerm1.count, cleanTerm2.count)
        if maxLength > 0 {
            let similarity = 1.0 - (Double(distance) / Double(maxLength))
            return similarity > 0.6 ? similarity * 0.6 : 0.0
        }
        
        return 0.0
    }
    
    /// Correct common typos in search queries
    public func correctTypos(in query: String) -> String {
        let cleanQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return typoCorrections[cleanQuery] ?? query
    }
    
    /// Get search suggestions based on partial input
    public func getSearchSuggestions(for partialQuery: String) -> [String] {
        let cleanQuery = partialQuery.lowercased()
        var suggestions: Set<String> = []
        
        // Find matching synonyms
        for (key, values) in synonymDictionary {
            if key.hasPrefix(cleanQuery) {
                suggestions.insert(key)
            }
            for value in values {
                if value.hasPrefix(cleanQuery) {
                    suggestions.insert(value)
                }
            }
        }
        
        // Find matching themes
        for (key, values) in themeRelationships {
            if key.hasPrefix(cleanQuery) {
                suggestions.insert(key)
            }
            for value in values {
                if value.hasPrefix(cleanQuery) {
                    suggestions.insert(value)
                }
            }
        }
        
        return Array(suggestions).sorted().prefix(10).map { $0 }
    }
    
    // MARK: - Private Methods
    
    private func buildSemanticMappings() {
        buildSynonymDictionary()
        buildThemeRelationships()
        buildArabicToEnglishMap()
        buildTypoCorrections()
    }
    
    private func buildSynonymDictionary() {
        synonymDictionary = [
            // Prayer and Worship
            "prayer": ["salah", "namaz", "worship", "dua", "supplication", "invocation"],
            "worship": ["prayer", "salah", "namaz", "devotion", "adoration", "service"],
            "dua": ["prayer", "supplication", "invocation", "petition", "plea"],
            
            // Allah and Divine Names
            "allah": ["god", "lord", "creator", "almighty", "divine"],
            "god": ["allah", "lord", "creator", "divine", "almighty"],
            "lord": ["allah", "god", "master", "creator", "rabb"],
            "creator": ["allah", "god", "lord", "maker", "originator"],
            
            // Mercy and Compassion
            "mercy": ["compassion", "kindness", "forgiveness", "grace", "rahma"],
            "compassion": ["mercy", "kindness", "sympathy", "empathy", "tenderness"],
            "forgiveness": ["mercy", "pardon", "absolution", "clemency", "maghfira"],
            "kindness": ["mercy", "compassion", "benevolence", "goodness", "gentleness"],
            
            // Guidance and Direction
            "guidance": ["direction", "path", "way", "light", "hidayah"],
            "direction": ["guidance", "path", "way", "course", "route"],
            "path": ["guidance", "direction", "way", "route", "sirat"],
            "light": ["guidance", "illumination", "brightness", "nur", "enlightenment"],
            
            // Faith and Belief
            "faith": ["belief", "trust", "confidence", "iman", "conviction"],
            "belief": ["faith", "trust", "conviction", "confidence", "creed"],
            "trust": ["faith", "belief", "confidence", "reliance", "tawakkul"],
            
            // Paradise and Afterlife
            "paradise": ["heaven", "jannah", "garden", "afterlife", "eternal life"],
            "heaven": ["paradise", "jannah", "garden", "afterlife", "eternal bliss"],
            "jannah": ["paradise", "heaven", "garden", "afterlife", "eternal life"],
            "hell": ["jahannam", "fire", "punishment", "torment", "damnation"],
            
            // Patience and Perseverance
            "patience": ["perseverance", "endurance", "steadfastness", "sabr", "tolerance"],
            "perseverance": ["patience", "endurance", "persistence", "steadfastness", "sabr"],
            "endurance": ["patience", "perseverance", "tolerance", "fortitude", "sabr"],
            
            // Knowledge and Wisdom
            "knowledge": ["wisdom", "learning", "understanding", "ilm", "insight"],
            "wisdom": ["knowledge", "understanding", "insight", "prudence", "hikmah"],
            "understanding": ["knowledge", "wisdom", "comprehension", "insight", "awareness"],
            
            // Justice and Righteousness
            "justice": ["fairness", "equity", "righteousness", "adl", "balance"],
            "righteousness": ["justice", "goodness", "virtue", "piety", "taqwa"],
            "fairness": ["justice", "equity", "impartiality", "balance", "equality"],
            
            // Death and Mortality
            "death": ["mortality", "passing", "demise", "end", "maut"],
            "mortality": ["death", "passing", "transience", "impermanence", "finite"],
            "life": ["existence", "being", "living", "hayat", "vitality"],
            
            // Peace and Tranquility
            "peace": ["tranquility", "serenity", "calm", "salam", "harmony"],
            "tranquility": ["peace", "serenity", "calm", "stillness", "quietude"],
            "calm": ["peace", "tranquility", "serenity", "stillness", "composure"],
            
            // Love and Affection
            "love": ["affection", "devotion", "adoration", "hubb", "care"],
            "affection": ["love", "fondness", "tenderness", "care", "attachment"],
            "devotion": ["love", "dedication", "commitment", "worship", "loyalty"],
            
            // Gratitude and Praise
            "gratitude": ["thankfulness", "appreciation", "praise", "shukr", "acknowledgment"],
            "praise": ["gratitude", "commendation", "worship", "hamd", "glorification"],
            "thankfulness": ["gratitude", "appreciation", "acknowledgment", "recognition", "shukr"],
            
            // Fear and Reverence
            "fear": ["reverence", "awe", "respect", "khawf", "apprehension"],
            "reverence": ["fear", "awe", "respect", "veneration", "honor"],
            "awe": ["fear", "reverence", "wonder", "amazement", "respect"],

            // Famous Verses and Islamic Terms
            "ayat al-kursi": ["throne verse", "kursi", "2:255", "allah la ilaha illa huwa", "throne", "sustainer"],
            "throne verse": ["ayat al-kursi", "kursi", "2:255", "throne", "sustainer", "allah"],
            "kursi": ["throne", "ayat al-kursi", "throne verse", "2:255", "sustainer", "allah"],
            "throne": ["kursi", "ayat al-kursi", "throne verse", "sustainer", "sovereignty", "power"],
            "sustainer": ["qayyoom", "kursi", "throne", "ayat al-kursi", "living", "eternal"],
            "qayyoom": ["sustainer", "self-sustaining", "eternal", "living", "ayat al-kursi"],
            "hayy": ["living", "ever-living", "alive", "life", "ayat al-kursi"],

            // Other Famous Verses
            "al-fatiha": ["opening", "mother of the book", "seven oft-repeated", "1:1-7"],
            "ikhlas": ["sincerity", "purity", "112", "say he is allah one"],
            "falaq": ["daybreak", "dawn", "113", "refuge"],
            "nas": ["mankind", "people", "114", "refuge"],

            // Food and Dietary Terms
            "pork": ["swine", "pig", "haram meat", "forbidden food", "unclean meat", "khinzir"],
            "swine": ["pork", "pig", "haram meat", "forbidden food", "unclean meat", "khinzir"],
            "pig": ["pork", "swine", "haram meat", "forbidden food", "unclean meat", "khinzir"],
            "haram meat": ["pork", "swine", "pig", "forbidden food", "unclean meat"],
            "forbidden food": ["pork", "swine", "pig", "haram meat", "unclean meat"],
            "unclean meat": ["pork", "swine", "pig", "haram meat", "forbidden food"],

            // Charity and Giving Terms
            "charity": ["zakat", "sadaqah", "giving to poor", "alms", "helping needy", "infaq"],
            "zakat": ["charity", "purification", "giving", "alms", "obligatory charity"],
            "sadaqah": ["charity", "voluntary giving", "alms", "helping poor", "kindness"],
            "alms": ["charity", "zakat", "sadaqah", "giving to poor", "helping needy"],
            "giving": ["charity", "zakat", "sadaqah", "alms", "generosity", "spending"],
            "helping needy": ["charity", "zakat", "sadaqah", "alms", "giving to poor"],

            // Fasting Terms
            "fasting": ["sawm", "ramadan", "abstaining", "self-control", "hunger", "iftar", "suhur"],
            "sawm": ["fasting", "abstinence", "self-control", "ramadan", "spiritual discipline"],
            "ramadan": ["fasting", "sawm", "holy month", "abstaining", "iftar", "suhur"],
            "abstaining": ["fasting", "sawm", "self-control", "refraining", "restraint"],
            "iftar": ["breaking fast", "evening meal", "ramadan meal", "fasting"],
            "suhur": ["pre-dawn meal", "morning meal", "ramadan meal", "fasting"],

            // Prayer Position Terms
            "prostration": ["sujud", "bowing", "worship", "submission", "prayer position"],
            "sujud": ["prostration", "bowing", "worship", "submission", "prayer position"],
            "bowing": ["prostration", "sujud", "ruku", "worship", "prayer position"],
            "ruku": ["bowing", "prostration", "prayer position", "worship"],

            // Light and Guidance Terms
            "light verse": ["ayat an-nur", "24:35", "allah is light", "nur", "divine light"],
            "ayat an-nur": ["light verse", "24:35", "allah is light", "nur", "divine light"],
            "nur": ["light", "illumination", "guidance", "divine light", "ayat an-nur"],
            "divine light": ["nur", "light verse", "ayat an-nur", "illumination", "guidance"]
        ]
    }
    
    private func buildThemeRelationships() {
        themeRelationships = [
            // Core worship themes
            "prayer": ["worship", "devotion", "ritual", "remembrance", "spirituality"],
            "worship": ["prayer", "devotion", "submission", "obedience", "service"],
            "devotion": ["worship", "prayer", "dedication", "commitment", "love"],
            
            // Divine attributes
            "mercy": ["compassion", "forgiveness", "kindness", "love", "grace"],
            "justice": ["fairness", "righteousness", "balance", "equity", "judgment"],
            "wisdom": ["knowledge", "understanding", "guidance", "insight", "prudence"],
            "power": ["might", "strength", "authority", "control", "dominion"],
            
            // Moral and ethical themes
            "righteousness": ["justice", "goodness", "virtue", "piety", "morality"],
            "morality": ["righteousness", "ethics", "virtue", "goodness", "conduct"],
            "virtue": ["righteousness", "morality", "goodness", "excellence", "character"],
            
            // Afterlife themes
            "paradise": ["heaven", "afterlife", "eternity", "reward", "bliss"],
            "hell": ["punishment", "torment", "afterlife", "consequence", "fire"],
            "judgment": ["afterlife", "accountability", "reckoning", "justice", "consequence"],
            
            // Spiritual development
            "patience": ["perseverance", "endurance", "steadfastness", "resilience", "tolerance"],
            "gratitude": ["thankfulness", "appreciation", "contentment", "blessing", "praise"],
            "humility": ["modesty", "submission", "lowliness", "meekness", "reverence"],
            
            // Community and relationships
            "community": ["society", "brotherhood", "unity", "cooperation", "fellowship"],
            "family": ["relationships", "kinship", "parents", "children", "marriage"],
            "charity": ["generosity", "giving", "kindness", "compassion", "zakah", "sadaqah", "alms"],

            // Food and dietary themes
            "dietary laws": ["halal", "haram", "food", "eating", "consumption", "purity"],
            "forbidden food": ["haram", "pork", "swine", "unclean", "prohibited", "dietary laws"],
            "halal food": ["permissible", "lawful", "pure", "good", "tayyib", "dietary laws"],

            // Fasting and spiritual discipline
            "fasting": ["sawm", "ramadan", "self-control", "discipline", "abstinence", "spirituality"],
            "ramadan": ["fasting", "sawm", "holy month", "spiritual", "iftar", "suhur"],
            "spiritual discipline": ["fasting", "sawm", "self-control", "restraint", "purification"],

            // Prayer and worship positions
            "prostration": ["sujud", "worship", "submission", "humility", "prayer", "devotion"],
            "prayer positions": ["sujud", "ruku", "qiyam", "prostration", "bowing", "standing"],
            
            // Knowledge and learning
            "knowledge": ["learning", "education", "wisdom", "understanding", "insight"],
            "learning": ["knowledge", "education", "study", "teaching", "instruction"],
            "teaching": ["education", "instruction", "guidance", "learning", "knowledge"],
            
            // Nature and creation
            "creation": ["nature", "universe", "earth", "heavens", "signs"],
            "nature": ["creation", "environment", "earth", "signs", "beauty"],
            "signs": ["creation", "nature", "miracles", "evidence", "proof"],

            // Famous Verses and Their Themes
            "ayat al-kursi": ["monotheism", "unity", "throne", "protection", "power", "knowledge"],
            "kursi": ["throne", "sovereignty", "power", "protection", "monotheism", "unity"],
            "throne": ["power", "sovereignty", "authority", "protection", "kursi", "dominion"],
            "sustainer": ["life", "eternal", "power", "protection", "care", "maintenance"],
            "qayyoom": ["eternal", "self-sustaining", "independent", "permanent", "everlasting"],
            "hayy": ["life", "living", "vitality", "eternal", "ever-living", "alive"],

            // Chapter themes
            "al-fatiha": ["opening", "praise", "guidance", "worship", "prayer", "essential"],
            "ikhlas": ["monotheism", "unity", "purity", "sincerity", "oneness", "tawhid"],
            "falaq": ["protection", "refuge", "dawn", "evil", "seeking shelter", "safety"],
            "nas": ["protection", "refuge", "mankind", "evil", "seeking shelter", "whispers"],

            // Light and guidance themes
            "light verse": ["divine light", "guidance", "illumination", "nur", "spiritual light"],
            "ayat an-nur": ["light", "divine light", "guidance", "illumination", "spiritual guidance"],
            "divine light": ["guidance", "illumination", "spiritual light", "nur", "enlightenment"],
            "spiritual light": ["guidance", "divine light", "illumination", "enlightenment", "clarity"]
        ]
    }
    
    private func buildArabicToEnglishMap() {
        arabicToEnglishMap = [
            "allah": ["god", "lord", "creator", "divine"],
            "rahman": ["merciful", "compassionate", "mercy"],
            "raheem": ["merciful", "compassionate", "mercy"],
            "rabb": ["lord", "master", "sustainer", "cherisher"],
            "salah": ["prayer", "worship", "ritual"],
            "sabr": ["patience", "perseverance", "endurance"],
            "shukr": ["gratitude", "thankfulness", "appreciation"],
            "taqwa": ["righteousness", "piety", "god-consciousness"],
            "iman": ["faith", "belief", "trust"],
            "islam": ["submission", "peace", "surrender"],
            "muslim": ["submitter", "believer", "faithful"],
            "quran": ["recitation", "reading", "book"],
            "ayah": ["verse", "sign", "miracle"],
            "surah": ["chapter", "section"],
            "jannah": ["paradise", "heaven", "garden"],
            "jahannam": ["hell", "fire", "punishment"],
            "dunya": ["world", "life", "temporary"],
            "akhirah": ["afterlife", "hereafter", "eternal"],
            "maghfira": ["forgiveness", "pardon", "mercy"],
            "hikmah": ["wisdom", "knowledge", "understanding"],
            "fitrah": ["nature", "natural state", "innate"],
            "tawhid": ["monotheism", "unity", "oneness"],
            "shirk": ["polytheism", "association", "idolatry"],
            "halal": ["permissible", "lawful", "allowed"],
            "haram": ["forbidden", "unlawful", "prohibited"],
            "zakah": ["charity", "purification", "giving"],
            "hajj": ["pilgrimage", "journey", "ritual"],
            "sawm": ["fasting", "abstinence", "self-control"],

            // Food and dietary Arabic terms
            "khinzir": ["pig", "swine", "pork", "haram meat"],
            "lahm": ["meat", "flesh", "food"],
            "tayyib": ["pure", "good", "wholesome", "halal"],

            // Prayer position Arabic terms
            "sujud": ["prostration", "bowing", "worship", "submission"],
            "ruku": ["bowing", "prostration", "prayer position"],
            "qiyam": ["standing", "prayer position", "worship"],
            "takbir": ["allahu akbar", "glorification", "magnification"],

            // Charity Arabic terms
            "sadaqah": ["voluntary charity", "alms", "giving", "kindness"],
            "infaq": ["spending", "giving", "charity", "expenditure"],
            "khairat": ["charity", "good deeds", "benevolence"],

            // Fasting Arabic terms
            "iftar": ["breaking fast", "evening meal", "ramadan meal"],
            "suhur": ["pre-dawn meal", "morning meal", "ramadan meal"],
            "itikaf": ["spiritual retreat", "seclusion", "mosque retreat"],

            // Light and guidance Arabic terms
            "nur": ["light", "illumination", "guidance", "divine light"],
            "hidayah": ["guidance", "direction", "path", "divine guidance"],
            "sirat": ["path", "way", "straight path", "bridge"],
            "jihad": ["struggle", "effort", "striving"],
            "ummah": ["community", "nation", "people"],
            "khilafah": ["caliphate", "succession", "leadership"],
            "shura": ["consultation", "council", "advice"],
            "adl": ["justice", "fairness", "equity"],
            "ihsan": ["excellence", "perfection", "doing good"],
            "tawakkul": ["trust", "reliance", "dependence"],
            "istighfar": ["seeking forgiveness", "repentance", "pardon"],
            "dhikr": ["remembrance", "mention", "recitation"],
            "barakah": ["blessing", "abundance", "prosperity"],
            "rahmah": ["mercy", "compassion", "kindness"],
            "husn": ["beauty", "goodness", "excellence"],
            "mizan": ["balance", "scale", "justice"],
            "lawh": ["tablet", "record", "book"],
            "qalam": ["pen", "writing", "knowledge"],
            "kitab": ["book", "scripture", "writing"],
            "furqan": ["criterion", "distinction", "separator"],
            "huda": ["guidance", "direction", "light"],
            "bashir": ["bearer of good news", "herald", "messenger"],
            "nadhir": ["warner", "cautioner", "messenger"],
            "rasul": ["messenger", "apostle", "envoy"],
            "nabi": ["prophet", "messenger", "chosen one"]
        ]
    }
    
    private func buildTypoCorrections() {
        typoCorrections = [
            "merci": "mercy",
            "mercey": "mercy",
            "guidnce": "guidance",
            "guidanc": "guidance",
            "paitence": "patience",
            "patiance": "patience",
            "beleif": "belief",
            "belif": "belief",
            "paradis": "paradise",
            "paradice": "paradise",
            "forgivness": "forgiveness",
            "forgivenes": "forgiveness",
            "knowlege": "knowledge",
            "knowladge": "knowledge",
            "wisdon": "wisdom",
            "wisdome": "wisdom",
            "prayr": "prayer",
            "pryer": "prayer",
            "worshp": "worship",
            "worshipe": "worship",
            "gratitud": "gratitude",
            "gratefullness": "gratitude",
            "thankfullness": "thankfulness",
            "rightiousness": "righteousness",
            "rightousness": "righteousness",
            "compasion": "compassion",
            "compasson": "compassion",
            "kindnes": "kindness",
            "kindnness": "kindness",
            "creatoin": "creation",
            "creaton": "creation",
            "understaning": "understanding",
            "understandng": "understanding",
            "peac": "peace",
            "peacce": "peace",
            "tranquility": "tranquility",
            "tranqulity": "tranquility",

            // Famous verse typos
            "ayat al kursi": "ayat al-kursi",
            "ayat alkursi": "ayat al-kursi",
            "ayatul kursi": "ayat al-kursi",
            "ayat ul kursi": "ayat al-kursi",
            "ayat-al-kursi": "ayat al-kursi",
            "ayat-ul-kursi": "ayat al-kursi",
            "kursy": "kursi",
            "kursee": "kursi",
            "throne vers": "throne verse",
            "thron verse": "throne verse",
            "sustaner": "sustainer",
            "sustainor": "sustainer",
            "qayoom": "qayyoom",
            "qayum": "qayyoom",
            "qayyum": "qayyoom",
            "hay": "hayy",
            "hayy": "hayy",
            "al fatiha": "al-fatiha",
            "alfatiha": "al-fatiha",
            "fatiha": "al-fatiha",

            // Light verse typos
            "light vers": "light verse",
            "lite verse": "light verse",
            "ayat an nur": "ayat an-nur",
            "ayat annur": "ayat an-nur",
            "ayatul nur": "ayat an-nur",
            "nur vers": "nur verse",

            // Food/dietary typos
            "prok": "pork",
            "porc": "pork",
            "swin": "swine",
            "swyne": "swine",
            "haram meat": "haram meat",
            "haraam": "haram",

            // Charity typos
            "charitey": "charity",
            "charaty": "charity",
            "zakat": "zakat",
            "zakaat": "zakat",
            "sadaqa": "sadaqah",
            "sadaka": "sadaqah",
            "alms": "alms",

            // Fasting typos
            "fastin": "fasting",
            "fastng": "fasting",
            "ramadhan": "ramadan",
            "ramzan": "ramadan",
            "iftar": "iftar",
            "iftaar": "iftar",
            "suhoor": "suhur",
            "sahur": "suhur",

            // Prayer typos
            "prostration": "prostration",
            "prostraton": "prostration",
            "sujood": "sujud",
            "sajda": "sujud",
            "rukoo": "ruku",
            "ruku": "ruku"
        ]
    }
    
    /// Calculate Levenshtein distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        
        var matrix = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        
        for i in 0...a.count {
            matrix[i][0] = i
        }
        
        for j in 0...b.count {
            matrix[0][j] = j
        }
        
        for i in 1...a.count {
            for j in 1...b.count {
                if a[i-1] == b[j-1] {
                    matrix[i][j] = matrix[i-1][j-1]
                } else {
                    matrix[i][j] = min(
                        matrix[i-1][j] + 1,     // deletion
                        matrix[i][j-1] + 1,     // insertion
                        matrix[i-1][j-1] + 1    // substitution
                    )
                }
            }
        }
        
        return matrix[a.count][b.count]
    }
}
