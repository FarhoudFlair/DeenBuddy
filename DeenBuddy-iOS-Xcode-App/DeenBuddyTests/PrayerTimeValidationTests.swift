//
//  PrayerTimeValidationTests.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-11.
//

import XCTest
import CoreLocation
import Combine
@testable import DeenBuddy

/// Validation tests for prayer time accuracy across different calculation methods and real locations
class PrayerTimeValidationTests: XCTestCase {
    
    // MARK: - Properties
    
    private var settingsService: PrayerValidationMockSettingsService!
    private var locationService: PrayerValidationMockLocationService!
    private var apiClient: MockAPIClient!
    private var prayerTimeService: PrayerTimeService!
    
    // Test locations with known prayer times for validation
    private let testLocations = [
        TestLocation(name: "New York", latitude: 40.7128, longitude: -74.0060),
        TestLocation(name: "Mecca", latitude: 21.4225, longitude: 39.8262),
        TestLocation(name: "London", latitude: 51.5074, longitude: -0.1278),
        TestLocation(name: "Jakarta", latitude: -6.2088, longitude: 106.8456),
        TestLocation(name: "Cairo", latitude: 30.0444, longitude: 31.2357)
    ]
    
    // MARK: - Setup & Teardown
    
    @MainActor
    override func setUp() {
        super.setUp()
        
        // Create mock services
        settingsService = PrayerValidationMockSettingsService()
        locationService = PrayerValidationMockLocationService()
        apiClient = MockAPIClient()

        // Create prayer time service
        prayerTimeService = PrayerTimeService(
            locationService: locationService,
            settingsService: settingsService,
            apiClient: apiClient,
            errorHandler: ErrorHandler(crashReporter: CrashReporter()),
            retryMechanism: RetryMechanism(networkMonitor: NetworkMonitor.shared),
            networkMonitor: NetworkMonitor.shared,
            islamicCacheManager: IslamicCacheManager()
        )
    }
    
    override func tearDown() {
        settingsService = nil
        locationService = nil
        apiClient = nil
        prayerTimeService = nil
        
        super.tearDown()
    }
    
    // MARK: - Real Location Validation Tests
    
    @MainActor
    func testPrayerTimesForNewYork() async throws {
        // Given: New York location and specific date
        let location = testLocations[0] // New York
        let testDate = createTestDate(year: 2024, month: 6, day: 21) // Summer solstice
        
        locationService.mockLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        // Test different calculation methods
        for method in CalculationMethod.allCases {
            await MainActor.run {
                settingsService.calculationMethod = method
            }

            // When: Prayer times are calculated
            await prayerTimeService.refreshPrayerTimes()

            // Then: Prayer times should be reasonable for New York
            let prayerTimes = await prayerTimeService.todaysPrayerTimes
            XCTAssertFalse(prayerTimes.isEmpty, "Prayer times should be calculated for \(method.rawValue)")

            // Validate prayer time ranges for New York in summer
            validatePrayerTimeRanges(prayerTimes, location: location, method: method, season: .summer)
        }
    }
    
    @MainActor
    func testPrayerTimesForMecca() async throws {
        // Given: Mecca location (should have consistent times across methods)
        let location = testLocations[1] // Mecca
        let testDate = createTestDate(year: 2024, month: 3, day: 20) // Spring equinox
        
        locationService.mockLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        // Test with Muslim World League method (most appropriate for Mecca)
        await MainActor.run {
            settingsService.calculationMethod = .muslimWorldLeague
        }
        
        // When: Prayer times are calculated
        await prayerTimeService.refreshPrayerTimes()
        
        // Then: Prayer times should be reasonable for Mecca
        let prayerTimes = await prayerTimeService.todaysPrayerTimes
        XCTAssertFalse(prayerTimes.isEmpty, "Prayer times should be calculated for Mecca")
        
        // Validate prayer time ranges for Mecca
        validatePrayerTimeRanges(prayerTimes, location: location, method: .muslimWorldLeague, season: .spring)
    }
    
