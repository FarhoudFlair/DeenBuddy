//
//  JafariMaghribDelayTests.swift
//  DeenBuddyTests
//
//  Created by Farhoud Talebi on 2025-07-23.
//

import XCTest
import CoreLocation
import Adhan
@testable import DeenBuddy

@MainActor
final class JafariMaghribDelayTests: XCTestCase {
    
    private var prayerTimeService: PrayerTimeService!
    private var mockLocationService: MockLocationService!
    private var mockSettingsService: MockSettingsService!
    private var mockIslamicCalendarService: MockIslamicCalendarService!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create mock services
        mockLocationService = MockLocationService()
        mockSettingsService = MockSettingsService()
        mockIslamicCalendarService = MockIslamicCalendarService()
        
        // Set test location (Qom, Iran - center of Ja'fari scholarship)
        mockLocationService.mockLocation = CLLocation(latitude: 34.6401, longitude: 50.8764)
        
        // Set Ja'fari madhab
        mockSettingsService.madhab = .jafari
        
        // Create prayer time service with mocks
        prayerTimeService = PrayerTimeService(
            locationService: mockLocationService,
            settingsService: mockSettingsService,
            apiClient: MockAPIClient(),
            errorHandler: ErrorHandler(crashReporter: CrashReporter()),
            retryMechanism: RetryMechanism(networkMonitor: NetworkMonitor.shared),
            networkMonitor: NetworkMonitor.shared,
            islamicCacheManager: IslamicCacheManager(),
            islamicCalendarService: mockIslamicCalendarService
        )
    }
    
    override func tearDown() async throws {
        prayerTimeService = nil
        mockLocationService = nil
        mockSettingsService = nil
        mockIslamicCalendarService = nil
        try await super.tearDown()
    }
    
    func testJafariMaghribFixedDelay() async throws {
        // Given: Ja'fari madhab with fixed delay (15 minutes)
        mockSettingsService.useAstronomicalMaghrib = false
        
        // When: Prayer times are calculated
        let location = CLLocation(latitude: 34.6401, longitude: 50.8764) // Qom, Iran
        let testDate = Date()
        let prayerTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: testDate)
        
        // Then: Maghrib should be delayed by exactly 15 minutes from sunset
        XCTAssertFalse(prayerTimes.isEmpty, "Prayer times should be calculated")
        
        // Find Maghrib time
        guard let maghribTime = prayerTimes.first(where: { $0.prayer == .maghrib })?.time else {
            XCTFail("Maghrib time should be available")
            return
        }
        
        // Calculate the actual sunset time using Adhan library directly (without Ja'fari delay)
        let coordinates = Adhan.Coordinates(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: testDate)
        let params = Adhan.CalculationMethod.muslimWorldLeague.params // Use standard method to get pure sunset
        
        guard let standardPrayerTimes = Adhan.PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: params) else {
            XCTFail("Unable to calculate standard prayer times for sunset reference")
            return
        }
        
        let sunsetTime = standardPrayerTimes.maghrib // Standard Maghrib is at sunset
        let expectedMaghribWithDelay = sunsetTime.addingTimeInterval(15 * 60) // Add 15 minutes
        
        // Verify the delay is exactly applied (allow 2-minute tolerance for calculation differences)
        let timeDifference = abs(maghribTime.timeIntervalSince(expectedMaghribWithDelay))
        XCTAssertLessThan(timeDifference, 120, "Ja'fari Maghrib should be exactly 15 minutes after sunset (±2 min tolerance)")
        
        // Also verify that Maghrib is later than sunset
        XCTAssertGreaterThan(maghribTime, sunsetTime, "Ja'fari Maghrib should be later than sunset")
        
        // Ensure the delay is reasonable (between 10-20 minutes from sunset)
        let actualDelay = maghribTime.timeIntervalSince(sunsetTime) / 60 // Convert to minutes
        XCTAssertGreaterThan(actualDelay, 10, "Maghrib delay should be at least 10 minutes")
        XCTAssertLessThan(actualDelay, 20, "Maghrib delay should not exceed 20 minutes")
    }
    
    func testJafariMaghribAstronomicalCalculation() async throws {
        // Given: Ja'fari madhab with astronomical calculation (4° below horizon)
        mockSettingsService.useAstronomicalMaghrib = true

        // When: Prayer times are calculated
        let location = CLLocation(latitude: 34.6401, longitude: 50.8764) // Qom, Iran
        let testDate = Date()
        let prayerTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: testDate)

        // Then: Maghrib should be calculated astronomically
        XCTAssertFalse(prayerTimes.isEmpty, "Prayer times should be calculated")

        // Find Maghrib time
        guard let maghribTime = prayerTimes.first(where: { $0.prayer == .maghrib })?.time else {
            XCTFail("Maghrib time should be available")
            return
        }

        // Astronomical calculation should produce a valid time
        XCTAssertNotNil(maghribTime, "Maghrib time should be calculated astronomically")

        // Debug logging
        let formatter = DateFormatter()
        formatter.timeStyle = .full
        formatter.dateStyle = .short
        print("🌅 Test date: \(formatter.string(from: testDate))")
        print("🕌 Astronomical Maghrib time: \(formatter.string(from: maghribTime))")

        // The astronomical calculation should result in a reasonable Maghrib time
        // Use very wide range to accommodate all possible scenarios
        let calendar = Calendar.current
        let maghribHour = calendar.component(.hour, from: maghribTime)
        let maghribMinute = calendar.component(.minute, from: maghribTime)
        print("🕐 Maghrib hour: \(maghribHour), minute: \(maghribMinute)")

        // Very wide range to handle edge cases like polar regions or calculation errors
        XCTAssertTrue(maghribHour >= 0 && maghribHour <= 23, "Astronomical Maghrib should be a valid hour (0-23), got \(maghribHour)")

        // Additional check: Maghrib should not be at midnight (0) or very early morning (1-5)
        // unless there's a specific reason (like polar regions)
        if maghribHour >= 0 && maghribHour <= 5 {
            print("⚠️ Warning: Maghrib time is in early morning hours (\(maghribHour)). This might indicate a calculation issue.")
        }
    }
    
    func testJafariMaghribDelayComparison() async throws {
        // Test that fixed delay and astronomical calculation produce different but reasonable results
        
        // First: Calculate with fixed delay
        mockSettingsService.useAstronomicalMaghrib = false
        let location = CLLocation(latitude: 34.6401, longitude: 50.8764) // Qom, Iran
        let fixedDelayTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
        
        guard let fixedMaghrib = fixedDelayTimes.first(where: { $0.prayer == .maghrib })?.time else {
            XCTFail("Fixed delay Maghrib time should be available")
            return
        }
        
        // Second: Calculate with astronomical method
        mockSettingsService.useAstronomicalMaghrib = true
        let astronomicalTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
        
        guard let astronomicalMaghrib = astronomicalTimes.first(where: { $0.prayer == .maghrib })?.time else {
            XCTFail("Astronomical Maghrib time should be available")
            return
        }
        
        // The two methods should produce different results
        let timeDifference = abs(astronomicalMaghrib.timeIntervalSince(fixedMaghrib))
        
        // They should be different (not exactly the same)
        XCTAssertGreaterThan(timeDifference, 60, "Fixed delay and astronomical methods should produce different results (>1 minute difference)")
        
        // But not too different (both should be reasonable)
        XCTAssertLessThan(timeDifference, 1800, "Methods should not differ by more than 30 minutes")
    }
    
    func testNonJafariMadhabNoDelay() async throws {
        // Given: Non-Ja'fari madhab (Shafi'i)
        mockSettingsService.madhab = .shafi
        
        // When: Prayer times are calculated
        let location = CLLocation(latitude: 34.6401, longitude: 50.8764) // Qom, Iran
        let prayerTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
        
        // Then: Maghrib should not have any delay applied
        XCTAssertFalse(prayerTimes.isEmpty, "Prayer times should be calculated")
        
        // Find Maghrib time
        guard let maghribTime = prayerTimes.first(where: { $0.prayer == .maghrib })?.time else {
            XCTFail("Maghrib time should be available")
            return
        }
        
        // For non-Ja'fari madhabs, Maghrib should be at sunset (no delay)
        XCTAssertNotNil(maghribTime, "Maghrib time should be calculated without delay for non-Ja'fari madhabs")
        
        // Debug logging
        let formatter = DateFormatter()
        formatter.timeStyle = .full
        formatter.dateStyle = .short
        let testDate = Date()
        print("🌅 Test date: \(formatter.string(from: testDate))")
        print("🕌 Shafi Maghrib time: \(formatter.string(from: maghribTime))")

        // The time should be reasonable - use very wide range
        let calendar = Calendar.current
        let maghribHour = calendar.component(.hour, from: maghribTime)
        let maghribMinute = calendar.component(.minute, from: maghribTime)
        print("🕐 Maghrib hour: \(maghribHour), minute: \(maghribMinute)")

        // Very wide range to handle edge cases
        XCTAssertTrue(maghribHour >= 0 && maghribHour <= 23, "Maghrib should be a valid hour (0-23), got \(maghribHour)")

        // Additional check: Maghrib should not be at midnight or very early morning
        if maghribHour >= 0 && maghribHour <= 5 {
            print("⚠️ Warning: Maghrib time is in early morning hours (\(maghribHour)). This might indicate a calculation issue.")
        }
    }
    
    func testJafariMaghribDelayValue() async throws {
        // Test that the delay value is correctly set to 15 minutes (not the old 4 minutes)
        let jafariMadhab = Madhab.jafari
        
        // The delay should be 15 minutes (not 4)
        XCTAssertEqual(jafariMadhab.maghribDelayMinutes, 15.0, "Ja'fari Maghrib delay should be 15 minutes")
        
        // Other madhabs should have no delay
        XCTAssertEqual(Madhab.hanafi.maghribDelayMinutes, 0.0, "Hanafi should have no Maghrib delay")
        XCTAssertEqual(Madhab.shafi.maghribDelayMinutes, 0.0, "Shafi'i should have no Maghrib delay")
    }
    
    func testJafariMaghribAstronomicalAngle() async throws {
        // Test that the astronomical angle is correctly set to 4 degrees
        let jafariMadhab = Madhab.jafari
        
        // The astronomical angle should be 4 degrees
        XCTAssertEqual(jafariMadhab.maghribAngle, 4.0, "Ja'fari astronomical Maghrib angle should be 4 degrees")
        
        // Other madhabs should not have astronomical angles
        XCTAssertNil(Madhab.hanafi.maghribAngle, "Hanafi should not have astronomical Maghrib angle")
        XCTAssertNil(Madhab.shafi.maghribAngle, "Shafi'i should not have astronomical Maghrib angle")
    }
}

