// MARK: - AR COMPASS DISABLED - TOO BUGGY, FOCUSING ON 2D COMPASS
// This entire file is commented out to resolve compilation issues
// AR compass can be re-enabled in the future when issues are resolved

/*
import SwiftUI
import ARKit
import CoreLocation
import Combine

/// Augmented Reality Qibla Compass screen with dual needle system
public struct ARQiblaCompassScreen: View {
    
    // MARK: - Properties
    
    private let locationService: any LocationServiceProtocol
    @StateObject private var arSession: ARCompassSession
    
    let onDismiss: () -> Void
    
    // MARK: - State
    
    @State private var qiblaDirection: QiblaDirection?
    @State private var isLoading = true
    @State private var error: ARCompassError?
    @State private var showingSettings = false
    @State private var isTrackingActive = false
    @State private var showingPermissionAlert = false
    
    // MARK: - Initialization
    
    public init(
        locationService: any LocationServiceProtocol,
        onDismiss: @escaping () -> Void
    ) {
        self.locationService = locationService
        self.onDismiss = onDismiss
        self._arSession = StateObject(wrappedValue: ARCompassSession(locationService: locationService))
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            ZStack {
                if let error = error {
                    errorView(error)
                } else if isLoading {
                    loadingView
                } else {
                    arCompassContent
                }
            }
            .navigationTitle("AR Qibla Compass")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                ARCompassSettingsView(
                    arSession: arSession,
                    onDismiss: {
                        showingSettings = false
                    }
                )
            }
            .alert("Camera Permission Required", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    openAppSettings()
                }
                Button("Cancel", role: .cancel) {
                    onDismiss()
                }
            } message: {
                Text("Please enable camera access in Settings to use the AR compass feature.")
            }
        }
        .onAppear {
            print("🎯 ARQiblaCompassScreen: Screen appeared")
            Task {
                await loadQiblaDirection()
            }
        }
        .onDisappear {
            arSession.stopSession()
        }
        .onChange(of: arSession.error) { _, newError in
            if newError == .cameraPermissionDenied {
                showingPermissionAlert = true
            }
            error = newError
        }
    }
    
    // MARK: - Views
    
    @ViewBuilder
    private var loadingView: some View {
        ContextualLoadingView(
            context: .qiblaDirection,
            customMessage: "Initializing AR compass..."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.backgroundPrimary)
    }
    
    @ViewBuilder
    private var arCompassContent: some View {
        ZStack {
            // AR Camera View
            ARCompassView(
                qiblaDirection: $qiblaDirection,
                isTrackingActive: $isTrackingActive,
                error: $error,
                arSession: arSession
            )
            .edgesIgnoringSafeArea(.all)
            
            // Overlay UI
            VStack {
                // Top status overlay
                topStatusOverlay
                
                Spacer()
                
                // Bottom information panel
                if let qiblaDirection = qiblaDirection {
                    bottomInfoPanel(qiblaDirection)
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var topStatusOverlay: some View {
        HStack {
            // Tracking status
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(arSession.compassAccuracy.color))
                    .frame(width: 12, height: 12)
                
                Text(arSession.compassAccuracy.description)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.7))
            )
            
            Spacer()
            
            // AR indicator
            HStack(spacing: 4) {
                Image(systemName: "arkit")
                    .font(.caption)
                Text("AR")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ColorPalette.primary.opacity(0.8))
            )
        }
    }
    
    @ViewBuilder
    private func bottomInfoPanel(_ qiblaDirection: QiblaDirection) -> some View {
        VStack(spacing: 16) {
            // Direction and distance info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Qibla Direction")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("\(Int(qiblaDirection.direction))°")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Distance to Kaaba")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(qiblaDirection.formattedDistance)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(ColorPalette.primary.opacity(0.5), lineWidth: 1)
                    )
            )
            
            // Instructions
            instructionsView
        }
    }
    
    @ViewBuilder
    private var instructionsView: some View {
        VStack(spacing: 12) {
            // Simple legend for AR arrow
            HStack(spacing: 6) {
                Image(systemName: "arrow.forward")
                    .foregroundColor(ColorPalette.primary)
                    .font(.caption)
                
                Text("Qibla Direction")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }
            
            // Main instruction
            Text("Point your device toward the **green arrow** to face Mecca")
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Calibration tip
            if arSession.compassAccuracy != .high {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text("Move your device in a figure-8 pattern to improve accuracy")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.2))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
        )
    }
    
    @ViewBuilder
    private func errorView(_ error: ARCompassError) -> some View {
        VStack(spacing: 24) {
            Image(systemName: errorIcon(for: error))
                .font(.system(size: 64))
                .foregroundColor(ColorPalette.error)
            
            VStack(spacing: 8) {
                Text("AR Compass Unavailable")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.textPrimary)
                
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if error == .cameraPermissionDenied {
                Button("Open Settings") {
                    openAppSettings()
                }
                .buttonStyle(.borderedProminent)
                .tint(ColorPalette.primary)
            } else {
                Button("Try Again") {
                    Task {
                        await loadQiblaDirection()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(ColorPalette.primary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.backgroundPrimary)
    }
    
    // MARK: - Private Methods
    
    private func loadQiblaDirection() async {
        print("🎯 ARQiblaCompassScreen: Loading Qibla direction...")
        
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            // Check if we already have a location
            if let location = locationService.currentLocation {
                print("🎯 ARQiblaCompassScreen: Using cached location: \(location.coordinate)")
                let coordinate = LocationCoordinate(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                let direction = QiblaDirection.calculate(from: coordinate)
                
                await MainActor.run {
                    self.qiblaDirection = direction
                    self.isLoading = false
                    print("🎯 ARQiblaCompassScreen: Qibla direction set: \(direction.direction)° at \(direction.formattedDistance)")
                }
                return
            }
            
            print("🎯 ARQiblaCompassScreen: Requesting new location...")
            // Request location if needed
            let location = try await locationService.requestLocation()
            let coordinate = LocationCoordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            let direction = QiblaDirection.calculate(from: coordinate)
            
            await MainActor.run {
                self.qiblaDirection = direction
                self.isLoading = false
                print("🎯 ARQiblaCompassScreen: Qibla direction set: \(direction.direction)° at \(direction.formattedDistance)")
            }
            
        } catch {
            print("❌ ARQiblaCompassScreen: Failed to get location: \(error)")
            await MainActor.run {
                self.error = .locationUnavailable
                self.isLoading = false
            }
        }
    }
    
    private func errorIcon(for error: ARCompassError) -> String {
        switch error {
        case .arNotSupported:
            return "arkit"
        case .cameraPermissionDenied:
            return "camera.fill"
        case .sessionFailed:
            return "exclamationmark.triangle"
        case .locationUnavailable:
            return "location.slash"
        }
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - AR Compass Settings

private struct ARCompassSettingsView: View {
    @ObservedObject var arSession: ARCompassSession
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Compass Status") {
                    HStack {
                        Text("Tracking State")
                        Spacer()
                        Text(trackingStateDescription)
                            .foregroundColor(trackingStateColor)
                    }
                    
                    HStack {
                        Text("Accuracy")
                        Spacer()
                        Text(arSession.compassAccuracy.description)
                            .foregroundColor(Color(arSession.compassAccuracy.color))
                    }
                    
                    HStack {
                        Text("Current Heading")
                        Spacer()
                        Text("\(Int(arSession.currentHeading))°")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("AR Features") {
                    HStack {
                        Text("Session Running")
                        Spacer()
                        Image(systemName: arSession.isSessionRunning ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(arSession.isSessionRunning ? .green : .red)
                    }
                    
                    if !arSession.isSessionRunning {
                        Text("AR session is not active. The compass may not function properly.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Section("Calibration") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("To improve accuracy:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("• Move your device in a figure-8 pattern")
                        Text("• Keep the device away from magnetic objects")
                        Text("• Ensure good lighting conditions")
                        Text("• Hold the device steadily")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("AR Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private var trackingStateDescription: String {
        switch arSession.trackingState {
        case .normal:
            return "Normal"
        case .limited(let reason):
            switch reason {
            case .initializing:
                return "Initializing"
            case .relocalizing:
                return "Relocalizing"
            case .excessiveMotion:
                return "Excessive Motion"
            case .insufficientFeatures:
                return "Insufficient Features"
            @unknown default:
                return "Limited"
            }
        case .notAvailable:
            return "Not Available"
        }
    }
    
    private var trackingStateColor: Color {
        switch arSession.trackingState {
        case .normal:
            return .green
        case .limited:
            return .orange
        case .notAvailable:
            return .red
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ARQiblaCompassScreen_Previews: PreviewProvider {
    static var previews: some View {
        ARQiblaCompassScreen(
            locationService: MockLocationService(),
            onDismiss: {}
        )
    }
}
#endif
*/ // End of AR Compass disabled code