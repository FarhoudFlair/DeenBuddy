import XCTest
import Foundation
@testable import DeenAssistCore

/// Comprehensive test suite for Quran search functionality
/// Tests search coverage, synonym mapping, famous verses, case-insensitive search, and performance
class QuranSearchComprehensiveTest: XCTestCase {
    
    private var searchService: QuranSearchService!
    private var semanticEngine: SemanticSearchEngine!
    private var testResults: [TestResult] = []
    
    override func setUp() {
        super.setUp()
        searchService = QuranSearchService()
        semanticEngine = SemanticSearchEngine.shared
        testResults = []
        
        // Wait for data to load
        let expectation = XCTestExpectation(description: "Data loading")
        
        // Check if data is already loaded
        if searchService.isCompleteDataLoaded() {
            expectation.fulfill()
        } else {
            // Wait for data to load with timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    override func tearDown() {
        generateTestReport()
        super.tearDown()
    }
    
    // MARK: - Test Categories
    
    /// Test 1: Synonym and Related Term Coverage
    func testSynonymAndRelatedTermCoverage() {
        print("\n🧪 Testing Synonym and Related Term Coverage...")
        
        let testCases: [(query: String, expectedTerms: [String], category: String)] = [
            // Food/Dietary Terms
            ("pork", ["swine", "pig", "haram", "forbidden"], "Food/Dietary"),
            ("swine", ["pork", "pig", "haram", "forbidden"], "Food/Dietary"),
            ("pig", ["pork", "swine", "haram", "forbidden"], "Food/Dietary"),
            
            // Prayer Terms
            ("prayer", ["salah", "worship", "prostration", "dua"], "Prayer"),
            ("salah", ["prayer", "worship", "namaz"], "Prayer"),
            ("prostration", ["sujud", "bowing", "worship"], "Prayer"),
            ("worship", ["prayer", "salah", "devotion"], "Prayer"),
            
            // Charity Terms
            ("charity", ["zakat", "sadaqah", "giving", "poor"], "Charity"),
            ("zakat", ["charity", "purification", "giving"], "Charity"),
            ("sadaqah", ["charity", "giving", "voluntary"], "Charity"),
            ("giving", ["charity", "zakat", "sadaqah"], "Charity"),
            
            // Fasting Terms
            ("fasting", ["sawm", "ramadan", "abstaining"], "Fasting"),
            ("sawm", ["fasting", "abstinence", "self-control"], "Fasting"),
            ("ramadan", ["fasting", "sawm", "month"], "Fasting"),
            ("abstaining", ["fasting", "sawm", "self-control"], "Fasting")
        ]
        
        for testCase in testCases {
            let expandedTerms = semanticEngine.expandQuery(testCase.query)
            let hasExpectedTerms = testCase.expectedTerms.allSatisfy { expectedTerm in
                expandedTerms.contains { expandedTerm in
                    expandedTerm.lowercased().contains(expectedTerm.lowercased())
                }
            }
            
            let result = TestResult(
                category: testCase.category,
                query: testCase.query,
                passed: hasExpectedTerms,
                details: "Expanded terms: \(expandedTerms)",
                expectedTerms: testCase.expectedTerms,
                actualTerms: expandedTerms
            )
            
            testResults.append(result)
            
            if !hasExpectedTerms {
                print("❌ \(testCase.category): '\(testCase.query)' missing expected terms")
                print("   Expected: \(testCase.expectedTerms)")
                print("   Got: \(expandedTerms)")
            } else {
                print("✅ \(testCase.category): '\(testCase.query)' has good coverage")
            }
        }
    }
    
    /// Test 2: Famous Verse Name Recognition
    func testFamousVerseRecognition() {
        print("\n🧪 Testing Famous Verse Recognition...")
        
        let famousVerseTests: [(query: String, expectedSurah: Int, expectedVerse: Int)] = [
            // Ayat al-Kursi variations
            ("ayat al-kursi", 2, 255),
            ("Ayat Al-Kursi", 2, 255),
            ("AYAT AL-KURSI", 2, 255),
            ("ayat al kursi", 2, 255),
            ("ayatul kursi", 2, 255),
            ("throne verse", 2, 255),
            ("Throne Verse", 2, 255),
            ("kursi", 2, 255),
            
            // Other famous verses
            ("al-fatiha", 1, 1),
            ("Al-Fatiha", 1, 1),
            ("fatiha", 1, 1),
            ("opening", 1, 1),
            ("ikhlas", 112, 1),
            ("sincerity", 112, 1),
            
            // Light Verse (should be added)
            ("light verse", 24, 35),
            ("Light Verse", 24, 35),
            ("ayat an-nur", 24, 35),
            ("Ayat an-Nur", 24, 35)
        ]
        
        for test in famousVerseTests {
            Task {
                await searchService.searchVerses(query: test.query, searchOptions: QuranSearchOptions())
                
                let results = searchService.enhancedSearchResults
                let foundExpectedVerse = results.contains { result in
                    result.verse.surahNumber == test.expectedSurah && 
                    result.verse.verseNumber == test.expectedVerse
                }
                
                let testResult = TestResult(
                    category: "Famous Verses",
                    query: test.query,
                    passed: foundExpectedVerse,
                    details: "Expected: \(test.expectedSurah):\(test.expectedVerse), Found: \(results.count) results",
                    expectedTerms: ["\(test.expectedSurah):\(test.expectedVerse)"],
                    actualTerms: results.map { "\($0.verse.surahNumber):\($0.verse.verseNumber)" }
                )
                
                testResults.append(testResult)
                
                if !foundExpectedVerse {
                    print("❌ Famous verse: '\(test.query)' should find \(test.expectedSurah):\(test.expectedVerse)")
                } else {
                    print("✅ Famous verse: '\(test.query)' correctly found \(test.expectedSurah):\(test.expectedVerse)")
                }
            }
        }
    }
    
    /// Test 3: Case-Insensitive Search Verification
    func testCaseInsensitiveSearch() {
        print("\n🧪 Testing Case-Insensitive Search...")
        
        let caseTestQueries = [
            "mercy", "MERCY", "Mercy", "mErCy",
            "allah", "ALLAH", "Allah", "aLLaH",
            "prayer", "PRAYER", "Prayer", "pRaYeR",
            "ayat al-kursi", "AYAT AL-KURSI", "Ayat Al-Kursi"
        ]
        
        for baseQuery in ["mercy", "allah", "prayer", "ayat al-kursi"] {
            let variations = caseTestQueries.filter { $0.lowercased() == baseQuery.lowercased() }
            var resultCounts: [Int] = []
            
            for variation in variations {
                Task {
                    await searchService.searchVerses(query: variation, searchOptions: QuranSearchOptions())
                    resultCounts.append(searchService.enhancedSearchResults.count)
                }
            }
            
            let allCountsEqual = resultCounts.allSatisfy { $0 == resultCounts.first }
            
            let testResult = TestResult(
                category: "Case Insensitive",
                query: baseQuery,
                passed: allCountsEqual,
                details: "Result counts: \(resultCounts)",
                expectedTerms: ["consistent results"],
                actualTerms: resultCounts.map { String($0) }
            )
            
            testResults.append(testResult)
            
            if !allCountsEqual {
                print("❌ Case sensitivity issue with '\(baseQuery)': \(resultCounts)")
            } else {
                print("✅ Case insensitive search working for '\(baseQuery)'")
            }
        }
    }
    
    /// Test 4: Arabic and English Search
    func testArabicAndEnglishSearch() {
        print("\n🧪 Testing Arabic and English Search...")
        
        let bilingualTests: [(arabic: String, english: String, description: String)] = [
            ("الله", "allah", "Allah"),
            ("الرحمن", "rahman", "The Merciful"),
            ("الصلاة", "salah", "Prayer"),
            ("القرآن", "quran", "Quran"),
            ("الصوم", "sawm", "Fasting")
        ]
        
        for test in bilingualTests {
            Task {
                // Test Arabic search
                await searchService.searchVerses(query: test.arabic, searchOptions: QuranSearchOptions())
                let arabicResults = searchService.enhancedSearchResults.count
                
                // Test English search
                await searchService.searchVerses(query: test.english, searchOptions: QuranSearchOptions())
                let englishResults = searchService.enhancedSearchResults.count
                
                let bothFoundResults = arabicResults > 0 && englishResults > 0
                
                let testResult = TestResult(
                    category: "Bilingual Search",
                    query: test.description,
                    passed: bothFoundResults,
                    details: "Arabic: \(arabicResults) results, English: \(englishResults) results",
                    expectedTerms: ["results for both languages"],
                    actualTerms: ["Arabic: \(arabicResults)", "English: \(englishResults)"]
                )
                
                testResults.append(testResult)
                
                if !bothFoundResults {
                    print("❌ Bilingual search issue with \(test.description)")
                } else {
                    print("✅ Bilingual search working for \(test.description)")
                }
            }
        }
    }
    
    /// Test 5: Performance Testing
    func testSearchPerformance() {
        print("\n🧪 Testing Search Performance...")
        
        let performanceQueries = [
            "mercy", "allah", "prayer", "guidance", "patience",
            "ayat al-kursi", "al-fatiha", "light verse",
            "charity and giving", "fasting in ramadan"
        ]
        
        for query in performanceQueries {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            Task {
                await searchService.searchVerses(query: query, searchOptions: QuranSearchOptions())
                
                let endTime = CFAbsoluteTimeGetCurrent()
                let duration = endTime - startTime
                let resultCount = searchService.enhancedSearchResults.count
                
                let performanceGood = duration < 1.0 // Should complete within 1 second
                
                let testResult = TestResult(
                    category: "Performance",
                    query: query,
                    passed: performanceGood,
                    details: "Duration: \(String(format: "%.3f", duration))s, Results: \(resultCount)",
                    expectedTerms: ["< 1.0s"],
                    actualTerms: ["\(String(format: "%.3f", duration))s"]
                )
                
                testResults.append(testResult)
                
                if !performanceGood {
                    print("❌ Performance issue with '\(query)': \(String(format: "%.3f", duration))s")
                } else {
                    print("✅ Good performance for '\(query)': \(String(format: "%.3f", duration))s")
                }
            }
        }
    }
    
    // MARK: - Test Execution
    
    func testComprehensiveSearchFunctionality() {
        testSynonymAndRelatedTermCoverage()
        testFamousVerseRecognition()
        testCaseInsensitiveSearch()
        testArabicAndEnglishSearch()
        testSearchPerformance()
    }
    
    // MARK: - Test Reporting
    
    private func generateTestReport() {
        print("\n📊 COMPREHENSIVE SEARCH TEST REPORT")
        print("=====================================")
        
        let categories = Set(testResults.map { $0.category })
        
        for category in categories.sorted() {
            let categoryResults = testResults.filter { $0.category == category }
            let passedCount = categoryResults.filter { $0.passed }.count
            let totalCount = categoryResults.count
            let passRate = totalCount > 0 ? Double(passedCount) / Double(totalCount) * 100 : 0
            
            print("\n📂 \(category)")
            print("   Pass Rate: \(passedCount)/\(totalCount) (\(String(format: "%.1f", passRate))%)")
            
            for result in categoryResults {
                let status = result.passed ? "✅" : "❌"
                print("   \(status) \(result.query): \(result.details)")
            }
        }
        
        // Overall summary
        let totalPassed = testResults.filter { $0.passed }.count
        let totalTests = testResults.count
        let overallPassRate = totalTests > 0 ? Double(totalPassed) / Double(totalTests) * 100 : 0
        
        print("\n🎯 OVERALL SUMMARY")
        print("   Total Tests: \(totalTests)")
        print("   Passed: \(totalPassed)")
        print("   Failed: \(totalTests - totalPassed)")
        print("   Pass Rate: \(String(format: "%.1f", overallPassRate))%")
        
        // Recommendations
        generateRecommendations()
    }
    
    private func generateRecommendations() {
        print("\n💡 RECOMMENDATIONS")
        print("==================")
        
        let failedResults = testResults.filter { !$0.passed }
        
        if failedResults.isEmpty {
            print("🎉 All tests passed! Search functionality is comprehensive.")
        } else {
            print("🔧 Areas for improvement:")
            
            let failedByCategory = Dictionary(grouping: failedResults) { $0.category }
            
            for (category, failures) in failedByCategory {
                print("\n📂 \(category):")
                for failure in failures {
                    print("   • Fix '\(failure.query)': \(failure.details)")
                }
            }
        }
    }
}

// MARK: - Test Result Model

struct TestResult {
    let category: String
    let query: String
    let passed: Bool
    let details: String
    let expectedTerms: [String]
    let actualTerms: [String]
}
