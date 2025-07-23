//
//  NewCalculationMethodsTests.swift
//  DeenBuddyTests
//
//  Created by Farhoud Talebi on 2025-07-23.
//

import XCTest
import CoreLocation
@testable import DeenBuddy

@MainActor
final class NewCalculationMethodsTests: XCTestCase {
    
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
        
        // Set test location (Toronto, Canada for FCNA testing)
        mockLocationService.mockLocation = CLLocation(latitude: 43.6532, longitude: -79.3832)
        
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
    
    func testJafariLevaCalculationMethod() async throws {
        // Given: Ja'fari (Leva Institute, Qum) calculation method
        mockSettingsService.calculationMethod = .jafariLeva
        
        // When: Prayer times are calculated
        let location = CLLocation(latitude: 32.4279, longitude: 53.6880) // Isfahan, Iran
        let prayerTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
        
        // Then: Prayer times should be calculated successfully
        XCTAssertFalse(prayerTimes.isEmpty, "Ja'fari Leva prayer times should be calculated")
        XCTAssertEqual(prayerTimes.count, 5, "Should have 5 prayer times")
        
        // Verify all prayer types are present
        let prayerTypes = Set(prayerTimes.map { $0.prayer })
        let expectedTypes: Set<Prayer> = [.fajr, .dhuhr, .asr, .maghrib, .isha]
        XCTAssertEqual(prayerTypes, expectedTypes, "All prayer types should be present")
        
        // Verify times are in chronological order
        for i in 1..<prayerTimes.count {
            XCTAssertLessThan(prayerTimes[i-1].time, prayerTimes[i].time, "Prayer times should be in chronological order")
        }
    }
    
    func testJafariTehranCalculationMethod() async throws {
        // Given: Ja'fari (Tehran IOG) calculation method
        mockSettingsService.calculationMethod = .jafariTehran
        
        // When: Prayer times are calculated
        let location = CLLocation(latitude: 35.6892, longitude: 51.3890) // Tehran, Iran
        let prayerTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
        
        // Then: Prayer times should be calculated successfully
        XCTAssertFalse(prayerTimes.isEmpty, "Ja'fari Tehran prayer times should be calculated")
        XCTAssertEqual(prayerTimes.count, 5, "Should have 5 prayer times")
        
        // Verify all prayer types are present
        let prayerTypes = Set(prayerTimes.map { $0.prayer })
        let expectedTypes: Set<Prayer> = [.fajr, .dhuhr, .asr, .maghrib, .isha]
        XCTAssertEqual(prayerTypes, expectedTypes, "All prayer types should be present")
        
        // Verify times are in chronological order
        for i in 1..<prayerTimes.count {
            XCTAssertLessThan(prayerTimes[i-1].time, prayerTimes[i].time, "Prayer times should be in chronological order")
        }
    }
    
    func testFCNACanadaCalculationMethod() async throws {
        // Given: FCNA Canada calculation method
        mockSettingsService.calculationMethod = .fcnaCanada
        
        // When: Prayer times are calculated
        let location = CLLocation(latitude: 43.6532, longitude: -79.3832) // Toronto, Canada
        let prayerTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
        
        // Then: Prayer times should be calculated successfully
        XCTAssertFalse(prayerTimes.isEmpty, "FCNA Canada prayer times should be calculated")
        XCTAssertEqual(prayerTimes.count, 5, "Should have 5 prayer times")
        
        // Verify all prayer types are present
        let prayerTypes = Set(prayerTimes.map { $0.prayer })
        let expectedTypes: Set<Prayer> = [.fajr, .dhuhr, .asr, .maghrib, .isha]
        XCTAssertEqual(prayerTypes, expectedTypes, "All prayer types should be present")
        
        // Verify times are in chronological order
        for i in 1..<prayerTimes.count {
            XCTAssertLessThan(prayerTimes[i-1].time, prayerTimes[i].time, "Prayer times should be in chronological order")
        }
    }
    
