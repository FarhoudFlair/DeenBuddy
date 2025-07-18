import Foundation
import Combine

/// Comprehensive Quran search service with advanced search capabilities
@MainActor
public class QuranSearchService: ObservableObject {

    // MARK: - Published Properties

    @Published public var searchResults: [QuranSearchResult] = []
    @Published public var enhancedSearchResults: [EnhancedSearchResult] = []
    @Published public var isLoading = false
    @Published public var error: Error?
    @Published public var lastQuery = ""
    @Published public var searchHistory: [String] = []
    @Published public var bookmarkedVerses: [QuranVerse] = []
    @Published public var searchSuggestions: [String] = []
    @Published public var queryExpansion: QueryExpansion?
    @Published public var dataValidationResult: QuranDataValidator.ValidationResult?
    @Published public var isDataLoaded = false
    @Published public var loadingProgress: Double = 0.0

    // MARK: - Private Properties

    private var allVerses: [QuranVerse] = []
    private var allSurahs: [QuranSurah] = []
    private let userDefaults = UserDefaults.standard
    private let maxHistoryItems = 20
    private let semanticEngine = SemanticSearchEngine.shared
    private let quranAPIService = QuranAPIService()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Cache Keys

    private enum CacheKeys {
        static let searchHistory = "QuranSearchHistory"
        static let bookmarkedVerses = "BookmarkedQuranVerses"
        static let cachedQuranData = "CachedQuranData"
        static let dataValidationResult = "DataValidationResult"
        static let lastDataUpdate = "LastDataUpdate"
    }

    // MARK: - Initialization

    public init() {
        loadSearchHistory()
        loadBookmarkedVerses()
        loadCompleteQuranData()
    }

    // MARK: - Complete Quran Data Loading

    /// Load complete Quran data from API or cache
    private func loadCompleteQuranData() {
        print("🔧 DEBUG: Starting loadCompleteQuranData()")
        isLoading = true
        loadingProgress = 0.0

        // First try to load from cache
        if let cachedData = loadCachedQuranData() {
            print("📚 Loading Quran data from cache...")
            print("🔧 DEBUG: Cached data contains \(cachedData.count) verses")
            self.allVerses = cachedData
            self.allSurahs = createSurahsFromVerses(cachedData)
            self.isDataLoaded = true
            self.isLoading = false
            self.loadingProgress = 1.0

            // Validate cached data
            let validation = QuranDataValidator.validateQuranData(cachedData)
            self.dataValidationResult = validation

            if validation.isValid {
                print("✅ Cached Quran data validation passed")
                print("🔧 DEBUG: Cache validation successful, allVerses.count = \(self.allVerses.count)")
                return
            } else {
                print("⚠️ Cached data validation failed, fetching fresh data...")
                print("🔧 DEBUG: Cache validation failed - \(validation.summary)")
            }
        } else {
            print("🔧 DEBUG: No cached data found, will fetch from API")
        }

        // Fetch fresh data from API
        fetchCompleteQuranFromAPI()
    }

