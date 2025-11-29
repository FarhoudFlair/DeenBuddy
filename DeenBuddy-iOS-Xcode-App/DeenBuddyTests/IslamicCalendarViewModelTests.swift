import XCTest
import Combine
import CoreLocation
@testable import DeenBuddy

/// Comprehensive tests for IslamicCalendarViewModel
/// Validates prayer time calculations, Islamic events, and state management
@MainActor
class IslamicCalendarViewModelTests: XCTestCase {

    // MARK: - Test Properties

    private var sut: IslamicCalendarViewModel!
    private var mockPrayerTimeService: MockPrayerTimeService!
    private var mockIslamicCalendarService: MockIslamicCalendarService!
    private var mockLocationService: MockLocationService!
    private var mockSettingsService: MockSettingsService!
    private var cancellables: Set<AnyCancellable>!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        mockPrayerTimeService = MockPrayerTimeService()
        mockIslamicCalendarService = MockIslamicCalendarService()
        mockLocationService = MockLocationService()
        mockSettingsService = MockSettingsService()
        cancellables = Set<AnyCancellable>()

        sut = IslamicCalendarViewModel(
            prayerTimeService: mockPrayerTimeService,
            islamicCalendarService: mockIslamicCalendarService,
            locationService: mockLocationService,
            settingsService: mockSettingsService
        )
    }

    override func tearDown() {
        cancellables = nil
        sut = nil
        mockSettingsService = nil
        mockLocationService = nil
        mockIslamicCalendarService = nil
        mockPrayerTimeService = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization_ShouldHaveDefaultState() {
        // Then
        XCTAssertEqual(Calendar.current.isDateInToday(sut.selectedDate), true, "Should default to today")
        XCTAssertNil(sut.prayerTimeResult, "Prayer time result should be nil initially")
        XCTAssertEqual(sut.islamicEvents.count, 0, "Islamic events should be empty initially")
        XCTAssertFalse(sut.isLoading, "Should not be loading initially")
        XCTAssertNil(sut.error, "Should have no errors initially")
        XCTAssertTrue(sut.showDisclaimer, "Disclaimer should be shown by default")
        XCTAssertFalse(sut.showHighLatitudeWarning, "High latitude warning should be hidden initially")
    }

    // MARK: - Date Selection Tests

    func testSelectedDate_WhenSetToToday_IsToday ShouldReturnTrue() {
        // Given
        sut.selectedDate = Date()

        // Then
        XCTAssertTrue(sut.isToday, "isToday should return true when date is today")
    }

    func testSelectedDate_WhenSetToFutureDate_IsToday ShouldReturnFalse() {
        // Given
        let futureDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        sut.selectedDate = futureDate

        // Then
        XCTAssertFalse(sut.isToday, "isToday should return false for future date")
    }

    func testSelectToday_ShouldResetDateToToday() {
        // Given
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        sut.selectedDate = futureDate

        // When
        sut.selectToday()

        // Then
        XCTAssertTrue(Calendar.current.isDateInToday(sut.selectedDate), "selectToday should reset to today")
    }

    // MARK: - Prayer Times Loading Tests

    func testOnAppear_ShouldLoadPrayerTimesAndEvents() async {
        // Given
        let expectation = XCTestExpectation(description: "Prayer times loaded")
        let expectedLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
        mockLocationService.mockLocation = expectedLocation

        sut.$prayerTimeResult
            .dropFirst()
            .sink { result in
                if result != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        sut.onAppear()

        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertNotNil(sut.prayerTimeResult, "Prayer time result should be loaded")
        XCTAssertFalse(sut.isLoading, "Loading should be complete")
        XCTAssertNil(sut.error, "Should have no errors")
    }

    func testLoadPrayerTimes_WithValidLocation_ShouldLoadSuccessfully() async {
        // Given
        let expectedLocation = CLLocation(latitude: 21.4225, longitude: 39.8262) // Mecca
        mockLocationService.mockLocation = expectedLocation

        // When
        sut.onAppear()

        // Wait for async loading
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Then
        XCTAssertNotNil(sut.prayerTimeResult, "Prayer times should be loaded")
        XCTAssertEqual(sut.prayerTimeResult?.prayerTimes.count, 5, "Should have 5 prayer times")
        XCTAssertNil(sut.error, "Should have no errors")
    }

    func testLoadPrayerTimes_WithLocationError_ShouldSetError() async {
        // Given
        mockLocationService.shouldFailWithError = LocationError.permissionDenied

        // When
        sut.onAppear()

        // Wait for async loading
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Then
        XCTAssertNil(sut.prayerTimeResult, "Prayer times should not be loaded")
        XCTAssertNotNil(sut.error, "Should have an error")
        if case .location(let locationError) = sut.error {
            XCTAssertEqual(locationError as? LocationError, LocationError.permissionDenied)
        } else {
            XCTFail("Expected location error")
        }
    }

    func testRetry_ShouldClearErrorAndReload() async {
        // Given
        mockLocationService.shouldFailWithError = LocationError.locationUnavailable
        sut.onAppear()
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertNotNil(sut.error, "Should have error initially")

        // Remove the error for retry
        mockLocationService.shouldFailWithError = nil
        mockLocationService.mockLocation = CLLocation(latitude: 40.7128, longitude: -74.0060) // NYC

        // When
        sut.retry()

        // Wait for retry
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Then
        XCTAssertNil(sut.error, "Error should be cleared")
        XCTAssertNotNil(sut.prayerTimeResult, "Prayer times should be loaded after retry")
    }

    // MARK: - Disclaimer Tests

    func testDisclaimerLevel_WhenToday_ShouldReturnToday() {
        // Given
        sut.selectedDate = Date()
        sut.prayerTimeResult = createMockPrayerTimeResult(disclaimerLevel: .today)

        // Then
        XCTAssertEqual(sut.disclaimerLevel, .today, "Disclaimer level should be .today")
    }

    func testDisclaimerLevel_WhenShortTerm_ShouldReturnShortTerm() {
        // Given
        let futureDate = Calendar.current.date(byAdding: .month, value: 6, to: Date())!
        sut.selectedDate = futureDate
        sut.prayerTimeResult = createMockPrayerTimeResult(disclaimerLevel: .shortTerm)

        // Then
        XCTAssertEqual(sut.disclaimerLevel, .shortTerm, "Disclaimer level should be .shortTerm")
    }

    func testDisclaimerVariant_WhenShortTerm_ShouldReturnShortTermVariant() {
        // Given
        sut.prayerTimeResult = createMockPrayerTimeResult(disclaimerLevel: .shortTerm)

        // Then
        XCTAssertEqual(sut.disclaimerVariant, .shortTerm, "Variant should match disclaimer level")
    }

    func testDisclaimerVariant_WhenMediumTerm_ShouldReturnMediumTermVariant() {
        // Given
        sut.prayerTimeResult = createMockPrayerTimeResult(disclaimerLevel: .mediumTerm)

        // Then
        XCTAssertEqual(sut.disclaimerVariant, .mediumTerm, "Variant should be medium term")
    }

    // MARK: - Islamic Events Tests

    func testEventOnSelectedDate_WhenNoEvents_ShouldReturnNil() {
        // Given
        sut.selectedDate = Date()
        sut.islamicEvents = []

        // Then
        XCTAssertNil(sut.eventOnSelectedDate, "Should return nil when no events")
    }

    func testEventOnSelectedDate_WhenEventExists_ShouldReturnEvent() {
        // Given
        let testDate = Date()
        sut.selectedDate = testDate

        let ramadanEvent = IslamicEventEstimate(
            event: IslamicEvent.ramadanStart,
            estimatedDate: testDate,
            hijriDate: HijriDate(day: 1, month: .ramadan, year: 1446),
            confidenceLevel: .high
        )
        sut.islamicEvents = [ramadanEvent]

        // Then
        XCTAssertNotNil(sut.eventOnSelectedDate, "Should find event on selected date")
        XCTAssertEqual(sut.eventOnSelectedDate?.event, IslamicEvent.ramadanStart)
    }

    // MARK: - High Latitude Tests

    func testHighLatitude_OsloNorway_ShouldShowWarning() async {
        // Given
        let osloLocation = CLLocation(latitude: 59.9139, longitude: 10.7522)
        mockLocationService.mockLocation = osloLocation

        // When
        sut.onAppear()
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Then
        XCTAssertTrue(sut.showHighLatitudeWarning, "Should show high latitude warning for Oslo")
    }

    func testHighLatitude_MeccaSaudiArabia_ShouldNotShowWarning() async {
        // Given
        let meccaLocation = CLLocation(latitude: 21.4225, longitude: 39.8262)
        mockLocationService.mockLocation = meccaLocation

        // When
        sut.onAppear()
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Then
        XCTAssertFalse(sut.showHighLatitudeWarning, "Should not show warning for Mecca")
    }

    // MARK: - Max Lookahead Tests

    func testMaxLookaheadDate_ShouldCalculateCorrectly() {
        // Given
        mockSettingsService.maxLookaheadMonths = 24

        // When
        let maxDate = sut.maxLookaheadDate

        // Then
        let expectedDate = Calendar.current.date(byAdding: .month, value: 24, to: Date())!
        let difference = abs(maxDate.timeIntervalSince(expectedDate))
        XCTAssertLessThan(difference, 86400, "Max lookahead date should be 24 months from now")
    }

    // MARK: - Calculation Method & Madhab Tests

    func testCalculationMethod_ShouldReturnFromSettings() {
        // Given
        mockSettingsService.calculationMethod = .muslimWorldLeague

        // Then
        XCTAssertEqual(sut.calculationMethod, .muslimWorldLeague)
    }

    func testMadhab_ShouldReturnFromSettings() {
        // Given
        mockSettingsService.madhab = .hanafi

        // Then
        XCTAssertEqual(sut.madhab, .hanafi)
    }

    // MARK: - Helper Methods

    private func createMockPrayerTimeResult(disclaimerLevel: DisclaimerLevel) -> FuturePrayerTimeResult {
        let sampleTimes: [PrayerTime] = [
            PrayerTime(prayer: .fajr, time: Calendar.current.date(bySettingHour: 5, minute: 30, second: 0, of: Date())!),
            PrayerTime(prayer: .dhuhr, time: Calendar.current.date(bySettingHour: 12, minute: 45, second: 0, of: Date())!),
            PrayerTime(prayer: .asr, time: Calendar.current.date(bySettingHour: 15, minute: 30, second: 0, of: Date())!),
            PrayerTime(prayer: .maghrib, time: Calendar.current.date(bySettingHour: 18, minute: 15, second: 0, of: Date())!),
            PrayerTime(prayer: .isha, time: Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!)
        ]

        return FuturePrayerTimeResult(
            date: Date(),
            prayerTimes: sampleTimes,
            hijriDate: HijriDate(day: 15, month: .ramadan, year: 1446),
            isRamadan: false,
            disclaimerLevel: disclaimerLevel,
            calculationTimezone: TimeZone.current,
            isHighLatitude: false,
            precision: .exact
        )
    }
}

// MARK: - Mock Prayer Time Service

private class MockPrayerTimeService: PrayerTimeServiceProtocol {
    var shouldFailWithError: Error?

    func getFuturePrayerTimes(for date: Date, location: CLLocation?) async throws -> FuturePrayerTimeResult {
        if let error = shouldFailWithError {
            throw error
        }

        let sampleTimes: [PrayerTime] = [
            PrayerTime(prayer: .fajr, time: Calendar.current.date(bySettingHour: 5, minute: 30, second: 0, of: date)!),
            PrayerTime(prayer: .dhuhr, time: Calendar.current.date(bySettingHour: 12, minute: 45, second: 0, of: date)!),
            PrayerTime(prayer: .asr, time: Calendar.current.date(bySettingHour: 15, minute: 30, second: 0, of: date)!),
            PrayerTime(prayer: .maghrib, time: Calendar.current.date(bySettingHour: 18, minute: 15, second: 0, of: date)!),
            PrayerTime(prayer: .isha, time: Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: date)!)
        ]

        // Determine disclaimer level based on how far in the future
        let monthsDiff = Calendar.current.dateComponents([.month], from: Date(), to: date).month ?? 0
        let disclaimerLevel: DisclaimerLevel
        if monthsDiff == 0 {
            disclaimerLevel = .today
        } else if monthsDiff < 12 {
            disclaimerLevel = .shortTerm
        } else if monthsDiff < 60 {
            disclaimerLevel = .mediumTerm
        } else {
            disclaimerLevel = .longTerm
        }

        return FuturePrayerTimeResult(
            date: date,
            prayerTimes: sampleTimes,
            hijriDate: HijriDate(day: 15, month: .ramadan, year: 1446),
            isRamadan: false,
            disclaimerLevel: disclaimerLevel,
            calculationTimezone: TimeZone.current,
            isHighLatitude: location != nil && abs(location!.coordinate.latitude) > 55.0,
            precision: .exact
        )
    }
}

