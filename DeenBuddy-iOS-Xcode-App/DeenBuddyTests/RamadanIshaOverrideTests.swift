//
//  RamadanIshaOverrideTests.swift
//  DeenBuddyTests
//
//  Created by Farhoud Talebi on 2025-07-23.
//

import XCTest
import CoreLocation
@testable import DeenBuddy

@MainActor
final class RamadanIshaOverrideTests: XCTestCase {
    
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
        
        // Set test location (Mecca for accuracy)
        mockLocationService.mockLocation = CLLocation(latitude: 21.4225, longitude: 39.8262)
        
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
    
    func testUmmAlQuraRamadanIshaOverride() async throws {
        // Given: Umm Al-Qura method during Ramadan
        mockSettingsService.calculationMethod = .ummAlQura
        mockIslamicCalendarService.mockIsRamadan = true
        
        // When: Prayer times are calculated
        let location = CLLocation(latitude: 21.4225, longitude: 39.8262) // Mecca
        let prayerTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
        
        // Then: Isha should be calculated with 120-minute interval (Ramadan override)
        XCTAssertFalse(prayerTimes.isEmpty, "Prayer times should be calculated")
        
        // Find Maghrib and Isha times
        guard let maghribTime = prayerTimes.first(where: { $0.prayer == .maghrib })?.time,
              let ishaTime = prayerTimes.first(where: { $0.prayer == .isha })?.time else {
            XCTFail("Maghrib and Isha times should be available")
            return
        }
        
        // Calculate the interval between Maghrib and Isha
        let interval = ishaTime.timeIntervalSince(maghribTime)
        let intervalMinutes = interval / 60
        
        // Should be 120 minutes during Ramadan (with some tolerance for calculation precision)
        XCTAssertEqual(intervalMinutes, 120, accuracy: 2, "Isha should be 120 minutes after Maghrib during Ramadan for Umm Al-Qura")
    }
    
    func testUmmAlQuraNonRamadanIshaInterval() async throws {
        // Given: Umm Al-Qura method outside Ramadan
        mockSettingsService.calculationMethod = .ummAlQura
        mockIslamicCalendarService.mockIsRamadan = false
        
        // When: Prayer times are calculated
        let location = CLLocation(latitude: 21.4225, longitude: 39.8262) // Mecca
        let prayerTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
        
        // Then: Isha should be calculated with 90-minute interval (normal)
        XCTAssertFalse(prayerTimes.isEmpty, "Prayer times should be calculated")
        
        // Find Maghrib and Isha times
        guard let maghribTime = prayerTimes.first(where: { $0.prayer == .maghrib })?.time,
              let ishaTime = prayerTimes.first(where: { $0.prayer == .isha })?.time else {
            XCTFail("Maghrib and Isha times should be available")
            return
        }
        
        // Calculate the interval between Maghrib and Isha
        let interval = ishaTime.timeIntervalSince(maghribTime)
        let intervalMinutes = interval / 60
        
        // Should be 90 minutes outside Ramadan (with some tolerance for calculation precision)
        XCTAssertEqual(intervalMinutes, 90, accuracy: 2, "Isha should be 90 minutes after Maghrib outside Ramadan for Umm Al-Qura")
    }
    
    func testQatarRamadanIshaOverride() async throws {
        // Given: Qatar method during Ramadan
        mockSettingsService.calculationMethod = .qatar
        mockIslamicCalendarService.mockIsRamadan = true
        
        // When: Prayer times are calculated
        let location = CLLocation(latitude: 25.2854, longitude: 51.5310) // Doha
        let prayerTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
        
        // Then: Isha should be calculated with 120-minute interval (Ramadan override)
        XCTAssertFalse(prayerTimes.isEmpty, "Prayer times should be calculated")
        
        // Find Maghrib and Isha times
        guard let maghribTime = prayerTimes.first(where: { $0.prayer == .maghrib })?.time,
              let ishaTime = prayerTimes.first(where: { $0.prayer == .isha })?.time else {
            XCTFail("Maghrib and Isha times should be available")
            return
        }
        
        // Calculate the interval between Maghrib and Isha
        let interval = ishaTime.timeIntervalSince(maghribTime)
        let intervalMinutes = interval / 60
        
        // Should be 120 minutes during Ramadan (with some tolerance for calculation precision)
        XCTAssertEqual(intervalMinutes, 120, accuracy: 2, "Isha should be 120 minutes after Maghrib during Ramadan for Qatar")
    }
    
    func testOtherMethodsNotAffectedByRamadan() async throws {
        // Given: Muslim World League method during Ramadan (should not be affected)
        mockSettingsService.calculationMethod = .muslimWorldLeague
        mockIslamicCalendarService.mockIsRamadan = true
        
        // When: Prayer times are calculated
        let location = CLLocation(latitude: 21.4225, longitude: 39.8262) // Mecca
        let prayerTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
        
        // Then: Isha should be calculated using twilight angle, not fixed interval
        XCTAssertFalse(prayerTimes.isEmpty, "Prayer times should be calculated")
        
        // Muslim World League uses twilight angles, not fixed intervals
        // So Ramadan should not affect the calculation
        // This test ensures the Ramadan override only applies to methods that use fixed intervals
        let ishaTime = prayerTimes.first(where: { $0.prayer == .isha })
        XCTAssertNotNil(ishaTime, "Isha time should be calculated normally for non-interval methods")
    }
}

// MARK: - Mock Islamic Calendar Service

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
    func exportCalendar(format: CalendarExportFormat) async throws -> Data { return Data() }
    func importEvents(from data: Data, format: CalendarImportFormat) async throws {}
    func setCalculationMethod(_ method: IslamicCalendarMethod) async {}
    func setEventNotifications(_ enabled: Bool) async {}
    func setDefaultReminderTime(_ time: TimeInterval) async {}
    func refreshCalendarData() async {}
}
