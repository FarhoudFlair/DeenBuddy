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
        mockLocationService.currentLocation = CLLocation(latitude: 21.4225, longitude: 39.8262)
        
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
        setupPrayerTimeCalculation(method: .ummAlQura, madhab: .shafi, isRamadan: true)

        // When: Prayer times are calculated
        let location = CLLocation(latitude: 21.4225, longitude: 39.8262) // Mecca
        guard let prayerTimes = try await calculatePrayerTimes(for: Date(), location: location) else {
            XCTFail("Failed to calculate prayer times")
            return
        }

        // Then: Isha should be calculated with 120-minute interval (Ramadan override)
        verifyMaghribIshaInterval(prayerTimes, expectedMinInterval: 120)
    }
    
    func testUmmAlQuraNonRamadanIshaInterval() async throws {
        // Given: Umm Al-Qura method outside Ramadan
        setupPrayerTimeCalculation(method: .ummAlQura, madhab: .shafi, isRamadan: false)

        // When: Prayer times are calculated
        let location = CLLocation(latitude: 21.4225, longitude: 39.8262) // Mecca
        guard let prayerTimes = try await calculatePrayerTimes(for: Date(), location: location) else {
            XCTFail("Failed to calculate prayer times")
            return
        }

        // Then: Isha should be calculated with 90-minute interval (normal)
        verifyMaghribIshaInterval(prayerTimes, expectedMinInterval: 90)
    }
    
    func testQatarRamadanIshaOverride() async throws {
        // Given: Qatar method during Ramadan
        setupPrayerTimeCalculation(method: .qatar, madhab: .shafi, isRamadan: true)

        // When: Prayer times are calculated
        let location = CLLocation(latitude: 25.2854, longitude: 51.5310) // Doha
        guard let prayerTimes = try await calculatePrayerTimes(for: Date(), location: location) else {
            XCTFail("Failed to calculate prayer times")
            return
        }

        // Then: Isha should be calculated with 120-minute interval (Ramadan override)
        verifyMaghribIshaInterval(prayerTimes, expectedMinInterval: 120)

        // Additional verification: Compare with non-Ramadan calculation to demonstrate override
        setupPrayerTimeCalculation(method: .qatar, madhab: .shafi, isRamadan: false)
        guard let nonRamadanPrayerTimes = try await calculatePrayerTimes(for: Date(), location: location) else {
            XCTFail("Failed to calculate non-Ramadan prayer times")
            return
        }

        // Verify that Ramadan Isha time differs from non-Ramadan Isha time
        guard let ramadanIsha = prayerTimes.first(where: { $0.prayer == .isha })?.time,
              let nonRamadanIsha = nonRamadanPrayerTimes.first(where: { $0.prayer == .isha })?.time else {
            XCTFail("Isha times should be available for both scenarios")
            return
        }

        XCTAssertNotEqual(ramadanIsha.timeIntervalSince1970, nonRamadanIsha.timeIntervalSince1970, accuracy: 60,
                         "Ramadan Isha time should differ from non-Ramadan Isha time for Qatar method")
    }
    
    func testOtherMethodsNotAffectedByRamadan() async throws {
        // Given: Muslim World League method during Ramadan (should not be affected)
        setupPrayerTimeCalculation(method: .muslimWorldLeague, madhab: .shafi, isRamadan: true)

        // When: Prayer times are calculated for both Ramadan and non-Ramadan
        let location = CLLocation(latitude: 21.4225, longitude: 39.8262) // Mecca
        let ramadanPrayerTimes = try await calculatePrayerTimes(for: Date(), location: location)

        setupPrayerTimeCalculation(method: .muslimWorldLeague, madhab: .shafi, isRamadan: false)
        let nonRamadanPrayerTimes = try await calculatePrayerTimes(for: Date(), location: location)

        // Then: Isha should be calculated using twilight angle, not fixed interval
        XCTAssertNotNil(ramadanPrayerTimes, "Ramadan prayer times should be calculated")
        XCTAssertNotNil(nonRamadanPrayerTimes, "Non-Ramadan prayer times should be calculated")

        // Muslim World League uses twilight angles, not fixed intervals
        // So Ramadan should not affect the calculation - times should be identical
        guard let ramadanIsha = ramadanPrayerTimes?.first(where: { $0.prayer == .isha })?.time,
              let nonRamadanIsha = nonRamadanPrayerTimes?.first(where: { $0.prayer == .isha })?.time else {
            XCTFail("Isha times should be available for both scenarios")
            return
        }

        // Times should be nearly identical (within 1 second tolerance for calculation precision)
        XCTAssertEqual(ramadanIsha.timeIntervalSince1970, nonRamadanIsha.timeIntervalSince1970, accuracy: 1.0,
                      "Isha time should not be affected by Ramadan for twilight-angle based methods")
    }

    // MARK: - Helper Functions

    /**
     * Configures the settings service and mocks the Ramadan status for prayer time calculation
     * - Parameters:
     *   - method: The calculation method to use
     *   - madhab: The madhab to use for Asr calculation
     *   - isRamadan: Whether to simulate Ramadan period
     */
    private func setupPrayerTimeCalculation(method: CalculationMethod, madhab: Madhab, isRamadan: Bool) {
        mockSettingsService.calculationMethod = method
        mockSettingsService.madhab = madhab
        mockIslamicCalendarService.mockIsRamadan = isRamadan
    }

    /**
     * Validates the time difference between Maghrib and Isha prayers
     * - Parameters:
     *   - prayerTimes: Array of prayer times to validate
     *   - expectedMinInterval: Expected interval in minutes between Maghrib and Isha
     *   - tolerance: Tolerance in seconds for time comparison (default: 60 seconds)
     *     Reduced from 120 to 60 seconds based on Adhan library's precision requirements.
     *     The Adhan library provides minute-level accuracy, so 1-minute tolerance is appropriate
     *     for Islamic prayer time calculations while accounting for floating-point precision.
     */
    private func verifyMaghribIshaInterval(_ prayerTimes: [PrayerTime], expectedMinInterval: TimeInterval, tolerance: TimeInterval = 60) {
        guard let maghribTime = prayerTimes.first(where: { $0.prayer == .maghrib })?.time,
              let ishaTime = prayerTimes.first(where: { $0.prayer == .isha })?.time else {
            XCTFail("Maghrib and Isha times should be available")
            return
        }

        let interval = ishaTime.timeIntervalSince(maghribTime)
        let intervalMinutes = interval / 60

        XCTAssertEqual(intervalMinutes, expectedMinInterval, accuracy: tolerance / 60,
                      "Isha should be \(expectedMinInterval) minutes after Maghrib")
    }

    /**
     * Encapsulates the prayer time calculation logic with proper error handling
     * - Parameters:
     *   - date: Date for which to calculate prayer times
     *   - location: Location for prayer time calculation
     * - Returns: Array of prayer times or nil if calculation fails
     */
    private func calculatePrayerTimes(for date: Date, location: CLLocation) async throws -> [PrayerTime]? {
        let prayerTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: date)
        XCTAssertFalse(prayerTimes.isEmpty, "Prayer times should be calculated successfully")
        return prayerTimes.isEmpty ? nil : prayerTimes
    }
}

// MARK: - Mock Services
// Note: Using shared MockIslamicCalendarService from other test files to avoid duplication
