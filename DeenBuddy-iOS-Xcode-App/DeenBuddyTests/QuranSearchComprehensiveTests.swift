import XCTest
import Combine
@testable import DeenAssistCore

/// Comprehensive tests for Quran search functionality with complete data validation
class QuranSearchComprehensiveTests: XCTestCase {
    
    var searchService: QuranSearchService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        searchService = QuranSearchService()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables?.removeAll()
        searchService = nil
        super.tearDown()
    }
    
    // MARK: - Data Completeness Tests
    
    func testQuranDataCompleteness() async {
        // Wait for data to load
        await waitForDataLoad()
        
        let validation = searchService.getDataValidationStatus()
        XCTAssertNotNil(validation, "Data validation result should be available")
        
        if let validation = validation {
            print("📊 Validation Summary:")
            print(validation.summary)
            
            // Test total verse count
            XCTAssertEqual(validation.totalVerses, QuranDataValidator.EXPECTED_TOTAL_VERSES,
                          "Should have exactly \(QuranDataValidator.EXPECTED_TOTAL_VERSES) verses")
            
            // Test total surah count
            XCTAssertEqual(validation.totalSurahs, QuranDataValidator.EXPECTED_TOTAL_SURAHS,
                          "Should have exactly \(QuranDataValidator.EXPECTED_TOTAL_SURAHS) surahs")
            
            // Test validation passes
            XCTAssertTrue(validation.isValid, "Quran data validation should pass")
            
            // Test no missing verses
            XCTAssertTrue(validation.missingVerses.isEmpty, "Should have no missing verses")
            
            // Test no missing surahs
            XCTAssertTrue(validation.missingSurahs.isEmpty, "Should have no missing surahs")
            
            // Test no invalid verses
            XCTAssertTrue(validation.invalidVerses.isEmpty, "Should have no invalid verses")
        }
    }
    
    func testSpecificSurahCompleteness() async {
        await waitForDataLoad()
        
        // Test Al-Fatiha (7 verses)
        let fatihaVerses = searchService.getVersesFromSurah(1)
        XCTAssertEqual(fatihaVerses.count, 7, "Al-Fatiha should have 7 verses")
        
        // Test Al-Baqarah (286 verses)
        let baqarahVerses = searchService.getVersesFromSurah(2)
        XCTAssertEqual(baqarahVerses.count, 286, "Al-Baqarah should have 286 verses")
        
        // Test Al-Ikhlas (4 verses)
        let ikhlasVerses = searchService.getVersesFromSurah(112)
        XCTAssertEqual(ikhlasVerses.count, 4, "Al-Ikhlas should have 4 verses")
        
        // Test An-Nas (6 verses)
        let nasVerses = searchService.getVersesFromSurah(114)
        XCTAssertEqual(nasVerses.count, 6, "An-Nas should have 6 verses")
    }
    
    // MARK: - Search Functionality Tests
    
    func testArabicTextSearch() async {
        await waitForDataLoad()
        
        // Test search for "الله" (Allah)
        await searchService.searchVerses(query: "الله")
        
        XCTAssertFalse(searchService.searchResults.isEmpty, "Should find verses containing 'الله'")
        XCTAssertGreaterThan(searchService.searchResults.count, 100, "Should find many verses with 'الله'")
        
        // Verify all results contain the search term
        for result in searchService.searchResults {
            XCTAssertTrue(result.verse.textArabic.contains("الله"), 
                         "All results should contain 'الله' in Arabic text")
        }
    }
    
    func testEnglishTranslationSearch() async {
        await waitForDataLoad()
        
        // Test search for "Allah"
        await searchService.searchVerses(query: "Allah")
        
        XCTAssertFalse(searchService.searchResults.isEmpty, "Should find verses containing 'Allah'")
        XCTAssertGreaterThan(searchService.searchResults.count, 100, "Should find many verses with 'Allah'")
        
        // Verify results contain the search term
        for result in searchService.searchResults.prefix(10) {
            XCTAssertTrue(result.verse.textTranslation.lowercased().contains("allah"), 
                         "Results should contain 'Allah' in translation")
        }
    }
    
    func testTransliterationSearch() async {
        await waitForDataLoad()
        
        // Test search for "bismillah"
        await searchService.searchVerses(query: "bismillah")
        
        XCTAssertFalse(searchService.searchResults.isEmpty, "Should find verses containing 'bismillah'")
        
        // Should find Al-Fatiha verse 1
        let fatihaResult = searchService.searchResults.first { 
            $0.verse.surahNumber == 1 && $0.verse.verseNumber == 1 
        }
        XCTAssertNotNil(fatihaResult, "Should find Al-Fatiha verse 1 with 'bismillah'")
    }
    
    func testMultiWordSearch() async {
        await waitForDataLoad()
        
        // Test search for "In the name"
        await searchService.searchVerses(query: "In the name")
        
        XCTAssertFalse(searchService.searchResults.isEmpty, "Should find verses containing 'In the name'")
        
        // Should find Al-Fatiha verse 1
        let fatihaResult = searchService.searchResults.first { 
            $0.verse.surahNumber == 1 && $0.verse.verseNumber == 1 
        }
        XCTAssertNotNil(fatihaResult, "Should find Al-Fatiha verse 1 with 'In the name'")
    }
    
    func testProphetNamesSearch() async {
        await waitForDataLoad()
        
        // Test search for prophet names
        let prophetNames = ["Moses", "Jesus", "Abraham", "Noah", "Muhammad"]
        
        for prophetName in prophetNames {
            await searchService.searchVerses(query: prophetName)
            
            if !searchService.searchResults.isEmpty {
                print("✅ Found \(searchService.searchResults.count) verses mentioning \(prophetName)")
                
                // Verify results contain the prophet's name
                let hasMatch = searchService.searchResults.contains { result in
                    result.verse.textTranslation.lowercased().contains(prophetName.lowercased())
                }
                XCTAssertTrue(hasMatch, "Should find verses mentioning \(prophetName)")
            }
        }
    }
    
    func testPlaceNamesSearch() async {
        await waitForDataLoad()
        
        // Test search for place names
        let placeNames = ["Mecca", "Medina", "Jerusalem", "Egypt", "Babylon"]
        
        for placeName in placeNames {
            await searchService.searchVerses(query: placeName)
            
            if !searchService.searchResults.isEmpty {
                print("✅ Found \(searchService.searchResults.count) verses mentioning \(placeName)")
            }
        }
    }
    
    func testConceptualSearch() async {
        await waitForDataLoad()
        
        // Test search for Islamic concepts
        let concepts = ["prayer", "charity", "pilgrimage", "fasting", "faith", "paradise", "hell"]
        
        for concept in concepts {
            await searchService.searchVerses(query: concept)
            
            XCTAssertFalse(searchService.searchResults.isEmpty, 
                          "Should find verses related to '\(concept)'")
            print("✅ Found \(searchService.searchResults.count) verses about \(concept)")
        }
    }
    
    // MARK: - Search Algorithm Tests
    
    func testPartialWordMatching() async {
        await waitForDataLoad()
        
        // Test partial word search
        await searchService.searchVerses(query: "merci")
        
        XCTAssertFalse(searchService.searchResults.isEmpty, "Should find verses with partial match for 'merci' (merciful)")
    }
    
    func testCaseInsensitiveSearch() async {
        await waitForDataLoad()
        
        // Test different cases
        let queries = ["ALLAH", "allah", "Allah", "aLLaH"]
        var allResults: [Int] = []
        
        for query in queries {
            await searchService.searchVerses(query: query)
            allResults.append(searchService.searchResults.count)
        }
        
        // All should return the same number of results
        let firstCount = allResults.first!
        for count in allResults {
            XCTAssertEqual(count, firstCount, "Case insensitive search should return same results")
        }
    }
    
    // MARK: - Performance Tests
    
    func testSearchPerformance() async {
        await waitForDataLoad()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Perform multiple searches
        let queries = ["Allah", "mercy", "prayer", "guidance", "believers"]
        
        for query in queries {
            await searchService.searchVerses(query: query)
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(timeElapsed, 5.0, "Search should complete within 5 seconds")
        print("⏱️ Search performance: \(timeElapsed) seconds for \(queries.count) queries")
    }
    
    // MARK: - Helper Methods
    
    private func waitForDataLoad() async {
        let expectation = XCTestExpectation(description: "Data loading")
        
        searchService.$isDataLoaded
            .filter { $0 }
            .first()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [expectation], timeout: 30.0)
        
        // Additional wait to ensure data is fully processed
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }
}
