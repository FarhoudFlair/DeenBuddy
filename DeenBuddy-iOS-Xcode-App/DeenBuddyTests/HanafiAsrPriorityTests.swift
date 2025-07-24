//
//  HanafiAsrPriorityTests.swift
//  DeenBuddyTests
//
//  Created by Farhoud Talebi on 2025-07-23.
//

import XCTest
import CoreLocation
import Adhan
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
        // Test with a simple case to understand the actual behavior
        let coordinates = Coordinates(latitude: 33.5731, longitude: -7.5898) // Casablanca - moderate latitude

        // Test with a fixed date to ensure consistent results
        var dateComponents = DateComponents()
        dateComponents.year = 2024
        dateComponents.month = 3  // March - equinox period for more moderate differences
        dateComponents.day = 21

        // Test Hanafi calculation
        var hanafiParams = Adhan.CalculationMethod.muslimWorldLeague.params
        hanafiParams.madhab = .hanafi

        guard let hanafiPrayerTimes = Adhan.PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: hanafiParams) else {
            XCTFail("Failed to calculate Hanafi prayer times")
            return
        }

        // Test Shafi calculation
        var shafiParams = Adhan.CalculationMethod.muslimWorldLeague.params
        shafiParams.madhab = .shafi

        guard let shafiPrayerTimes = Adhan.PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: shafiParams) else {
            XCTFail("Failed to calculate Shafi prayer times")
            return
        }

        let hanafiAsr = hanafiPrayerTimes.asr
        let shafiAsr = shafiPrayerTimes.asr
        let timeDifference = hanafiAsr.timeIntervalSince(shafiAsr)
        let minutesDifference = timeDifference / 60

        // Debug logging
        let formatter = DateFormatter()
        formatter.timeStyle = .medium

        print("🔍 ADHAN TEST - Casablanca:")
        print("   📍 Location: Casablanca (33.5731, -7.5898)")
        print("   📅 Date: March 21, 2024 (Equinox)")
        print("   🕐 Hanafi Asr: \(formatter.string(from: hanafiAsr))")
        print("   🕐 Shafi Asr: \(formatter.string(from: shafiAsr))")
        print("   ⏱️ Difference: \(timeDifference) seconds (\(minutesDifference) minutes)")

        // Core assertion - Hanafi should always be later than Shafi
        XCTAssertGreaterThan(hanafiAsr, shafiAsr, "Hanafi Asr should be later than Shafi Asr")

        // The difference can vary significantly based on location and date
        // Let's just ensure it's positive and reasonable (between 5 minutes and 2 hours)
        XCTAssertGreaterThan(minutesDifference, 5.0, "Hanafi Asr should be at least 5 minutes later")
        XCTAssertLessThan(minutesDifference, 120.0, "Hanafi Asr should not be more than 2 hours later")

        print("✅ Test passed: Hanafi Asr is \(Int(minutesDifference)) minutes later than Shafi Asr")
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
        
        // The difference should be consistent with madhab difference (varies by location and date)
        let timeDifference = hanafiAsrTime.timeIntervalSince(shafiAsrTime)
        let minutesDifference = timeDifference / 60
        XCTAssertGreaterThan(minutesDifference, 5.0, "Madhab difference should be at least 5 minutes")
        XCTAssertLessThan(minutesDifference, 120.0, "Madhab difference should not exceed 2 hours")

        print("✅ Custom method test: Hanafi Asr is \(Int(minutesDifference)) minutes later than Shafi Asr")
    }
    
    func testHanafiAsrPriorityWithAllCustomMethods() async throws {
        // Test that Hanafi madhab takes priority with all custom calculation methods
        let customMethods: [DeenBuddy.CalculationMethod] = [.jafariLeva, .jafariTehran, .fcnaCanada]
        
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
        let hanafi = DeenBuddy.Madhab.hanafi

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
                "Hanafi Asr should be later at location \(location.coordinate)")
        }
    }
    
    func testHanafiAsrPriorityDocumentation() async throws {
        // Test that the priority logic is properly documented in the madhab model
        let hanafi = Adhan.Madhab.hanafi
        
        // Verify that Hanafi is documented as using later Asr timing
        let appHanafi = DeenBuddy.Madhab.hanafi
        XCTAssertFalse(appHanafi.usesEarlyAsr, "Hanafi should not use early Asr (uses 2x shadow)")
        XCTAssertTrue(Madhab.shafi.usesEarlyAsr, "Shafi should use early Asr (uses 1x shadow)")
        XCTAssertTrue(Madhab.jafari.usesEarlyAsr, "Ja'fari should use early Asr (uses 1x shadow)")
    }
}

// MARK: - Mock Services
// Note: Using shared MockIslamicCalendarService from other test files to avoid duplication
