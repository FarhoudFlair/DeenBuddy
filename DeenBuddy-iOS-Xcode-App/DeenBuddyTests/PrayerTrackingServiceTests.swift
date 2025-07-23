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
    
    @MainActor
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
            mood: .excellent
        )
        
        // Then
        XCTAssertEqual(sut.todaysCompletedPrayers, initialCount + 1)
        XCTAssertFalse(sut.recentEntries.isEmpty)
        XCTAssertEqual(sut.recentEntries.last?.prayer, prayer)
        XCTAssertEqual(sut.recentEntries.last?.notes, "Test prayer")
        XCTAssertEqual(sut.recentEntries.last?.mood, .excellent)
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
        XCTAssertGreaterThan(streak?.current ?? 0, 0)
        XCTAssertGreaterThanOrEqual(streak?.longest ?? 0, streak?.current ?? 0)
        XCTAssertNotNil(streak?.startDate)
        XCTAssertTrue(streak?.isActive ?? false)
        XCTAssertNil(streak?.endDate) // Should be nil for active streaks
        XCTAssertNotNil(streak?.currentStreakDuration)
        XCTAssertGreaterThanOrEqual(streak?.currentStreakDays ?? 0, 0)
    }
    
    // MARK: - Journal Tests
    
    @MainActor
    func testAddPrayerJournalEntry_ShouldStoreEntry() async throws {
        // Given
        let journal = PrayerJournalEntry(
            id: UUID().uuidString,
            prayer: Prayer.maghrib,
            date: Date(),
            notes: "Test reflection",
            mood: PrayerMood.good,
            hadithRemembered: "Test dua",
            gratitudeNote: "Test gratitude"
        )
        
        // When
        await sut.addPrayerJournalEntry(journal)
        
        // Then
        let period = DateInterval(start: Date().addingTimeInterval(-3600), end: Date().addingTimeInterval(3600))
        let entries = await sut.getPrayerJournalEntries(for: period)
        
        XCTAssertFalse(entries.isEmpty)
        XCTAssertEqual(entries.first?.notes, "Test reflection")
        XCTAssertEqual(entries.first?.prayer, .maghrib)
        XCTAssertEqual(entries.first?.mood, .good)
        XCTAssertEqual(entries.first?.hadithRemembered, "Test dua")
        XCTAssertEqual(entries.first?.gratitudeNote, "Test gratitude")
    }
    
    @MainActor
    func testUpdatePrayerJournalEntry_ShouldModifyExistingEntry() async throws {
        // Given
        let originalJournal = PrayerJournalEntry(
            id: UUID().uuidString,
            prayer: Prayer.isha,
            date: Date(),
            notes: "Original reflection",
            mood: PrayerMood.neutral,
            hadithRemembered: "",
            gratitudeNote: ""
        )
        
        await sut.addPrayerJournalEntry(originalJournal)
        
        let updatedJournal = PrayerJournalEntry(
            id: originalJournal.id,
            prayer: originalJournal.prayer,
            date: originalJournal.date,
            notes: "Updated reflection",
            mood: originalJournal.mood,
            hadithRemembered: originalJournal.hadithRemembered,
            gratitudeNote: originalJournal.gratitudeNote
        )
        
        // When
        await sut.updatePrayerJournalEntry(updatedJournal)
        
        // Then
        let period = DateInterval(start: Date().addingTimeInterval(-3600), end: Date().addingTimeInterval(3600))
        let entries = await sut.getPrayerJournalEntries(for: period)
        
        XCTAssertEqual(entries.first?.notes, "Updated reflection")
        XCTAssertEqual(entries.first?.prayer, .isha)
        XCTAssertEqual(entries.first?.id, originalJournal.id)
    }
    
    // MARK: - Reminder Tests
    
    @MainActor
    func testSetPrayerReminder_ShouldStoreReminder() async throws {
        // Given
        let reminder = PrayerReminderEntry(
            id: UUID(),
            prayer: Prayer.asr,
            offsetMinutes: -15,
            isEnabled: true,
            createdAt: Date()
        )
        
        // When
        await sut.setPrayerReminder(reminder)
        
        // Then
        let reminders = await sut.getPrayerReminders()
        XCTAssertFalse(reminders.isEmpty)
        XCTAssertEqual(reminders.first?.prayer, .asr)
        XCTAssertEqual(reminders.first?.offsetMinutes, -15)
        XCTAssertEqual(reminders.first?.isEnabled, true)
        XCTAssertNotNil(reminders.first?.id)
        XCTAssertNotNil(reminders.first?.createdAt)
    }
    
    @MainActor
    func testDeletePrayerReminder_ShouldRemoveReminder() async throws {
        // Given
        let reminder = PrayerReminderEntry(
            id: UUID(),
            prayer: Prayer.maghrib,
            offsetMinutes: 0,
            isEnabled: true,
            createdAt: Date()
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
            id: UUID().uuidString,
            title: "Fajr Goal",
            description: "Pray Fajr for 30 days",
            type: .streak,
            targetValue: 30.0,
            currentValue: 0.0,
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        )
        
        let period = DateInterval(start: Date(), end: goal.endDate)
        
        // When
        await sut.setPrayerGoal(goal, for: period)
        
        // Then
        let goals = await sut.getCurrentGoals()
        XCTAssertFalse(goals.isEmpty)
        XCTAssertEqual(goals.first?.targetValue, 30.0)
        XCTAssertEqual(goals.first?.title, "Fajr Goal")
        XCTAssertEqual(goals.first?.description, "Pray Fajr for 30 days")
        XCTAssertEqual(goals.first?.type, .streak)
        XCTAssertNotNil(goals.first?.id)
        XCTAssertNotNil(goals.first?.prayers)
        XCTAssertEqual(goals.first?.prayers, Set(Prayer.allCases))
        XCTAssertEqual(goals.first?.currentValue, 0.0)
        XCTAssertEqual(goals.first?.isActive, true)
    }
    
    @MainActor
    func testGetGoalProgress_ShouldReturnProgress() async throws {
        // Given
        let goal = PrayerGoal(
            id: UUID().uuidString,
            title: "Dhuhr Goal",
            description: "Test goal",
            type: .consistency,
            targetValue: 10.0,
            currentValue: 0.0,
            endDate: Calendar.current.date(byAdding: .weekOfYear, value: 2, to: Date())!
        )
        
        let period = DateInterval(start: Date(), end: goal.endDate)
        await sut.setPrayerGoal(goal, for: period)
        
        // Complete some prayers
        await sut.markPrayerCompleted(.dhuhr)
        await sut.markPrayerCompleted(.dhuhr)
        
        // When
        let progress = await sut.getGoalProgress()
        
        // Then
        XCTAssertFalse(progress.isEmpty)
        XCTAssertGreaterThan(progress.first?.completionRate ?? 0, 0)
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
        XCTAssertNotNil(tips.first?.description)
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
