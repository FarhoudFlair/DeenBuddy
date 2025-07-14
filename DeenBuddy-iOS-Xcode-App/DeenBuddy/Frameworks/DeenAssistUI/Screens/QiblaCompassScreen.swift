import SwiftUI
import CoreMotion
import CoreLocation
import Combine

/// Qibla Compass screen with real-time direction to Kaaba
public struct QiblaCompassScreen: View {
    private let locationService: any LocationServiceProtocol
    @StateObject private var compassManager: CompassManager
    
    let onDismiss: () -> Void
    let onShowAR: (() -> Void)?
    
    @State private var qiblaDirection: QiblaDirection?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var showingCalibration = false
    
    public init(
        locationService: any LocationServiceProtocol,
        onDismiss: @escaping () -> Void,
        onShowAR: (() -> Void)? = nil
    ) {
        self.locationService = locationService
        self.onDismiss = onDismiss
        self.onShowAR = onShowAR
        self._compassManager = StateObject(wrappedValue: CompassManager(locationService: locationService))
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        ColorPalette.primary.opacity(0.1),
                        ColorPalette.secondary.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if isLoading {
                    LoadingView.prayer(message: "Finding Qibla direction...")
                } else if let error = error {
                    ErrorView(
                        error: .unknownError(error.localizedDescription),
                        onRetry: {
                            Task {
                                await loadQiblaDirection()
                            }
                        }
                    )
                } else {
                    compassContent
                }
            }
            .navigationTitle("Qibla Compass")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        onDismiss()
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if let onShowAR = onShowAR {
                        Button(action: onShowAR) {
                            HStack(spacing: 4) {
                                Image(systemName: "arkit")
                                Text("AR")
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(ColorPalette.primary)
                    }
                    
                    Button(action: {
                        showingCalibration = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingCalibration) {
                CalibrationView(
                    accuracy: compassManager.accuracy,
                    onDismiss: {
                        showingCalibration = false
                    }
                )
            }
        }
        .onAppear {
            Task {
                await loadQiblaDirection()
            }
            compassManager.startUpdating()
        }
        .onDisappear {
            compassManager.stopUpdating()
        }
    }
    
    @ViewBuilder
    private var compassContent: some View {
        VStack(spacing: 32) {
            // Compass accuracy indicator
            accuracyIndicator
            
            // Enhanced Main compass with premium styling
            ZStack {
                // Outer compass ring with Islamic aesthetic
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                ColorPalette.primary.opacity(0.1),
                                ColorPalette.secondary.opacity(0.05)
                            ],
                            center: .center,
                            startRadius: 140,
                            endRadius: 160
                        )
                    )
                    .frame(width: 320, height: 320)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        ColorPalette.primary.opacity(0.3),
                                        ColorPalette.accent.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                
                // Main compass background with enhanced gradients
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.98),
                                Color.white.opacity(0.92),
                                ColorPalette.surface.opacity(0.85)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                    .overlay(
                        Circle()
                            .stroke(ColorPalette.primary.opacity(0.1), lineWidth: 1)
                    )
                
                // Compass markings
                compassMarkings
                
                // North reference needle (red arrow pointing to magnetic North)
                deviceHeadingIndicator

                // Qibla direction indicator (green arrow pointing to Qibla)
                if let qiblaDirection = qiblaDirection {
                    qiblaNeedle(direction: qiblaDirection)
                }
                
