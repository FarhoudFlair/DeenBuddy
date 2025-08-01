import XCTest
import Combine
@testable import DeenBuddy
@testable import DeenAssistCore
@testable import DeenAssistProtocols

// MARK: - Test Location Helper

struct TestLocation {
    let name: String
    let latitude: Double
    let longitude: Double
}

// MARK: - Main Test Class

class PrayerTimeValidationTests: XCTestCase {
    var prayerTimeService: PrayerTimeService!
    private var settingsService: PrayerValidationMockSettingsService!
    private var locationService: PrayerValidationMockLocationService!
    private var apiClient: MockAPIClient!
    private var islamicCalendarService: PrayerValidationMockIslamicCalendarService!

    private let testLocations = [
        TestLocation(name: "New York", latitude: 40.7128, longitude: -74.0060),
        TestLocation(name: "Mecca", latitude: 21.4225, longitude: 39.8262),
        TestLocation(name: "London", latitude: 51.5074, longitude: -0.1278),
        TestLocation(name: "Jakarta", latitude: -6.2088, longitude: 106.8456),
        TestLocation(name: "Cairo", latitude: 30.0444, longitude: 31.2357)
    ]

    @MainActor
    override func setUp() {
        super.setUp()
        settingsService = PrayerValidationMockSettingsService()
        locationService = PrayerValidationMockLocationService()
        apiClient = MockAPIClient()
        islamicCalendarService = PrayerValidationMockIslamicCalendarService()
        prayerTimeService = PrayerTimeService(
            locationService: locationService,
            settingsService: settingsService,
            apiClient: apiClient,
            errorHandler: ErrorHandler(crashReporter: CrashReporter()),
            retryMechanism: RetryMechanism(networkMonitor: NetworkMonitor.shared),
            networkMonitor: NetworkMonitor.shared,
            islamicCacheManager: IslamicCacheManager(),
            islamicCalendarService: islamicCalendarService
        )
    }

    override func tearDown() {
        prayerTimeService = nil
        settingsService = nil
        locationService = nil
        apiClient = nil
        islamicCalendarService = nil
        super.tearDown()
    }

    // MARK: - Helper Functions

    private func date(from string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string) ?? Date()
    }

    private func validatePrayerTimesOrder(prayerTimes: [DeenAssistProtocols.PrayerTime], file: StaticString = #file, line: UInt = #line) {
        guard prayerTimes.count > 1 else {
            XCTFail("Not enough prayer times to validate order.", file: file, line: line)
            return
        }

        let sortedTimes = prayerTimes.sorted()
        XCTAssertEqual(prayerTimes, sortedTimes, "Prayer times are not in chronological order.", file: file, line: line)
    }

    // MARK: - Test Cases

    func testPrayerTimesForAllLocationsAndMethods() async throws {
        let calculationMethods = DeenAssistCore.CalculationMethod.allCases
        let testDate = date(from: "2024-05-15T12:00:00Z")

        for location in testLocations {
            locationService.mockedLocation = .init(latitude: location.latitude, longitude: location.longitude)

            for method in calculationMethods {
                settingsService.calculationMethod = method

                let prayerTimes = try await prayerTimeService.calculatePrayerTimes(for: locationService.mockedLocation, date: testDate)

                XCTAssertEqual(prayerTimes.count, 5, "Expected 5 prayer times for \(location.name) using \(method.displayName).")
                validatePrayerTimesOrder(prayerTimes: prayerTimes)
            }
        }
    }

    func testPrayerTimesForTehran() async throws {
        let tehran = TestLocation(name: "Tehran", latitude: 35.6892, longitude: 51.3890)
        locationService.mockedLocation = .init(latitude: tehran.latitude, longitude: tehran.longitude)
        settingsService.calculationMethod = .jafariTehran
        let testDate = date(from: "2024-05-15T12:00:00Z")

        let prayerTimes = try await prayerTimeService.calculatePrayerTimes(for: locationService.mockedLocation, date: testDate)

        XCTAssertEqual(prayerTimes.count, 5, "Expected 5 prayer times for Tehran.")
        validatePrayerTimesOrder(prayerTimes: prayerTimes)
    }

    func testPrayerTimesForNewYorkShafi() async throws {
        let newYork = TestLocation(name: "New York", latitude: 40.7128, longitude: -74.0060)
        locationService.mockedLocation = .init(latitude: newYork.latitude, longitude: newYork.longitude)
        settingsService.calculationMethod = .northAmerica
        settingsService.madhab = .shafi
        let testDate = date(from: "2024-05-15T12:00:00Z")

        let prayerTimes = try await prayerTimeService.calculatePrayerTimes(for: locationService.mockedLocation, date: testDate)

        XCTAssertEqual(prayerTimes.count, 5, "Expected 5 prayer times for New York (Shafi).")
        validatePrayerTimesOrder(prayerTimes: prayerTimes)
    }

    func testPrayerTimesForNewYorkHanafi() async throws {
        let newYork = TestLocation(name: "New York", latitude: 40.7128, longitude: -74.0060)
        locationService.mockedLocation = .init(latitude: newYork.latitude, longitude: newYork.longitude)
        settingsService.calculationMethod = .northAmerica
        settingsService.madhab = .hanafi
        let testDate = date(from: "2024-05-15T12:00:00Z")

        let prayerTimes = try await prayerTimeService.calculatePrayerTimes(for: locationService.mockedLocation, date: testDate)

        XCTAssertEqual(prayerTimes.count, 5, "Expected 5 prayer times for New York (Hanafi).")
        validatePrayerTimesOrder(prayerTimes: prayerTimes)
    }
}