    func testJafariMethodsComparison() async throws {
        // Test that the two Ja'fari methods produce different results
        
        let location = CLLocation(latitude: 35.6892, longitude: 51.3890) // Tehran, Iran
        
        // Calculate with Leva method (16°/14°)
        mockSettingsService.calculationMethod = .jafariLeva
        let levaTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
        
        // Calculate with Tehran method (17.7°/14°)
        mockSettingsService.calculationMethod = .jafariTehran
        let tehranTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
        
        // Find Fajr times for comparison
        guard let levaFajr = levaTimes.first(where: { $0.prayer == .fajr })?.time,
              let tehranFajr = tehranTimes.first(where: { $0.prayer == .fajr })?.time else {
            XCTFail("Both methods should calculate Fajr times")
            return
        }
        
        // Tehran method (17.7°) should have later Fajr than Leva method (16°)
        // Higher angle = later Fajr time
        XCTAssertGreaterThan(tehranFajr, levaFajr, "Tehran IOG method (17.7°) should have later Fajr than Leva method (16°)")
        
        // The difference should be reasonable (not too extreme)
        let fajrDifference = tehranFajr.timeIntervalSince(levaFajr)
        XCTAssertLessThan(fajrDifference, 1800, "Fajr time difference should be less than 30 minutes")
        XCTAssertGreaterThan(fajrDifference, 60, "Fajr time difference should be more than 1 minute")
    }
    
    func testFCNAvsISNAComparison() async throws {
        // Test that FCNA Canada (13°/13°) produces different results from ISNA (15°/15°)
        
        let location = CLLocation(latitude: 43.6532, longitude: -79.3832) // Toronto, Canada
        
        // Calculate with FCNA Canada method (13°/13°)
        mockSettingsService.calculationMethod = .fcnaCanada
        let fcnaTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
        
        // Calculate with ISNA method (15°/15°)
        mockSettingsService.calculationMethod = .northAmerica
        let isnaTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
        
        // Find Fajr and Isha times for comparison
        guard let fcnaFajr = fcnaTimes.first(where: { $0.prayer == .fajr })?.time,
              let isnaFajr = isnaTimes.first(where: { $0.prayer == .fajr })?.time,
              let fcnaIsha = fcnaTimes.first(where: { $0.prayer == .isha })?.time,
              let isnaIsha = isnaTimes.first(where: { $0.prayer == .isha })?.time else {
            XCTFail("Both methods should calculate Fajr and Isha times")
            return
        }
        
        // FCNA (13°) should have later Fajr than ISNA (15°)
        // Lower angle = later Fajr time
        XCTAssertGreaterThan(fcnaFajr, isnaFajr, "FCNA Canada (13°) should have later Fajr than ISNA (15°)")
        
        // FCNA (13°) should have earlier Isha than ISNA (15°)
        // Lower angle = earlier Isha time
        XCTAssertLessThan(fcnaIsha, isnaIsha, "FCNA Canada (13°) should have earlier Isha than ISNA (15°)")
        
        // The differences should be reasonable
        let fajrDifference = fcnaFajr.timeIntervalSince(isnaFajr)
        let ishaDifference = isnaIsha.timeIntervalSince(fcnaIsha)
        
        XCTAssertLessThan(fajrDifference, 1800, "Fajr time difference should be less than 30 minutes")
        XCTAssertGreaterThan(fajrDifference, 60, "Fajr time difference should be more than 1 minute")
        XCTAssertLessThan(ishaDifference, 1800, "Isha time difference should be less than 30 minutes")
        XCTAssertGreaterThan(ishaDifference, 60, "Isha time difference should be more than 1 minute")
    }
    
    func testCalculationMethodDisplayNames() async throws {
        // Test that new calculation methods have proper display names
        
        XCTAssertEqual(CalculationMethod.jafariLeva.displayName, "Ja'fari (Leva Institute, Qum)", "Ja'fari Leva should have correct display name")
        XCTAssertEqual(CalculationMethod.jafariTehran.displayName, "Ja'fari (Tehran IOG)", "Ja'fari Tehran should have correct display name")
        XCTAssertEqual(CalculationMethod.fcnaCanada.displayName, "FCNA (Canada)", "FCNA Canada should have correct display name")
    }
    