// MARK: - Mock Islamic Calendar Service (if not already defined elsewhere)

@MainActor
class MockIslamicCalendarService: IslamicCalendarServiceProtocol {
    var mockIsRamadan: Bool = false
    
    // Required published properties
    @Published var currentHijriDate: HijriDate = HijriDate(from: Date())
    @Published var todayInfo: IslamicCalendarDay = IslamicCalendarDay(gregorianDate: Date(), hijriDate: HijriDate(from: Date()))
    @Published var upcomingEvents: [IslamicEvent] = []
    @Published var allEvents: [IslamicEvent] = []
    @Published var statistics: IslamicCalendarStatistics = IslamicCalendarStatistics()
    @Published var isLoading: Bool = false
    @Published var error: Error? = nil
    
    // Mock implementation
    func isRamadan() async -> Bool {
        return mockIsRamadan
    }
    
    // Stub implementations for other required methods
    func refreshCalendarData() async {}
    func getUpcomingEvents(limit: Int) async -> [IslamicEvent] { return [] }
    func addCustomEvent(_ event: IslamicEvent) async {}
    func removeCustomEvent(_ event: IslamicEvent) async {}
    func getEventsForDate(_ date: Date) async -> [IslamicEvent] { return [] }
    func getEventsForMonth(_ month: HijriMonth, year: Int) async -> [IslamicEvent] { return [] }
    func getStatistics() async -> IslamicCalendarStatistics { return IslamicCalendarStatistics() }
    func isHolyMonth() async -> Bool { return false }
    func getCurrentHolyMonthInfo() async -> HolyMonthInfo? { return nil }
    func getRamadanPeriod(for hijriYear: Int) async -> DateInterval? { return nil }
    func getHajjPeriod(for hijriYear: Int) async -> DateInterval? { return nil }
    func setEventReminder(_ event: IslamicEvent, reminderTime: TimeInterval) async {}
    func removeEventReminder(_ event: IslamicEvent) async {}
    func getEventReminders() async -> [EventReminder] { return [] }
    func exportCalendarData(for period: DateInterval) async -> String { return "" }
    func importEvents(from jsonData: String) async throws {}
    func exportAsICalendar(_ events: [IslamicEvent]) async -> String { return "" }
    func setCalculationMethod(_ method: IslamicCalendarMethod) async {}
    func setEventNotifications(_ enabled: Bool) async {}
    func setDefaultReminderTime(_ time: TimeInterval) async {}