                // Enhanced center dot with Islamic styling
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    ColorPalette.accent,
                                    ColorPalette.primary
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 8
                            )
                        )
                        .frame(width: 16, height: 16)
                        .shadow(color: ColorPalette.primary.opacity(0.3), radius: 2, x: 0, y: 1)
                    
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 6, height: 6)
                }
            }
            
            // Direction info
            if let qiblaDirection = qiblaDirection {
                directionInfo(qiblaDirection)
            }
            
            Spacer()
        }
        .padding()
    }
    
    @ViewBuilder
    private var accuracyIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(compassManager.accuracy.color)
                .frame(width: 12, height: 12)
            
            Text(compassManager.accuracy.description)
                .bodyMedium()
                .foregroundColor(ColorPalette.textSecondary)
            
            if compassManager.accuracy == .low {
                Button("Calibrate") {
                    showingCalibration = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
    
    @ViewBuilder
    private var compassMarkings: some View {
        ForEach(0..<360, id: \.self) { degree in
            if degree % 30 == 0 {
                // Enhanced major markings (every 30 degrees) - more prominent for key directions
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                ColorPalette.primary.opacity(degree % 90 == 0 ? 0.9 : 0.7),
                                ColorPalette.textSecondary.opacity(degree % 90 == 0 ? 0.7 : 0.5)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: degree % 90 == 0 ? 4 : 2.5, height: degree % 90 == 0 ? 30 : 22)
                    .offset(y: -140)
                    .rotationEffect(.degrees(Double(degree)))
            } else if degree % 15 == 0 {
                // Medium markings (every 15 degrees) - added for better orientation
                Rectangle()
                    .fill(ColorPalette.textSecondary.opacity(0.5))
                    .frame(width: 1.5, height: 16)
                    .offset(y: -140)
                    .rotationEffect(.degrees(Double(degree)))
            } else if degree % 10 == 0 {
                // Refined minor markings (every 10 degrees)
                Rectangle()
                    .fill(ColorPalette.textSecondary.opacity(0.4))
                    .frame(width: 1, height: 12)
                    .offset(y: -140)
                    .rotationEffect(.degrees(Double(degree)))
            } else if degree % 5 == 0 {
                // Fine markings (every 5 degrees)
                Rectangle()
                    .fill(ColorPalette.textSecondary.opacity(0.2))
                    .frame(width: 0.5, height: 8)
                    .offset(y: -140)
                    .rotationEffect(.degrees(Double(degree)))
            }
        }
        
        // Enhanced degree markings for orientation (without cardinal direction labels)
        // Primary degree markers (every 90 degrees)
        ForEach([0, 90, 180, 270], id: \.self) { degree in
            VStack(spacing: 1) {
                Text("\(degree)°")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(ColorPalette.textPrimary.opacity(0.8))
            }
            .background(
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 32, height: 32)
                    .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
            )
            .offset(y: -115)
            .rotationEffect(.degrees(Double(degree)))
        }

        // Secondary degree markers (every 45 degrees) for better orientation
        ForEach([45, 135, 225, 315], id: \.self) { degree in
            VStack(spacing: 1) {
                Text("\(degree)°")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(ColorPalette.textSecondary.opacity(0.7))
            }
            .background(
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 0.5)
            )
            .offset(y: -110)
            .rotationEffect(.degrees(Double(degree)))
        }
    }
    
    @ViewBuilder
    private func qiblaNeedle(direction: QiblaDirection) -> some View {
        VStack(spacing: 0) {
            // Premium Qibla arrow tip with gradient and shadow
            Triangle()
                .fill(
                    LinearGradient(
                        colors: [
                            ColorPalette.primary,
                            ColorPalette.primary.opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 20, height: 28)
                .shadow(color: ColorPalette.primary.opacity(0.3), radius: 3, x: 0, y: 2)

            // Prominent needle body with gradient
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            ColorPalette.primary,
                            ColorPalette.secondary
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6, height: 110)
                .shadow(color: ColorPalette.primary.opacity(0.2), radius: 2, x: 0, y: 1)

            // Enhanced Qibla indicator with Islamic symbolism
            VStack(spacing: 4) {
                // Kaaba symbol with Islamic styling
                ZStack {
                    // Background for Kaaba symbol
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black)
                        .frame(width: 16, height: 12)
                    
                    // Golden accent for Kaaba
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ColorPalette.accent.opacity(0.8))
                        .frame(width: 14, height: 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.black)
                                .frame(width: 10, height: 6)
                        )
                }
                
                Text("قِبْلَة")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(ColorPalette.primary)
                
                Text("QIBLA")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.textSecondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                Color.white.opacity(0.85)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ColorPalette.primary.opacity(0.3), lineWidth: 1.5)
                    )
            )
        }
        .offset(y: -40)
        .rotationEffect(.degrees(direction.direction - compassManager.heading))
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: compassManager.heading)
        .accessibilityLabel("Qibla Direction Indicator")
        .accessibilityValue("Pointing \(Int(direction.direction)) degrees toward Mecca")
        .accessibilityHint("Align your device with this indicator to face the Qibla")
    }
    
    @ViewBuilder
    private var deviceHeadingIndicator: some View {
        // Subtle North reference needle for accuracy verification
        VStack(spacing: 0) {
            // Refined north arrow tip - smaller and more subtle
            Triangle()
                .fill(Color.red.opacity(0.7))
                .frame(width: 8, height: 12)

            // Thinner needle body
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.red.opacity(0.7),
                            Color.red.opacity(0.5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2, height: 60)

            // Refined North label with better contrast
            Text("N")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.red.opacity(0.8))
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .offset(y: -135)
        .opacity(0.8) // Make the entire north indicator more subtle
        .animation(.easeInOut(duration: 0.2), value: compassManager.heading)
        .accessibilityLabel("North Reference Needle")
        .accessibilityValue("Pointing toward magnetic north")
        .accessibilityHint("Use this red needle to verify compass accuracy")
    }
    
    @ViewBuilder
    private func directionInfo(_ qiblaDirection: QiblaDirection) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Direction")
                        .font(.caption)
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    Text("\(Int(qiblaDirection.direction))°")
                        .headlineLarge()
                        .foregroundColor(ColorPalette.textPrimary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Distance")
                        .font(.caption)
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    Text(qiblaDirection.formattedDistance)
                        .headlineLarge()
                        .foregroundColor(ColorPalette.textPrimary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorPalette.surface)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            
            VStack(spacing: 12) {
                // Primary instruction with Islamic context
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(ColorPalette.primary)
                        .font(.title3)
                    
                    Text("Align your device with the **Qibla indicator** to face Mecca")
                        .bodySmall()
                        .foregroundColor(ColorPalette.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorPalette.primary.opacity(0.1))
                )

                // Dual indicator explanation
                VStack(spacing: 6) {
                    HStack(spacing: 12) {
                        // Qibla indicator legend
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ColorPalette.primary)
                                .frame(width: 16, height: 8)
                            Text("Qibla Direction")
                                .caption()
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                        
                        Spacer()
                        
                        // North indicator legend
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.red.opacity(0.7))
                                .frame(width: 16, height: 8)
                            Text("North Reference")
                                .caption()
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                    }
                    
                    Text("Use the red north needle to verify compass accuracy")
                        .caption()
                        .foregroundColor(ColorPalette.textSecondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 8)
                
                // Accuracy tip
                if compassManager.accuracy != .high {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .foregroundColor(ColorPalette.warning)
                            .font(.caption)
                        
                        Text("For best accuracy, calibrate your compass and move away from magnetic interference")
                            .caption()
                            .foregroundColor(ColorPalette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ColorPalette.warning.opacity(0.1))
                    )
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadQiblaDirection() async {
        // Update the loading state on the main thread
        await MainActor.run {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            // First, check if we already have a location
            if let location = self.locationService.currentLocation {
                // If we already had a location, calculate the direction
                await MainActor.run {
                    self.qiblaDirection = QiblaDirection.calculate(from: LocationCoordinate(latitude: location.coordinate.latitude, 
                                                                                         longitude: location.coordinate.longitude))
                    self.isLoading = false
                }
                return
            }
            
            // Check current permission status
            let currentPermissionStatus = self.locationService.permissionStatus
            
            // If permission is not determined, request it
            if currentPermissionStatus == .notDetermined {
                let permissionStatus = await self.locationService.requestLocationPermissionAsync()
                
                // Check if permission was granted
                guard permissionStatus == .authorizedWhenInUse || permissionStatus == .authorizedAlways else {
                    // Permission denied or restricted - throw appropriate error
                    let permissionError = LocationError.permissionDenied("Location permission is required to determine Qibla direction. Please enable location access in Settings.")
                    throw permissionError
                }
            } else if currentPermissionStatus == .denied || currentPermissionStatus == .restricted {
                // Permission previously denied
                let permissionError = LocationError.permissionDenied("Location permission is required to determine Qibla direction. Please enable location access in Settings.")
                throw permissionError
            }
            
            // At this point, we should have permission, so request location
            let updatedLocation = try await self.locationService.requestLocation()
            
            // Calculate the direction with the obtained location
            await MainActor.run {
                self.qiblaDirection = QiblaDirection.calculate(from: LocationCoordinate(latitude: updatedLocation.coordinate.latitude, 
                                                                                     longitude: updatedLocation.coordinate.longitude))
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
}



// MARK: - Supporting Views

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct CalibrationView: View {
    let accuracy: CompassAccuracy
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "compass.drawing")
                    .font(.system(size: 80))
                    .foregroundColor(ColorPalette.primary)
                
                Text("Compass Calibration")
                    .headlineLarge()
                
                Text("For accurate Qibla direction, calibrate your compass by moving your device in a figure-8 pattern.")
                    .bodyMedium()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Calibration animation or instructions
                VStack(spacing: 16) {
                    Text("Current Accuracy: \(accuracy.description)")
                        .bodyMedium()
                        .foregroundColor(accuracy.color)
                    
                    if accuracy == .low {
                        Text("Move your device in a figure-8 pattern away from magnetic interference")
                            .bodySmall()
                            .foregroundColor(ColorPalette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Calibration")
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
}

// MARK: - Compass Manager

@MainActor
private class CompassManager: ObservableObject {
    @Published var heading: Double = 0
    @Published var accuracy: CompassAccuracy = .unknown
    
    private let locationService: any LocationServiceProtocol
    private var headingCancellable: AnyCancellable?
    
    init(locationService: any LocationServiceProtocol) {
        self.locationService = locationService
        setupHeadingSubscription()
    }
    
    private func setupHeadingSubscription() {
        headingCancellable = locationService.headingPublisher
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Compass: Heading update failed: \(error)")
                    }
                },
                receiveValue: { [weak self] newHeading in
                    self?.processHeading(newHeading)
                }
            )
    }
    
    private func processHeading(_ newHeading: CLHeading) {
        heading = newHeading.magneticHeading
        
        // Update accuracy based on heading accuracy
        if newHeading.headingAccuracy < 0 {
            accuracy = .unknown
        } else if newHeading.headingAccuracy < 5 {
            accuracy = .high
        } else if newHeading.headingAccuracy < 15 {
            accuracy = .medium
        } else {
            accuracy = .low
        }
    }
    
    func startUpdating() {
        guard CLLocationManager.headingAvailable() else { 
            print("❌ Compass: Heading not available")
            return 
        }
        
        // Check location authorization for compass using the shared location service
        let authStatus = locationService.permissionStatus
        guard authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways else {
            print("❌ Compass: Location permission required for compass functionality. Current status: \(authStatus)")
            return
        }
        
        locationService.startUpdatingHeading()
        print("🧭 Compass: Started updating heading via LocationService")
    }
    
    func stopUpdating() {
        locationService.stopUpdatingHeading()
        print("🧭 Compass: Stopped updating heading via LocationService")
    }
    
    deinit {
        headingCancellable?.cancel()
    }
}

// MARK: - Supporting Types

public enum CompassAccuracy {
    case unknown, low, medium, high
    
    var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .low: return "Low Accuracy"
        case .medium: return "Medium Accuracy"
        case .high: return "High Accuracy"
        }
    }
    
    var color: Color {
        switch self {
        case .unknown: return .gray
        case .low: return .red
        case .medium: return .orange
        case .high: return .green
        }
    }
}

