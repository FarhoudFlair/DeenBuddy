//
//  HanafiAsrPriorityTests.swift
//  DeenBuddyTests
//
//  Created by Farhoud Talebi on 2025-07-23.
//

import XCTest
import CoreLocation
@testable import DeenBuddy

@MainActor
final class HanafiAsrPriorityTests: XCTestCase {
    
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
        
        // Set test location (Istanbul, Turkey - historically Hanafi region)
        mockLocationService.mockLocation = CLLocation(latitude: 41.0082, longitude: 28.9784)
        
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
    
    func testHanafiAsrWithStandardCalculationMethod() async throws {
        // Given: Standard calculation method (Muslim World League) + Hanafi madhab
        mockSettingsService.calculationMethod = .muslimWorldLeague
        mockSettingsService.madhab = .hanafi
        
        // When: Prayer times are calculated
        let location = CLLocation(latitude: 41.0082, longitude: 28.9784) // Istanbul
        let prayerTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
        
        // Then: Asr should be calculated with Hanafi method (2x shadow)
        XCTAssertFalse(prayerTimes.isEmpty, "Prayer times should be calculated")
        
        guard let asrTime = prayerTimes.first(where: { $0.prayer == .asr })?.time else {
            XCTFail("Asr time should be available")
            return
        }
        
        // Hanafi Asr should be later than Shafi Asr
        // We'll verify this by comparing with Shafi calculation
        mockSettingsService.madhab = .shafi
        let shafiTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
        
        guard let shafiAsrTime = shafiTimes.first(where: { $0.prayer == .asr })?.time else {
            XCTFail("Shafi Asr time should be available")
            return
        }
        
        // Hanafi Asr (2x shadow) should be later than Shafi Asr (1x shadow)
        XCTAssertGreaterThan(asrTime, shafiAsrTime, "Hanafi Asr should be later than Shafi Asr (2x vs 1x shadow)")
        
        // The difference should be reasonable (typically 30-40 minutes)
        let timeDifference = asrTime.timeIntervalSince(shafiAsrTime)
        XCTAssertGreaterThan(timeDifference, 1200, "Hanafi Asr should be at least 20 minutes later") // 20 minutes
        XCTAssertLessThan(timeDifference, 3600, "Hanafi Asr should not be more than 1 hour later") // 1 hour
    }
    
    func testHanafiAsrWithCustomCalculationMethod() async throws {
        // Given: Custom calculation method (Ja'fari Leva) + Hanafi madhab
        // This tests the priority logic: Ja'fari angles for twilight, Hanafi for Asr
        mockSettingsService.calculationMethod = .jafariLeva
        mockSettingsService.madhab = .hanafi
        
        // When: Prayer times are calculated
        let location = CLLocation(latitude: 41.0082, longitude: 28.9784) // Istanbul
        let hanafiJafariTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
        
        // Compare with Shafi + Ja'fari Leva combination
        mockSettingsService.madhab = .shafi
        let shafiJafariTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
        
        // Then: Asr should still follow Hanafi calculation (2x shadow) despite Ja'fari method
        guard let hanafiAsrTime = hanafiJafariTimes.first(where: { $0.prayer == .asr })?.time,
              let shafiAsrTime = shafiJafariTimes.first(where: { $0.prayer == .asr })?.time else {
            XCTFail("Both Asr times should be available")
            return
        }
        
        // Hanafi madhab should take priority for Asr calculation
        XCTAssertGreaterThan(hanafiAsrTime, shafiAsrTime, "Hanafi madhab should take priority for Asr calculation even with custom method")
        
        // The difference should be consistent with madhab difference
        let timeDifference = hanafiAsrTime.timeIntervalSince(shafiAsrTime)
        XCTAssertGreaterThan(timeDifference, 1200, "Madhab difference should be at least 20 minutes")
        XCTAssertLessThan(timeDifference, 3600, "Madhab difference should not exceed 1 hour")
    }
    