    @MainActor
    func testMadhabDifferencesInAsrTime() async throws {
        // Given: Cairo location (good for testing madhab differences)
        let location = testLocations[4] // Cairo
        locationService.mockLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        await MainActor.run {
            settingsService.calculationMethod = .muslimWorldLeague

            // Test Shafi madhab
            settingsService.madhab = .shafi
        }
        await prayerTimeService.refreshPrayerTimes()
        let shafiPrayerTimes = await prayerTimeService.todaysPrayerTimes
        let shafiAsrTime = shafiPrayerTimes.first { $0.prayer == .asr }?.time
        
        // Test Hanafi madhab
        await MainActor.run {
            settingsService.madhab = .hanafi
        }
        await prayerTimeService.refreshPrayerTimes()
        let hanafiPrayerTimes = await prayerTimeService.todaysPrayerTimes
        let hanafiAsrTime = hanafiPrayerTimes.first { $0.prayer == .asr }?.time
        
        // Then: Hanafi Asr should be later than Shafi Asr
        XCTAssertNotNil(shafiAsrTime, "Shafi Asr time should be calculated")
        XCTAssertNotNil(hanafiAsrTime, "Hanafi Asr time should be calculated")
        
        if let shafiTime = shafiAsrTime, let hanafiTime = hanafiAsrTime {
            XCTAssertGreaterThan(hanafiTime, shafiTime, "Hanafi Asr should be later than Shafi Asr")
            
            // Difference should be reasonable (typically 30-90 minutes)
            let timeDifference = hanafiTime.timeIntervalSince(shafiTime)
            XCTAssertGreaterThan(timeDifference, 30 * 60, "Asr difference should be at least 30 minutes")
            XCTAssertLessThan(timeDifference, 90 * 60, "Asr difference should be less than 90 minutes")
        }
    }

    @MainActor
    func testJafariMadhabTimingDifferences() async throws {
        // Given: Tehran location (good for testing Ja'fari madhab)
        let tehranLocation = CLLocation(latitude: 35.6892, longitude: 51.3890)
        locationService.mockLocation = tehranLocation
        await MainActor.run {
            settingsService.calculationMethod = .muslimWorldLeague

            // Test Shafi madhab (baseline)
            settingsService.madhab = .shafi
        }
        await prayerTimeService.refreshPrayerTimes()
        let shafiPrayerTimes = await prayerTimeService.todaysPrayerTimes
        let shafiMaghribTime = shafiPrayerTimes.first { $0.prayer == .maghrib }?.time
        let shafiIshaTime = shafiPrayerTimes.first { $0.prayer == .isha }?.time

        // Test Ja'fari madhab
        await MainActor.run {
            settingsService.madhab = .jafari
        }
        await prayerTimeService.refreshPrayerTimes()
        let jafariPrayerTimes = await prayerTimeService.todaysPrayerTimes
        let jafariMaghribTime = jafariPrayerTimes.first { $0.prayer == .maghrib }?.time
        let jafariIshaTime = jafariPrayerTimes.first { $0.prayer == .isha }?.time

        // Then: Ja'fari Maghrib should be 4 minutes later than Shafi
        XCTAssertNotNil(shafiMaghribTime, "Shafi Maghrib time should be calculated")
        XCTAssertNotNil(jafariMaghribTime, "Ja'fari Maghrib time should be calculated")

        if let shafiTime = shafiMaghribTime, let jafariTime = jafariMaghribTime {
            let timeDifference = jafariTime.timeIntervalSince(shafiTime)
            // Ja'fari Maghrib should be approximately 4 minutes later
            XCTAssertGreaterThanOrEqual(timeDifference, 3.5 * 60, "Ja'fari Maghrib should be at least 3.5 minutes later")
            XCTAssertLessThanOrEqual(timeDifference, 4.5 * 60, "Ja'fari Maghrib should be at most 4.5 minutes later")
        }

        // And: Ja'fari Isha should be earlier than Shafi (due to different twilight angle)
        XCTAssertNotNil(shafiIshaTime, "Shafi Isha time should be calculated")
        XCTAssertNotNil(jafariIshaTime, "Ja'fari Isha time should be calculated")

        if let shafiTime = shafiIshaTime, let jafariTime = jafariIshaTime {
            // Ja'fari uses 14° vs Shafi 17°, so Isha should be earlier
            XCTAssertLessThan(jafariTime, shafiTime, "Ja'fari Isha should be earlier than Shafi Isha due to smaller twilight angle")
        }
    }

