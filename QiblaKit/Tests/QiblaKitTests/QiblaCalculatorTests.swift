import XCTest
import CoreLocation
@testable import QiblaKit

final class QiblaCalculatorTests: XCTestCase {
    
    // MARK: - Test Data
    
    struct TestLocation {
        let name: String
        let coordinate: CLLocationCoordinate2D
        let expectedDirection: Double
        let tolerance: Double
        
        init(name: String, latitude: Double, longitude: Double, expectedDirection: Double, tolerance: Double = 1.0) {
            self.name = name
            self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            self.expectedDirection = expectedDirection
            self.tolerance = tolerance
        }
    }
    
    let testLocations = [
        TestLocation(name: "New York", latitude: 40.7128, longitude: -74.0060, expectedDirection: 58.48),
        TestLocation(name: "London", latitude: 51.5074, longitude: -0.1278, expectedDirection: 118.99),
        TestLocation(name: "Tokyo", latitude: 35.6762, longitude: 139.6503, expectedDirection: 293.02),
        TestLocation(name: "Sydney", latitude: -33.8688, longitude: 151.2093, expectedDirection: 277.50),
        TestLocation(name: "Cairo", latitude: 30.0444, longitude: 31.2357, expectedDirection: 135.04),
        TestLocation(name: "Istanbul", latitude: 41.0082, longitude: 28.9784, expectedDirection: 147.93),
        TestLocation(name: "Jakarta", latitude: -6.2088, longitude: 106.8456, expectedDirection: 295.15),
        TestLocation(name: "Mumbai", latitude: 19.0760, longitude: 72.8777, expectedDirection: 261.74),
        TestLocation(name: "Kuala Lumpur", latitude: 3.1390, longitude: 101.6869, expectedDirection: 295.84),
        TestLocation(name: "Riyadh", latitude: 24.7136, longitude: 46.6753, expectedDirection: 240.91)
    ]
    
    // MARK: - Basic Calculation Tests
    
    func testQiblaCalculationAccuracy() {
        for location in testLocations {
            let result = QiblaCalculator.calculateQibla(from: location.coordinate)
            
            XCTAssertEqual(
                result.direction,
                location.expectedDirection,
                accuracy: location.tolerance,
                "Qibla direction for \(location.name) should be approximately \(location.expectedDirection)°"
            )
            
            XCTAssertGreaterThan(result.distance, 0, "Distance should be positive for \(location.name)")
            XCTAssertEqual(result.fromLocation.latitude, location.coordinate.latitude, accuracy: 0.0001)
            XCTAssertEqual(result.fromLocation.longitude, location.coordinate.longitude, accuracy: 0.0001)
        }
    }
    
    func testKaabaToKaabaCalculation() {
        let result = QiblaCalculator.calculateQibla(from: QiblaCalculator.kaabaCoordinate)
        
        // When calculating from Kaaba to Kaaba, distance should be very small
        XCTAssertLessThan(result.distance, 0.1, "Distance from Kaaba to itself should be near zero")
    }
    
    // MARK: - Bearing Calculation Tests
    
    func testBearingCalculation() {
        // Test North
        let north = QiblaCalculator.calculateBearing(
            from: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            to: CLLocationCoordinate2D(latitude: 1, longitude: 0)
        )
        XCTAssertEqual(north, 0, accuracy: 0.1, "Bearing due north should be 0°")
        
        // Test East
        let east = QiblaCalculator.calculateBearing(
            from: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            to: CLLocationCoordinate2D(latitude: 0, longitude: 1)
        )
        XCTAssertEqual(east, 90, accuracy: 0.1, "Bearing due east should be 90°")
        
        // Test South
        let south = QiblaCalculator.calculateBearing(
            from: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            to: CLLocationCoordinate2D(latitude: -1, longitude: 0)
        )
        XCTAssertEqual(south, 180, accuracy: 0.1, "Bearing due south should be 180°")
        
        // Test West
        let west = QiblaCalculator.calculateBearing(
            from: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            to: CLLocationCoordinate2D(latitude: 0, longitude: -1)
        )
        XCTAssertEqual(west, 270, accuracy: 0.1, "Bearing due west should be 270°")
    }
    
    // MARK: - Distance Calculation Tests
    
    func testDistanceCalculation() {
        // Test known distances
        let newYork = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let london = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        
        let distance = QiblaCalculator.calculateDistance(from: newYork, to: london)
        
        // Approximate distance between New York and London is ~5585 km
        XCTAssertEqual(distance, 5585, accuracy: 50, "Distance between New York and London should be approximately 5585 km")
    }
    
