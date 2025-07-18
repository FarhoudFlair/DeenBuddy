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
        // Create a simple world anchor at the origin
        // The sphere positioning will handle the Qibla direction
        let identityTransform = simd_float4x4(
            simd_float4(1, 0, 0, 0),
            simd_float4(0, 1, 0, 0),
            simd_float4(0, 0, 1, 0),
            simd_float4(0, 0, 0, 1)
        )
        anchorEntity = AnchorEntity(world: identityTransform)

        guard let anchor = anchorEntity else { return }

        // Create the Qibla sphere indicator
        setupQiblaIndicator()

        // Add sphere to anchor
        if let indicator = qiblaIndicator {
            anchor.addChild(indicator)
        }

        // Add anchor to scene
        arView.scene.addAnchor(anchor)

        print("🎯 AR Compass: AR scene setup complete with floating Qibla sphere")

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
        // Create a simple floating sphere that points toward Qibla direction
        // This is much simpler and more reliable than complex arrow geometry
        let sphereRadius: Float = 0.05
        let indicatorMesh = MeshResource.generateSphere(radius: sphereRadius)
        let indicatorMaterial = createQiblaIndicatorMaterial()

        qiblaIndicator = ModelEntity(mesh: indicatorMesh, materials: [indicatorMaterial])
        qiblaIndicator?.scale = [indicatorScale, indicatorScale, indicatorScale]

        // Position will be calculated based on Qibla direction in updateIndicatorPosition()
        qiblaIndicator?.position = [0, 0, -indicatorDistance] // Initial position

        // Add subtle pulsing animation
        addPulsingAnimation()

        print("🎯 AR Compass: Floating Qibla sphere created with radius \(sphereRadius) and scale \(indicatorScale)")
        print("🎯 AR Compass: Sphere will be positioned directly in Qibla direction")
    }
    

    
    private func addPulsingAnimation() {
        guard let indicator = qiblaIndicator else { return }

        // For now, skip the animation to avoid RealityKit complexity
        // The sphere will be visible and functional without animation
        // Animation can be added later if needed using RealityKit's animation system

        print("🎯 AR Compass: Qibla sphere ready (animation skipped for simplicity)")
    }
    
    // MARK: - Material Creation
    
    private func createQiblaIndicatorMaterial() -> SimpleMaterial {
        var material = SimpleMaterial()
        // Use Islamic green color for Qibla direction with enhanced visibility
        material.color = .init(tint: UIColor.systemGreen)
        material.metallic = .init(floatLiteral: 0.1)
        material.roughness = .init(floatLiteral: 0.2)
        return material
    }
    
    
    // MARK: - Indicator Updates
    
    private func updateIndicatorPosition() {
        guard let direction = qiblaDirection,
              let indicator = qiblaIndicator else { return }

        print("🎯 AR Compass: === Updating Qibla Sphere Position ===")
        print("🎯 AR Compass: Location: \(direction.location.latitude), \(direction.location.longitude)")
        print("🎯 AR Compass: Qibla bearing: \(direction.direction)° (\(direction.compassDirection))")
        print("🎯 AR Compass: Distance to Kaaba: \(direction.formattedDistance)")

        // Convert Qibla direction to 3D position using spherical coordinates
        // ARKit coordinate system: +X = East, +Y = Up, +Z = South (toward user)
        // We want to position the sphere in the Qibla direction at a fixed distance
        let qiblaAngleRadians = Float(direction.directionRadians)
        let distance = indicatorDistance

        // Calculate 3D position in ARKit coordinates
        // Note: ARKit +Z points toward the user, so we use negative for forward direction
        let x = distance * sin(qiblaAngleRadians)  // East-West position
        let y: Float = 0.0  // Keep at eye level
        let z = -distance * cos(qiblaAngleRadians)  // North-South position (negative for forward)

        // Position the sphere directly in the Qibla direction
        indicator.position = [x, y, z]

        print("🎯 AR Compass: Sphere positioned at [\(x), \(y), \(z)] for \(direction.direction)° bearing")
        print("🎯 AR Compass: Distance from user: \(distance)m")

        // Log expected results for known locations
        logExpectedDirection(for: direction)

        print("🎯 AR Compass: === Position Update Complete ===")
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

        // Clean up entities first
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