    @MainActor
    func testMadhabTimingProperties() {
        // Test Hanafi properties
        let hanafi = Madhab.hanafi
        XCTAssertEqual(hanafi.asrShadowMultiplier, 2.0, "Hanafi should use 2x shadow multiplier for Asr")
        XCTAssertEqual(hanafi.ishaTwilightAngle, 18.0, "Hanafi should use 18° twilight angle for Isha")
        XCTAssertEqual(hanafi.maghribDelayMinutes, 0.0, "Hanafi should not delay Maghrib")
        XCTAssertEqual(hanafi.fajrTwilightAngle, 18.0, "Hanafi should use 18° twilight angle for Fajr")

        // Test Shafi properties
        let shafi = Madhab.shafi
        XCTAssertEqual(shafi.asrShadowMultiplier, 1.0, "Shafi should use 1x shadow multiplier for Asr")
        XCTAssertEqual(shafi.ishaTwilightAngle, 17.0, "Shafi should use 17° twilight angle for Isha")
        XCTAssertEqual(shafi.maghribDelayMinutes, 0.0, "Shafi should not delay Maghrib")
        XCTAssertEqual(shafi.fajrTwilightAngle, 18.0, "Shafi should use 18° twilight angle for Fajr")

        // Test Ja'fari properties
        let jafari = Madhab.jafari
        XCTAssertEqual(jafari.asrShadowMultiplier, 1.0, "Ja'fari should use 1x shadow multiplier for Asr")
        XCTAssertEqual(jafari.ishaTwilightAngle, 14.0, "Ja'fari should use 14° twilight angle for Isha")
        XCTAssertEqual(jafari.maghribDelayMinutes, 4.0, "Ja'fari should delay Maghrib by 4 minutes")
        XCTAssertEqual(jafari.fajrTwilightAngle, 16.0, "Ja'fari should use 16° twilight angle for Fajr")

        // Test helper properties
        XCTAssertFalse(hanafi.usesEarlyAsr, "Hanafi should not use early Asr")
        XCTAssertTrue(shafi.usesEarlyAsr, "Shafi should use early Asr")
        XCTAssertTrue(jafari.usesEarlyAsr, "Ja'fari should use early Asr")

        XCTAssertFalse(hanafi.delaysMaghrib, "Hanafi should not delay Maghrib")
        XCTAssertFalse(shafi.delaysMaghrib, "Shafi should not delay Maghrib")
        XCTAssertTrue(jafari.delaysMaghrib, "Ja'fari should delay Maghrib")
    }

    @MainActor
    func testCalculationMethodDifferences() async throws {
        // Given: London location (good for testing method differences)
        let location = testLocations[2] // London
        locationService.mockLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        var methodResults: [CalculationMethod: [PrayerTime]] = [:]
        
        // Calculate prayer times for different methods
        for method in [CalculationMethod.muslimWorldLeague, .egyptian, .karachi] {
            await MainActor.run {
                settingsService.calculationMethod = method
            }
            await prayerTimeService.refreshPrayerTimes()
            methodResults[method] = await prayerTimeService.todaysPrayerTimes
        }
        
        // Then: Different methods should produce different times
        let mwlTimes = methodResults[.muslimWorldLeague]!
        let egyptianTimes = methodResults[.egyptian]!
        let karachiTimes = methodResults[.karachi]!
        
        // Compare Fajr times (should be different)
        let mwlFajr = mwlTimes.first { $0.prayer == .fajr }?.time
        let egyptianFajr = egyptianTimes.first { $0.prayer == .fajr }?.time
        let karachiFajr = karachiTimes.first { $0.prayer == .fajr }?.time
        
        XCTAssertNotNil(mwlFajr, "MWL Fajr should be calculated")
        XCTAssertNotNil(egyptianFajr, "Egyptian Fajr should be calculated")
        XCTAssertNotNil(karachiFajr, "Karachi Fajr should be calculated")
        
        // Times should be different (allowing for small variations)
        if let mwl = mwlFajr, let egyptian = egyptianFajr {
            let difference = abs(mwl.timeIntervalSince(egyptian))
            XCTAssertGreaterThan(difference, 60, "Fajr times should differ by at least 1 minute between methods")
        }
    }
    
