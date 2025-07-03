import XCTest
import CoreLocation
@testable import DeenAssist

final class PrayerTimeCalculatorTests: XCTestCase {
    
    var calculator: PrayerTimeCalculator!
    var mockDataManager: MockDataManager!
    
    override func setUpWithError() throws {
        mockDataManager = MockDataManager()
        calculator = PrayerTimeCalculator(dataManager: mockDataManager)
    }
    
    override func tearDownWithError() throws {
        calculator = nil
        mockDataManager = nil
    }
    
    // MARK: - Test Data
    
    struct TestCity {
        let name: String
        let latitude: Double
        let longitude: Double
        let timeZone: TimeZone
    }
    
    private let testCities = [
        TestCity(name: "New York", latitude: 40.7128, longitude: -74.0060, timeZone: TimeZone(identifier: "America/New_York")!),
        TestCity(name: "London", latitude: 51.5074, longitude: -0.1278, timeZone: TimeZone(identifier: "Europe/London")!),
        TestCity(name: "Mecca", latitude: 21.4225, longitude: 39.8262, timeZone: TimeZone(identifier: "Asia/Riyadh")!),
        TestCity(name: "Istanbul", latitude: 41.0082, longitude: 28.9784, timeZone: TimeZone(identifier: "Europe/Istanbul")!),
        TestCity(name: "Jakarta", latitude: -6.2088, longitude: 106.8456, timeZone: TimeZone(identifier: "Asia/Jakarta")!),
        TestCity(name: "Cairo", latitude: 30.0444, longitude: 31.2357, timeZone: TimeZone(identifier: "Africa/Cairo")!),
        TestCity(name: "Karachi", latitude: 24.8607, longitude: 67.0011, timeZone: TimeZone(identifier: "Asia/Karachi")!),
        TestCity(name: "Dubai", latitude: 25.2048, longitude: 55.2708, timeZone: TimeZone(identifier: "Asia/Dubai")!),
        TestCity(name: "Kuala Lumpur", latitude: 3.1390, longitude: 101.6869, timeZone: TimeZone(identifier: "Asia/Kuala_Lumpur")!),
        TestCity(name: "Tehran", latitude: 35.6892, longitude: 51.3890, timeZone: TimeZone(identifier: "Asia/Tehran")!),
        TestCity(name: "Sydney", latitude: -33.8688, longitude: 151.2093, timeZone: TimeZone(identifier: "Australia/Sydney")!),
        TestCity(name: "Toronto", latitude: 43.6532, longitude: -79.3832, timeZone: TimeZone(identifier: "America/Toronto")!),
        TestCity(name: "Los Angeles", latitude: 34.0522, longitude: -118.2437, timeZone: TimeZone(identifier: "America/Los_Angeles")!),
        TestCity(name: "Paris", latitude: 48.8566, longitude: 2.3522, timeZone: TimeZone(identifier: "Europe/Paris")!),
        TestCity(name: "Tokyo", latitude: 35.6762, longitude: 139.6503, timeZone: TimeZone(identifier: "Asia/Tokyo")!)
    ]
    
    // MARK: - Basic Calculation Tests
    