    func testHanafiAsrPriorityWithAllCustomMethods() async throws {
        // Test that Hanafi madhab takes priority with all custom calculation methods
        let customMethods: [CalculationMethod] = [.jafariLeva, .jafariTehran, .fcnaCanada]
        
        for method in customMethods {
            // Given: Custom method + Hanafi madhab
            mockSettingsService.calculationMethod = method
            mockSettingsService.madhab = .hanafi
            
            // When: Prayer times are calculated
            let location = CLLocation(latitude: 41.0082, longitude: 28.9784)
            let hanafiTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
            
            // Compare with Shafi madhab for same method
            mockSettingsService.madhab = .shafi
            let shafiTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
            
            // Then: Hanafi should always produce later Asr
            guard let hanafiAsr = hanafiTimes.first(where: { $0.prayer == .asr })?.time,
                  let shafiAsr = shafiTimes.first(where: { $0.prayer == .asr })?.time else {
                XCTFail("Asr times should be available for method \(method.displayName)")
                continue
            }
            
            XCTAssertGreaterThan(hanafiAsr, shafiAsr, 
                "Hanafi madhab should produce later Asr for \(method.displayName)")
        }
    }
    
    func testMadhabShadowMultiplierValues() async throws {
        // Test that madhab shadow multipliers are correctly defined
        XCTAssertEqual(Madhab.hanafi.asrShadowMultiplier, 2.0, "Hanafi should use 2x shadow multiplier")
        XCTAssertEqual(Madhab.shafi.asrShadowMultiplier, 1.0, "Shafi should use 1x shadow multiplier")
        XCTAssertEqual(Madhab.jafari.asrShadowMultiplier, 1.0, "Ja'fari should use 1x shadow multiplier")
    }
    
    func testAdhanMadhabMapping() async throws {
        // Test that madhab mapping to Adhan library is correct
        XCTAssertEqual(Madhab.hanafi.adhanMadhab(), .hanafi, "Hanafi should map to Adhan.Madhab.hanafi")
        XCTAssertEqual(Madhab.shafi.adhanMadhab(), .shafi, "Shafi should map to Adhan.Madhab.shafi")
        XCTAssertEqual(Madhab.jafari.adhanMadhab(), .shafi, "Ja'fari should map to Adhan.Madhab.shafi (closest approximation)")
    }
    
    func testHanafiAsrTimingDescription() async throws {
        // Test that Hanafi madhab has correct timing description
        let hanafi = Madhab.hanafi
        
        XCTAssertTrue(hanafi.prayerTimingNotes.contains("30-40 minutes later"), 
            "Hanafi timing notes should mention later Asr timing")
        XCTAssertTrue(hanafi.keyPractices.contains("Later Asr prayer timing (2x shadow length)"), 
            "Hanafi key practices should mention later Asr timing")
        XCTAssertTrue(hanafi.prayerDifferences.contains("Asr prayer when shadow = 2x object height"), 
            "Hanafi prayer differences should mention 2x shadow height")
    }
    
    func testHanafiAsrConsistencyAcrossLocations() async throws {
        // Test that Hanafi Asr priority works consistently across different locations
        let locations = [
            CLLocation(latitude: 41.0082, longitude: 28.9784), // Istanbul, Turkey
            CLLocation(latitude: 33.3152, longitude: 44.3661), // Baghdad, Iraq
            CLLocation(latitude: 28.0339, longitude: 1.6596),  // Ghardaia, Algeria
            CLLocation(latitude: 31.2001, longitude: 29.9187)  // Alexandria, Egypt
        ]
        
        for location in locations {
            mockLocationService.mockLocation = location
            
            // Calculate with Hanafi madhab
            mockSettingsService.madhab = .hanafi
            let hanafiTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
            
            // Calculate with Shafi madhab
            mockSettingsService.madhab = .shafi
            let shafiTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
            
            // Hanafi should always be later
            guard let hanafiAsr = hanafiTimes.first(where: { $0.prayer == .asr })?.time,
                  let shafiAsr = shafiTimes.first(where: { $0.prayer == .asr })?.time else {
                XCTFail("Asr times should be available for location \(location)")
                continue
            }
            
            XCTAssertGreaterThan(hanafiAsr, shafiAsr, 
                "Hanafi Asr should be later at location \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }
    }
    
    func testHanafiAsrPriorityDocumentation() async throws {
        // Test that the priority logic is properly documented in the madhab model
        let hanafi = Madhab.hanafi
        
        // Verify that Hanafi is documented as using later Asr timing
        XCTAssertFalse(hanafi.usesEarlyAsr, "Hanafi should not use early Asr (uses 2x shadow)")
        XCTAssertTrue(Madhab.shafi.usesEarlyAsr, "Shafi should use early Asr (uses 1x shadow)")
        XCTAssertTrue(Madhab.jafari.usesEarlyAsr, "Ja'fari should use early Asr (uses 1x shadow)")
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
