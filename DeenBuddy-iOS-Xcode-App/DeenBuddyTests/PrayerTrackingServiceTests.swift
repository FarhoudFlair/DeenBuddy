import XCTest
import Combine
import CoreLocation
@testable import DeenBuddy

/// Comprehensive tests for PrayerTrackingService
class PrayerTrackingServiceTests: XCTestCase {
    
    // MARK: - Test Properties
    private var sut: PrayerTrackingService!
    private var mockPrayerTimeService: MockPrayerTimeService!
    private var mockSettingsService: MockSettingsService!
    private var mockLocationService: MockLocationService!
    private var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        mockPrayerTimeService = MockPrayerTimeService()
        mockSettingsService = MockSettingsService()
        mockLocationService = MockLocationService()
        cancellables = Set<AnyCancellable>()
        
        sut = PrayerTrackingService(
            prayerTimeService: mockPrayerTimeService,
            settingsService: mockSettingsService,
            locationService: mockLocationService
        )
        
        // Clear any existing data
        Task { @MainActor in
            await sut.clearTrackingCache()
        }
    }
    
    override func tearDownWithError() throws {
        cancellables = nil
        sut = nil
        mockPrayerTimeService = nil
        mockSettingsService = nil
        mockLocationService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Prayer Completion Tests
    
    @MainActor
    func testMarkPrayerCompleted_ShouldAddEntryAndUpdateStats() async throws {
        // Given
        let prayer = Prayer.fajr
        let initialCount = sut.todaysCompletedPrayers
        
        // When
        await sut.markPrayerCompleted(
            prayer,
            notes: "Test prayer",
            mood: .grateful
        )
        
        // Then
        XCTAssertEqual(sut.todaysCompletedPrayers, initialCount + 1)
        XCTAssertFalse(sut.recentEntries.isEmpty)
        XCTAssertEqual(sut.recentEntries.last?.prayer, prayer)
        XCTAssertEqual(sut.recentEntries.last?.notes, "Test prayer")
        XCTAssertEqual(sut.recentEntries.last?.mood, .grateful)
    }
    
    @MainActor
    func testMarkPrayerCompleted_WithLocation_ShouldStoreLocation() async throws {
        // Given
        let prayer = Prayer.dhuhr
        let location = "Test Mosque"
        mockLocationService.currentLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        
        // When
        await sut.markPrayerCompleted(prayer, location: location)
        
        // Then
        XCTAssertEqual(sut.recentEntries.last?.location, location)
    }
    
    @MainActor
    func testMarkPrayerCompleted_ShouldUpdateCompletionRate() async throws {
        // Given
        let initialRate = sut.todayCompletionRate
        
        // When
        await sut.markPrayerCompleted(.fajr)
        
        // Then
        XCTAssertGreaterThan(sut.todayCompletionRate, initialRate)
    }
    
    @MainActor
    func testUndoLastPrayerEntry_ShouldRemoveLastEntry() async throws {
        // Given
        await sut.markPrayerCompleted(.fajr)
        let countAfterAdd = sut.recentEntries.count
        
        // When
        let success = await sut.undoLastPrayerEntry()
        
        // Then
        XCTAssertTrue(success)
        XCTAssertEqual(sut.recentEntries.count, countAfterAdd - 1)
    }
    
    @MainActor
    func testUndoLastPrayerEntry_WhenEmpty_ShouldReturnFalse() async throws {
        // Given - empty entries
        
        // When
        let success = await sut.undoLastPrayerEntry()
        
        // Then
        XCTAssertFalse(success)
    }
    
    // MARK: - Statistics Tests
    
    @MainActor
    func testGetPrayerStatistics_ShouldReturnCorrectStats() async throws {
        // Given
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!
        let period = DateInterval(start: startDate, end: endDate)
        
        await sut.markPrayerCompleted(.fajr)
        await sut.markPrayerCompleted(.dhuhr)
        
        // When
        let stats = await sut.getPrayerStatistics(for: period)
        
        // Then
        XCTAssertEqual(stats.totalPrayers, 2)
        XCTAssertEqual(stats.completedPrayers, 2)
        XCTAssertGreaterThan(stats.averagePerDay, 0)
    }
    
    @MainActor
    func testGetPrayerStreak_ShouldReturnCorrectStreak() async throws {
        // Given
        await sut.markPrayerCompleted(.fajr)
        await sut.markPrayerCompleted(.fajr)
        
        // When
        let streak = await sut.getPrayerStreak(for: .fajr)
        
        // Then
        XCTAssertNotNil(streak)
        XCTAssertEqual(streak?.prayer, .fajr)
        XCTAssertGreaterThan(streak?.currentStreak ?? 0, 0)
    }
    
    // MARK: - Journal Tests
    
    @MainActor
    func testAddPrayerJournalEntry_ShouldStoreEntry() async throws {
        // Given
        let journal = PrayerJournal(
            id: UUID(),
            date: Date(),
            prayer: .maghrib,
            reflection: "Test reflection",
            gratitude: ["Test gratitude"],
            dua: "Test dua",
            mood: .peaceful,
            lessons: ["Test lesson"],
            challenges: ["Test challenge"],
            improvements: ["Test improvement"]
        )
        
        // When
        await sut.addPrayerJournalEntry(journal)
        
        // Then
        let period = DateInterval(start: Date().addingTimeInterval(-3600), end: Date().addingTimeInterval(3600))
        let entries = await sut.getPrayerJournalEntries(for: period)
        
        XCTAssertFalse(entries.isEmpty)
        XCTAssertEqual(entries.first?.reflection, "Test reflection")
    }
    
    @MainActor
    func testUpdatePrayerJournalEntry_ShouldModifyExistingEntry() async throws {
        // Given
        let originalJournal = PrayerJournal(
            id: UUID(),
            date: Date(),
            prayer: .isha,
            reflection: "Original reflection",
            gratitude: [],
            dua: "",
            mood: .neutral,
            lessons: [],
            challenges: [],
            improvements: []
        )
        
        await sut.addPrayerJournalEntry(originalJournal)
        
        let updatedJournal = PrayerJournal(
            id: originalJournal.id,
            date: originalJournal.date,
            prayer: originalJournal.prayer,
            reflection: "Updated reflection",
            gratitude: originalJournal.gratitude,
            dua: originalJournal.dua,
            mood: originalJournal.mood,
            lessons: originalJournal.lessons,
            challenges: originalJournal.challenges,
            improvements: originalJournal.improvements
        )
        
        // When
        await sut.updatePrayerJournalEntry(updatedJournal)
        
        // Then
        let period = DateInterval(start: Date().addingTimeInterval(-3600), end: Date().addingTimeInterval(3600))
        let entries = await sut.getPrayerJournalEntries(for: period)
        
        XCTAssertEqual(entries.first?.reflection, "Updated reflection")
    }
    
    // MARK: - Reminder Tests
    
    @MainActor
    func testSetPrayerReminder_ShouldStoreReminder() async throws {
        // Given
        let reminder = PrayerReminder(
            id: UUID(),
            prayer: .asr,
            offsetMinutes: -15,
            isEnabled: true,
            message: "Time for Asr prayer",
            soundName: "default",
            repeatDaily: true
        )
        
        // When
        await sut.setPrayerReminder(reminder)
        
        // Then
        let reminders = await sut.getPrayerReminders()
        XCTAssertFalse(reminders.isEmpty)
        XCTAssertEqual(reminders.first?.prayer, .asr)
        XCTAssertEqual(reminders.first?.message, "Time for Asr prayer")
    }
    
    @MainActor
    func testDeletePrayerReminder_ShouldRemoveReminder() async throws {
        // Given
        let reminder = PrayerReminder(
            id: UUID(),
            prayer: .maghrib,
            offsetMinutes: 0,
            isEnabled: true,
            message: "Maghrib time",
            soundName: "default",
            repeatDaily: true
        )
        
        await sut.setPrayerReminder(reminder)
        
        // When
        await sut.deletePrayerReminder(for: .maghrib)
        
        // Then
        let reminders = await sut.getPrayerReminders()
        XCTAssertTrue(reminders.filter { $0.prayer == .maghrib }.isEmpty)
    }
    
    // MARK: - Goal Tests
    
    @MainActor
    func testSetPrayerGoal_ShouldStoreGoal() async throws {
        // Given
        let goal = PrayerGoal(
            id: UUID(),
            prayer: .fajr,
            targetCount: 30,
            currentCount: 0,
            targetDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!,
            createdAt: Date(),
            description: "Pray Fajr for 30 days",
            isCompleted: false
        )
        
        let period = DateInterval(start: Date(), end: goal.targetDate)
        
        // When
        await sut.setPrayerGoal(goal, for: period)
        
        // Then
        let goals = await sut.getCurrentGoals()
        XCTAssertFalse(goals.isEmpty)
        XCTAssertEqual(goals.first?.prayer, .fajr)
        XCTAssertEqual(goals.first?.targetCount, 30)
    }
    
    @MainActor
    func testGetGoalProgress_ShouldReturnProgress() async throws {
        // Given
        let goal = PrayerGoal(
            id: UUID(),
            prayer: .dhuhr,
            targetCount: 10,
            currentCount: 0,
            targetDate: Calendar.current.date(byAdding: .week, value: 2, to: Date())!,
            createdAt: Date(),
            description: "Test goal",
            isCompleted: false
        )
        
        let period = DateInterval(start: Date(), end: goal.targetDate)
        await sut.setPrayerGoal(goal, for: period)
        
        // Complete some prayers
        await sut.markPrayerCompleted(.dhuhr)
        await sut.markPrayerCompleted(.dhuhr)
        
        // When
        let progress = await sut.getGoalProgress()
        
        // Then
        XCTAssertFalse(progress.isEmpty)
        XCTAssertGreaterThan(progress.first?.progress ?? 0, 0)
    }
    
    // MARK: - Export Tests
    
    @MainActor
    func testExportPrayerData_ShouldReturnCSV() async throws {
        // Given
        await sut.markPrayerCompleted(.fajr, notes: "Test export")
        
        let period = DateInterval(start: Date().addingTimeInterval(-3600), end: Date().addingTimeInterval(3600))
        
        // When
        let csvData = await sut.exportPrayerData(for: period)
        
        // Then
        XCTAssertTrue(csvData.contains("Date,Prayer,Location"))
        XCTAssertTrue(csvData.contains("fajr"))
        XCTAssertTrue(csvData.contains("Test export"))
    }
    
    @MainActor
    func testExportPrayerStatistics_ShouldReturnJSON() async throws {
        // Given
        await sut.markPrayerCompleted(.maghrib)
        
        let period = DateInterval(start: Date().addingTimeInterval(-3600), end: Date().addingTimeInterval(3600))
        
        // When
        let jsonData = await sut.exportPrayerStatistics(for: period)
        
        // Then
        XCTAssertTrue(jsonData.contains("totalPrayers"))
        XCTAssertTrue(jsonData.contains("completedPrayers"))
        XCTAssertTrue(jsonData.contains("currentStreak"))
    }
    
    // MARK: - Insights Tests
    
    @MainActor
    func testGetPrayerInsights_ShouldReturnInsights() async throws {
        // Given
        await sut.markPrayerCompleted(.fajr)
        
        // When
        let insights = await sut.getPrayerInsights()
        
        // Then
        XCTAssertFalse(insights.isEmpty)
    }
    
    @MainActor
    func testGetPersonalizedTips_ShouldReturnTips() async throws {
        // When
        let tips = await sut.getPersonalizedTips()
        
        // Then
        XCTAssertFalse(tips.isEmpty)
        XCTAssertNotNil(tips.first?.title)
        XCTAssertNotNil(tips.first?.content)
    }
    
    // MARK: - Cache Tests
    
    @MainActor
    func testClearTrackingCache_ShouldResetAllData() async throws {
        // Given
        await sut.markPrayerCompleted(.fajr)
        XCTAssertFalse(sut.recentEntries.isEmpty)
        
        // When
        await sut.clearTrackingCache()
        
        // Then
        XCTAssertTrue(sut.recentEntries.isEmpty)
        XCTAssertEqual(sut.todaysCompletedPrayers, 0)
        XCTAssertEqual(sut.todayCompletionRate, 0.0)
        XCTAssertEqual(sut.currentStreak, 0)
    }
}