    func testPrayerTimeCalculationForMultipleCities() throws {
        let testDate = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 15))!
        
        for city in testCities {
            let config = PrayerCalculationConfig(
                calculationMethod: .muslimWorldLeague,
                madhab: .shafi,
                location: CLLocationCoordinate2D(latitude: city.latitude, longitude: city.longitude),
                timeZone: city.timeZone
            )
            
            let prayerTimes = try calculator.calculatePrayerTimes(for: testDate, config: config)
            
            // Verify all prayer times are valid
            XCTAssertEqual(prayerTimes.date, testDate, "Prayer times date should match input date for \(city.name)")
            XCTAssertEqual(prayerTimes.calculationMethod, CalculationMethod.muslimWorldLeague.rawValue, "Calculation method should match for \(city.name)")
            
            // Verify prayer times are in chronological order
            XCTAssertLessThan(prayerTimes.fajr, prayerTimes.dhuhr, "Fajr should be before Dhuhr in \(city.name)")
            XCTAssertLessThan(prayerTimes.dhuhr, prayerTimes.asr, "Dhuhr should be before Asr in \(city.name)")
            XCTAssertLessThan(prayerTimes.asr, prayerTimes.maghrib, "Asr should be before Maghrib in \(city.name)")
            XCTAssertLessThan(prayerTimes.maghrib, prayerTimes.isha, "Maghrib should be before Isha in \(city.name)")
            
            print("✓ \(city.name): Fajr \(formatTime(prayerTimes.fajr)), Dhuhr \(formatTime(prayerTimes.dhuhr)), Asr \(formatTime(prayerTimes.asr)), Maghrib \(formatTime(prayerTimes.maghrib)), Isha \(formatTime(prayerTimes.isha))")
        }
    }
    
    func testDifferentCalculationMethods() throws {
        let testDate = Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 15))!
        let newYork = testCities.first { $0.name == "New York" }!
        
        for method in CalculationMethod.allCases {
            let config = PrayerCalculationConfig(
                calculationMethod: method,
                madhab: .shafi,
                location: CLLocationCoordinate2D(latitude: newYork.latitude, longitude: newYork.longitude),
                timeZone: newYork.timeZone
            )
            
            let prayerTimes = try calculator.calculatePrayerTimes(for: testDate, config: config)
            
            XCTAssertEqual(prayerTimes.calculationMethod, method.rawValue, "Calculation method should match for \(method.displayName)")
            
            // Verify prayer times are reasonable (not in the past or too far in the future)
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: testDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            XCTAssertGreaterThanOrEqual(prayerTimes.fajr, startOfDay, "Fajr should be after start of day for \(method.displayName)")
            XCTAssertLessThan(prayerTimes.isha, endOfDay, "Isha should be before end of day for \(method.displayName)")
        }
    }
    
    func testDifferentMadhabs() throws {
        let testDate = Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 15))!
        let istanbul = testCities.first { $0.name == "Istanbul" }!
        
        var shafiAsrTime: Date?
        var hanafiAsrTime: Date?
        
        for madhab in Madhab.allCases {
            let config = PrayerCalculationConfig(
                calculationMethod: .muslimWorldLeague,
                madhab: madhab,
                location: CLLocationCoordinate2D(latitude: istanbul.latitude, longitude: istanbul.longitude),
                timeZone: istanbul.timeZone
            )
            
            let prayerTimes = try calculator.calculatePrayerTimes(for: testDate, config: config)
            
            if madhab == .shafi {
                shafiAsrTime = prayerTimes.asr
            } else {
                hanafiAsrTime = prayerTimes.asr
            }
        }
        
        // Hanafi Asr time should typically be later than Shafi Asr time
        XCTAssertNotNil(shafiAsrTime, "Shafi Asr time should be calculated")
        XCTAssertNotNil(hanafiAsrTime, "Hanafi Asr time should be calculated")
        
        if let shafiTime = shafiAsrTime, let hanafiTime = hanafiAsrTime {
            XCTAssertLessThanOrEqual(shafiTime, hanafiTime, "Shafi Asr should be before or equal to Hanafi Asr")
        }
    }
    
    // MARK: - Caching Tests
    
    func testPrayerTimeCaching() throws {
        let testDate = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 15))!
        let config = PrayerCalculationConfig(
            calculationMethod: .muslimWorldLeague,
            madhab: .shafi,
            location: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            timeZone: TimeZone(identifier: "America/New_York")!
        )
        
        // First calculation should cache the result
        let prayerTimes1 = try calculator.calculatePrayerTimes(for: testDate, config: config)
        
        // Second call should return cached result
        let cachedTimes = calculator.getCachedPrayerTimes(for: testDate)
        
        XCTAssertNotNil(cachedTimes, "Prayer times should be cached")
        XCTAssertEqual(cachedTimes?.fajr, prayerTimes1.fajr, "Cached Fajr time should match")
        XCTAssertEqual(cachedTimes?.dhuhr, prayerTimes1.dhuhr, "Cached Dhuhr time should match")
        XCTAssertEqual(cachedTimes?.asr, prayerTimes1.asr, "Cached Asr time should match")
        XCTAssertEqual(cachedTimes?.maghrib, prayerTimes1.maghrib, "Cached Maghrib time should match")
        XCTAssertEqual(cachedTimes?.isha, prayerTimes1.isha, "Cached Isha time should match")
    }
    
    // MARK: - Next Prayer Tests
    
    func testGetNextPrayer() throws {
        let config = PrayerCalculationConfig(
            calculationMethod: .muslimWorldLeague,
            madhab: .shafi,
            location: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            timeZone: TimeZone(identifier: "America/New_York")!
        )
        
        let (nextPrayerName, nextPrayerTime) = try calculator.getNextPrayer(config: config)
        
        XCTAssertFalse(nextPrayerName.isEmpty, "Next prayer name should not be empty")
        XCTAssertGreaterThan(nextPrayerTime, Date(), "Next prayer time should be in the future")
        
        let validPrayerNames = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
        XCTAssertTrue(validPrayerNames.contains(nextPrayerName), "Next prayer name should be valid")
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidLocationHandling() {
        let invalidConfig = PrayerCalculationConfig(
            calculationMethod: .muslimWorldLeague,
            madhab: .shafi,
            location: CLLocationCoordinate2D(latitude: 200, longitude: 200), // Invalid coordinates
            timeZone: TimeZone.current
        )
        
        XCTAssertThrowsError(try calculator.calculatePrayerTimes(for: Date(), config: invalidConfig)) { error in
            XCTAssertTrue(error is PrayerCalculationError, "Should throw PrayerCalculationError")
            if case PrayerCalculationError.invalidLocation = error {
                // Expected error type
            } else {
                XCTFail("Should throw invalidLocation error")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
