import XCTest
import Combine
@testable import DeenBuddy

/// Comprehensive tests for TasbihService
class TasbihServiceTests: XCTestCase {
    
    // MARK: - Test Properties
    private var sut: TasbihService!
    private var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        sut = TasbihService()
        cancellables = Set<AnyCancellable>()
        
        // Clear any existing data
        Task { @MainActor in
            await sut.clearCache()
        }
    }
    
    override func tearDownWithError() throws {
        cancellables = nil
        sut = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Session Management Tests
    
    @MainActor
    func testStartSession_ShouldCreateNewSession() async throws {
        // Given
        let dhikr = Dhikr(
            arabicText: "سُبْحَانَ اللَّهِ",
            transliteration: "SubhanAllah",
            translation: "Glory be to Allah",
            category: .tasbih
        )
        
        // When
        await sut.startSession(with: dhikr, targetCount: 33, counter: nil)
        
        // Then
        XCTAssertNotNil(sut.currentSession)
        XCTAssertEqual(sut.currentSession?.dhikr.arabicText, dhikr.arabicText)
        XCTAssertEqual(sut.currentSession?.targetCount, 33)
        XCTAssertEqual(sut.currentCount, 0)
        XCTAssertFalse(sut.currentSession?.isPaused ?? true)
    }
    
    @MainActor
    func testPauseSession_ShouldPauseCurrentSession() async throws {
        // Given
        let dhikr = Dhikr(
            arabicText: "الْحَمْدُ لِلَّهِ",
            transliteration: "Alhamdulillah",
            translation: "All praise is due to Allah",
            category: .tahmid
        )
        
        await sut.startSession(with: dhikr, targetCount: nil, counter: nil)
        
        // When
        await sut.pauseSession()
        
        // Then
        XCTAssertTrue(sut.currentSession?.isPaused ?? false)
    }
    
    @MainActor
    func testResumeSession_ShouldResumeCurrentSession() async throws {
        // Given
        let dhikr = Dhikr(
            arabicText: "اللَّهُ أَكْبَرُ",
            transliteration: "Allahu Akbar",
            translation: "Allah is the Greatest",
            category: .takbir
        )
        
        await sut.startSession(with: dhikr, targetCount: nil, counter: nil)
        await sut.pauseSession()
        
        // When
        await sut.resumeSession()
        
        // Then
        XCTAssertFalse(sut.currentSession?.isPaused ?? true)
    }
    
    @MainActor
    func testCompleteSession_ShouldAddToRecentSessions() async throws {
        // Given
        let dhikr = Dhikr(
            arabicText: "لَا إِلَهَ إِلَّا اللَّهُ",
            transliteration: "La ilaha illa Allah",
            translation: "There is no god but Allah",
            category: .tahlil
        )
        
        await sut.startSession(with: dhikr, targetCount: 10, counter: nil)
        await sut.incrementCount(by: 5)
        
        let initialSessionCount = sut.recentSessions.count
        
        // When
        await sut.completeSession(notes: "Test session", mood: .peaceful)
        
        // Then
        XCTAssertNil(sut.currentSession)
        XCTAssertEqual(sut.currentCount, 0)
        XCTAssertEqual(sut.recentSessions.count, initialSessionCount + 1)
        XCTAssertEqual(sut.recentSessions.last?.notes, "Test session")
        XCTAssertEqual(sut.recentSessions.last?.mood, .peaceful)
        XCTAssertTrue(sut.recentSessions.last?.isCompleted ?? false)
    }
    
    @MainActor
    func testCancelSession_ShouldClearCurrentSession() async throws {
        // Given
        let dhikr = Dhikr(
            arabicText: "أَسْتَغْفِرُ اللَّهَ",
            transliteration: "Astaghfirullah",
            translation: "I seek forgiveness from Allah",
            category: .istighfar
        )
        
        await sut.startSession(with: dhikr, targetCount: nil, counter: nil)
        
        // When
        await sut.cancelSession()
        
        // Then
        XCTAssertNil(sut.currentSession)
        XCTAssertEqual(sut.currentCount, 0)
    }
    
    @MainActor
    func testResetSession_ShouldResetCountToZero() async throws {
        // Given
        let dhikr = Dhikr(
            arabicText: "سُبْحَانَ اللَّهِ",
            transliteration: "SubhanAllah",
            translation: "Glory be to Allah",
            category: .tasbih
        )
        
        await sut.startSession(with: dhikr, targetCount: 33, counter: nil)
        await sut.incrementCount(by: 10)
        
        // When
        await sut.resetSession()
        
        // Then
        XCTAssertEqual(sut.currentCount, 0)
        XCTAssertEqual(sut.currentSession?.currentCount, 0)
    }
    
    // MARK: - Counting Operations Tests
    
    @MainActor
    func testIncrementCount_ShouldIncreaseCount() async throws {
        // Given
        let dhikr = Dhikr(
            arabicText: "الْحَمْدُ لِلَّهِ",
            transliteration: "Alhamdulillah",
            translation: "All praise is due to Allah",
            category: .tahmid
        )
        
        await sut.startSession(with: dhikr, targetCount: 50, counter: nil)
        
        // When
        await sut.incrementCount(by: 5)
        
        // Then
        XCTAssertEqual(sut.currentCount, 5)
        XCTAssertEqual(sut.currentSession?.currentCount, 5)
    }
    
    @MainActor
    func testIncrementCount_ShouldNotExceedMaxCount() async throws {
        // Given
        let counter = TasbihCounter(name: "Test", maxCount: 10)
        let dhikr = Dhikr(
            arabicText: "اللَّهُ أَكْبَرُ",
            transliteration: "Allahu Akbar",
            translation: "Allah is the Greatest",
            category: .takbir
        )
        
        await sut.startSession(with: dhikr, targetCount: 20, counter: counter)
        
        // When
        await sut.incrementCount(by: 15)
        
        // Then
        XCTAssertEqual(sut.currentCount, 10) // Should not exceed maxCount
    }
    
    @MainActor
    func testDecrementCount_ShouldDecreaseCount() async throws {
        // Given
        let dhikr = Dhikr(
            arabicText: "لَا إِلَهَ إِلَّا اللَّهُ",
            transliteration: "La ilaha illa Allah",
            translation: "There is no god but Allah",
            category: .tahlil
        )
        
        await sut.startSession(with: dhikr, targetCount: 50, counter: nil)
        await sut.incrementCount(by: 10)
        
        // When
        await sut.decrementCount(by: 3)
        
        // Then
        XCTAssertEqual(sut.currentCount, 7)
        XCTAssertEqual(sut.currentSession?.currentCount, 7)
    }
    
    @MainActor
    func testDecrementCount_ShouldNotGoBelowZero() async throws {
        // Given
        let dhikr = Dhikr(
            arabicText: "أَسْتَغْفِرُ اللَّهَ",
            transliteration: "Astaghfirullah",
            translation: "I seek forgiveness from Allah",
            category: .istighfar
        )
        
        await sut.startSession(with: dhikr, targetCount: 50, counter: nil)
        await sut.incrementCount(by: 5)
        
        // When
        await sut.decrementCount(by: 10)
        
        // Then
        XCTAssertEqual(sut.currentCount, 0) // Should not go below zero
    }
    
    @MainActor
    func testSetCount_ShouldSetSpecificCount() async throws {
        // Given
        let dhikr = Dhikr(
            arabicText: "سُبْحَانَ اللَّهِ",
            transliteration: "SubhanAllah",
            translation: "Glory be to Allah",
            category: .tasbih
        )
        
        await sut.startSession(with: dhikr, targetCount: 100, counter: nil)
        
        // When
        await sut.setCount(25)
        
        // Then
        XCTAssertEqual(sut.currentCount, 25)
        XCTAssertEqual(sut.currentSession?.currentCount, 25)
    }
    
    // MARK: - Dhikr Management Tests
    
    @MainActor
    func testGetAllDhikr_ShouldReturnAvailableDhikr() async throws {
        // When
        let dhikr = await sut.getAllDhikr()
        
        // Then
        XCTAssertFalse(dhikr.isEmpty)
        XCTAssertTrue(dhikr.contains { $0.category == .tasbih })
        XCTAssertTrue(dhikr.contains { $0.category == .tahmid })
        XCTAssertTrue(dhikr.contains { $0.category == .takbir })
    }
    
    @MainActor
    func testGetDhikrByCategory_ShouldReturnFilteredDhikr() async throws {
        // When
        let tasbihDhikr = await sut.getDhikr(by: .tasbih)
        
        // Then
        XCTAssertFalse(tasbihDhikr.isEmpty)
        XCTAssertTrue(tasbihDhikr.allSatisfy { $0.category == .tasbih })
    }
    
    @MainActor
    func testAddCustomDhikr_ShouldAddToAvailableDhikr() async throws {
        // Given
        let customDhikr = Dhikr(
            arabicText: "رَبِّ اغْفِرْ لِي",
            transliteration: "Rabbi ghfir li",
            translation: "My Lord, forgive me",
            category: .dua,
            isCustom: true
        )
        
        let initialCount = sut.availableDhikr.count
        
        // When
        await sut.addCustomDhikr(customDhikr)
        
        // Then
        XCTAssertEqual(sut.availableDhikr.count, initialCount + 1)
        XCTAssertTrue(sut.availableDhikr.contains { $0.arabicText == customDhikr.arabicText })
        XCTAssertTrue(sut.availableDhikr.last?.isCustom ?? false)
    }
    
    @MainActor
    func testSearchDhikr_ShouldReturnMatchingDhikr() async throws {
        // When
        let results = await sut.searchDhikr("SubhanAllah")
        
        // Then
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { dhikr in
            dhikr.arabicText.lowercased().contains("subhanallah".lowercased()) ||
            dhikr.transliteration.lowercased().contains("subhanallah".lowercased()) ||
            dhikr.translation.lowercased().contains("subhanallah".lowercased())
        })
    }
    
    // MARK: - Statistics Tests
    
    @MainActor
    func testGetDailyCount_ShouldReturnCorrectCount() async throws {
        // Given
        let dhikr = Dhikr(
            arabicText: "الْحَمْدُ لِلَّهِ",
            transliteration: "Alhamdulillah",
            translation: "All praise is due to Allah",
            category: .tahmid
        )
        
        await sut.startSession(with: dhikr, targetCount: 20, counter: nil)
        await sut.incrementCount(by: 15)
        await sut.completeSession(notes: nil, mood: nil)
        
        // When
        let dailyCount = await sut.getDailyCount(for: Date())
        
        // Then
        XCTAssertEqual(dailyCount, 15)
    }
    
    @MainActor
    func testGetStreakInfo_ShouldReturnStreakData() async throws {
        // When
        let streakInfo = await sut.getStreakInfo()
        
        // Then
        XCTAssertGreaterThanOrEqual(streakInfo.current, 0)
        XCTAssertGreaterThanOrEqual(streakInfo.longest, 0)
        XCTAssertGreaterThanOrEqual(streakInfo.longest, streakInfo.current)
    }
    
    // MARK: - Counter Management Tests
    
    @MainActor
    func testGetAllCounters_ShouldReturnAvailableCounters() async throws {
        // When
        let counters = await sut.getAllCounters()
        
        // Then
        XCTAssertFalse(counters.isEmpty)
        XCTAssertTrue(counters.contains { $0.isDefault })
    }
    
    @MainActor
    func testAddCounter_ShouldAddToAvailableCounters() async throws {
        // Given
        let customCounter = TasbihCounter(
            name: "Custom Counter",
            maxCount: 500,
            hapticFeedback: false
        )
        
        let initialCount = sut.availableCounters.count
        
        // When
        await sut.addCounter(customCounter)
        
        // Then
        XCTAssertEqual(sut.availableCounters.count, initialCount + 1)
        XCTAssertTrue(sut.availableCounters.contains { $0.name == "Custom Counter" })
    }
    
    @MainActor
    func testSetActiveCounter_ShouldUpdateCurrentCounter() async throws {
        // Given
        let newCounter = TasbihCounter(
            name: "Test Counter",
            maxCount: 200,
            hapticFeedback: false
        )
        
        await sut.addCounter(newCounter)
        
        // When
        await sut.setActiveCounter(newCounter)
        
        // Then
        XCTAssertEqual(sut.currentCounter.name, "Test Counter")
        XCTAssertEqual(sut.currentCounter.maxCount, 200)
        XCTAssertFalse(sut.currentCounter.hapticFeedback)
    }
    
    // MARK: - Export Tests
    
    @MainActor
    func testExportData_ShouldReturnJSONString() async throws {
        // Given
        let dhikr = Dhikr(
            arabicText: "سُبْحَانَ اللَّهِ",
            transliteration: "SubhanAllah",
            translation: "Glory be to Allah",
            category: .tasbih
        )
        
        await sut.startSession(with: dhikr, targetCount: 10, counter: nil)
        await sut.incrementCount(by: 5)
        await sut.completeSession(notes: "Test export", mood: .peaceful)
        
        let period = DateInterval(start: Date().addingTimeInterval(-3600), end: Date().addingTimeInterval(3600))
        
        // When
        let exportData = await sut.exportData(for: period)
        
        // Then
        XCTAssertTrue(exportData.contains("sessions"))
        XCTAssertTrue(exportData.contains("SubhanAllah"))
        XCTAssertTrue(exportData.contains("Test export"))
        XCTAssertTrue(exportData.contains("peaceful"))
    }
    
    @MainActor
    func testExportStatistics_ShouldReturnCSVString() async throws {
        // Given
        let period = DateInterval(start: Date().addingTimeInterval(-86400), end: Date())
        
        // When
        let csvData = await sut.exportStatistics(for: period)
        
        // Then
        XCTAssertTrue(csvData.contains("Metric,Value"))
        XCTAssertTrue(csvData.contains("Total Sessions"))
        XCTAssertTrue(csvData.contains("Completed Sessions"))
        XCTAssertTrue(csvData.contains("Total Dhikr Count"))
    }
    
    // MARK: - Cache Management Tests
    
    @MainActor
    func testClearCache_ShouldResetAllData() async throws {
        // Given
        let dhikr = Dhikr(
            arabicText: "الْحَمْدُ لِلَّهِ",
            transliteration: "Alhamdulillah",
            translation: "All praise is due to Allah",
            category: .tahmid
        )
        
        await sut.startSession(with: dhikr, targetCount: 10, counter: nil)
        await sut.incrementCount(by: 5)
        await sut.completeSession(notes: nil, mood: nil)
        
        XCTAssertFalse(sut.recentSessions.isEmpty)
        
        // When
        await sut.clearCache()
        
        // Then
        XCTAssertTrue(sut.recentSessions.isEmpty)
        XCTAssertNil(sut.currentSession)
        XCTAssertEqual(sut.currentCount, 0)
        XCTAssertFalse(sut.availableDhikr.isEmpty) // Should have default dhikr
        XCTAssertFalse(sut.availableCounters.isEmpty) // Should have default counters
    }
}
