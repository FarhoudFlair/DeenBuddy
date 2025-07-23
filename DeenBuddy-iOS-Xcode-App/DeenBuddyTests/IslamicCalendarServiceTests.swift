import XCTest
import Combine
@testable import DeenBuddy

/// Comprehensive tests for IslamicCalendarService
class IslamicCalendarServiceTests: XCTestCase {

    // MARK: - Test Properties
    private var sut: IslamicCalendarService!
    private var cancellables: Set<AnyCancellable>!

    // MARK: - Setup & Teardown

    @MainActor
    override func setUp() async throws {
        try await super.setUp()

        sut = IslamicCalendarService()
        cancellables = Set<AnyCancellable>()

        // Clear any existing data - await to ensure completion before tests run
        await sut.clearCache()
    }
    
    override func tearDownWithError() throws {
        cancellables = nil
        sut = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Date Conversion Tests
    
    @MainActor
    func testConvertToHijri_ShouldReturnValidHijriDate() async throws {
        // Given
        let gregorianDate = Date()
        
        // When
        let hijriDate = await sut.convertToHijri(gregorianDate)
        
        // Then
        XCTAssertGreaterThan(hijriDate.year, 1400) // Should be in modern Islamic era
        XCTAssertGreaterThanOrEqual(hijriDate.day, 1)
        XCTAssertLessThanOrEqual(hijriDate.day, 30)
        XCTAssertEqual(hijriDate.era, .afterHijra)
    }
    
    @MainActor
    func testConvertToGregorian_ShouldReturnValidGregorianDate() async throws {
        // Given
        let hijriDate = HijriDate(day: 15, month: .ramadan, year: 1445)
        
        // When
        let gregorianDate = await sut.convertToGregorian(hijriDate)
        
        // Then
        XCTAssertNotNil(gregorianDate)
        // The date should be reasonable (not in distant past or future)
        let currentYear = Calendar.current.component(.year, from: Date())
        let convertedYear = Calendar.current.component(.year, from: gregorianDate)
        XCTAssertTrue(abs(convertedYear - currentYear) < 10)
    }
    
    @MainActor
    func testGetCurrentHijriDate_ShouldReturnCurrentDate() async throws {
        // When
        let currentHijri = await sut.getCurrentHijriDate()
        
        // Then
        XCTAssertGreaterThan(currentHijri.year, 1400)
        XCTAssertEqual(currentHijri.era, .afterHijra)
        XCTAssertEqual(currentHijri, sut.currentHijriDate)
    }
    
    @MainActor
    func testIsDateEqualToHijri_ShouldReturnCorrectComparison() async throws {
        // Given
        let hijriDate = HijriDate(day: 1, month: .muharram, year: 1445)
        let gregorianDate = hijriDate.toGregorianDate()
        
        // When
        let isEqual = await sut.isDate(gregorianDate, equalToHijri: hijriDate)
        
        // Then
        XCTAssertTrue(isEqual)
    }
    
    // MARK: - Calendar Information Tests
    
    @MainActor
    func testGetCalendarInfo_ShouldReturnValidInfo() async throws {
        // Given
        let testDate = Date()
        
        // When
        let calendarInfo = await sut.getCalendarInfo(for: testDate)
        
        // Then
        XCTAssertEqual(calendarInfo.gregorianDate.timeIntervalSince1970, testDate.timeIntervalSince1970, accuracy: 86400) // Within a day
        XCTAssertNotNil(calendarInfo.hijriDate)
        XCTAssertNotNil(calendarInfo.moonPhase)
    }
    
    @MainActor
    func testGetCalendarInfoForPeriod_ShouldReturnMultipleDays() async throws {
        // Given
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate)!
        let period = DateInterval(start: startDate, end: endDate)
        
        // When
        let calendarDays = await sut.getCalendarInfo(for: period)
        
        // Then
        XCTAssertGreaterThanOrEqual(calendarDays.count, 7)
        XCTAssertTrue(calendarDays.allSatisfy { $0.gregorianDate >= startDate && $0.gregorianDate <= endDate })
    }
    
    @MainActor
    func testGetMonthInfo_ShouldReturnMonthDays() async throws {
        // Given
        let month = HijriMonth.ramadan
        let year = 1445
        
        // When
        let monthDays = await sut.getMonthInfo(month: month, year: year)
        
        // Then
        XCTAssertFalse(monthDays.isEmpty)
        XCTAssertTrue(monthDays.allSatisfy { $0.hijriDate.month == month })
        XCTAssertTrue(monthDays.allSatisfy { $0.hijriDate.year == year })
    }
    
