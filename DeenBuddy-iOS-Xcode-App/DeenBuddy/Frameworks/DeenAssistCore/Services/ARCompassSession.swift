// MARK: - AR COMPASS SESSION DISABLED - TOO BUGGY, FOCUSING ON 2D COMPASS
// This entire file is commented out to resolve compilation issues
// AR compass can be re-enabled in the future when issues are resolved

/*
import Foundation
import ARKit
import RealityKit
import CoreLocation
import Combine

/// AR session manager for the Qibla compass with dual needle system
@MainActor
public class ARCompassSession: NSObject, ObservableObject {
    
    // MARK: - Logger
    
    private let logger = AppLogger.arCompass
    
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

    private let indicatorDistance: Float = 1.0 // Optimal distance for visibility and accuracy
    private let indicatorScale: Float = 0.2 // Larger scale for better visibility of glowing circle
    
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
        
        logger.info("Starting AR session...")
        
        guard ARWorldTrackingConfiguration.isSupported else {
            logger.error("ARWorldTrackingConfiguration not supported")
            error = .arNotSupported
            return
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        configuration.planeDetection = []
        
        logger.debug("Configuration created with gravity and heading alignment")
        
        arView.session.delegate = self
        arView.session.run(configuration)
        
        setupARScene(arView)
        isSessionRunning = true
        
        logger.info("Session started successfully")
        logger.debug("ARView frame: \(arView.frame)")
        logger.debug("Scene anchor count: \(arView.scene.anchors.count)")
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

        logger.info("Session stopped")
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

        logger.debug("AR scene setup complete with floating Qibla sphere")

        // Test with known locations for debugging
        testKnownQiblaDirections()
    }
    
    private func testKnownQiblaDirections() {
        logger.debug("=== Testing Known Qibla Directions ===")
        
        // Test NYC (should be ~58° NE)
        let nycCoord = LocationCoordinate(latitude: 40.7128, longitude: -74.0060)
        let nycQibla = QiblaDirection.calculate(from: nycCoord)
        logger.debug("NYC Test - Expected: ~58°, Calculated: \(Int(nycQibla.direction))°")
        
        // Test London (should be ~118° SE)  
        let londonCoord = LocationCoordinate(latitude: 51.5074, longitude: -0.1278)
        let londonQibla = QiblaDirection.calculate(from: londonCoord)
        logger.debug("London Test - Expected: ~118°, Calculated: \(Int(londonQibla.direction))°")
        
        // Test Tokyo (should be ~293° NW)
        let tokyoCoord = LocationCoordinate(latitude: 35.6762, longitude: 139.6503)
        let tokyoQibla = QiblaDirection.calculate(from: tokyoCoord)
        logger.debug("Tokyo Test - Expected: ~293°, Calculated: \(Int(tokyoQibla.direction))°")
        
        // Test Sydney (should be ~277° W)
        let sydneyCoord = LocationCoordinate(latitude: -33.8688, longitude: 151.2093)
        let sydneyQibla = QiblaDirection.calculate(from: sydneyCoord)
        logger.debug("Sydney Test - Expected: ~277°, Calculated: \(Int(sydneyQibla.direction))°")
        
        logger.debug("=== End Known Direction Tests ===")
    }
    
    private func setupQiblaIndicator() {
        // Create a glowing green circle (torus) that points toward Qibla direction
        // Using sphere for Qibla indicator as torus is not available
        let indicatorRadius: Float = 0.04
        let indicatorMesh = MeshResource.generateSphere(radius: indicatorRadius)
        let indicatorMaterial = createGlowingQiblaMaterial()

        qiblaIndicator = ModelEntity(mesh: indicatorMesh, materials: [indicatorMaterial])
        qiblaIndicator?.scale = [indicatorScale, indicatorScale, indicatorScale]

        // Position will be calculated based on Qibla direction in updateIndicatorPosition()
        qiblaIndicator?.position = [0, 0, -indicatorDistance] // Initial position

        // Add glowing pulsing animation
        addGlowingAnimation()

        logger.debug("Glowing Qibla sphere created with radius \(indicatorRadius) and scale \(indicatorScale)")
        logger.debug("Sphere will be positioned directly in Qibla direction with glow effect")
    }
    

    
    private func addGlowingAnimation() {
        guard let indicator = qiblaIndicator else { return }

        // Create a subtle pulsing animation for the glow effect
        // This helps draw attention to the Qibla direction
        let scaleAnimation = FromToByAnimation<Transform>(
            name: "qibla-pulse",
            from: .init(scale: [1.0, 1.0, 1.0]),
            to: .init(scale: [1.2, 1.2, 1.2]),
            duration: 1.5,
            timing: .easeInOut,
            isAdditive: false
        )

        // Make the animation repeat indefinitely with auto-reverse
        let animationResource = try? AnimationResource.generate(with: scaleAnimation)
        if let animation = animationResource {
            let controller = indicator.playAnimation(animation.repeat())
            logger.debug("Glowing pulse animation started")
        } else {
            logger.warning("Animation creation failed, using static glow")
        }
    }

    // Legacy method for backward compatibility
    private func addPulsingAnimation() {
        addGlowingAnimation()
    }
    
    // MARK: - Material Creation

    private func createGlowingQiblaMaterial() -> UnlitMaterial {
        // Use UnlitMaterial for better glow effect and visibility
        var material = UnlitMaterial()

        // Islamic green color with enhanced brightness for glow
        let islamicGreen = UIColor(red: 0.0, green: 0.8, blue: 0.3, alpha: 1.0)

        // Set base color for glow effect
        // Note: emissiveColor and emissiveIntensity are not available in UnlitMaterial
        // Using high opacity color for a glowing effect
        material.color = .init(tint: islamicGreen.withAlphaComponent(0.9))

        return material
    }

    // Legacy method for backward compatibility
    private func createQiblaIndicatorMaterial() -> SimpleMaterial {
        var material = SimpleMaterial()
        material.color = .init(tint: UIColor.systemGreen)
        material.metallic = .init(floatLiteral: 0.1)
        material.roughness = .init(floatLiteral: 0.2)
        return material
    }
    
    
    // MARK: - Indicator Updates
    
    private func updateIndicatorPosition() {
        guard let direction = qiblaDirection,
              let indicator = qiblaIndicator else { return }

        logger.debug("=== Updating Qibla Sphere Position ===")
        logger.debug("Location: \(direction.location.latitude), \(direction.location.longitude)")
        logger.debug("Qibla bearing: \(direction.direction)° (\(direction.compassDirection))")
        logger.debug("Distance to Kaaba: \(direction.formattedDistance)")

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

        logger.debug("Sphere positioned at [\(x), \(y), \(z)] for \(direction.direction)° bearing")
        logger.debug("Distance from user: \(distance)m")

        // Log expected results for known locations
        logExpectedDirection(for: direction)

        logger.debug("=== Position Update Complete ===")
    }
    
    private func logExpectedDirection(for direction: QiblaDirection) {
        let lat = direction.location.latitude
        let lon = direction.location.longitude
        
        // Check if this is a known location and log expected Qibla direction
        if abs(lat - 40.7128) < 0.1 && abs(lon - (-74.0060)) < 0.1 {
            logger.debug("*** NYC Location Detected ***")
            logger.debug("Expected Qibla: ~58° NE (should point northeast)")
            logger.debug("Calculated: \(Int(direction.direction))°")
            if direction.direction > 50 && direction.direction < 70 {
                logger.debug("Direction looks correct for NYC!")
            } else {
                logger.warning("Direction may be wrong for NYC!")
            }
        } else if abs(lat - 51.5074) < 0.1 && abs(lon - (-0.1278)) < 0.1 {
            logger.debug("*** London Location Detected ***")
            logger.debug("Expected Qibla: ~118° SE (should point southeast)")
            logger.debug("Calculated: \(Int(direction.direction))°")
            if direction.direction > 110 && direction.direction < 130 {
                logger.debug("Direction looks correct for London!")
            } else {
                logger.warning("Direction may be wrong for London!")
            }
        }
    }
    
    // MARK: - Location Observer
    
    private func setupLocationObserver() {
        // Subscribe to location updates from the location service
        locationService.locationPublisher
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.logger.error("Location error: \(error)")
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

        logger.debug("Session cleaned up in deinit")
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
            logger.debug("Tracking accuracy changed: \(oldAccuracy.description) -> \(compassAccuracy.description)")
        }
        
        // Extract heading from camera transform
        let transform = camera.transform
        let heading = atan2(transform.columns.2.x, transform.columns.2.z) * 180 / .pi
        currentHeading = Double(heading)
        
        // Debug logging every 60 frames (roughly once per second)
        if frame.timestamp.truncatingRemainder(dividingBy: 1.0) < 0.017 {
            logger.debug("Frame update - State: \(camera.trackingState), Accuracy: \(compassAccuracy.description), Heading: \(Int(currentHeading))°")
            if let arView = arView {
                logger.debug("Scene has \(arView.scene.anchors.count) anchors")
            }
        }
    }
    
    nonisolated public func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.logger.error("Session failed with error: \(error)")
            self.error = .sessionFailed(error.localizedDescription)
            self.isSessionRunning = false
        }
    }

    nonisolated public func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.logger.warning("Session was interrupted")
            self.isSessionRunning = false
        }
    }

    nonisolated public func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.logger.info("Session interruption ended")
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
*/ // End of AR Compass Session disabled code