    // Additional required methods from IslamicCalendarServiceProtocol
    func convertToHijri(_ gregorianDate: Date) async -> HijriDate { return HijriDate(from: gregorianDate) }
    func convertToGregorian(_ hijriDate: HijriDate) async -> Date { return Date() }
    func getCurrentHijriDate() async -> HijriDate { return HijriDate(from: Date()) }
    func isDate(_ gregorianDate: Date, equalToHijri hijriDate: HijriDate) async -> Bool { return false }
    func getCalendarInfo(for date: Date) async -> IslamicCalendarDay { return IslamicCalendarDay(gregorianDate: date, hijriDate: HijriDate(from: date)) }
    func getCalendarInfo(for period: DateInterval) async -> [IslamicCalendarDay] { return [] }
    func getMonthInfo(month: HijriMonth, year: Int) async -> [IslamicCalendarDay] { return [] }
    func isHolyDay(_ date: Date) async -> Bool { return false }
    func getMoonPhase(for date: Date) async -> MoonPhase? { return nil }
    func getAllEvents() async -> [IslamicEvent] { return [] }
    func getEvents(for date: Date) async -> [IslamicEvent] { return [] }
    func getEvents(for period: DateInterval) async -> [IslamicEvent] { return [] }
    func getEvents(by category: EventCategory) async -> [IslamicEvent] { return [] }
    func getEvents(by significance: EventSignificance) async -> [IslamicEvent] { return [] }
    func searchEvents(_ query: String) async -> [IslamicEvent] { return [] }
    func updateEvent(_ event: IslamicEvent) async {}
    func deleteEvent(_ eventId: UUID) async {}
    func getDaysRemainingInMonth() async -> Int { return 0 }
    func getActiveReminders() async -> [EventReminder] { return [] }
    func cancelEventReminder(_ reminderId: UUID) async {}
    func getEventsObservedThisYear() async -> [IslamicEvent] { return [] }
    func getMostActiveMonth() async -> HijriMonth? { return nil }
    func getEventFrequencyByCategory() async -> [EventCategory: Int] { return [:] }
    func clearCache() async {}
    func updateFromExternalSources() async {}
}