    // MARK: - Edge Case Tests
    
    @MainActor
    func testHighLatitudeLocation() async throws {
        // Given: High latitude location (Oslo, Norway)
        let osloLocation = TestLocation(name: "Oslo", latitude: 59.9139, longitude: 10.7522)
        locationService.mockLocation = CLLocation(latitude: osloLocation.latitude, longitude: osloLocation.longitude)
        settingsService.calculationMethod = .muslimWorldLeague
        
        // Test summer solstice (extreme case)
        let summerDate = createTestDate(year: 2024, month: 6, day: 21)
        
        // When: Prayer times are calculated
        await prayerTimeService.refreshPrayerTimes()
        
        // Then: Prayer times should be calculated (may use special high-latitude rules)
        let prayerTimes = await prayerTimeService.todaysPrayerTimes
        XCTAssertFalse(prayerTimes.isEmpty, "Prayer times should be calculated even for high latitudes")
        
        // Validate that times are in logical order
        validatePrayerTimeOrder(prayerTimes)
    }
    
    @MainActor
    func testSouthernHemisphereLocation() async throws {
        // Given: Southern hemisphere location (Jakarta)
        let location = testLocations[3] // Jakarta
        locationService.mockLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        await MainActor.run {
            settingsService.calculationMethod = .muslimWorldLeague
        }
        
        // When: Prayer times are calculated
        await prayerTimeService.refreshPrayerTimes()
        
        // Then: Prayer times should be reasonable for southern hemisphere
        let prayerTimes = await prayerTimeService.todaysPrayerTimes
        XCTAssertFalse(prayerTimes.isEmpty, "Prayer times should be calculated for southern hemisphere")
        
        validatePrayerTimeOrder(prayerTimes)
        validatePrayerTimeRanges(prayerTimes, location: location, method: .muslimWorldLeague, season: .spring)
    }
    
    // MARK: - Performance Validation
    
    @MainActor
    func testPrayerTimeCalculationPerformance() async {
        // Given: Multiple locations and methods
        let location = testLocations[0] // New York
        locationService.mockLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        // When: Measuring calculation time
        let startTime = Date()
        
        for method in CalculationMethod.allCases {
            await MainActor.run {
                settingsService.calculationMethod = method
            }
            await prayerTimeService.refreshPrayerTimes()
        }
        
        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime)
        
        // Then: Total time should be reasonable
        XCTAssertLessThan(totalTime, 10.0, "Calculating prayer times for all methods should take less than 10 seconds")
    }
    
    // MARK: - Helper Methods
    
    private func validatePrayerTimeRanges(_ prayerTimes: [PrayerTime], location: TestLocation, method: CalculationMethod, season: Season) {
        for prayerTime in prayerTimes {
            let hour = Calendar.current.component(.hour, from: prayerTime.time)
            
            switch prayerTime.prayer {
            case .fajr:
                XCTAssertGreaterThanOrEqual(hour, 3, "Fajr should be after 3 AM")
                XCTAssertLessThanOrEqual(hour, 7, "Fajr should be before 7 AM")
            case .dhuhr:
                XCTAssertGreaterThanOrEqual(hour, 11, "Dhuhr should be after 11 AM")
                XCTAssertLessThanOrEqual(hour, 14, "Dhuhr should be before 2 PM")
            case .asr:
                XCTAssertGreaterThanOrEqual(hour, 13, "Asr should be after 1 PM")
                XCTAssertLessThanOrEqual(hour, 18, "Asr should be before 6 PM")
            case .maghrib:
                XCTAssertGreaterThanOrEqual(hour, 16, "Maghrib should be after 4 PM")
                XCTAssertLessThanOrEqual(hour, 21, "Maghrib should be before 9 PM")
            case .isha:
                XCTAssertGreaterThanOrEqual(hour, 18, "Isha should be after 6 PM")
                XCTAssertLessThanOrEqual(hour, 23, "Isha should be before 11 PM")
            }
        }
    }
    
    private func validatePrayerTimeOrder(_ prayerTimes: [PrayerTime]) {
        let sortedTimes = prayerTimes.sorted { $0.time < $1.time }
        let expectedOrder: [Prayer] = [.fajr, .dhuhr, .asr, .maghrib, .isha]
        
        for (index, prayer) in expectedOrder.enumerated() {
            if index < sortedTimes.count {
                XCTAssertEqual(sortedTimes[index].prayer, prayer, "Prayer times should be in correct order")
            }
        }
    }
    
    private func createTestDate(year: Int, month: Int, day: Int) -> Date {
        let calendar = Calendar.current
        let components = DateComponents(year: year, month: month, day: day, hour: 12, minute: 0, second: 0)
        return calendar.date(from: components) ?? Date()
    }
}