    /// Fetch complete Quran data from external API
    private func fetchCompleteQuranFromAPI() {
        print("🌐 Fetching complete Quran data from Al-Quran Cloud API...")
        loadingProgress = 0.1

        quranAPIService.fetchCompleteQuranCombined()
            .retry(3) // Retry up to 3 times on failure
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        print("✅ Successfully loaded complete Quran data")
                        self?.isLoading = false
                        self?.loadingProgress = 1.0
                    case .failure(let error):
                        print("❌ Failed to load Quran data after retries: \(error)")
                        self?.error = error
                        self?.isLoading = false
                        self?.loadingProgress = 0.0
                        // Fallback to sample data if API fails
                        self?.loadFallbackSampleData()
                    }
                },
                receiveValue: { [weak self] verses in
                    self?.loadingProgress = 0.8

                    print("🔧 DEBUG: Received \(verses.count) verses from API")

                    // Validate the received data
                    let validation = QuranDataValidator.validateQuranData(verses)
                    self?.dataValidationResult = validation

                    print(validation.summary)

                    if validation.isValid {
                        // Store complete data
                        self?.allVerses = verses
                        self?.allSurahs = self?.createSurahsFromVerses(verses) ?? []
                        self?.isDataLoaded = true

                        // Cache the data for future use
                        self?.cacheQuranData(verses)

                        print("🎉 Complete Quran data loaded successfully!")
                        print("📊 Total verses: \(verses.count)")
                        print("📊 Total surahs: \(Set(verses.map { $0.surahNumber }).count)")
                    } else {
                        print("⚠️ Data validation failed, using fallback data")
                        self?.loadFallbackSampleData()
                    }

                    self?.loadingProgress = 1.0
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - Data Caching

    /// Cache Quran data locally for offline use
    private func cacheQuranData(_ verses: [QuranVerse]) {
        do {
            let data = try JSONEncoder().encode(verses)
            userDefaults.set(data, forKey: CacheKeys.cachedQuranData)
            userDefaults.set(Date(), forKey: CacheKeys.lastDataUpdate)
            print("💾 Quran data cached successfully")
        } catch {
            print("❌ Failed to cache Quran data: \(error)")
        }
    }

    /// Load cached Quran data
    private func loadCachedQuranData() -> [QuranVerse]? {
        guard let data = userDefaults.data(forKey: CacheKeys.cachedQuranData) else {
            return nil
        }

        do {
            let verses = try JSONDecoder().decode([QuranVerse].self, from: data)
            return verses
        } catch {
            print("❌ Failed to decode cached Quran data: \(error)")
            return nil
        }
    }

    /// Create surah objects from verses
    private func createSurahsFromVerses(_ verses: [QuranVerse]) -> [QuranSurah] {
        let groupedVerses = Dictionary(grouping: verses) { $0.surahNumber }
        return groupedVerses.compactMap { surahNumber, surahVerses in
            guard let firstVerse = surahVerses.first else { return nil }

            return QuranSurah(
                number: surahNumber,
                name: firstVerse.surahName,
                nameArabic: firstVerse.surahNameArabic,
                nameTransliteration: firstVerse.surahName, // Use name as transliteration fallback
                meaning: firstVerse.surahName, // Use name as meaning fallback
                verseCount: surahVerses.count,
                revelationPlace: firstVerse.revelationPlace,
                revelationOrder: surahNumber, // Use surah number as revelation order fallback
                verses: surahVerses
            )
        }.sorted { $0.number < $1.number }
    }

    /// Fallback to sample data if API fails
    private func loadFallbackSampleData() {
        print("⚠️ Loading fallback sample data...")
        print("🔧 DEBUG: Creating sample verses...")
        allVerses = createSampleVerses()
        allSurahs = createSampleSurahs()
        isDataLoaded = true

        print("🔧 DEBUG: Sample data created - \(allVerses.count) verses, \(allSurahs.count) surahs")

        // Validate sample data
        let validation = QuranDataValidator.validateQuranData(allVerses)
        dataValidationResult = validation
        print("📊 Sample data validation: \(validation.isValid ? "✅ PASSED" : "❌ FAILED")")
        
        // Log some sample verses for debugging
        for (index, verse) in allVerses.prefix(3).enumerated() {
            print("🔧 DEBUG: Sample verse \(index + 1): \(verse.shortReference) - \(verse.textTranslation.prefix(50))...")
        }
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
                themes: ["mercy", "compassion", "beginning", "prayer", "Allah", "divine names", "bismillah", "opening", "blessing", "invocation", "worship", "devotion", "kindness", "grace", "love"],
                keywords: ["Allah", "Rahman", "Raheem", "mercy", "compassion", "name", "bismillah", "merciful", "gracious", "benevolent", "kind", "loving", "forgiving", "gentle", "tender"]
            ),
            QuranVerse(
                surahNumber: 1, surahName: "Al-Fatiha", surahNameArabic: "الفاتحة",
                verseNumber: 2, textArabic: "الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ",
                textTranslation: "All praise is due to Allah, Lord of the worlds.",
                textTransliteration: "Alhamdu lillahi rabbi l-alameen",
                revelationPlace: .mecca, juzNumber: 1, hizbNumber: 1, rukuNumber: 1, manzilNumber: 1, pageNumber: 1,
                themes: ["praise", "gratitude", "lordship", "creation", "worlds", "thankfulness", "worship", "acknowledgment", "sovereignty", "universe", "dominion", "authority", "reverence", "submission"],
                keywords: ["praise", "Allah", "Lord", "worlds", "creation", "gratitude", "hamd", "rabb", "alameen", "universe", "thankful", "grateful", "worship", "adoration", "reverence", "master", "sustainer", "cherisher", "provider"]
            ),

            // Al-Baqarah (Chapter 2) - Famous verses
            QuranVerse(
                surahNumber: 2, surahName: "Al-Baqarah", surahNameArabic: "البقرة",
                verseNumber: 255, textArabic: "اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ",
                textTranslation: "Allah - there is no deity except Him, the Ever-Living, the Sustainer of existence.",
                textTransliteration: "Allahu la ilaha illa huwa l-hayyu l-qayyoom",
                revelationPlace: .medina, juzNumber: 3, hizbNumber: 5, rukuNumber: 35, manzilNumber: 1, pageNumber: 42,
                themes: ["monotheism", "Allah", "life", "sustenance", "throne", "protection", "unity", "oneness", "divine attributes", "eternity", "permanence", "power", "sovereignty", "knowledge", "guardian", "watchful", "omniscience", "omnipotence", "tawhid", "kursi"],
                keywords: ["Allah", "deity", "living", "sustainer", "throne", "Ayat al-Kursi", "hayy", "qayyoom", "monotheism", "unity", "oneness", "eternal", "everlasting", "self-sustaining", "guardian", "protector", "knowledge", "power", "sovereignty", "kursi", "encompassing", "watchful", "omniscient", "omnipotent", "divine", "sacred", "holy", "tawhid", "la ilaha illa Allah"]
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
            ),
            
            // Add more comprehensive sample data for testing
            QuranVerse(
                surahNumber: 2, surahName: "Al-Baqarah", surahNameArabic: "البقرة",
                verseNumber: 155, textArabic: "وَلَنَبْلُوَنَّكُم بِشَيْءٍ مِّنَ الْخَوْفِ وَالْجُوعِ",
                textTranslation: "And We will surely test you with something of fear and hunger and a loss of wealth and lives and fruits, but give good tidings to the patient.",
                textTransliteration: "Wa la nablu wannakum bi shay'in minal khawfi wal ju'i",
                revelationPlace: .medina, juzNumber: 2, hizbNumber: 3, rukuNumber: 19, manzilNumber: 1, pageNumber: 24,
                themes: ["test", "trial", "patience", "fear", "hunger", "loss", "good tidings"],
                keywords: ["test", "fear", "hunger", "patient", "trial", "loss", "wealth"]
            ),
            QuranVerse(
                surahNumber: 4, surahName: "An-Nisa", surahNameArabic: "النساء", 
                verseNumber: 29, textArabic: "يَا أَيُّهَا الَّذِينَ آمَنُوا لَا تَأْكُلُوا أَمْوَالَكُم",
                textTranslation: "O you who believe! Do not consume one another's wealth unjustly but only [in lawful] business by mutual consent.",
                textTransliteration: "Ya ayyuha alladheena amanoo la ta'kuloo amwalakum",
                revelationPlace: .medina, juzNumber: 5, hizbNumber: 9, rukuNumber: 4, manzilNumber: 2, pageNumber: 83,
                themes: ["wealth", "justice", "business", "consent", "believers", "lawful"],
                keywords: ["believe", "wealth", "consume", "unjustly", "business", "consent"]
            ),
            QuranVerse(
                surahNumber: 5, surahName: "Al-Ma'idah", surahNameArabic: "المائدة",
                verseNumber: 3, textArabic: "حُرِّمَتْ عَلَيْكُمُ الْمَيْتَةُ وَالدَّمُ وَلَحْمُ الْخِنزِيرِ",
                textTranslation: "Prohibited to you are dead animals, blood, the flesh of swine, and that which has been dedicated to other than Allah.",
                textTransliteration: "Hurrimat 'alaykumu al-maytatu wa'd-damu wa lahmu al-khinzeer",
                revelationPlace: .medina, juzNumber: 6, hizbNumber: 11, rukuNumber: 1, manzilNumber: 2, pageNumber: 106,
                themes: ["prohibited", "food", "lawful", "unlawful", "dead animals", "blood", "swine", "dedicated"],
                keywords: ["prohibited", "dead", "animals", "blood", "flesh", "swine", "dedicated", "Allah"]
            ),
            QuranVerse(
                surahNumber: 6, surahName: "Al-An'am", surahNameArabic: "الأنعام",
                verseNumber: 145, textArabic: "قُل لَّا أَجِدُ فِي مَا أُوحِيَ إِلَيَّ مُحَرَّمًا",
                textTranslation: "Say, 'I do not find within that which was revealed to me [anything] forbidden to the one who would eat it unless it be a dead animal or blood spilled out or the flesh of swine.'",
                textTransliteration: "Qul la ajidu fi ma oohiya ilayya muharraman",
                revelationPlace: .mecca, juzNumber: 8, hizbNumber: 15, rukuNumber: 18, manzilNumber: 3, pageNumber: 148,
                themes: ["revelation", "forbidden", "food", "dead animal", "blood", "swine", "flesh"],
                keywords: ["revealed", "forbidden", "dead", "animal", "blood", "spilled", "flesh", "swine"]
            ),
            QuranVerse(
                surahNumber: 16, surahName: "An-Nahl", surahNameArabic: "النحل",
                verseNumber: 115, textArabic: "إِنَّمَا حَرَّمَ عَلَيْكُمُ الْمَيْتَةَ وَالدَّمَ وَلَحْمَ الْخِنزِيرِ",
                textTranslation: "He has only forbidden to you dead animals, blood, the flesh of swine, and that which has been dedicated to other than Allah.",
                textTransliteration: "Innama harrama 'alaykumu al-maytata wa'd-dama wa lahma al-khinzeer",
                revelationPlace: .mecca, juzNumber: 14, hizbNumber: 28, rukuNumber: 14, manzilNumber: 4, pageNumber: 278,
                themes: ["forbidden", "dead animals", "blood", "swine", "dedicated", "Allah"],
                keywords: ["forbidden", "dead", "animals", "blood", "flesh", "swine", "dedicated", "Allah"]
            ),
            QuranVerse(
                surahNumber: 17, surahName: "Al-Isra", surahNameArabic: "الإسراء",
                verseNumber: 70, textArabic: "وَلَقَدْ كَرَّمْنَا بَنِي آدَمَ وَحَمَلْنَاهُمْ فِي الْبَرِّ وَالْبَحْرِ",
                textTranslation: "And We have certainly honored the children of Adam and carried them on the land and sea and provided for them of the good things.",
                textTransliteration: "Wa laqad karramna bani Adama wa hamalnahum fi al-barri wa al-bahri",
                revelationPlace: .mecca, juzNumber: 15, hizbNumber: 30, rukuNumber: 9, manzilNumber: 4, pageNumber: 290,
                themes: ["honor", "children", "Adam", "land", "sea", "provision", "good things"],
                keywords: ["honored", "children", "Adam", "carried", "land", "sea", "provided", "good"]
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

    // MARK: - Debug Methods

    /// Test method to debug search functionality
    public func testSearch(query: String) {
        print("🔧 DEBUG: Testing search for '\(query)'")

        // Test semantic engine
        let correctedQuery = semanticEngine.correctTypos(in: query)
        print("🔧 DEBUG: Corrected query: '\(correctedQuery)'")

        let expandedTerms = semanticEngine.expandQuery(correctedQuery)
        print("🔧 DEBUG: Expanded terms: \(expandedTerms)")

        // Test famous verse check
        let famousResults = checkForFamousVerses(query: query)
        print("🔧 DEBUG: Famous verse results: \(famousResults.count)")

        // Test verse 2:255 specifically
        if let ayatAlKursi = allVerses.first(where: { $0.surahNumber == 2 && $0.verseNumber == 255 }) {
            print("🔧 DEBUG: Found Ayat al-Kursi verse")
            print("🔧 DEBUG: Keywords: \(ayatAlKursi.keywords)")
            print("🔧 DEBUG: Themes: \(ayatAlKursi.themes)")

            let matches = ayatAlKursi.contains(text: query)
            print("🔧 DEBUG: Direct contains check: \(matches)")

            let semanticMatches = ayatAlKursi.semanticallyMatches(query: query, expandedTerms: expandedTerms)
            print("🔧 DEBUG: Semantic matches: \(semanticMatches)")
        }
    }

    /// Test case-insensitive search functionality
    public func testCaseInsensitiveSearch() {
        print("🔧 DEBUG: === Testing Case-Insensitive Search ===")

        let testQueries = [
            "Ayat al-Kursi",
            "AYAT AL-KURSI",
            "ayat al-kursi",
            "Ayat Al-Kursi",
            "KURSI",
            "kursi",
            "Kursi",
            "THRONE VERSE",
            "throne verse",
            "Throne Verse"
        ]

        for query in testQueries {
            print("🔧 DEBUG: Testing query: '\(query)'")

            // Test famous verse recognition
            let famousResults = checkForFamousVerses(query: query)
            print("🔧 DEBUG: Famous verse matches: \(famousResults.count)")

            // Test semantic expansion
            let expandedTerms = semanticEngine.expandQuery(query)
            print("🔧 DEBUG: Expanded terms: \(expandedTerms)")

            // Test direct verse matching
            if let ayatAlKursi = allVerses.first(where: { $0.surahNumber == 2 && $0.verseNumber == 255 }) {
                let directMatch = ayatAlKursi.contains(text: query)
                let semanticMatch = ayatAlKursi.semanticallyMatches(query: query, expandedTerms: expandedTerms)
                print("🔧 DEBUG: Direct match: \(directMatch), Semantic match: \(semanticMatch)")
            }

            print("🔧 DEBUG: ---")
        }

        print("🔧 DEBUG: === End Case-Insensitive Test ===")
    }

    /// Comprehensive test for case-insensitive search functionality
    public func runCaseInsensitiveTests() async {
        print("🔧 DEBUG: === Running Comprehensive Case-Insensitive Tests ===")

        let testCases = [
            ("Ayat al-Kursi", "Mixed case with hyphens"),
            ("AYAT AL-KURSI", "All uppercase with hyphens"),
            ("ayat al-kursi", "All lowercase with hyphens"),
            ("Ayat Al-Kursi", "Title case with hyphens"),
            ("ayat al kursi", "Lowercase with spaces"),
            ("AYAT AL KURSI", "Uppercase with spaces"),
            ("Ayat Al Kursi", "Title case with spaces"),
            ("KURSI", "Single word uppercase"),
            ("kursi", "Single word lowercase"),
            ("Kursi", "Single word title case"),
            ("THRONE VERSE", "Alternative name uppercase"),
            ("throne verse", "Alternative name lowercase"),
            ("Throne Verse", "Alternative name title case")
        ]

        for (query, description) in testCases {
            print("🔧 DEBUG: Testing '\(query)' (\(description))")

            // Test the full search flow
            await searchVerses(query: query)

            let foundResults = !enhancedSearchResults.isEmpty
            let hasAyatAlKursi = enhancedSearchResults.contains { result in
                result.verse.surahNumber == 2 && result.verse.verseNumber == 255
            }

            print("🔧 DEBUG: Results found: \(foundResults), Contains Ayat al-Kursi: \(hasAyatAlKursi)")

            if hasAyatAlKursi {
                let ayatResult = enhancedSearchResults.first { $0.verse.surahNumber == 2 && $0.verse.verseNumber == 255 }
                print("🔧 DEBUG: Ayat al-Kursi relevance score: \(ayatResult?.relevanceScore ?? 0)")
                print("🔧 DEBUG: Match type: \(ayatResult?.matchType ?? .partial)")
            }

            print("🔧 DEBUG: ---")
        }

        print("🔧 DEBUG: === End Comprehensive Case-Insensitive Tests ===")
    }

    // MARK: - Public Search Methods
    
    /// Perform comprehensive search across Quran verses
    public func searchVerses(query: String, searchOptions: QuranSearchOptions = QuranSearchOptions()) async {
        print("🔧 DEBUG: searchVerses called with query: '\(query)'")
        print("🔧 DEBUG: allVerses.count = \(allVerses.count)")
        print("🔧 DEBUG: isDataLoaded = \(isDataLoaded)")
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("🔧 DEBUG: Empty query, returning empty results")
            searchResults = []
            enhancedSearchResults = []
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
            
            // Use semantic search for enhanced results
            let results = await performSemanticSearch(query: query, options: searchOptions)
            print("🔧 DEBUG: performSemanticSearch returned \(results.count) results")
            enhancedSearchResults = results.sorted { $0.combinedScore > $1.combinedScore }
            
            // Also maintain legacy results for backward compatibility
            searchResults = results.map { enhancedResult in
                QuranSearchResult(
                    verse: enhancedResult.verse,
                    relevanceScore: enhancedResult.relevanceScore,
                    matchedText: enhancedResult.matchedText,
                    matchType: enhancedResult.matchType,
                    highlightedText: enhancedResult.highlightedText,
                    contextSuggestions: enhancedResult.contextSuggestions
                )
            }
            
            print("🔧 DEBUG: Final search results count: \(searchResults.count)")
            
        } catch {
            print("🔧 DEBUG: Search error: \(error)")
            self.error = error
            searchResults = []
            enhancedSearchResults = []
        }
        
        isLoading = false
    }
    
    /// Check for famous verse names first
    private func checkForFamousVerses(query: String) -> [EnhancedSearchResult] {
        let queryLower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Famous verse mappings
        let famousVerses: [String: (surah: Int, verse: Int)] = [
            // Ayat al-Kursi (Throne Verse) - 2:255
            "ayat al-kursi": (2, 255),
            "ayat al kursi": (2, 255),
            "ayatul kursi": (2, 255),
            "ayat ul kursi": (2, 255),
            "throne verse": (2, 255),
            "kursi": (2, 255),
            "throne": (2, 255),
            "sustainer verse": (2, 255),

            // Al-Fatiha (The Opening) - 1:1-7
            "al-fatiha": (1, 1),
            "fatiha": (1, 1),
            "opening": (1, 1),
            "bismillah": (1, 1),
            "opening verse": (1, 1),
            "mother of the book": (1, 1),

            // Light Verse (Ayat an-Nur) - 24:35
            "light verse": (24, 35),
            "ayat an-nur": (24, 35),
            "ayat an nur": (24, 35),
            "nur verse": (24, 35),
            "allah is light": (24, 35),

            // Ikhlas (Sincerity) - 112:1-4
            "ikhlas": (112, 1),
            "sincerity": (112, 1),
            "purity": (112, 1),
            "say he is allah one": (112, 1),

            // Al-Falaq (The Daybreak) - 113:1-5
            "falaq": (113, 1),
            "daybreak": (113, 1),
            "dawn": (113, 1),
            "refuge": (113, 1),

            // An-Nas (Mankind) - 114:1-6
            "nas": (114, 1),
            "mankind": (114, 1),
            "people": (114, 1),

            // Death Verse - 3:185
            "death verse": (3, 185),
            "every soul will taste death": (3, 185),
            "taste death": (3, 185),

            // Burden Verse - 2:286
            "burden verse": (2, 286),
            "allah does not burden": (2, 286),
            "does not charge": (2, 286),
            "capacity": (2, 286)
        ]

        // Check if query matches any famous verse (case-insensitive)
        for (name, location) in famousVerses {
            // Exact match check (case-insensitive)
            if queryLower == name {
                if let verse = allVerses.first(where: { $0.surahNumber == location.surah && $0.verseNumber == location.verse }) {
                    print("🔧 DEBUG: Found exact famous verse match: '\(name)' -> \(verse.shortReference)")
                    return [EnhancedSearchResult(
                        verse: verse,
                        relevanceScore: 10.0,
                        semanticScore: 10.0,
                        matchedText: name,
                        matchType: .exact,
                        highlightedText: verse.textTranslation,
                        contextSuggestions: [name, "monotheism", "unity", "protection"],
                        queryExpansion: QueryExpansion(
                            originalQuery: name,
                            expandedTerms: [name, "monotheism", "unity"],
                            relatedConcepts: ["Tawhid", "Oneness"],
                            suggestions: ["search by verse reference", "search by theme"]
                        ),
                        relatedVerses: verse.getRelatedVerses(from: allVerses, limit: 3)
                    )]
                }
            }

            // Partial match check (case-insensitive)
            if queryLower.contains(name) || name.contains(queryLower) {
                if let verse = allVerses.first(where: { $0.surahNumber == location.surah && $0.verseNumber == location.verse }) {
                    print("🔧 DEBUG: Found partial famous verse match: '\(name)' -> \(verse.shortReference)")
                    return [EnhancedSearchResult(
                        verse: verse,
                        relevanceScore: 9.0, // Slightly lower for partial matches
                        semanticScore: 9.0,
                        matchedText: name,
                        matchType: .semantic,
                        highlightedText: verse.textTranslation,
                        contextSuggestions: [name, "monotheism", "unity", "protection"],
                        queryExpansion: QueryExpansion(
                            originalQuery: name,
                            expandedTerms: [name, "monotheism", "unity"],
                            relatedConcepts: ["Tawhid", "Oneness"],
                            suggestions: ["search by verse reference", "search by theme"]
                        ),
                        relatedVerses: verse.getRelatedVerses(from: allVerses, limit: 3)
                    )]
                }
            }
        }

        return []
    }

    /// Perform semantic search with expanded query terms
    private func performSemanticSearch(query: String, options: QuranSearchOptions) async -> [EnhancedSearchResult] {
        print("🔧 DEBUG: performSemanticSearch called with query: '\(query)'")
        print("🔧 DEBUG: Processing \(allVerses.count) verses")

        // First check for famous verses
        let famousResults = checkForFamousVerses(query: query)
        if !famousResults.isEmpty {
            print("🔧 DEBUG: Found \(famousResults.count) famous verse matches")
            return famousResults
        }

        // Correct typos
        let correctedQuery = semanticEngine.correctTypos(in: query)
        print("🔧 DEBUG: Corrected query: '\(correctedQuery)'")

        // Expand query with synonyms and related terms
        let expandedTerms = semanticEngine.expandQuery(correctedQuery)
        print("🔧 DEBUG: Expanded terms: \(expandedTerms)")
        
        // Determine query type
        let queryType = determineQueryType(query)
        print("🔧 DEBUG: Query type: \(queryType)")
        
        // Create query expansion object
        let expansion = QueryExpansion(
            originalQuery: query,
            expandedTerms: expandedTerms,
            relatedConcepts: semanticEngine.getRelatedConcepts(for: correctedQuery),
            suggestions: semanticEngine.getSearchSuggestions(for: correctedQuery),
            correctedQuery: correctedQuery != query ? correctedQuery : nil,
            queryType: queryType
        )
        
        queryExpansion = expansion
        
        var results: [EnhancedSearchResult] = []
        
        for (index, verse) in allVerses.enumerated() {
            // Special debug for verse 2:255 (Ayat al-Kursi)
            if verse.surahNumber == 2 && verse.verseNumber == 255 {
                print("🔧 DEBUG: Checking Ayat al-Kursi (2:255)")
                print("🔧 DEBUG: Original query: '\(expansion.originalQuery)'")
                print("🔧 DEBUG: Expanded terms: \(expansion.expandedTerms)")
                print("🔧 DEBUG: Verse keywords: \(verse.keywords)")
                print("🔧 DEBUG: Verse themes: \(verse.themes)")

                let matches = verse.semanticallyMatches(query: expansion.originalQuery, expandedTerms: expansion.expandedTerms)
                print("🔧 DEBUG: Ayat al-Kursi semantically matches: \(matches)")

                // Test individual terms
                for term in [expansion.originalQuery] + expansion.expandedTerms {
                    let termMatches = verse.contains(text: term)
                    print("🔧 DEBUG: Term '\(term)' matches: \(termMatches)")
                }
            }

            if let result = evaluateVerseSemanticallly(verse, expansion: expansion, options: options) {
                results.append(result)
                if index < 5 { // Log first 5 matches for debugging
                    print("🔧 DEBUG: Match found at verse \(verse.shortReference): \(result.matchType)")
                }
            }
        }
        
        print("🔧 DEBUG: Found \(results.count) semantic matches")
        return results
    }
    
    /// Evaluate verse using semantic search
    private func evaluateVerseSemanticallly(_ verse: QuranVerse, expansion: QueryExpansion, options: QuranSearchOptions) -> EnhancedSearchResult? {
        // Check if verse matches using expanded terms
        guard verse.semanticallyMatches(query: expansion.originalQuery, expandedTerms: expansion.expandedTerms) else {
            return nil
        }
        
        // Calculate relevance score (original method)
        let relevanceScore = calculateRelevanceScore(verse, query: expansion.originalQuery, options: options)
        
        // Calculate semantic score using expanded terms
        let semanticScore = verse.semanticRelevanceScore(for: expansion.originalQuery, expandedTerms: expansion.expandedTerms)
        
        guard relevanceScore > 0 || semanticScore > 0 else { return nil }
        
        // Determine match type
        let matchType = determineMatchType(verse, query: expansion.originalQuery, expandedTerms: expansion.expandedTerms)
        
        // Generate highlighted text
        let highlightedText = generateHighlightedText(verse, query: expansion.originalQuery, expandedTerms: expansion.expandedTerms)
        
        // Find related verses
        let relatedVerses = verse.getRelatedVerses(from: allVerses, limit: 3)
        
        // Generate context suggestions
        let contextSuggestions = generateContextSuggestions(for: verse, expansion: expansion)
        
        return EnhancedSearchResult(
            verse: verse,
            relevanceScore: relevanceScore,
            semanticScore: semanticScore,
            matchedText: expansion.originalQuery,
            matchType: matchType,
            highlightedText: highlightedText,
            contextSuggestions: contextSuggestions,
            queryExpansion: expansion,
            relatedVerses: relatedVerses
        )
    }
    
    /// Generate real-time search suggestions
    public func generateSearchSuggestions(for partialQuery: String) {
        guard !partialQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchSuggestions = []
            return
        }
        
        searchSuggestions = semanticEngine.getSearchSuggestions(for: partialQuery)
    }
    
    /// Get intelligent search suggestions based on context
    public func getIntelligentSuggestions(for query: String) -> [String] {
        let expandedTerms = semanticEngine.expandQuery(query)
        let relatedConcepts = semanticEngine.getRelatedConcepts(for: query)
        
        var suggestions: Set<String> = []
        
        // Add expanded terms
        suggestions.formUnion(expandedTerms)
        
        // Add related concepts
        suggestions.formUnion(relatedConcepts)
        
        // Add theme-based suggestions
        for verse in allVerses {
            if verse.contains(text: query) {
                suggestions.formUnion(verse.themes)
                suggestions.formUnion(verse.keywords)
            }
        }
        
        // Remove the original query and return top suggestions
        suggestions.remove(query.lowercased())
        return Array(suggestions).sorted().prefix(8).map { $0 }
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

    // MARK: - Data Management

    /// Refresh Quran data from API
    public func refreshQuranData() {
        print("🔄 Refreshing Quran data from API...")
        // Clear cache and reload
        userDefaults.removeObject(forKey: CacheKeys.cachedQuranData)
        userDefaults.removeObject(forKey: CacheKeys.lastDataUpdate)
        
        // Reset state
        allVerses.removeAll()
        allSurahs.removeAll()
        isDataLoaded = false
        error = nil
        dataValidationResult = nil
        
        loadCompleteQuranData()
    }

    /// Get data validation status
    public func getDataValidationStatus() -> QuranDataValidator.ValidationResult? {
        return dataValidationResult
    }

    /// Check if complete Quran data is loaded
    public func isCompleteDataLoaded() -> Bool {
        return isDataLoaded && allVerses.count == QuranDataValidator.EXPECTED_TOTAL_VERSES
    }

    /// Get data loading progress (0.0 to 1.0)
    public func getLoadingProgress() -> Double {
        return loadingProgress
    }

    /// Get total verses count
    public func getTotalVersesCount() -> Int {
        return allVerses.count
    }

    /// Get total surahs count
    public func getTotalSurahsCount() -> Int {
        return allSurahs.count
    }

    /// Force reload data (useful for testing)
    public func forceReloadData() {
        allVerses.removeAll()
        allSurahs.removeAll()
        isDataLoaded = false
        loadCompleteQuranData()
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
    
    /// Determine the type of query being performed
    private func determineQueryType(_ query: String) -> QueryType {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanQueryLower = cleanQuery.lowercased()

        // Check if it's a reference (e.g., "2:255", "Al-Baqarah 255")
        if cleanQuery.contains(":") && cleanQuery.components(separatedBy: ":").count == 2 {
            return .reference
        }

        // Check if it's a question (case-insensitive)
        if cleanQueryLower.hasPrefix("what") || cleanQueryLower.hasPrefix("how") || cleanQueryLower.hasPrefix("why") || cleanQueryLower.hasPrefix("when") || cleanQueryLower.hasPrefix("where") {
            return .question
        }
        
        // Check if it contains Arabic characters
        if cleanQuery.rangeOfCharacter(from: CharacterSet(charactersIn: "ابتثجحخدذرزسشصضطظعغفقكلمنهوي")) != nil {
            return .arabic
        }
        
        // Check if it's a common theme (case-insensitive)
        let commonThemes = ["prayer", "mercy", "guidance", "patience", "forgiveness", "paradise", "hell", "death", "life", "love", "fear", "knowledge", "wisdom", "justice", "peace"]
        if commonThemes.contains(cleanQueryLower) {
            return .theme
        }
        
        // Check if it's a concept
        let commonConcepts = ["allah", "god", "lord", "creator", "faith", "belief", "worship", "devotion", "community", "family", "charity", "gratitude"]
        if commonConcepts.contains(cleanQuery.lowercased()) {
            return .concept
        }
        
        return .general
    }
    
    /// Calculate relevance score for a verse
    private func calculateRelevanceScore(_ verse: QuranVerse, query: String, options: QuranSearchOptions) -> Double {
        var score: Double = 0
        let lowercasedQuery = query.lowercased()
        
        // Check translation match
        if options.searchTranslation && verse.textTranslation.lowercased().contains(lowercasedQuery) {
            score += calculateTranslationScore(verse.textTranslation, query: lowercasedQuery)
        }
        
        // Check Arabic text match
        if options.searchArabic && verse.textArabic.lowercased().contains(lowercasedQuery) {
            score += 10.0 // Higher score for Arabic matches
        }
        
        // Check transliteration match
        if options.searchTransliteration,
           let transliteration = verse.textTransliteration,
           transliteration.lowercased().contains(lowercasedQuery) {
            score += 8.0
        }
        
        // Check theme match
        if options.searchThemes && verse.themes.contains(where: { $0.lowercased().contains(lowercasedQuery) }) {
            score += 6.0
        }
        
        // Check keyword match
        if options.searchKeywords && verse.keywords.contains(where: { $0.lowercased().contains(lowercasedQuery) }) {
            score += 5.0
        }
        
        // Check Surah name match
        if verse.surahName.lowercased().contains(lowercasedQuery) || verse.surahNameArabic.contains(lowercasedQuery) {
            score += 4.0
        }
        
        return score
    }
    
    /// Determine match type for semantic search
    private func determineMatchType(_ verse: QuranVerse, query: String, expandedTerms: [String]) -> MatchType {
        let queryLower = query.lowercased()
        
        // Check exact match in translation
        if verse.textTranslation.lowercased().contains(queryLower) {
            return .exact
        }
        
        // Check exact match in Arabic
        if verse.textArabic.lowercased().contains(queryLower) {
            return .exact
        }
        
        // Check exact match in transliteration
        if verse.textTransliteration?.lowercased().contains(queryLower) ?? false {
            return .exact
        }
        
        // Check if any expanded term matches exactly
        for term in expandedTerms {
            if verse.textTranslation.lowercased().contains(term.lowercased()) {
                return .semantic
            }
        }
        
        // Check theme match
        if verse.themes.contains(where: { $0.lowercased().contains(queryLower) }) {
            return .thematic
        }
        
        // Check keyword match
        if verse.keywords.contains(where: { $0.lowercased().contains(queryLower) }) {
            return .keyword
        }
        
        return .partial
    }
    
    /// Generate highlighted text with matched terms
    private func generateHighlightedText(_ verse: QuranVerse, query: String, expandedTerms: [String]) -> String {
        var highlightedText = verse.textTranslation
        let allTerms = [query] + expandedTerms
        
        // Simple highlighting - in a real app, this would use AttributedString
        for term in allTerms {
            highlightedText = highlightedText.replacingOccurrences(
                of: term,
                with: "**\(term)**",
                options: .caseInsensitive
            )
        }
        
        return highlightedText
    }
    
    /// Generate context suggestions for a verse
    private func generateContextSuggestions(for verse: QuranVerse, expansion: QueryExpansion) -> [String] {
        var suggestions: [String] = []
        
        // Add expanded terms as suggestions
        suggestions.append(contentsOf: expansion.expandedTerms.prefix(3))
        
        // Add related concepts
        suggestions.append(contentsOf: expansion.relatedConcepts.prefix(2))
        
        // Add verse themes
        suggestions.append(contentsOf: verse.themes.prefix(2))
        
        // Add Surah-based suggestion
        suggestions.append("More from \(verse.surahName)")
        
        // Add Juz-based suggestion
        suggestions.append("Juz \(verse.juzNumber)")
        
        // Remove duplicates and return top suggestions
        let uniqueSuggestions = Array(Set(suggestions))
        return Array(uniqueSuggestions.prefix(6))
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
