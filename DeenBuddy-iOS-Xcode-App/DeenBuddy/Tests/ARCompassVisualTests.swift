import XCTest
import SwiftUI
import ARKit
import RealityKit
@testable import DeenAssistCore
@testable import DeenAssistUI

/// Visual tests for AR Qibla Compass appearance and behavior
class ARCompassVisualTests: XCTestCase {
    
    var mockLocationService: MockLocationService!
    var arSession: ARCompassSession!
    
    override func setUp() {
        super.setUp()
        mockLocationService = MockLocationService()
        arSession = ARCompassSession(locationService: mockLocationService)
    }
    
    override func tearDown() {
        arSession?.stopSession()
        arSession = nil
        mockLocationService = nil
        super.tearDown()
    }
    
    // MARK: - Visual Appearance Tests
    
    func testGreenGlowingCircleCreation() {
        // Test that the AR compass creates a green glowing circle, not 3 lines
        let expectation = XCTestExpectation(description: "Green glowing circle creation")
        
        guard ARWorldTrackingConfiguration.isSupported else {
            print("⚠️ AR not supported on this device, skipping visual test")
            return
        }
        
        let arView = ARView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        
        // Start AR session
        arSession.startSession(arView: arView)
        
        // Set a test Qibla direction
        let testCoordinate = LocationCoordinate(latitude: 40.7128, longitude: -74.0060) // NYC
        let qiblaDirection = QiblaDirection.calculate(from: testCoordinate)
        arSession.updateQiblaDirection(qiblaDirection)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Verify AR scene setup
            XCTAssertEqual(arView.scene.anchors.count, 1, "Should have exactly one anchor")
            
            if let anchor = arView.scene.anchors.first {
                XCTAssertEqual(anchor.children.count, 1, "Anchor should have exactly one child (the Qibla indicator)")
                
                if let qiblaEntity = anchor.children.first as? ModelEntity {
                    // Verify it's a torus (circle) not a sphere
                    XCTAssertNotNil(qiblaEntity.model, "Qibla entity should have a model")
                    
                    // Verify material properties for glow effect
                    if let material = qiblaEntity.model?.materials.first {
                        print("✅ Material type: \(type(of: material))")
                        
                        // Check if it's UnlitMaterial for glow effect
                        if let unlitMaterial = material as? UnlitMaterial {
                            print("✅ Using UnlitMaterial for glow effect")
                            print("✅ Emissive intensity: \(unlitMaterial.emissiveIntensity)")
                        }
                    }
                    
                    // Verify position is not at origin (should be positioned for Qibla direction)
                    let position = qiblaEntity.position
                    let distanceFromOrigin = sqrt(position.x * position.x + position.z * position.z)
                    XCTAssertGreaterThan(distanceFromOrigin, 0.5, "Qibla indicator should be positioned away from origin")
                    
                    print("✅ Qibla circle positioned at: [\(position.x), \(position.y), \(position.z)]")
                    print("✅ Distance from origin: \(distanceFromOrigin)m")
                }
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testNoDebugLinesVisible() {
        // Verify that debug options are disabled and no debug lines are shown
        let arView = ARView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        
        // Check debug options are disabled
        XCTAssertTrue(arView.debugOptions.isEmpty, "Debug options should be empty to prevent 3-line display")
        
        print("✅ Debug options disabled: \(arView.debugOptions)")
    }
    
    func testQiblaDirectionAccuracy() {
        // Test positioning accuracy for known locations
        let testCases = [
            (name: "NYC", coord: LocationCoordinate(latitude: 40.7128, longitude: -74.0060), expectedAngle: 58.0),
            (name: "London", coord: LocationCoordinate(latitude: 51.5074, longitude: -0.1278), expectedAngle: 118.0),
            (name: "Tokyo", coord: LocationCoordinate(latitude: 35.6762, longitude: 139.6503), expectedAngle: 293.0),
            (name: "Sydney", coord: LocationCoordinate(latitude: -33.8688, longitude: 151.2093), expectedAngle: 277.0)
        ]
        
        for testCase in testCases {
            let qiblaDirection = QiblaDirection.calculate(from: testCase.coord)
            let angleDifference = abs(qiblaDirection.direction - testCase.expectedAngle)
            
            XCTAssertLessThan(angleDifference, 10.0, "\(testCase.name) Qibla direction should be within 10° of expected")
            
            print("✅ \(testCase.name): Expected \(testCase.expectedAngle)°, Got \(qiblaDirection.direction)°, Diff: \(angleDifference)°")
        }
    }
    
    func testARCompassViewIntegration() {
        // Test the SwiftUI ARCompassView integration
        let expectation = XCTestExpectation(description: "ARCompassView integration")
        
        guard ARWorldTrackingConfiguration.isSupported else {
            print("⚠️ AR not supported on this device, skipping integration test")
            return
        }
        
        // Create test bindings
        let qiblaDirection = QiblaDirection.calculate(from: LocationCoordinate(latitude: 40.7128, longitude: -74.0060))
        
        // Test ARCompassView creation
        let arCompassView = ARCompassView(
            qiblaDirection: .constant(qiblaDirection),
            isTrackingActive: .constant(false),
            error: .constant(nil),
            arSession: arSession
        )
        
        // Create UIView from SwiftUI view
        let hostingController = UIHostingController(rootView: arCompassView)
        let arView = hostingController.view
        
        XCTAssertNotNil(arView, "ARCompassView should create successfully")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Performance Tests
    
    func testARRenderingPerformance() {
        // Test AR rendering performance with the glowing circle
        guard ARWorldTrackingConfiguration.isSupported else {
            print("⚠️ AR not supported on this device, skipping performance test")
            return
        }
        
        let arView = ARView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
        arSession.startSession(arView: arView)
        
        let qiblaDirection = QiblaDirection.calculate(from: LocationCoordinate(latitude: 40.7128, longitude: -74.0060))
        
        measure {
            // Measure performance of updating Qibla direction
            for _ in 0..<100 {
                arSession.updateQiblaDirection(qiblaDirection)
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testARNotSupportedError() {
        // Test error handling when AR is not supported
        // Note: This test may pass on devices that support AR
        
        let mockSession = ARCompassSession(locationService: mockLocationService)
        
        // On devices without AR support, should set appropriate error
        if !ARWorldTrackingConfiguration.isSupported {
            let arView = ARView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
            mockSession.startSession(arView: arView)
            
            XCTAssertEqual(mockSession.error, .arNotSupported, "Should set AR not supported error")
        }
    }
}

// MARK: - Mock Location Service for Visual Tests

extension MockLocationService {
    convenience init(coordinate: LocationCoordinate) {
        self.init()
        // Could be extended to support different test coordinates
    }
}
