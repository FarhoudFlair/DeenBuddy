import XCTest
import CoreLocation
@testable import DeenBuddy

private typealias CalculationMethod = DeenBuddy.CalculationMethod
private typealias Madhab = DeenBuddy.Madhab
private typealias PrayerTime = DeenBuddy.PrayerTime

/// Test-only comparator for prayer times using coordinate-based location comparison
fileprivate func prayerTimesAreEqual(_ lhs: DeenBuddy.PrayerTime, _ rhs: DeenBuddy.PrayerTime) -> Bool {
    guard lhs.prayer == rhs.prayer && lhs.time == rhs.time else { return false }
    
    // Compare locations by coordinates instead of object identity
    switch (lhs.location, rhs.location) {
    case (nil, nil):
        return true
    case (let lhsLoc?, let rhsLoc?):
        return lhsLoc.coordinate.latitude == rhsLoc.coordinate.latitude &&
               lhsLoc.coordinate.longitude == rhsLoc.coordinate.longitude
    default:
        return false
    }
}

// MARK: - Test Location Helper

struct TestLocation {
    let name: String
    let latitude: Double
    let longitude: Double
}

// MARK: - Main Test Class

@MainActor
final class PrayerTimeValidationTests: XCTestCase {
    var prayerTimeService: PrayerTimeService!
    private var settingsService: MockSettingsService!
    private var locationService: Phase1MockLocationService!
    private var apiClient: MockAPIClient!
    private var islamicCalendarService: MockIslamicCalendarService!

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
        settingsService = MockSettingsService()
        locationService = Phase1MockLocationService()
        apiClient = MockAPIClient()
        islamicCalendarService = MockIslamicCalendarService()
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

    private func validatePrayerTimesOrder(prayerTimes: [PrayerTime], file: StaticString = #file, line: UInt = #line) {
        guard prayerTimes.count > 1 else {
            XCTFail("Not enough prayer times to validate order.", file: file, line: line)
            return
        }

        let sortedTimes = prayerTimes.sorted { $0.time < $1.time }
        
        // Compare arrays element-by-element using coordinate-based comparison
        guard prayerTimes.count == sortedTimes.count else {
            XCTFail("Prayer times and sorted times have different counts.", file: file, line: line)
            return
        }
        
        for (index, (original, sorted)) in zip(prayerTimes, sortedTimes).enumerated() {
            if !prayerTimesAreEqual(original, sorted) {
                XCTFail("Prayer times are not in chronological order at index \(index). Expected \(sorted.prayer.displayName) at \(sorted.time), but got \(original.prayer.displayName) at \(original.time).", file: file, line: line)
                return
            }
        }
    }

    private func makeCLLocation(from location: TestLocation) -> CLLocation {
        CLLocation(latitude: location.latitude, longitude: location.longitude)
    }

    // MARK: - Test Cases

    func testPrayerTimesForAllLocationsAndMethods() async throws {
        let calculationMethods = CalculationMethod.allCases
        let testDate = date(from: "2024-05-15T12:00:00Z")

        for location in testLocations {
            let clLocation = makeCLLocation(from: location)
            locationService.currentLocation = clLocation

            for method in calculationMethods {
                settingsService.calculationMethod = method

                let prayerTimes = try await prayerTimeService.calculatePrayerTimes(
                    for: clLocation,
                    date: testDate
                )

                XCTAssertEqual(prayerTimes.count, 5, "Expected 5 prayer times for \(location.name) using \(method.displayName).")
                validatePrayerTimesOrder(prayerTimes: prayerTimes)
            }
        }
    }

    func testPrayerTimesForTehran() async throws {
        let tehran = TestLocation(name: "Tehran", latitude: 35.6892, longitude: 51.3890)
        let clLocation = makeCLLocation(from: tehran)
        locationService.currentLocation = clLocation
        settingsService.calculationMethod = .jafariTehran
        let testDate = date(from: "2024-05-15T12:00:00Z")

        let prayerTimes = try await prayerTimeService.calculatePrayerTimes(
            for: clLocation,
            date: testDate
        )

        XCTAssertEqual(prayerTimes.count, 5, "Expected 5 prayer times for Tehran.")
        validatePrayerTimesOrder(prayerTimes: prayerTimes)
    }

    func testPrayerTimesForNewYorkShafi() async throws {
        let newYork = TestLocation(name: "New York", latitude: 40.7128, longitude: -74.0060)
        let clLocation = makeCLLocation(from: newYork)
        locationService.currentLocation = clLocation
        settingsService.calculationMethod = .northAmerica
        settingsService.madhab = .shafi
        let testDate = date(from: "2024-05-15T12:00:00Z")

        let prayerTimes = try await prayerTimeService.calculatePrayerTimes(
            for: clLocation,
            date: testDate
        )

        XCTAssertEqual(prayerTimes.count, 5, "Expected 5 prayer times for New York (Shafi).")
        validatePrayerTimesOrder(prayerTimes: prayerTimes)
    }

    func testPrayerTimesForNewYorkHanafi() async throws {
        let newYork = TestLocation(name: "New York", latitude: 40.7128, longitude: -74.0060)
        let clLocation = makeCLLocation(from: newYork)
        locationService.currentLocation = clLocation
        settingsService.calculationMethod = .northAmerica
        settingsService.madhab = .hanafi
        let testDate = date(from: "2024-05-15T12:00:00Z")

        let prayerTimes = try await prayerTimeService.calculatePrayerTimes(
            for: clLocation,
            date: testDate
        )

        XCTAssertEqual(prayerTimes.count, 5, "Expected 5 prayer times for New York (Hanafi).")
        validatePrayerTimesOrder(prayerTimes: prayerTimes)
    }
}