// MARK: - Mock Islamic Calendar Service

private class MockIslamicCalendarService: IslamicCalendarServiceProtocol {
    func getHijriYear(for date: Date) -> Int {
        return HijriDate(from: date).year
    }

    func estimateRamadanDates(for hijriYear: Int) async -> DateInterval? {
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDate)!
        return DateInterval(start: startDate, end: endDate)
    }

    func estimateEidAlFitr(for hijriYear: Int) async -> Date? {
        return Calendar.current.date(byAdding: .day, value: 30, to: Date())
    }

    func estimateEidAlAdha(for hijriYear: Int) async -> Date? {
        return Calendar.current.date(byAdding: .day, value: 70, to: Date())
    }

    func getEventConfidence(for date: Date) -> EventConfidence {
        let monthsFromNow = Calendar.current.dateComponents([.month], from: Date(), to: date).month ?? 0
        if monthsFromNow < 12 {
            return .high
        } else if monthsFromNow < 60 {
            return .medium
        } else {
            return .low
        }
    }
}

// MARK: - Mock Location Service

private class MockLocationService: LocationServiceProtocol {
    var mockLocation: CLLocation?
    var shouldFailWithError: Error?

    func getCurrentLocation() async throws -> CLLocation {
        if let error = shouldFailWithError {
            throw error
        }
        return mockLocation ?? CLLocation(latitude: 37.7749, longitude: -122.4194) // Default to San Francisco
    }

    var authorizationStatus: CLAuthorizationStatus {
        return .authorizedWhenInUse
    }
}
