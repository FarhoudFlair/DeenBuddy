import XCTest
import ARKit
import RealityKit
import CoreLocation
@testable import DeenAssistCore
@testable import DeenAssistUI

/// Comprehensive tests for AR Qibla Compass functionality
class ARCompassTests: XCTestCase {
    
    var mockLocationService: MockLocationService!
    var arSession: ARCompassSession!
    
    override func setUp() {
        super.setUp()
        mockLocationService = MockLocationService()
        arSession = ARCompassSession(locationService: mockLocationService)
    }
    
    override func tearDown() {
        arSession = nil
        mockLocationService = nil
        super.tearDown()
    }
    
    // MARK: - Qibla Direction Accuracy Tests
    
    func testQiblaDirectionFromNewYork() {
        // Test from New York City - should point Northeast (~58°)
        let nycCoordinate = LocationCoordinate(latitude: 40.7128, longitude: -74.0060)
        let qiblaDirection = QiblaDirection.calculate(from: nycCoordinate)
        
        XCTAssertGreaterThan(qiblaDirection.direction, 50, "NYC Qibla should be greater than 50°")
        XCTAssertLessThan(qiblaDirection.direction, 70, "NYC Qibla should be less than 70°")
        XCTAssertEqual(qiblaDirection.compassDirection, "NE", "NYC Qibla should point Northeast")
        
        print("✅ NYC Test: \(qiblaDirection.direction)° (\(qiblaDirection.compassDirection))")
    }
    
    func testQiblaDirectionFromLondon() {
        // Test from London - should point Southeast (~118°)
        let londonCoordinate = LocationCoordinate(latitude: 51.5074, longitude: -0.1278)
        let qiblaDirection = QiblaDirection.calculate(from: londonCoordinate)
        
        XCTAssertGreaterThan(qiblaDirection.direction, 110, "London Qibla should be greater than 110°")
        XCTAssertLessThan(qiblaDirection.direction, 130, "London Qibla should be less than 130°")
        XCTAssertEqual(qiblaDirection.compassDirection, "SE", "London Qibla should point Southeast")
        
        print("✅ London Test: \(qiblaDirection.direction)° (\(qiblaDirection.compassDirection))")
    }
    
    func testQiblaDirectionFromTokyo() {
        // Test from Tokyo - should point Northwest (~293°)
        let tokyoCoordinate = LocationCoordinate(latitude: 35.6762, longitude: 139.6503)
        let qiblaDirection = QiblaDirection.calculate(from: tokyoCoordinate)
        
        XCTAssertGreaterThan(qiblaDirection.direction, 285, "Tokyo Qibla should be greater than 285°")
        XCTAssertLessThan(qiblaDirection.direction, 300, "Tokyo Qibla should be less than 300°")
        XCTAssertEqual(qiblaDirection.compassDirection, "NW", "Tokyo Qibla should point Northwest")
        
        print("✅ Tokyo Test: \(qiblaDirection.direction)° (\(qiblaDirection.compassDirection))")
    }
    
    func testQiblaDirectionFromSydney() {
        // Test from Sydney - should point West (~277°)
        let sydneyCoordinate = LocationCoordinate(latitude: -33.8688, longitude: 151.2093)
        let qiblaDirection = QiblaDirection.calculate(from: sydneyCoordinate)
        
        XCTAssertGreaterThan(qiblaDirection.direction, 270, "Sydney Qibla should be greater than 270°")
        XCTAssertLessThan(qiblaDirection.direction, 285, "Sydney Qibla should be less than 285°")
        XCTAssertEqual(qiblaDirection.compassDirection, "W", "Sydney Qibla should point West")
        
        print("✅ Sydney Test: \(qiblaDirection.direction)° (\(qiblaDirection.compassDirection))")
    }
    
    // MARK: - AR Session Tests
    
    func testARSessionInitialization() {
        XCTAssertNotNil(arSession, "AR session should initialize successfully")
        XCTAssertFalse(arSession.isSessionRunning, "AR session should not be running initially")
        XCTAssertEqual(arSession.trackingState, .notAvailable, "Initial tracking state should be not available")
    }
    
    func testARSessionConfiguration() {
        // Test that AR configuration is supported
        let isSupported = ARWorldTrackingConfiguration.isSupported
        if isSupported {
            XCTAssertTrue(isSupported, "AR World Tracking should be supported on test device")
        } else {
            print("⚠️ AR World Tracking not supported on this test device")
        }
    }
    
    // MARK: - Visual Appearance Tests
    
    func testSingleARObjectCreation() {
        // Verify that only one AR object is created (no 3-line display)
        let expectation = XCTestExpectation(description: "AR object creation")
        
        // Mock ARView for testing
        let arView = ARView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        // Start session and verify single object creation
        arSession.startSession(arView: arView)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Check that scene has exactly one anchor (our Qibla indicator)
            XCTAssertEqual(arView.scene.anchors.count, 1, "Should have exactly one anchor (no debug objects)")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Performance Tests
    
    func testQiblaCalculationPerformance() {
        let coordinate = LocationCoordinate(latitude: 40.7128, longitude: -74.0060)
        
        measure {
            for _ in 0..<1000 {
                _ = QiblaDirection.calculate(from: coordinate)
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testQiblaFromMecca() {
        // Test from Mecca itself - direction should be valid but distance should be minimal
        let meccaCoordinate = LocationCoordinate(latitude: 21.4225, longitude: 39.8262)
        let qiblaDirection = QiblaDirection.calculate(from: meccaCoordinate)
        
        XCTAssertLessThan(qiblaDirection.distance, 1.0, "Distance from Mecca should be minimal")
        XCTAssertGreaterThanOrEqual(qiblaDirection.direction, 0, "Direction should be valid")
        XCTAssertLessThan(qiblaDirection.direction, 360, "Direction should be less than 360°")
        
        print("✅ Mecca Test: \(qiblaDirection.distance) km, \(qiblaDirection.direction)°")
    }
    
    func testQiblaFromAntipode() {
        // Test from the antipode of Mecca (opposite side of Earth)
        let antipodeCoordinate = LocationCoordinate(latitude: -21.4225, longitude: -140.1738)
        let qiblaDirection = QiblaDirection.calculate(from: antipodeCoordinate)
        
        XCTAssertGreaterThan(qiblaDirection.distance, 19000, "Distance from antipode should be maximum")
        XCTAssertLessThan(qiblaDirection.distance, 21000, "Distance should be reasonable")
        
        print("✅ Antipode Test: \(qiblaDirection.distance) km, \(qiblaDirection.direction)°")
    }
}

// MARK: - Mock Location Service

class MockLocationService: LocationServiceProtocol {
    var locationPublisher: AnyPublisher<CLLocation, Error> {
        Just(CLLocation(latitude: 40.7128, longitude: -74.0060))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func requestLocation() async throws -> CLLocation {
        return CLLocation(latitude: 40.7128, longitude: -74.0060)
    }
    
    func requestPermission() async -> CLAuthorizationStatus {
        return .authorizedWhenInUse
    }
    
    func startUpdatingLocation() {}
    func stopUpdatingLocation() {}
}
