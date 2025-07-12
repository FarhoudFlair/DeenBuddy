import SwiftUI
import CoreMotion
import CoreLocation
import Combine

/// Qibla Compass screen with real-time direction to Kaaba
public struct QiblaCompassScreen: View {
    private let locationService: any LocationServiceProtocol
    @StateObject private var compassManager: CompassManager
    
    let onDismiss: () -> Void
    
    @State private var qiblaDirection: QiblaDirection?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var showingCalibration = false
    
    public init(
        locationService: any LocationServiceProtocol,
        onDismiss: @escaping () -> Void
    ) {
        self.locationService = locationService
        self.onDismiss = onDismiss
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
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
            
            // Main compass
            ZStack {
                // Compass background
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.9),
                                ColorPalette.surface.opacity(0.8)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                
                // Compass markings
                compassMarkings
                
                // North reference needle (red arrow pointing to magnetic North)
                deviceHeadingIndicator

                // Qibla direction indicator (green arrow pointing to Qibla)
                if let qiblaDirection = qiblaDirection {
                    qiblaNeedle(direction: qiblaDirection)
                }
                
                // Center dot
                Circle()
                    .fill(ColorPalette.primary)
                    .frame(width: 12, height: 12)
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
                // Major markings (every 30 degrees)
                Rectangle()
                    .fill(ColorPalette.textSecondary)
                    .frame(width: 2, height: degree % 90 == 0 ? 20 : 15)
                    .offset(y: -140)
                    .rotationEffect(.degrees(Double(degree)))
            } else if degree % 10 == 0 {
                // Minor markings (every 10 degrees)
                Rectangle()
                    .fill(ColorPalette.textSecondary.opacity(0.5))
                    .frame(width: 1, height: 10)
                    .offset(y: -140)
                    .rotationEffect(.degrees(Double(degree)))
            }
        }
        
        // Cardinal directions
        ForEach(["N", "E", "S", "W"], id: \.self) { direction in
            Text(direction)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(ColorPalette.textPrimary)
                .offset(y: -120)
                .rotationEffect(.degrees(Double(["N": 0, "E": 90, "S": 180, "W": 270][direction] ?? 0)))
        }
    }
    
    @ViewBuilder
    private func qiblaNeedle(direction: QiblaDirection) -> some View {
        VStack(spacing: 0) {
            // Enhanced GREEN Qibla arrow tip
            Triangle()
                .fill(Color.green)
                .frame(width: 16, height: 24)

            // Thick green needle body
            Rectangle()
                .fill(Color.green)
                .frame(width: 5, height: 100)

            // Qibla label and Kaaba symbol
            VStack(spacing: 2) {
                Text("QIBLA")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)

                Image(systemName: "house.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.7))
                    .frame(width: 50, height: 40)
            )
        }
        .offset(y: -50)
        .rotationEffect(.degrees(direction.direction - compassManager.heading))
        .animation(.easeInOut(duration: 0.3), value: compassManager.heading)
    }
    
    @ViewBuilder
    private var deviceHeadingIndicator: some View {
        // Enhanced North reference needle (red arrow pointing to magnetic North)
        VStack(spacing: 0) {
            Triangle()
                .fill(Color.red)
                .frame(width: 12, height: 16)

            Rectangle()
                .fill(Color.red)
                .frame(width: 3, height: 70)

            // North label for accuracy verification
            Text("N")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.red)
                .background(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                )
        }
        .offset(y: -135)
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
            
            VStack(spacing: 8) {
                Text("Point your device towards the GREEN arrow to face Qibla")
                    .bodySmall()
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)

                Text("RED needle points to North for accuracy verification")
                    .caption()
                    .foregroundColor(ColorPalette.textSecondary.opacity(0.8))
                    .multilineTextAlignment(.center)
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

