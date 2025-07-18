import XCTest
import SwiftUI
@testable import DeenBuddy
@testable import DeenAssistCore

/// Integration tests for Quran search functionality with UI components
/// Tests the complete search flow from user input to result display
class QuranSearchIntegrationTest: XCTestCase {
    
    private var searchService: QuranSearchService!
    private var semanticEngine: SemanticSearchEngine!
    
    override func setUp() {
        super.setUp()
        searchService = QuranSearchService()
        semanticEngine = SemanticSearchEngine.shared
        
        // Wait for data to load
        let expectation = XCTestExpectation(description: "Data loading")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Integration Tests
    
    /// Test complete search flow for food/dietary terms
    func testFoodDietarySearchIntegration() {
        let expectation = XCTestExpectation(description: "Food dietary search")
        
        Task {
            // Test pork search
            await searchService.searchVerses(query: "pork", searchOptions: QuranSearchOptions())
            
            let results = searchService.enhancedSearchResults
            XCTAssertGreaterThan(results.count, 0, "Pork search should return results")
            
            // Verify semantic expansion worked
            if let expansion = searchService.queryExpansion {
                XCTAssertTrue(expansion.expandedTerms.contains { $0.contains("haram") }, 
                             "Pork should expand to include haram terms")
                XCTAssertTrue(expansion.expandedTerms.contains { $0.contains("forbidden") }, 
                             "Pork should expand to include forbidden terms")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    /// Test complete search flow for charity terms
    func testCharitySearchIntegration() {
        let expectation = XCTestExpectation(description: "Charity search")
        
        Task {
            // Test charity search
            await searchService.searchVerses(query: "charity", searchOptions: QuranSearchOptions())
            
            let results = searchService.enhancedSearchResults
            XCTAssertGreaterThan(results.count, 0, "Charity search should return results")
            
            // Verify semantic expansion
            if let expansion = searchService.queryExpansion {
                XCTAssertTrue(expansion.expandedTerms.contains { $0.contains("zakat") }, 
                             "Charity should expand to include zakat")
                XCTAssertTrue(expansion.expandedTerms.contains { $0.contains("sadaqah") }, 
                             "Charity should expand to include sadaqah")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    /// Test complete search flow for fasting terms
    func testFastingSearchIntegration() {
        let expectation = XCTestExpectation(description: "Fasting search")
        
        Task {
            // Test fasting search
            await searchService.searchVerses(query: "fasting", searchOptions: QuranSearchOptions())
            
            let results = searchService.enhancedSearchResults
            XCTAssertGreaterThan(results.count, 0, "Fasting search should return results")
            
            // Verify semantic expansion
            if let expansion = searchService.queryExpansion {
                XCTAssertTrue(expansion.expandedTerms.contains { $0.contains("sawm") }, 
                             "Fasting should expand to include sawm")
                XCTAssertTrue(expansion.expandedTerms.contains { $0.contains("ramadan") }, 
                             "Fasting should expand to include ramadan")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    /// Test famous verse recognition integration
    func testFamousVerseIntegration() {
        let expectation = XCTestExpectation(description: "Famous verse search")
        
        Task {
            // Test Light Verse search (newly added)
            await searchService.searchVerses(query: "light verse", searchOptions: QuranSearchOptions())
            
            let results = searchService.enhancedSearchResults
            XCTAssertGreaterThan(results.count, 0, "Light verse search should return results")
            
            // Verify correct verse is found
            let lightVerse = results.first { result in
                result.verse.surahNumber == 24 && result.verse.verseNumber == 35
            }
            XCTAssertNotNil(lightVerse, "Should find the Light Verse (24:35)")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    /// Test case-insensitive search integration
    func testCaseInsensitiveIntegration() {
        let expectation = XCTestExpectation(description: "Case insensitive search")
        
        Task {
            let queries = ["ayat al-kursi", "AYAT AL-KURSI", "Ayat Al-Kursi"]
            var resultCounts: [Int] = []
            
            for query in queries {
                await searchService.searchVerses(query: query, searchOptions: QuranSearchOptions())
                resultCounts.append(searchService.enhancedSearchResults.count)
            }
            
            // All variations should return the same number of results
            XCTAssertTrue(resultCounts.allSatisfy { $0 == resultCounts.first }, 
                         "Case variations should return identical results")
            XCTAssertGreaterThan(resultCounts.first ?? 0, 0, 
                               "Should find results for Ayat al-Kursi")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    /// Test Arabic search integration
    func testArabicSearchIntegration() {
        let expectation = XCTestExpectation(description: "Arabic search")
        
        Task {
            // Test Arabic term search
            await searchService.searchVerses(query: "sujud", searchOptions: QuranSearchOptions())
            
            let results = searchService.enhancedSearchResults
            XCTAssertGreaterThan(results.count, 0, "Sujud search should return results")
            
            // Verify semantic expansion includes English terms
            if let expansion = searchService.queryExpansion {
                XCTAssertTrue(expansion.expandedTerms.contains { $0.contains("prostration") }, 
                             "Sujud should expand to include prostration")
                XCTAssertTrue(expansion.expandedTerms.contains { $0.contains("bowing") }, 
                             "Sujud should expand to include bowing")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    /// Test search performance integration
    func testSearchPerformanceIntegration() {
        let expectation = XCTestExpectation(description: "Search performance")
        
        Task {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Test multiple searches in sequence
            await searchService.searchVerses(query: "mercy", searchOptions: QuranSearchOptions())
            await searchService.searchVerses(query: "charity", searchOptions: QuranSearchOptions())
            await searchService.searchVerses(query: "ayat al-kursi", searchOptions: QuranSearchOptions())
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let totalTime = endTime - startTime
            
            // Should complete all searches within reasonable time
            XCTAssertLessThan(totalTime, 2.0, "Multiple searches should complete within 2 seconds")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    /// Test search result quality integration
    func testSearchResultQualityIntegration() {
        let expectation = XCTestExpectation(description: "Search result quality")
        
        Task {
            // Test specific search that should return high-quality results
            await searchService.searchVerses(query: "patience", searchOptions: QuranSearchOptions())
            
            let results = searchService.enhancedSearchResults
            XCTAssertGreaterThan(results.count, 0, "Patience search should return results")
            
            // Verify results are properly ranked
            if results.count > 1 {
                let firstScore = results[0].combinedScore
                let secondScore = results[1].combinedScore
                XCTAssertGreaterThanOrEqual(firstScore, secondScore, 
                                          "Results should be sorted by relevance score")
            }
            
            // Verify results contain relevant information
            for result in results.prefix(3) {
                XCTAssertFalse(result.verse.textTranslation.isEmpty, 
                              "Results should have translation text")
                XCTAssertFalse(result.verse.textArabic.isEmpty, 
                              "Results should have Arabic text")
                XCTAssertGreaterThan(result.combinedScore, 0, 
                                   "Results should have positive relevance score")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    /// Test search options integration
    func testSearchOptionsIntegration() {
        let expectation = XCTestExpectation(description: "Search options")
        
        Task {
            // Test with different search options
            var options = QuranSearchOptions()
            options.searchTranslation = true
            options.searchArabic = true
            options.searchThemes = true
            options.searchKeywords = true
            options.maxResults = 10
            
            await searchService.searchVerses(query: "guidance", searchOptions: options)
            
            let results = searchService.enhancedSearchResults
            XCTAssertGreaterThan(results.count, 0, "Guidance search should return results")
            XCTAssertLessThanOrEqual(results.count, 10, "Should respect maxResults limit")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    /// Test bookmark integration
    func testBookmarkIntegration() {
        let expectation = XCTestExpectation(description: "Bookmark integration")
        
        Task {
            // Search for a verse
            await searchService.searchVerses(query: "ayat al-kursi", searchOptions: QuranSearchOptions())
            
            let results = searchService.enhancedSearchResults
            XCTAssertGreaterThan(results.count, 0, "Should find Ayat al-Kursi")
            
            if let firstResult = results.first {
                let verse = firstResult.verse
                
                // Test bookmark functionality
                XCTAssertFalse(searchService.isBookmarked(verse), "Verse should not be bookmarked initially")
                
                searchService.toggleBookmark(for: verse)
                XCTAssertTrue(searchService.isBookmarked(verse), "Verse should be bookmarked after toggle")
                
                searchService.toggleBookmark(for: verse)
                XCTAssertFalse(searchService.isBookmarked(verse), "Verse should not be bookmarked after second toggle")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - UI Component Tests
    
    /// Test that search components can handle the enhanced results
    func testSearchComponentsIntegration() {
        // This would test UI components in a real implementation
        // For now, we'll test that the data structures are compatible
        
        let mockResult = EnhancedSearchResult(
            verse: createMockVerse(),
            relevanceScore: 8.5,
            semanticScore: 7.2,
            matchedText: "test query",
            matchType: .semantic,
            highlightedText: "Test highlighted text",
            contextSuggestions: ["suggestion1", "suggestion2"],
            queryExpansion: QueryExpansion(
                originalQuery: "test",
                expandedTerms: ["test", "expanded"],
                relatedConcepts: ["concept1"],
                suggestions: ["suggestion1"]
            ),
            relatedVerses: []
        )
        
        // Verify the result structure is valid
        XCTAssertEqual(mockResult.verse.surahNumber, 1)
        XCTAssertEqual(mockResult.relevanceScore, 8.5)
        XCTAssertEqual(mockResult.semanticScore, 7.2)
        XCTAssertGreaterThan(mockResult.combinedScore, 0)
        XCTAssertEqual(mockResult.matchType, .semantic)
    }
    
    // MARK: - Helper Methods
    
    private func createMockVerse() -> QuranVerse {
        return QuranVerse(
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
            themes: ["mercy", "compassion"],
            keywords: ["Allah", "mercy"]
        )
    }
}