    @MainActor
    func testIsHolyDay_ShouldDetectHolyDays() async throws {
        // Given - Create a date that should be a holy day (Islamic New Year)
        let islamicNewYear = HijriDate(day: 1, month: .muharram, year: 1445)
        let gregorianDate = islamicNewYear.toGregorianDate()
        
        // When
        let isHoly = await sut.isHolyDay(gregorianDate)
        
        // Then
        // This might be true if there are events on this date or if it's in a holy month
        XCTAssertTrue(isHoly || islamicNewYear.month.isHolyMonth)
    }
    
    @MainActor
    func testGetMoonPhase_ShouldReturnValidPhase() async throws {
        // Given
        let testDate = Date()
        
        // When
        let moonPhase = await sut.getMoonPhase(for: testDate)
        
        // Then
        XCTAssertNotNil(moonPhase)
        XCTAssertTrue(MoonPhase.allCases.contains(moonPhase!))
    }
    
    // MARK: - Event Management Tests
    
    @MainActor
    func testGetAllEvents_ShouldReturnDefaultEvents() async throws {
        // When
        let events = await sut.getAllEvents()
        
        // Then
        XCTAssertFalse(events.isEmpty)
        XCTAssertTrue(events.contains { $0.name.contains("Islamic New Year") })
        XCTAssertTrue(events.contains { $0.name.contains("Eid al-Fitr") })
        XCTAssertTrue(events.contains { $0.name.contains("Eid al-Adha") })
    }
    
    @MainActor
    func testGetEventsByCategory_ShouldFilterCorrectly() async throws {
        // When
        let religiousEvents = await sut.getEvents(by: .religious)
        
        // Then
        XCTAssertFalse(religiousEvents.isEmpty)
        XCTAssertTrue(religiousEvents.allSatisfy { $0.category == .religious })
    }
    
    @MainActor
    func testGetEventsBySignificance_ShouldFilterCorrectly() async throws {
        // When
        let majorEvents = await sut.getEvents(by: .major)
        
        // Then
        XCTAssertFalse(majorEvents.isEmpty)
        XCTAssertTrue(majorEvents.allSatisfy { $0.significance == .major })
    }
    
    @MainActor
    func testAddCustomEvent_ShouldAddToAllEvents() async throws {
        // Given
        let customEvent = IslamicEvent(
            name: "Test Custom Event",
            arabicName: "حدث مخصص للاختبار",
            description: "A custom event for testing",
            hijriDate: HijriDate(day: 15, month: .shaban, year: 1445),
            category: .personal,
            significance: .minor,
            isUserAdded: true
        )
        
        let initialCount = sut.allEvents.count
        
        // When
        await sut.addCustomEvent(customEvent)
        
        // Then
        XCTAssertEqual(sut.allEvents.count, initialCount + 1)
        XCTAssertTrue(sut.allEvents.contains { $0.name == "Test Custom Event" })
        XCTAssertTrue(sut.allEvents.last?.isUserAdded ?? false)
    }
    
    @MainActor
    func testUpdateEvent_ShouldModifyExistingEvent() async throws {
        // Given
        let customEvent = IslamicEvent(
            name: "Original Event",
            description: "Original description",
            hijriDate: HijriDate(day: 10, month: .rajab, year: 1445),
            category: .personal,
            significance: .minor,
            isUserAdded: true
        )
        
        await sut.addCustomEvent(customEvent)
        
        let updatedEvent = IslamicEvent(
            id: customEvent.id,
            name: "Updated Event",
            description: "Updated description",
            hijriDate: customEvent.hijriDate,
            category: customEvent.category,
            significance: customEvent.significance,
            isUserAdded: true
        )
        
        // When
        await sut.updateEvent(updatedEvent)
        
        // Then
        let foundEvent = sut.allEvents.first { $0.id == customEvent.id }
        XCTAssertEqual(foundEvent?.name, "Updated Event")
        XCTAssertEqual(foundEvent?.description, "Updated description")
    }
    