// MARK: - Mock Services

private class PrayerValidationMockSettingsService: SettingsServiceProtocol {
    var calculationMethod: DeenAssistCore.CalculationMethod = .northAmerica
    var madhab: DeenAssistCore.Madhab = .shafi
    var highLatitudeRule: DeenAssistCore.HighLatitudeRule = .middleOfTheNight
    var notificationSettings: DeenAssistProtocols.NotificationSettings = .default
    var onboardingCompleted: Bool = true
    var activeTheme: String = "Default"
    var language: String = "en"

    func saveSettings() async { }
    func loadSettings() async { }
    func resetSettings() async { }
}

private class PrayerValidationMockLocationService: LocationServiceProtocol {
    var authorizationStatus: DeenAssistCore.LocationAuthorizationStatus = .authorized
    var currentLocation: DeenAssistCore.LocationCoordinate? = .init(latitude: 0, longitude: 0)
    var currentHeading: Double? = 0
    var lastKnownLocation: DeenAssistCore.LocationCoordinate? = .init(latitude: 0, longitude: 0)
    var mockedLocation: DeenAssistCore.LocationCoordinate = .init(latitude: 0, longitude: 0)

    func requestLocationPermission() { }
    func startUpdatingLocation() { }
    func stopUpdatingLocation() { }
    func fetchAndGeocodeCurrentLocation() async throws -> (DeenAssistCore.LocationCoordinate, String?) { return (mockedLocation, nil) }
    func getCachedLocation() -> DeenAssistCore.LocationCoordinate? { return mockedLocation }
    func reverseGeocode(location: DeenAssistCore.LocationCoordinate) async -> String? { return nil }
}

private class PrayerValidationMockIslamicCalendarService: IslamicCalendarServiceProtocol {
    func getIslamicDate(for date: Date, using settings: DeenAssistProtocols.SettingsServiceProtocol) async -> DeenAssistCore.IslamicDate {
        return .init(day: 1, month: .muharram, year: 1445, gregorianDate: date)
    }
}

// MARK: - Comparable Extension for Testing

extension DeenAssistProtocols.PrayerTime: Comparable {
    public static func < (lhs: DeenAssistProtocols.PrayerTime, rhs: DeenAssistProtocols.PrayerTime) -> Bool {
        return lhs.time < rhs.time
    }
}
