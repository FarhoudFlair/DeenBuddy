import Foundation
import ARKit
import RealityKit
import CoreLocation
import Combine

/// AR session manager for the Qibla compass with dual needle system
@MainActor
public class ARCompassSession: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var trackingState: ARCamera.TrackingState = .notAvailable
    @Published public var compassAccuracy: ARCompassAccuracy = .unknown
    @Published public var currentHeading: Double = 0
    @Published public var isSessionRunning = false
    @Published public var error: ARCompassError?
    
    // MARK: - Private Properties
    
    private var arView: ARView?
    private var arSession: ARSession?
    private var anchorEntity: AnchorEntity?
    private var qiblaIndicator: ModelEntity?
    
    private let locationService: any LocationServiceProtocol
    private var qiblaDirection: QiblaDirection?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Constants
    
    private let indicatorDistance: Float = 0.8 // Closer to user for cleaner view
    private let indicatorScale: Float = 0.15 // Much smaller, subtle indicator
    
    // MARK: - Initialization
    
    public init(locationService: any LocationServiceProtocol) {
        self.locationService = locationService
        super.init()
        setupLocationObserver()
    }
    
    // MARK: - Public Methods
    
    /// Start the AR session with camera feed
    public func startSession(arView: ARView) {
        self.arView = arView
        self.arSession = arView.session
        
        print("🎯 AR Compass: Starting AR session...")
        
        guard ARWorldTrackingConfiguration.isSupported else {
            print("❌ AR Compass: ARWorldTrackingConfiguration not supported")
            error = .arNotSupported
            return
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        configuration.planeDetection = []
        
        print("🎯 AR Compass: Configuration created with gravity and heading alignment")
        
        arView.session.delegate = self
        arView.session.run(configuration)
        
        setupARScene(arView)
        isSessionRunning = true
        
        print("🎯 AR Compass: Session started successfully")
        print("🎯 AR Compass: ARView frame: \(arView.frame)")
        print("🎯 AR Compass: Scene anchor count: \(arView.scene.anchors.count)")
    }
    
    /// Stop the AR session
    public func stopSession() {
        arSession?.pause()
        arSession?.delegate = nil
        arView?.scene.anchors.removeAll()
        isSessionRunning = false

        // Clean up entities
        anchorEntity = nil
        qiblaIndicator = nil

        print("🎯 AR Compass: Session stopped")
    }
    
    /// Update Qibla direction and indicator positioning
    public func updateQiblaDirection(_ direction: QiblaDirection) {
        self.qiblaDirection = direction
        updateIndicatorPosition()
    }
    
    // MARK: - Private AR Setup
    
    private func setupARScene(_ arView: ARView) {
        // Create world anchor positioned closer to user
        let transform = simd_float4x4(
            simd_float4(1, 0, 0, 0),
            simd_float4(0, 1, 0, 0),
            simd_float4(0, 0, 1, 0),
            simd_float4(0, 0, -indicatorDistance, 1)
        )
        anchorEntity = AnchorEntity(world: transform)
        
        guard let anchor = anchorEntity else { return }
        
        // Create simple Qibla indicator
        setupQiblaIndicator()
        
        // Add indicator to anchor
        if let indicator = qiblaIndicator { 
            anchor.addChild(indicator) 
        }
        
        // Add anchor to scene
        arView.scene.addAnchor(anchor)
        
        print("🎯 AR Compass: Simple scene setup complete with world anchor at distance \(indicatorDistance)m")
        
        // Test with known locations for debugging
        testKnownQiblaDirections()
    }
    
    private func testKnownQiblaDirections() {
        print("🎯 AR Compass: === Testing Known Qibla Directions ===")
        
        // Test NYC (should be ~58° NE)
        let nycCoord = LocationCoordinate(latitude: 40.7128, longitude: -74.0060)
        let nycQibla = QiblaDirection.calculate(from: nycCoord)
        print("🎯 AR Compass: NYC Test - Expected: ~58°, Calculated: \(Int(nycQibla.direction))°")
        
        // Test London (should be ~118° SE)  
        let londonCoord = LocationCoordinate(latitude: 51.5074, longitude: -0.1278)
        let londonQibla = QiblaDirection.calculate(from: londonCoord)
        print("🎯 AR Compass: London Test - Expected: ~118°, Calculated: \(Int(londonQibla.direction))°")
        
        // Test Tokyo (should be ~293° NW)
        let tokyoCoord = LocationCoordinate(latitude: 35.6762, longitude: 139.6503)
        let tokyoQibla = QiblaDirection.calculate(from: tokyoCoord)
        print("🎯 AR Compass: Tokyo Test - Expected: ~293°, Calculated: \(Int(tokyoQibla.direction))°")
        
        // Test Sydney (should be ~277° W)
        let sydneyCoord = LocationCoordinate(latitude: -33.8688, longitude: 151.2093)
        let sydneyQibla = QiblaDirection.calculate(from: sydneyCoord)
        print("🎯 AR Compass: Sydney Test - Expected: ~277°, Calculated: \(Int(sydneyQibla.direction))°")
        
        print("🎯 AR Compass: === End Known Direction Tests ===")
    }
    
    private func setupQiblaIndicator() {
        // Create simple arrow pointing toward Qibla using a pyramid shape
        // GEOMETRY ANALYSIS:
        // - Box dimensions: width=0.03 (X), height=0.015 (Y), depth=0.06 (Z)
        // - In AR coordinates: X=left/right, Y=up/down, Z=forward/back
        // - Arrow body extends in +Z direction (forward from anchor)
        // - Initial orientation: Arrow points in +Z direction (0° relative to anchor)
        let indicatorMesh = MeshResource.generateBox(width: 0.03, height: 0.015, depth: 0.06)
        let indicatorMaterial = createQiblaIndicatorMaterial()
        
        qiblaIndicator = ModelEntity(mesh: indicatorMesh, materials: [indicatorMaterial])
        qiblaIndicator?.scale = [indicatorScale, indicatorScale, indicatorScale]
        qiblaIndicator?.position = [0, 0, 0] // Centered at anchor
        
        // Add a small tip to make it more arrow-like
        createArrowTip()
        
        // Add subtle pulsing animation
        addPulsingAnimation()
        
        print("🎯 AR Compass: Simple Qibla arrow created with size [0.03, 0.015, 0.06] and scale \(indicatorScale)")
        print("🎯 AR Compass: Arrow geometry - initially points in +Z direction (forward)")
        print("🎯 AR Compass: With .gravityAndHeading alignment, +Z should be North (0°)")
    }
    
    
    private func createArrowTip() {
        guard let indicator = qiblaIndicator else { return }
        
        // Create a small pyramid tip for the arrow
        // TIP ANALYSIS:
        // - Tip positioned at [0, 0, 0.04] = +Z direction from arrow center
        // - This places tip at the "front" of the arrow in +Z direction
        // - Confirms arrow points in +Z direction initially
        let tipMesh = MeshResource.generateBox(width: 0.04, height: 0.02, depth: 0.02)
        let tipMaterial = createQiblaIndicatorMaterial()
        
        let tipEntity = ModelEntity(mesh: tipMesh, materials: [tipMaterial])
        tipEntity.position = [0, 0, 0.04] // Position at front of arrow (+Z direction)
        
        indicator.addChild(tipEntity)
        
        print("🎯 AR Compass: Arrow tip positioned at +Z (0.04), confirming arrow points forward")
    }
    
    private func addPulsingAnimation() {
        guard let indicator = qiblaIndicator else { return }
        
        // Create a simple Transform component animation using Timer
        // RealityKit animations are more complex, so let's keep it simple for now
        // The subtle pulsing will be handled through manual scale updates
        
        // For now, just add a comment that animation could be added later
        // The indicator is already visible and functional without animation
        print("🎯 AR Compass: Qibla indicator ready (animation placeholder)")
    }
    
    // MARK: - Material Creation
    
    private func createQiblaIndicatorMaterial() -> SimpleMaterial {
        var material = SimpleMaterial()
        // Use Islamic green color for Qibla direction
        material.color = .init(tint: UIColor.systemGreen)
        material.metallic = .init(floatLiteral: 0.2)
        material.roughness = .init(floatLiteral: 0.3)
        return material
    }
    
    
    // MARK: - Indicator Updates
    
    private func updateIndicatorPosition() {
        guard let direction = qiblaDirection,
              let indicator = qiblaIndicator else { return }
        
        // Detailed logging for debugging
        print("🎯 AR Compass: === Qibla Direction Debug ===")
        print("🎯 AR Compass: Location: \(direction.location.latitude), \(direction.location.longitude)")
        print("🎯 AR Compass: Calculated Qibla bearing: \(direction.direction)° (\(direction.compassDirection))")
        print("🎯 AR Compass: Distance to Kaaba: \(direction.formattedDistance)")
        print("🎯 AR Compass: Radians conversion: \(direction.directionRadians)")
        
        // Rotate indicator to point toward Qibla direction
        let qiblaAngle = Float(direction.directionRadians)
        
        // POTENTIAL FIX: ARKit coordinate system adjustment
        // If the arrow is pointing wrong, it might be because:
        // 1. Our arrow geometry points in wrong initial direction, OR
        // 2. ARKit's coordinate system doesn't align +Z with North as expected
        // 
        // Testing both possibilities:
        let qiblaRotation = simd_quatf(angle: qiblaAngle, axis: [0, 1, 0])
        indicator.orientation = qiblaRotation
        
        // Alternative rotation if the above is wrong:
        // let adjustedAngle = qiblaAngle + .pi  // 180° offset
        // let qiblaRotation = simd_quatf(angle: adjustedAngle, axis: [0, 1, 0])
        // indicator.orientation = qiblaRotation
        
        print("🎯 AR Compass: Applied rotation: \(qiblaAngle) radians = \(qiblaAngle * 180 / .pi)°")
        
        // CRITICAL ANALYSIS: ARKit Coordinate System
        // POTENTIAL ISSUE IDENTIFIED:
        // With .gravityAndHeading, the coordinate system aligns with magnetic north,
        // BUT we need to verify if +Z actually points North or if there's an offset
        print("🎯 AR Compass: *** COORDINATE SYSTEM CHECK ***")
        print("🎯 AR Compass: ARKit .gravityAndHeading alignment setting used")
        print("🎯 AR Compass: ASSUMPTION: +Z = North, +X = East")
        print("🎯 AR Compass: Arrow initially points +Z direction")
        print("🎯 AR Compass: Applied rotation: \(qiblaAngle * 180 / .pi)° from initial +Z")
        print("🎯 AR Compass: ⚠️  IF INCORRECT: May need coordinate system adjustment")
        
        // Log expected results for known locations
        logExpectedDirection(for: direction)
        
        print("🎯 AR Compass: === End Debug ===")
    }
    
    private func logExpectedDirection(for direction: QiblaDirection) {
        let lat = direction.location.latitude
        let lon = direction.location.longitude
        
        // Check if this is a known location and log expected Qibla direction
        if abs(lat - 40.7128) < 0.1 && abs(lon - (-74.0060)) < 0.1 {
            print("🎯 AR Compass: *** NYC Location Detected ***")
            print("🎯 AR Compass: Expected Qibla: ~58° NE (should point northeast)")
            print("🎯 AR Compass: Calculated: \(Int(direction.direction))°")
            if direction.direction > 50 && direction.direction < 70 {
                print("✅ AR Compass: Direction looks correct for NYC!")
            } else {
                print("❌ AR Compass: Direction may be wrong for NYC!")
            }
        } else if abs(lat - 51.5074) < 0.1 && abs(lon - (-0.1278)) < 0.1 {
            print("🎯 AR Compass: *** London Location Detected ***")
            print("🎯 AR Compass: Expected Qibla: ~118° SE (should point southeast)")
            print("🎯 AR Compass: Calculated: \(Int(direction.direction))°")
            if direction.direction > 110 && direction.direction < 130 {
                print("✅ AR Compass: Direction looks correct for London!")
            } else {
                print("❌ AR Compass: Direction may be wrong for London!")
            }
        }
    }
    
    // MARK: - Location Observer
    
    private func setupLocationObserver() {
        // Subscribe to location updates from the location service
        locationService.locationPublisher
            .sink { completion in
                if case .failure(let error) = completion {
                    print("❌ AR Compass: Location error: \(error)")
                }
            } receiveValue: { [weak self] location in
                let coordinate = LocationCoordinate(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                let qiblaDirection = QiblaDirection.calculate(from: coordinate)
                self?.updateQiblaDirection(qiblaDirection)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Perform synchronous cleanup - no async tasks in deinit
        arSession?.pause()
        arSession?.delegate = nil
        arView?.scene.anchors.removeAll()

        // Clean up entities
        anchorEntity = nil
        qiblaIndicator = nil

        // Clean up references
        arView = nil
        arSession = nil

        // Clean up Combine subscriptions
        cancellables.removeAll()

        print("🎯 AR Compass: Session cleaned up in deinit")
    }
}

// MARK: - ARSessionDelegate

extension ARCompassSession: @preconcurrency ARSessionDelegate {
    
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let camera = frame.camera
        trackingState = camera.trackingState
        
        // Update compass accuracy based on tracking state
        let oldAccuracy = compassAccuracy
        switch camera.trackingState {
        case .normal:
            compassAccuracy = .high
        case .limited(.relocalizing), .limited(.initializing):
            compassAccuracy = .medium
        case .limited(.excessiveMotion), .limited(.insufficientFeatures):
            compassAccuracy = .low
        case .notAvailable:
            compassAccuracy = .unknown
        @unknown default:
            compassAccuracy = .unknown
        }
        
        // Log accuracy changes
        if oldAccuracy != compassAccuracy {
            print("🎯 AR Compass: Tracking accuracy changed: \(oldAccuracy.description) -> \(compassAccuracy.description)")
        }
        
        // Extract heading from camera transform
        let transform = camera.transform
        let heading = atan2(transform.columns.2.x, transform.columns.2.z) * 180 / .pi
        currentHeading = Double(heading)
        
        // Debug logging every 60 frames (roughly once per second)
        if frame.timestamp.truncatingRemainder(dividingBy: 1.0) < 0.017 {
            print("🎯 AR Compass: Frame update - State: \(camera.trackingState), Accuracy: \(compassAccuracy.description), Heading: \(Int(currentHeading))°")
            if let arView = arView {
                print("🎯 AR Compass: Scene has \(arView.scene.anchors.count) anchors")
            }
        }
    }
    
    nonisolated public func session(_ session: ARSession, didFailWithError error: Error) {
        print("❌ AR Compass: Session failed with error: \(error)")
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.error = .sessionFailed(error.localizedDescription)
            self.isSessionRunning = false
        }
    }

    nonisolated public func sessionWasInterrupted(_ session: ARSession) {
        print("⚠️ AR Compass: Session was interrupted")
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.isSessionRunning = false
        }
    }

    nonisolated public func sessionInterruptionEnded(_ session: ARSession) {
        print("✅ AR Compass: Session interruption ended")
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.isSessionRunning = true
        }
    }
}

// MARK: - Supporting Types

public enum ARCompassAccuracy {
    case unknown, low, medium, high
    
    public var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .low: return "Low Accuracy"
        case .medium: return "Medium Accuracy"
        case .high: return "High Accuracy"
        }
    }
    
    public var color: UIColor {
        switch self {
        case .unknown: return .systemGray
        case .low: return .systemRed
        case .medium: return .systemOrange
        case .high: return .systemGreen
        }
    }
}

public enum ARCompassError: LocalizedError, Equatable {
    case arNotSupported
    case cameraPermissionDenied
    case sessionFailed(String)
    case locationUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .arNotSupported:
            return "AR is not supported on this device"
        case .cameraPermissionDenied:
            return "Camera permission is required for AR compass"
        case .sessionFailed(let message):
            return "AR session failed: \(message)"
        case .locationUnavailable:
            return "Location is required for Qibla direction"
        }
    }
}