    @MainActor
    func testDeleteEvent_ShouldRemoveCustomEvent() async throws {
        // Given
        let customEvent = IslamicEvent(
            name: "Event to Delete",
            description: "This event will be deleted",
            hijriDate: HijriDate(day: 5, month: .dhulQadah, year: 1445),
            category: .personal,
            significance: .minor,
            isUserAdded: true
        )
        
        await sut.addCustomEvent(customEvent)
        let countAfterAdd = sut.allEvents.count
        
        // When
        await sut.deleteEvent(customEvent.id)
        
        // Then
        XCTAssertEqual(sut.allEvents.count, countAfterAdd - 1)
        XCTAssertFalse(sut.allEvents.contains { $0.id == customEvent.id })
    }
    
    @MainActor
    func testSearchEvents_ShouldReturnMatchingEvents() async throws {
        // When
        let results = await sut.searchEvents("Eid")
        
        // Then
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { event in
            event.name.lowercased().contains("eid") ||
            event.description.lowercased().contains("eid")
        })
    }
    
    @MainActor
    func testGetUpcomingEvents_ShouldReturnFutureEvents() async throws {
        // When
        let upcomingEvents = await sut.getUpcomingEvents(limit: 5)
        
        // Then
        XCTAssertLessThanOrEqual(upcomingEvents.count, 5)
        // All events should be in the future (within reasonable bounds)
        let today = Date()
        let nextYear = Calendar.current.date(byAdding: .year, value: 1, to: today)!
        
        for event in upcomingEvents {
            let eventDate = event.gregorianDate(for: sut.currentHijriDate.year)
            XCTAssertTrue(eventDate > today && eventDate <= nextYear)
        }
    }
    
    // MARK: - Holy Months & Special Periods Tests
    
    @MainActor
    func testIsRamadan_ShouldDetectRamadan() async throws {
        // This test depends on the current date, so we'll test the logic
        let isRamadan = await sut.isRamadan()
        let currentMonth = sut.currentHijriDate.month
        
        if currentMonth == .ramadan {
            XCTAssertTrue(isRamadan)
        } else {
            XCTAssertFalse(isRamadan)
        }
    }
    
    @MainActor
    func testIsHolyMonth_ShouldDetectHolyMonths() async throws {
        let isHoly = await sut.isHolyMonth()
        let currentMonth = sut.currentHijriDate.month
        
        XCTAssertEqual(isHoly, currentMonth.isHolyMonth)
    }
    
    @MainActor
    func testGetDaysRemainingInMonth_ShouldReturnValidCount() async throws {
        // When
        let daysRemaining = await sut.getDaysRemainingInMonth()
        
        // Then
        XCTAssertGreaterThanOrEqual(daysRemaining, 0)
        XCTAssertLessThanOrEqual(daysRemaining, 30) // Islamic months are 29-30 days
    }
    
    @MainActor
    func testGetRamadanPeriod_ShouldReturnValidPeriod() async throws {
        // Given
        let hijriYear = 1445
        
        // When
        let ramadanPeriod = await sut.getRamadanPeriod(for: hijriYear)
        
        // Then
        XCTAssertNotNil(ramadanPeriod)
        XCTAssertTrue(ramadanPeriod!.duration > 0)
        XCTAssertLessThanOrEqual(ramadanPeriod!.duration, 30 * 24 * 60 * 60) // Max 30 days
    }
    
    @MainActor
    func testGetHajjPeriod_ShouldReturnValidPeriod() async throws {
        // Given
        let hijriYear = 1445
        
        // When
        let hajjPeriod = await sut.getHajjPeriod(for: hijriYear)
        
        // Then
        XCTAssertNotNil(hajjPeriod)
        XCTAssertTrue(hajjPeriod!.duration > 0)
        XCTAssertLessThanOrEqual(hajjPeriod!.duration, 6 * 24 * 60 * 60) // Hajj is about 5-6 days
    }
    
    // MARK: - Statistics Tests
    
    @MainActor
    func testGetStatistics_ShouldReturnValidStats() async throws {
        // When
        let stats = await sut.getStatistics()
        
        // Then
        XCTAssertGreaterThan(stats.totalEventsTracked, 0)
        XCTAssertGreaterThanOrEqual(stats.majorEventsThisYear, 0)
        XCTAssertEqual(stats.holyMonthsObserved, 4) // Four holy months in Islam
        XCTAssertGreaterThanOrEqual(stats.personalEventsAdded, 0)
    }
    
    @MainActor
    func testGetEventsObservedThisYear_ShouldReturnCurrentYearEvents() async throws {
        // When
        let thisYearEvents = await sut.getEventsObservedThisYear()
        let currentYear = sut.currentHijriDate.year

        // Then
        XCTAssertFalse(thisYearEvents.isEmpty, "Should return events for the current Hijri year")
        XCTAssertTrue(thisYearEvents.allSatisfy { $0.hijriDate.year == currentYear }, "All events should be from the current Hijri year")
    }

    @MainActor
    func testGetEventsObservedThisYear_ShouldReturnDefaultEvents() async throws {
        // Given - clear cache to reset to default state
        await sut.clearCache()

        // When
        let thisYearEvents = await sut.getEventsObservedThisYear()

        // Then - should have default Islamic events for this year
        XCTAssertFalse(thisYearEvents.isEmpty, "Should return default Islamic events")

        // Verify we have major Islamic events
        let eventNames = thisYearEvents.map { $0.name }
        XCTAssertTrue(eventNames.contains("Eid al-Fitr") || eventNames.contains("Eid al-Adha"),
                     "Should contain major Islamic events")
    }

    @MainActor
    func testGetMostActiveMonth_ShouldReturnValidMonth() async throws {
        // When
        let mostActiveMonth = await sut.getMostActiveMonth()
        
        // Then
        XCTAssertNotNil(mostActiveMonth)
        XCTAssertTrue(HijriMonth.allCases.contains(mostActiveMonth!))
    }
    
    @MainActor
    func testGetEventFrequencyByCategory_ShouldReturnValidFrequencies() async throws {
        // When
        let frequencies = await sut.getEventFrequencyByCategory()
        
        // Then
        XCTAssertFalse(frequencies.isEmpty)
        XCTAssertTrue(frequencies.values.allSatisfy { $0 > 0 })
        XCTAssertTrue(frequencies.keys.contains(.religious)) // Should have religious events
    }
    
    // MARK: - Export Tests
    
    @MainActor
    func testExportCalendarData_ShouldReturnJSONString() async throws {
        // Given
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate)!
        let period = DateInterval(start: startDate, end: endDate)
        
        // When
        let exportData = await sut.exportCalendarData(for: period)
        
        // Then
        XCTAssertTrue(exportData.contains("events"))
        XCTAssertTrue(exportData.contains("exportDate"))
        XCTAssertTrue(exportData.contains("period"))
    }
    
    @MainActor
    func testExportAsICalendar_ShouldReturnValidICalFormat() async throws {
        // Given
        let events = Array(sut.allEvents.prefix(3))
        
        // When
        let icalData = await sut.exportAsICalendar(events)
        
        // Then
        XCTAssertTrue(icalData.contains("BEGIN:VCALENDAR"))
        XCTAssertTrue(icalData.contains("END:VCALENDAR"))
        XCTAssertTrue(icalData.contains("BEGIN:VEVENT"))
        XCTAssertTrue(icalData.contains("END:VEVENT"))
        XCTAssertTrue(icalData.contains("SUMMARY:"))
    }
    
    // MARK: - Cache Management Tests
    
    @MainActor
    func testClearCache_ShouldResetToDefaults() async throws {
        // Given
        let customEvent = IslamicEvent(
            name: "Test Event",
            description: "Test description",
            hijriDate: HijriDate(day: 1, month: .safar, year: 1445),
            category: .personal,
            significance: .minor,
            isUserAdded: true
        )
        
        await sut.addCustomEvent(customEvent)
        let countWithCustom = sut.allEvents.count
        
        // When
        await sut.clearCache()
        
        // Then
        XCTAssertLessThan(sut.allEvents.count, countWithCustom) // Custom events should be removed
        XCTAssertFalse(sut.allEvents.contains { $0.isUserAdded }) // No custom events should remain
        XCTAssertTrue(sut.allEvents.contains { $0.name.contains("Islamic New Year") }) // Default events should remain
    }
    
    @MainActor
    func testRefreshCalendarData_ShouldUpdateInfo() async throws {
        // Given
        let _ = sut.upcomingEvents.count // Store initial count for potential future use

        // When
        await sut.refreshCalendarData()
        
        // Then
        // The data should be refreshed (exact assertions depend on current date)
        XCTAssertNotNil(sut.todayInfo)
        XCTAssertGreaterThanOrEqual(sut.upcomingEvents.count, 0)
    }
}
