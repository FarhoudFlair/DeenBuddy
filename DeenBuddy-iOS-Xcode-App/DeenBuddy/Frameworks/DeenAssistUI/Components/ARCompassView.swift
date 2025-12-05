// MARK: - AR COMPASS VIEW DISABLED - TOO BUGGY, FOCUSING ON 2D COMPASS
// This entire file is commented out to resolve compilation issues
// AR compass can be re-enabled in the future when issues are resolved

/*
import SwiftUI
import ARKit
import RealityKit
import AVFoundation
import CoreLocation
import Combine

/// SwiftUI wrapper for ARView with Qibla compass functionality
public struct ARCompassView: UIViewRepresentable {
    
    // MARK: - Bindings
    
    @Binding var qiblaDirection: QiblaDirection?
    @Binding var isTrackingActive: Bool
    @Binding var error: ARCompassError?
    
    // MARK: - Properties
    
    private let arSession: ARCompassSession
    
    // MARK: - Initialization
    
    public init(
        qiblaDirection: Binding<QiblaDirection?>,
        isTrackingActive: Binding<Bool>,
        error: Binding<ARCompassError?>,
        arSession: ARCompassSession
    ) {
        self._qiblaDirection = qiblaDirection
        self._isTrackingActive = isTrackingActive
        self._error = error
        self.arSession = arSession
    }
    
    // MARK: - UIViewRepresentable
    
    public func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        print("🎯 ARCompassView: Creating ARView with frame: \(arView.frame)")
        
        // Configure ARView settings
        arView.automaticallyConfigureSession = false
        arView.renderOptions = [.disableMotionBlur, .disableDepthOfField]
        
        // Set camera background - correct method for RealityKit
        arView.environment.background = .cameraFeed()
        
        // Debug options disabled for clean AR compass display
        // Note: Debug options were causing 3-line display instead of single green circle
        #if DEBUG && false // Explicitly disabled to prevent 3-line display
        arView.debugOptions = [.showAnchorOrigins, .showAnchorGeometry]
        print("🎯 ARCompassView: Debug options enabled")
        #endif
        
        print("🎯 ARCompassView: ARView configured, checking camera permission...")
        
        // Check camera permission before starting
        checkCameraPermissionAndStart(arView: arView)
        
        return arView
    }
    
    public func updateUIView(_ arView: ARView, context: Context) {
        // Update Qibla direction if available
        if let direction = qiblaDirection {
            arSession.updateQiblaDirection(direction)
        }
        
        // Update tracking state
        isTrackingActive = arSession.isSessionRunning
    }
    
    // MARK: - Static Methods
    
    public static func dismantleUIView(_ arView: ARView, coordinator: ()) {
        arView.session.pause()
        arView.scene.anchors.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func checkCameraPermissionAndStart(arView: ARView) {
        let cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        print("🎯 ARCompassView: Camera authorization status: \(cameraAuthStatus.rawValue)")
        
        switch cameraAuthStatus {
        case .authorized:
            print("🎯 ARCompassView: Camera permission granted, starting AR session")
            startARSession(arView: arView)
            
        case .notDetermined:
            print("🎯 ARCompassView: Camera permission not determined, requesting access")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    print("🎯 ARCompassView: Camera permission request result: \(granted)")
                    if granted {
                        self.startARSession(arView: arView)
                    } else {
                        self.error = .cameraPermissionDenied
                    }
                }
            }
            
        case .denied, .restricted:
            print("❌ ARCompassView: Camera permission denied or restricted")
            error = .cameraPermissionDenied
            
        @unknown default:
            print("❌ ARCompassView: Unknown camera permission status")
            error = .cameraPermissionDenied
        }
    }
    
    private func startARSession(arView: ARView) {
        print("🎯 ARCompassView: Starting AR session with ARView frame: \(arView.frame)")
        arSession.startSession(arView: arView)
    }
}

// MARK: - Preview Support
// Preview removed due to AR dependency requirements
*/ // End of AR Compass View disabled code