    func testZeroDistance() {
        let coordinate = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        let distance = QiblaCalculator.calculateDistance(from: coordinate, to: coordinate)
        
        XCTAssertEqual(distance, 0, accuracy: 0.001, "Distance from a point to itself should be zero")
    }
    
    // MARK: - Magnetic Declination Tests
    
    func testMagneticDeclinationCorrection() {
        let compassBearing = 45.0
        let magneticDeclination = 10.0
        
        let correctedBearing = QiblaCalculator.applyMagneticDeclination(
            compassBearing: compassBearing,
            magneticDeclination: magneticDeclination
        )
        
        XCTAssertEqual(correctedBearing, 55.0, "Corrected bearing should account for magnetic declination")
    }
    
    func testMagneticDeclinationWrapAround() {
        // Test positive wrap-around
        let correctedPositive = QiblaCalculator.applyMagneticDeclination(
            compassBearing: 350.0,
            magneticDeclination: 20.0
        )
        XCTAssertEqual(correctedPositive, 10.0, "Bearing should wrap around at 360°")
        
        // Test negative wrap-around
        let correctedNegative = QiblaCalculator.applyMagneticDeclination(
            compassBearing: 10.0,
            magneticDeclination: -20.0
        )
        XCTAssertEqual(correctedNegative, 350.0, "Bearing should wrap around at 0°")
    }
    
    // MARK: - Validation Tests
    
    func testCoordinateValidation() {
        // Valid coordinates
        XCTAssertTrue(QiblaCalculator.isValidCoordinate(CLLocationCoordinate2D(latitude: 0, longitude: 0)))
        XCTAssertTrue(QiblaCalculator.isValidCoordinate(CLLocationCoordinate2D(latitude: 90, longitude: 180)))
        XCTAssertTrue(QiblaCalculator.isValidCoordinate(CLLocationCoordinate2D(latitude: -90, longitude: -180)))
        
        // Invalid coordinates
        XCTAssertFalse(QiblaCalculator.isValidCoordinate(CLLocationCoordinate2D(latitude: 91, longitude: 0)))
        XCTAssertFalse(QiblaCalculator.isValidCoordinate(CLLocationCoordinate2D(latitude: 0, longitude: 181)))
        XCTAssertFalse(QiblaCalculator.isValidCoordinate(CLLocationCoordinate2D(latitude: -91, longitude: 0)))
        XCTAssertFalse(QiblaCalculator.isValidCoordinate(CLLocationCoordinate2D(latitude: 0, longitude: -181)))
    }
    
    // MARK: - QiblaResult Tests
    
    func testQiblaResultFormatting() {
        let result = QiblaCalculator.calculateQibla(
            from: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        )
        
        XCTAssertFalse(result.compassBearing.isEmpty, "Compass bearing should not be empty")
        XCTAssertFalse(result.formattedDistance.isEmpty, "Formatted distance should not be empty")
        XCTAssertFalse(result.formattedDirection.isEmpty, "Formatted direction should not be empty")
        
        XCTAssertTrue(result.formattedDistance.contains("km") || result.formattedDistance.contains("m"),
                     "Formatted distance should include units")
        XCTAssertTrue(result.formattedDirection.contains("°"), "Formatted direction should include degree symbol")
    }
    
    // MARK: - Edge Cases
    
    func testPolarRegions() {
        // Test near North Pole
        let northPole = CLLocationCoordinate2D(latitude: 89.9, longitude: 0)
        let resultNorth = QiblaCalculator.calculateQibla(from: northPole)
        XCTAssertGreaterThan(resultNorth.distance, 0, "Should calculate distance from North Pole")
        
        // Test near South Pole
        let southPole = CLLocationCoordinate2D(latitude: -89.9, longitude: 0)
        let resultSouth = QiblaCalculator.calculateQibla(from: southPole)
        XCTAssertGreaterThan(resultSouth.distance, 0, "Should calculate distance from South Pole")
    }
    
    func testDateLineCrossing() {
        // Test locations across the International Date Line
        let fiji = CLLocationCoordinate2D(latitude: -18.1248, longitude: 178.4501)
        let result = QiblaCalculator.calculateQibla(from: fiji)
        
        XCTAssertGreaterThan(result.distance, 0, "Should handle date line crossing")
        XCTAssertGreaterThanOrEqual(result.direction, 0, "Direction should be valid")
        XCTAssertLessThan(result.direction, 360, "Direction should be less than 360°")
    }
}