// MARK: - Supporting Types

struct TestLocation {
    let name: String
    let latitude: Double
    let longitude: Double
}

enum Season {
    case spring, summer, fall, winter
}

// MARK: - Mock Classes

@MainActor
class PrayerValidationMockSettingsService: SettingsServiceProtocol, ObservableObject {
    @Published var calculationMethod: CalculationMethod = .muslimWorldLeague
    @Published var madhab: Madhab = .shafi
    @Published var notificationsEnabled: Bool = true
    @Published var theme: ThemeMode = .dark
    @Published var timeFormat: TimeFormat = .twelveHour
    @Published var notificationOffset: TimeInterval = 300
    @Published var hasCompletedOnboarding: Bool = false
    @Published var userName: String = ""
    @Published var overrideBatteryOptimization: Bool = false
    @Published var showArabicSymbolInWidget: Bool = true

    var enableNotifications: Bool {
        get { notificationsEnabled }
        set { notificationsEnabled = newValue }
    }

    func saveSettings() async throws {}
    func loadSettings() async throws {}
    func resetToDefaults() async throws {}
    func saveImmediately() async throws {}
    func saveOnboardingSettings() async throws {}
}

@MainActor
class PrayerValidationMockLocationService: LocationServiceProtocol, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    @Published var currentLocation: CLLocation? = nil
    @Published var currentLocationInfo: LocationInfo? = nil
    @Published var isUpdatingLocation: Bool = false
    @Published var locationError: Error? = nil
    @Published var currentHeading: Double = 0
    @Published var headingAccuracy: Double = 5.0
    @Published var isUpdatingHeading: Bool = false

    var permissionStatus: CLAuthorizationStatus { authorizationStatus }

    private let locationSubject = PassthroughSubject<CLLocation, Error>()
    private let headingSubject = PassthroughSubject<CLHeading, Error>()

    var locationPublisher: AnyPublisher<CLLocation, Error> {
        locationSubject.eraseToAnyPublisher()
    }

    var headingPublisher: AnyPublisher<CLHeading, Error> {
        headingSubject.eraseToAnyPublisher()
    }

    var mockLocation: CLLocation? {
        get { currentLocation }
        set { currentLocation = newValue }
    }

    func requestLocationPermission() {}
    func requestLocationPermissionAsync() async -> CLAuthorizationStatus { return .authorizedWhenInUse }
    func requestLocation() async throws -> CLLocation {
        return currentLocation ?? CLLocation(latitude: 37.7749, longitude: -122.4194)
    }
    func startUpdatingLocation() {}
    func stopUpdatingLocation() {}
    func startBackgroundLocationUpdates() {}
    func stopBackgroundLocationUpdates() {}
    func startUpdatingHeading() {}
    func stopUpdatingHeading() {}
    func geocodeCity(_ cityName: String) async throws -> CLLocation {
        return CLLocation(latitude: 37.7749, longitude: -122.4194)
    }
    func searchCity(_ cityName: String) async throws -> [LocationInfo] { return [] }
    func getLocationInfo(for coordinate: LocationCoordinate) async throws -> LocationInfo {
        return LocationInfo(coordinate: coordinate, accuracy: 10.0, city: "Test", country: "Test")
    }
    func getCachedLocation() -> CLLocation? { return currentLocation }
    func isCachedLocationValid() -> Bool { return true }
    func getLocationPreferCached() async throws -> CLLocation { return try await requestLocation() }
    func isCurrentLocationFromCache() -> Bool { return false }
    func getLocationAge() -> TimeInterval? { return 30.0 }
}
