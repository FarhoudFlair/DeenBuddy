import SwiftUI
import CoreMotion
import CoreLocation

/// Qibla Compass screen with real-time direction to Kaaba
public struct QiblaCompassScreen: View {
    private let locationService: any LocationServiceProtocol
    @StateObject private var compassManager = CompassManager()
    
    let onDismiss: () -> Void
    
    @State private var qiblaDirection: QiblaDirection?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var showingCalibration = false
    @State private var compassAccuracy: CompassAccuracy = .unknown
    
    public init(
        locationService: any LocationServiceProtocol,
        onDismiss: @escaping () -> Void
    ) {
        self.locationService = locationService
        self.onDismiss = onDismiss
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
                    accuracy: compassAccuracy,
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
                
                // Qibla needle
                if let qiblaDirection = qiblaDirection {
                    qiblaNeedle(direction: qiblaDirection)
                }
                
                // Device heading indicator
                deviceHeadingIndicator
                
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
                .fill(compassAccuracy.color)
                .frame(width: 12, height: 12)
            
            Text(compassAccuracy.description)
                .bodyMedium()
                .foregroundColor(ColorPalette.textSecondary)
            
            if compassAccuracy == .low {
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
            // Needle tip
            Triangle()
                .fill(ColorPalette.accent)
                .frame(width: 16, height: 24)
            
            // Needle body
            Rectangle()
                .fill(ColorPalette.accent)
                .frame(width: 4, height: 100)
            
            // Kaaba symbol
            Image(systemName: "house.fill")
                .font(.title2)
                .foregroundColor(ColorPalette.accent)
                .background(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 32, height: 32)
                )
        }
        .offset(y: -50)
        .rotationEffect(.degrees(direction.direction - compassManager.heading))
        .animation(.easeInOut(duration: 0.3), value: compassManager.heading)
    }
    
    @ViewBuilder
    private var deviceHeadingIndicator: some View {
        VStack(spacing: 0) {
            Triangle()
                .fill(ColorPalette.primary)
                .frame(width: 12, height: 16)
            
            Rectangle()
                .fill(ColorPalette.primary)
                .frame(width: 2, height: 30)
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
            
            Text("Point your device towards the green arrow to face Qibla")
                .bodySmall()
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
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
            guard let location = self.locationService.currentLocation else {
                // If not, request permission and the location
                _ = await self.locationService.requestLocationPermission()
                guard let updatedLocation = self.locationService.currentLocation else {
                    // If it's still unavailable, set an error
                    await MainActor.run {
                        self.error = NSError(domain: "LocationError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to determine your location"])
                    }
                    return
                }
                // If successful, calculate the direction
                await MainActor.run {
                    self.qiblaDirection = QiblaDirection.calculate(from: LocationCoordinate(latitude: updatedLocation.coordinate.latitude, 
                                                                                         longitude: updatedLocation.coordinate.longitude))
                    self.isLoading = false
                }
                return
            }
            
            // If we already had a location, calculate the direction
            await MainActor.run {
                self.qiblaDirection = QiblaDirection.calculate(from: LocationCoordinate(latitude: location.coordinate.latitude, 
                                                                                     longitude: location.coordinate.longitude))
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
private class CompassManager: NSObject, ObservableObject {
    @Published var heading: Double = 0
    @Published var accuracy: CompassAccuracy = .unknown
    
    private let motionManager = CMMotionManager()
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    func startUpdating() {
        guard CLLocationManager.headingAvailable() else { return }
        
        locationManager.startUpdatingHeading()
    }
    
    func stopUpdating() {
        locationManager.stopUpdatingHeading()
    }
}

extension CompassManager: @preconcurrency CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
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