    func testCalculationMethodDescriptions() async throws {
        // Test that new calculation methods have proper descriptions
        
        XCTAssertTrue(CalculationMethod.jafariLeva.description.contains("16°/14°"), "Ja'fari Leva description should mention angles")
        XCTAssertTrue(CalculationMethod.jafariTehran.description.contains("17.7°/14°"), "Ja'fari Tehran description should mention angles")
        XCTAssertTrue(CalculationMethod.fcnaCanada.description.contains("13°/13°"), "FCNA Canada description should mention angles")
        XCTAssertTrue(CalculationMethod.fcnaCanada.description.contains("Canada"), "FCNA Canada description should mention Canada")
    }
    
    func testCustomParametersImplementation() async throws {
        // Test that custom parameters are correctly implemented
        
        // Ja'fari Leva should have custom parameters
        let levaParams = CalculationMethod.jafariLeva.customParameters()
        XCTAssertNotNil(levaParams, "Ja'fari Leva should have custom parameters")
        XCTAssertEqual(levaParams?.fajrAngle, 16.0, "Ja'fari Leva should have 16° Fajr angle")
        XCTAssertEqual(levaParams?.ishaAngle, 14.0, "Ja'fari Leva should have 14° Isha angle")
        
        // Ja'fari Tehran should have custom parameters
        let tehranParams = CalculationMethod.jafariTehran.customParameters()
        XCTAssertNotNil(tehranParams, "Ja'fari Tehran should have custom parameters")
        XCTAssertEqual(tehranParams?.fajrAngle, 17.7, "Ja'fari Tehran should have 17.7° Fajr angle")
        XCTAssertEqual(tehranParams?.ishaAngle, 14.0, "Ja'fari Tehran should have 14° Isha angle")
        
        // FCNA Canada should have custom parameters
        let fcnaParams = CalculationMethod.fcnaCanada.customParameters()
        XCTAssertNotNil(fcnaParams, "FCNA Canada should have custom parameters")
        XCTAssertEqual(fcnaParams?.fajrAngle, 13.0, "FCNA Canada should have 13° Fajr angle")
        XCTAssertEqual(fcnaParams?.ishaAngle, 13.0, "FCNA Canada should have 13° Isha angle")
        
        // Standard methods should not have custom parameters
        XCTAssertNil(CalculationMethod.muslimWorldLeague.customParameters(), "Muslim World League should not have custom parameters")
        XCTAssertNil(CalculationMethod.northAmerica.customParameters(), "ISNA should not have custom parameters")
    }
    
    func testAllNewMethodsInCaseIterable() async throws {
        // Test that all new methods are included in CaseIterable
        let allMethods = CalculationMethod.allCases
        
        XCTAssertTrue(allMethods.contains(.jafariLeva), "Ja'fari Leva should be in allCases")
        XCTAssertTrue(allMethods.contains(.jafariTehran), "Ja'fari Tehran should be in allCases")
        XCTAssertTrue(allMethods.contains(.fcnaCanada), "FCNA Canada should be in allCases")
        
        // Validate that all expected new methods are present (more maintainable than hardcoded count)
        let expectedNewMethods: [CalculationMethod] = [.jafariLeva, .jafariTehran, .fcnaCanada]
        let hasAllNewMethods = expectedNewMethods.allSatisfy { allMethods.contains($0) }
        XCTAssertTrue(hasAllNewMethods, "All expected new calculation methods should be included in allCases")
        
        // Ensure we have a reasonable number of methods (should be at least the new ones)
        XCTAssertGreaterThanOrEqual(allMethods.count, expectedNewMethods.count, "Should have at least the expected new calculation methods")
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
    func exportCalendar(format: CalendarExportFormat) async throws -> Data { return Data() }
    func importEvents(from data: Data, format: CalendarImportFormat) async throws {}
    func setCalculationMethod(_ method: IslamicCalendarMethod) async {}
    func setEventNotifications(_ enabled: Bool) async {}
    func setDefaultReminderTime(_ time: TimeInterval) async {}
}
