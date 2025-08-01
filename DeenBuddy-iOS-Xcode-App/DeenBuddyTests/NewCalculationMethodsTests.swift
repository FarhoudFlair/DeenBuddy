//
//  NewCalculationMethodsTests.swift
//  DeenBuddyTests
//
//  Created by Farhoud Talebi on 2025-07-23.
//

import XCTest
import CoreLocation
import Adhan
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
        let expectedTypes: Set<DeenBuddy.Prayer> = [.fajr, .dhuhr, .asr, .maghrib, .isha]
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
        let expectedTypes: Set<DeenBuddy.Prayer> = [.fajr, .dhuhr, .asr, .maghrib, .isha]
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
        let expectedTypes: Set<DeenBuddy.Prayer> = [.fajr, .dhuhr, .asr, .maghrib, .isha]
        XCTAssertEqual(prayerTypes, expectedTypes, "All prayer types should be present")
        
        // Verify times are in chronological order
        for i in 1..<prayerTimes.count {
            XCTAssertLessThan(prayerTimes[i-1].time, prayerTimes[i].time, "Prayer times should be in chronological order")
        }
    }
    
    func testJafariMethodsComparison() async throws {
        // Test that the two Ja'fari methods produce different results with STRICT validation

        let location = CLLocation(latitude: 35.6892, longitude: 51.3890) // Tehran, Iran
        let testDate = Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 15))! // Fixed date for consistency

        // Ensure we're using Jafari madhab for both tests
        mockSettingsService.madhab = .jafari

        // Debug: Verify custom parameters are different
        let levaParams = CalculationMethod.jafariLeva.customParameters()
        let tehranParams = CalculationMethod.jafariTehran.customParameters()

        XCTAssertNotNil(levaParams, "Leva method should have custom parameters")
        XCTAssertNotNil(tehranParams, "Tehran method should have custom parameters")
        XCTAssertEqual(levaParams?.fajrAngle, 16.0, "Leva method should use 16° Fajr angle")
        XCTAssertEqual(tehranParams?.fajrAngle, 17.7, "Tehran method should use 17.7° Fajr angle")
        XCTAssertNotEqual(levaParams?.fajrAngle, tehranParams?.fajrAngle, "Methods should have different Fajr angles")

        print("🔧 Leva custom params: Fajr=\(levaParams?.fajrAngle ?? -1)°, Isha=\(levaParams?.ishaAngle ?? -1)°")
        print("🔧 Tehran custom params: Fajr=\(tehranParams?.fajrAngle ?? -1)°, Isha=\(tehranParams?.ishaAngle ?? -1)°")

        // Calculate with Leva method (16°/14°)
        mockSettingsService.calculationMethod = .jafariLeva
        let levaTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: testDate)

        // Calculate with Tehran method (17.7°/14°)
        mockSettingsService.calculationMethod = .jafariTehran
        let tehranTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: testDate)

        // Verify both methods calculated times successfully
        XCTAssertEqual(levaTimes.count, 5, "Leva method should calculate 5 prayer times")
        XCTAssertEqual(tehranTimes.count, 5, "Tehran method should calculate 5 prayer times")

        // Find Fajr times for comparison
        guard let levaFajr = levaTimes.first(where: { $0.prayer == .fajr })?.time,
              let tehranFajr = tehranTimes.first(where: { $0.prayer == .fajr })?.time else {
            XCTFail("Both methods should calculate Fajr times")
            return
        }

        // Log the times for debugging
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .short
        print("🌅 Leva Fajr (16°): \(formatter.string(from: levaFajr))")
        print("🌅 Tehran Fajr (17.7°): \(formatter.string(from: tehranFajr))")

        // Calculate the difference
        let fajrDifference = tehranFajr.timeIntervalSince(levaFajr)
        let differenceMinutes = fajrDifference / 60
        print("⏰ Fajr difference: \(String(format: "%.2f", differenceMinutes)) minutes")

        // CORRECTED ASSERTION: Tehran (17.7°) MUST have EARLIER Fajr than Leva (16°)
        // Higher Fajr angle = sun needs to be further below horizon = EARLIER time
        XCTAssertLessThan(tehranFajr, levaFajr,
            "CRITICAL: Tehran IOG method (17.7°) MUST have EARLIER Fajr than Leva method (16°). " +
            "Tehran: \(formatter.string(from: tehranFajr)), Leva: \(formatter.string(from: levaFajr)). " +
            "Higher angle = earlier time is the correct Islamic calculation.")

        // The difference should be meaningful (at least 2 minutes for 1.7° difference, negative because Tehran is earlier)
        XCTAssertLessThan(fajrDifference, -120,
            "Fajr time difference should be at least 2 minutes earlier for 1.7° angle difference, got \(String(format: "%.2f", differenceMinutes)) minutes")

        // But not too extreme (should be less than 15 minutes for 1.7° difference, negative because Tehran is earlier)
        XCTAssertGreaterThan(fajrDifference, -900,
            "Fajr time difference should be less than 15 minutes earlier for 1.7° angle difference, got \(String(format: "%.2f", differenceMinutes)) minutes")

        print("✅ Tehran method correctly calculates earlier Fajr time (\(String(format: "%.2f", differenceMinutes)) minutes)")
    }

    func testJafariMethodsDetailedComparison() async throws {
        // Comprehensive test to verify both Fajr and Isha calculations are working correctly

        let location = CLLocation(latitude: 35.6892, longitude: 51.3890) // Tehran, Iran
        let testDate = Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 15))! // Fixed date

        mockSettingsService.madhab = .jafari

        // Test Leva method
        mockSettingsService.calculationMethod = .jafariLeva
        let levaTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: testDate)

        // Test Tehran method
        mockSettingsService.calculationMethod = .jafariTehran
        let tehranTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: testDate)

        // Extract all prayer times for comparison
        let levaFajr = levaTimes.first(where: { $0.prayer == .fajr })?.time
        let levaIsha = levaTimes.first(where: { $0.prayer == .isha })?.time
        let tehranFajr = tehranTimes.first(where: { $0.prayer == .fajr })?.time
        let tehranIsha = tehranTimes.first(where: { $0.prayer == .isha })?.time

        XCTAssertNotNil(levaFajr, "Leva method should calculate Fajr time")
        XCTAssertNotNil(levaIsha, "Leva method should calculate Isha time")
        XCTAssertNotNil(tehranFajr, "Tehran method should calculate Fajr time")
        XCTAssertNotNil(tehranIsha, "Tehran method should calculate Isha time")

        guard let lFajr = levaFajr, let lIsha = levaIsha,
              let tFajr = tehranFajr, let tIsha = tehranIsha else {
            XCTFail("All prayer times should be calculated")
            return
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .medium

        // Log all times for debugging
        print("📊 DETAILED COMPARISON:")
        print("   Leva (16°/14°):   Fajr: \(formatter.string(from: lFajr)), Isha: \(formatter.string(from: lIsha))")
        print("   Tehran (17.7°/14°): Fajr: \(formatter.string(from: tFajr)), Isha: \(formatter.string(from: tIsha))")

        // Calculate differences
        let fajrDiff = tFajr.timeIntervalSince(lFajr) / 60 // minutes
        let ishaDiff = tIsha.timeIntervalSince(lIsha) / 60 // minutes

        print("   Differences: Fajr: +\(String(format: "%.2f", fajrDiff))min, Isha: +\(String(format: "%.2f", ishaDiff))min")

        // CRITICAL ASSERTIONS:

        // 1. Fajr: Tehran (17.7°) should be EARLIER than Leva (16°)
        XCTAssertLessThan(tFajr, lFajr, "Tehran Fajr (17.7°) must be EARLIER than Leva Fajr (16°) - higher angle = earlier time")
        XCTAssertLessThan(fajrDiff, -1.0, "Fajr difference should be at least 1 minute earlier")

        // 2. Isha: Both use 14°, so they should be very close (within 1 minute)
        XCTAssertLessThan(abs(ishaDiff), 1.0, "Isha times should be nearly identical (both use 14°), difference: \(String(format: "%.2f", ishaDiff))min")

        // 3. Verify the methods are actually different
        XCTAssertNotEqual(lFajr, tFajr, "Fajr times must be different between methods")

        print("✅ Both methods calculate correctly with expected differences")
    }

    func testDebugJafariCalculation() async throws {
        // Debug test using REAL Adhan library calculation (not mock)

        let location = CLLocation(latitude: 35.6892, longitude: 51.3890) // Tehran, Iran
        let testDate = Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 15))!

        print("🔍 DEBUG: Testing Jafari calculation methods with REAL Adhan library")

        // Test 1: Verify custom parameters exist and are different
        let levaParams = DeenBuddy.CalculationMethod.jafariLeva.customParameters()
        let tehranParams = DeenBuddy.CalculationMethod.jafariTehran.customParameters()

        print("📋 Custom Parameters:")
        print("   Leva: Fajr=\(levaParams?.fajrAngle ?? -1)°, Isha=\(levaParams?.ishaAngle ?? -1)°, Madhab=\(levaParams?.madhab.rawValue ?? -1)")
        print("   Tehran: Fajr=\(tehranParams?.fajrAngle ?? -1)°, Isha=\(tehranParams?.ishaAngle ?? -1)°, Madhab=\(tehranParams?.madhab.rawValue ?? -1)")

        XCTAssertNotEqual(levaParams?.fajrAngle, tehranParams?.fajrAngle, "Custom parameters should be different")

        // Test 2: Calculate times using REAL Adhan library (bypass mock)
        let coordinates = Adhan.Coordinates(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: testDate)

        // Calculate with Leva parameters (16°/14°)
        guard var levaCalculationParams = levaParams else {
            XCTFail("Leva custom parameters should exist")
            return
        }

        // IMPORTANT: Set madhab to Jafari for proper Asr calculation
        levaCalculationParams.madhab = .shafi // Use Shafi as base (1x shadow) since Jafari uses 1x shadow like Shafi

        guard let levaAdhanTimes = Adhan.PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: levaCalculationParams) else {
            XCTFail("Failed to calculate Leva prayer times with Adhan library")
            return
        }

        // Calculate with Tehran parameters (17.7°/14°)
        guard var tehranCalculationParams = tehranParams else {
            XCTFail("Tehran custom parameters should exist")
            return
        }

        // IMPORTANT: Set madhab to Jafari for proper Asr calculation
        tehranCalculationParams.madhab = .shafi // Use Shafi as base (1x shadow) since Jafari uses 1x shadow like Shafi

        guard let tehranAdhanTimes = Adhan.PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: tehranCalculationParams) else {
            XCTFail("Failed to calculate Tehran prayer times with Adhan library")
            return
        }

        // Test 3: Compare results
        let levaFajr = levaAdhanTimes.fajr
        let tehranFajr = tehranAdhanTimes.fajr

        let formatter = DateFormatter()
        formatter.timeStyle = .medium

        print("🌅 REAL Calculated Times:")
        print("   Leva Fajr (16°): \(formatter.string(from: levaFajr))")
        print("   Tehran Fajr (17.7°): \(formatter.string(from: tehranFajr))")

        let difference = tehranFajr.timeIntervalSince(levaFajr) / 60
        print("   Difference: \(String(format: "%.2f", difference)) minutes")

        // Test 4: Verify they're different and in correct order
        XCTAssertNotEqual(levaFajr, tehranFajr, "Fajr times should be different between methods")
        XCTAssertLessThan(tehranFajr, levaFajr, "Tehran Fajr (17.7°) should be EARLIER than Leva Fajr (16°) - higher angle = earlier time")
        XCTAssertLessThan(difference, -1.0, "Difference should be at least 1 minute earlier")
        XCTAssertGreaterThan(difference, -15.0, "Difference should be less than 15 minutes earlier")

        print("✅ REAL calculation works correctly - Tehran is \(String(format: "%.2f", difference)) minutes earlier than Leva")
    }

    func testCustomParametersAreDifferent() {
        // Test to verify that customParameters() method returns different values

        print("🔍 TESTING: customParameters() method")

        let levaParams = DeenBuddy.CalculationMethod.jafariLeva.customParameters()
        let tehranParams = DeenBuddy.CalculationMethod.jafariTehran.customParameters()

        XCTAssertNotNil(levaParams, "Leva should have custom parameters")
        XCTAssertNotNil(tehranParams, "Tehran should have custom parameters")

        guard let leva = levaParams, let tehran = tehranParams else {
            XCTFail("Both methods should return custom parameters")
            return
        }

        print("📋 Custom Parameters Retrieved:")
        print("   Leva: Fajr=\(leva.fajrAngle)°, Isha=\(leva.ishaAngle)°, Madhab=\(leva.madhab.rawValue)")
        print("   Tehran: Fajr=\(tehran.fajrAngle)°, Isha=\(tehran.ishaAngle)°, Madhab=\(tehran.madhab.rawValue)")

        // Test that Fajr angles are different
        XCTAssertNotEqual(leva.fajrAngle, tehran.fajrAngle, "Fajr angles should be different")
        XCTAssertEqual(leva.fajrAngle, 16.0, "Leva should use 16.0° Fajr angle")
        XCTAssertEqual(tehran.fajrAngle, 17.7, "Tehran should use 17.7° Fajr angle")

        // Test that Isha angles are the same
        XCTAssertEqual(leva.ishaAngle, tehran.ishaAngle, "Isha angles should be the same")
        XCTAssertEqual(leva.ishaAngle, 14.0, "Both should use 14.0° Isha angle")
        XCTAssertEqual(tehran.ishaAngle, 14.0, "Both should use 14.0° Isha angle")

        // Check default madhab settings
        print("   Default Madhab Settings: Leva=\(leva.madhab.rawValue), Tehran=\(tehran.madhab.rawValue)")

        print("✅ Custom parameters are correctly different")
    }

    func testAdhanLibraryBaseParameters() {
        // Test to understand what Adhan.CalculationMethod.muslimWorldLeague.params returns by default

        print("🔍 TESTING: Adhan.CalculationMethod.muslimWorldLeague.params defaults (FIXED approach)")

        let baseParams = Adhan.CalculationMethod.muslimWorldLeague.params

        print("📋 Base Parameters from Adhan.CalculationMethod.muslimWorldLeague (FIXED approach):")
        print("   Fajr Angle: \(baseParams.fajrAngle)°")
        print("   Isha Angle: \(baseParams.ishaAngle)°")
        print("   Madhab: \(baseParams.madhab.rawValue)")
        print("   Method: \(baseParams.method.rawValue)")

        // Test creating two separate instances using FIXED approach
        var params1 = Adhan.CalculationMethod.muslimWorldLeague.params
        params1.method = .other
        params1.fajrAngle = 16.0
        params1.ishaAngle = 14.0

        var params2 = Adhan.CalculationMethod.muslimWorldLeague.params
        params2.method = .other
        params2.fajrAngle = 17.7
        params2.ishaAngle = 14.0

        print("📋 Modified Parameters:")
        print("   Params1: Fajr=\(params1.fajrAngle)°, Isha=\(params1.ishaAngle)°, Madhab=\(params1.madhab.rawValue)")
        print("   Params2: Fajr=\(params2.fajrAngle)°, Isha=\(params2.ishaAngle)°, Madhab=\(params2.madhab.rawValue)")

        XCTAssertNotEqual(params1.fajrAngle, params2.fajrAngle, "Parameters should be independent")

        print("✅ Adhan library base parameters work correctly")
    }

    func testRealPrayerTimeServiceCalculation() async throws {
        // Test the actual PrayerTimeService with real services (no mocks)

        print("🔍 TESTING: Real PrayerTimeService calculation")

        // Create real services (no mocks)
        let realSettingsService = SettingsService()
        let realLocationService = LocationService()
        let realCacheManager = IslamicCacheManager()

        // Create real PrayerTimeService with all required dependencies
        let realPrayerTimeService = PrayerTimeService(
            locationService: realLocationService,
            settingsService: realSettingsService,
            apiClient: MockAPIClient(), // Still use mock API to avoid network calls
            errorHandler: ErrorHandler(crashReporter: CrashReporter()),
            retryMechanism: RetryMechanism(networkMonitor: NetworkMonitor.shared),
            networkMonitor: NetworkMonitor.shared,
            islamicCacheManager: realCacheManager,
            islamicCalendarService: mockIslamicCalendarService // Use existing mock
        )

        let location = CLLocation(latitude: 35.6892, longitude: 51.3890) // Tehran, Iran
        let testDate = Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 15))!

        // Test with Leva method
        realSettingsService.calculationMethod = DeenBuddy.CalculationMethod.jafariLeva
        realSettingsService.madhab = DeenBuddy.Madhab.jafari
        let levaTimes = try await realPrayerTimeService.calculatePrayerTimes(
            for: location,
            date: testDate
        )

        // Test with Tehran method
        realSettingsService.calculationMethod = DeenBuddy.CalculationMethod.jafariTehran
        realSettingsService.madhab = DeenBuddy.Madhab.jafari
        let tehranTimes = try await realPrayerTimeService.calculatePrayerTimes(
            for: location,
            date: testDate
        )

        // Extract Fajr times from the arrays
        guard let levaFajr = levaTimes.first(where: { $0.prayer == .fajr })?.time,
              let tehranFajr = tehranTimes.first(where: { $0.prayer == .fajr })?.time else {
            XCTFail("Could not find Fajr times in results")
            return
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .medium

        print("🌅 REAL PrayerTimeService Results:")
        print("   Leva Fajr (16°): \(formatter.string(from: levaFajr))")
        print("   Tehran Fajr (17.7°): \(formatter.string(from: tehranFajr))")

        let difference = tehranFajr.timeIntervalSince(levaFajr) / 60
        print("   Difference: \(String(format: "%.2f", difference)) minutes")

        // Verify they're different and in correct order
        XCTAssertNotEqual(levaFajr, tehranFajr, "Fajr times should be different between methods")
        XCTAssertLessThan(tehranFajr, levaFajr, "Tehran Fajr (17.7°) should be EARLIER than Leva Fajr (16°) - higher angle = earlier time")
        XCTAssertLessThan(difference, -1.0, "Difference should be at least 1 minute earlier")
        XCTAssertGreaterThan(difference, -15.0, "Difference should be less than 15 minutes earlier")

        print("✅ REAL PrayerTimeService calculation works correctly - Tehran is \(String(format: "%.2f", difference)) minutes earlier than Leva")
    }

    func testDirectAdhanLibraryWithCustomParameters() throws {
        // Test the Adhan library directly with our custom parameters to isolate the issue

        print("🔍 TESTING: Direct Adhan library with custom parameters")

        let coordinates = Adhan.Coordinates(latitude: 35.6892, longitude: 51.3890) // Tehran, Iran
        let dateComponents = DateComponents(year: 2024, month: 6, day: 15)

        // Test with Leva parameters (16°, 14°) using ULTIMATE approach (different base methods)
        var levaParams = Adhan.CalculationMethod.egyptian.params  // Different base for independence
        levaParams.method = .other
        levaParams.fajrAngle = 16.0
        levaParams.ishaAngle = 14.0
        levaParams.madhab = .shafi // Ja'fari maps to Shafi in Adhan library

        // Test with Tehran parameters (17.7°, 14°) using ULTIMATE approach (different base methods)
        var tehranParams = Adhan.CalculationMethod.karachi.params  // Different base for independence
        tehranParams.method = .other
        tehranParams.fajrAngle = 17.7
        tehranParams.ishaAngle = 14.0
        tehranParams.madhab = .shafi // Ja'fari maps to Shafi in Adhan library

        // Calculate prayer times with both parameter sets
        guard let levaPrayerTimes = Adhan.PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: levaParams),
              let tehranPrayerTimes = Adhan.PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: tehranParams) else {
            XCTFail("Failed to calculate prayer times with Adhan library")
            return
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .medium

        print("🌅 DIRECT Adhan Library Results:")
        print("   Leva Fajr (16°): \(formatter.string(from: levaPrayerTimes.fajr))")
        print("   Tehran Fajr (17.7°): \(formatter.string(from: tehranPrayerTimes.fajr))")

        let difference = tehranPrayerTimes.fajr.timeIntervalSince(levaPrayerTimes.fajr) / 60
        print("   Difference: \(String(format: "%.2f", difference)) minutes")

        // Verify they're different and in correct order
        XCTAssertNotEqual(levaPrayerTimes.fajr, tehranPrayerTimes.fajr, "Fajr times should be different between methods")
        XCTAssertLessThan(tehranPrayerTimes.fajr, levaPrayerTimes.fajr, "Tehran Fajr (17.7°) should be EARLIER than Leva Fajr (16°) - higher angle = earlier time")
        XCTAssertLessThan(difference, -1.0, "Difference should be at least 1 minute earlier")
        XCTAssertGreaterThan(difference, -15.0, "Difference should be less than 15 minutes earlier")

        print("✅ DIRECT Adhan library works correctly - Tehran is \(String(format: "%.2f", difference)) minutes earlier than Leva")
    }

    func testSimpleAdhanLibraryDebug() throws {
        // Simple test to debug the Adhan library issue

        print("🔍 TESTING: Simple Adhan library debug")

        let coordinates = Adhan.Coordinates(latitude: 35.6892, longitude: 51.3890) // Tehran, Iran
        let dateComponents = DateComponents(year: 2024, month: 6, day: 15)

        // Test with basic parameters first
        let basicParams = Adhan.CalculationMethod.muslimWorldLeague.params

        guard let basicPrayerTimes = Adhan.PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: basicParams) else {
            print("❌ Failed to calculate basic prayer times")
            XCTFail("Failed to calculate basic prayer times with Adhan library")
            return
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .medium

        print("🌅 BASIC Adhan Library Results:")
        print("   Basic Fajr: \(formatter.string(from: basicPrayerTimes.fajr))")
        print("   Basic Dhuhr: \(formatter.string(from: basicPrayerTimes.dhuhr))")
        print("   Basic Asr: \(formatter.string(from: basicPrayerTimes.asr))")
        print("   Basic Maghrib: \(formatter.string(from: basicPrayerTimes.maghrib))")
        print("   Basic Isha: \(formatter.string(from: basicPrayerTimes.isha))")

        print("✅ Basic Adhan library test completed successfully")
    }

    func testPrayerTimeServiceDirectDebug() async throws {
        // Test the PrayerTimeService directly to see what's happening

        print("🔍 TESTING: PrayerTimeService direct debug")

        let location = CLLocation(latitude: 35.6892, longitude: 51.3890) // Tehran, Iran
        let testDate = Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 15))!

        // Test with Leva method
        mockSettingsService.calculationMethod = DeenBuddy.CalculationMethod.jafariLeva
        mockSettingsService.madhab = DeenBuddy.Madhab.jafari

        let levaTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: testDate)

        // Test with Tehran method
        mockSettingsService.calculationMethod = DeenBuddy.CalculationMethod.jafariTehran
        mockSettingsService.madhab = DeenBuddy.Madhab.jafari

        let tehranTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: testDate)

        // Extract Fajr times
        guard let levaFajr = levaTimes.first(where: { $0.prayer == .fajr })?.time,
              let tehranFajr = tehranTimes.first(where: { $0.prayer == .fajr })?.time else {
            XCTFail("Could not find Fajr times in results")
            return
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .medium

        print("🌅 PrayerTimeService Direct Results:")
        print("   Leva Fajr (16°): \(formatter.string(from: levaFajr))")
        print("   Tehran Fajr (17.7°): \(formatter.string(from: tehranFajr))")

        let difference = tehranFajr.timeIntervalSince(levaFajr) / 60
        print("   Difference: \(String(format: "%.2f", difference)) minutes")

        if abs(difference) < 0.1 {
            print("❌ PROBLEM CONFIRMED: Both methods produce identical results!")
            print("   This confirms the Tehran method is NOT working correctly")
        } else {
            print("✅ Methods produce different results as expected")
        }

        // Don't fail the test, just report the findings
        print("✅ PrayerTimeService direct debug completed")
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
        let allMethods = DeenBuddy.CalculationMethod.allCases

        XCTAssertTrue(allMethods.contains(.jafariLeva), "Ja'fari Leva should be in allCases")
        XCTAssertTrue(allMethods.contains(.jafariTehran), "Ja'fari Tehran should be in allCases")
        XCTAssertTrue(allMethods.contains(.fcnaCanada), "FCNA Canada should be in allCases")

        // Validate that all expected new methods are present (more maintainable than hardcoded count)
        let expectedNewMethods: [DeenBuddy.CalculationMethod] = [.jafariLeva, .jafariTehran, .fcnaCanada]
        let hasAllNewMethods = expectedNewMethods.allSatisfy { allMethods.contains($0) }
        XCTAssertTrue(hasAllNewMethods, "All expected new calculation methods should be included in allCases")
        
        // Ensure we have a reasonable number of methods (should be at least the new ones)
        XCTAssertGreaterThanOrEqual(allMethods.count, expectedNewMethods.count, "Should have at least the expected new calculation methods")
    }
}

// MARK: - Mock Services
// Note: Using shared MockIslamicCalendarService from other test files to avoid duplication
