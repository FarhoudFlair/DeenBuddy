import SwiftUI
import CoreLocation
import CoreMotion

// MARK: - Qibla Compass View

struct QiblaCompassView: View {
    @StateObject private var locationService = LocationService()
    @StateObject private var qiblaCache = QiblaDirectionCache()
    @StateObject private var compassManager = CompassManager()

    let onDismiss: () -> Void

    @State private var qiblaDirection: QiblaDirection?
    @State private var optimisticDirection: QiblaDirection? // Shows immediately from cache
    @State private var isLoading = true
    @State private var isUpdatingInBackground = false
    @State private var error: String?
    @State private var showingCalibration = false

    var body: some View {
        ZStack {
            // Dark starry background
            StarryBackgroundView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top location card
                if let qiblaDirection = qiblaDirection {
                    LocationInfoCard(qiblaDirection: qiblaDirection)
                        .padding(.horizontal, 20)
                        .padding(.top, 60) // Account for status bar
                }

                Spacer()

                if isLoading && optimisticDirection == nil {
                    // Show Islamic-themed skeleton instead of loading spinner
                    QiblaCompassSkeleton()
                } else if let error = error, qiblaDirection == nil {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)

                        Text("Unable to Find Qibla")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text(error)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Retry") {
                            loadQiblaDirection()
                        }
                        .buttonStyle(ModernButtonStyle())
                    }
                } else {
                    compassContent
                }

                Spacer()

                // Bottom controls
                bottomControls
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadQiblaDirection()
            compassManager.startUpdating()
        }
        .onDisappear {
            compassManager.stopUpdating()
        }
    }
    
    @ViewBuilder
    private var compassContent: some View {
        // Modern compass design matching mockup
        ZStack {
            // Outer compass ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 280, height: 280)

            // Inner compass background
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.4),
                            Color.black.opacity(0.2)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)

            // Compass markings
            compassMarkings

            // Cardinal direction labels
            cardinalDirections

            // North reference needle (red arrow pointing to magnetic North)
            northReferenceNeedle

            // Qibla direction indicator (green arrow pointing to Qibla)
            if let qiblaDirection = qiblaDirection {
                qiblaNeedle(direction: qiblaDirection)
            }

            // Yellow Kaaba icon
            kaabaIcon

            // Center dot
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
        }
    }
    
    @ViewBuilder
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Compass accuracy and direction info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Compass Accuracy")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    HStack(spacing: 8) {
                        Text(compassManager.accuracy.description)
                            .font(.body)
                            .foregroundColor(.white)

                        Circle()
                            .fill(compassManager.accuracy == .low ? .red : .green)
                            .frame(width: 8, height: 8)
                    }
                }

                Spacer()

                if compassManager.accuracy == .low {
                    Button("Calibrate") {
                        showingCalibration = true
                    }
                    .buttonStyle(CalibrateButtonStyle())
                }
            }

            // Qibla direction info
            if let qiblaDirection = qiblaDirection {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("QIBLA DIRECTION")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        Text("\(Int(qiblaDirection.direction))°")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.cyan)
                    }

                    Spacer()
                }
            }
        }
    }
    
    @ViewBuilder
    private var compassMarkings: some View {
        ForEach(0..<360, id: \.self) { degree in
            if degree % 30 == 0 {
                Rectangle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 1, height: degree % 90 == 0 ? 16 : 8)
                    .offset(y: -132)
                    .rotationEffect(.degrees(Double(degree)))
            }
        }
    }

    @ViewBuilder
    private var cardinalDirections: some View {
        // North
        Text("N")
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .offset(y: -110)

        // East
        Text("E")
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .offset(x: 110)

        // South
        Text("S")
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .offset(y: 110)

        // West
        Text("W")
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .offset(x: -110)
    }
    
    @ViewBuilder
    private func qiblaNeedle(direction: QiblaDirection) -> some View {
        // Enhanced GREEN Qibla direction indicator
        VStack(spacing: 0) {
            // Arrow tip pointing to Qibla
            Triangle()
                .fill(Color.green)
                .frame(width: 12, height: 16)

            // Thick green line body
            Rectangle()
                .fill(Color.green)
                .frame(width: 4, height: 90)

            // Qibla label
            Text("QIBLA")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.green)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.7))
                        .frame(width: 40, height: 16)
                )
        }
        .offset(y: -45)
        .rotationEffect(.degrees(direction.direction - compassManager.heading))
        .animation(.easeInOut(duration: 0.3), value: compassManager.heading)
    }

    @ViewBuilder
    private var northReferenceNeedle: some View {
        // Enhanced North reference needle (red arrow pointing to magnetic North)
        VStack(spacing: 0) {
            // Arrow tip pointing to North
            Triangle()
                .fill(Color.red)
                .frame(width: 10, height: 14)

            // Red needle body
            Rectangle()
                .fill(Color.red)
                .frame(width: 3, height: 70)

            // North label
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
        .offset(y: -35)
        // North needle always points up (0 degrees) relative to device orientation
    }

    @ViewBuilder
    private var kaabaIcon: some View {
        // Yellow Kaaba icon positioned on the compass
        if let qiblaDirection = qiblaDirection {
            Image(systemName: "house.fill")
                .font(.system(size: 20))
                .foregroundColor(.yellow)
                .background(
                    Circle()
                        .fill(Color.black)
                        .frame(width: 32, height: 32)
                )
                .offset(
                    x: cos((qiblaDirection.direction - compassManager.heading - 90) * .pi / 180) * 100,
                    y: sin((qiblaDirection.direction - compassManager.heading - 90) * .pi / 180) * 100
                )
                .animation(.easeInOut(duration: 0.3), value: compassManager.heading)
        }
    }
    
    // MARK: - Private Methods

    private func loadQiblaDirection() {
        loadQiblaDirectionOptimistically()
    }

    /// Optimistic Qibla loading - shows cached direction immediately, updates in background
    private func loadQiblaDirectionOptimistically() {
        error = nil

        // Try to get cached direction first for instant response (<50ms)
        if let currentLocation = locationService.currentLocation,
           let cached = qiblaCache.getCachedDirection(for: currentLocation) {
            optimisticDirection = cached
            qiblaDirection = cached
            isLoading = false
            isUpdatingInBackground = true
        } else {
            isLoading = true
        }

        // Get fresh location and calculate in background
        locationService.requestLocationPermission()
        locationService.startUpdatingLocation()
        
        // Use async approach with proper timing
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            if let location = locationService.currentLocation {
                // Check cache again with fresh location
                if let cached = self.qiblaCache.getCachedDirection(for: location) {
                    await MainActor.run {
                        self.qiblaDirection = cached
                        self.optimisticDirection = nil
                        self.isLoading = false
                        self.isUpdatingInBackground = false
                    }
                } else {
                    // Calculate fresh direction
                    let freshDirection = QiblaDirection.calculate(from: LocationCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))

                    // Cache the result for future instant access
                    self.qiblaCache.cacheDirection(freshDirection, for: location)

                    await MainActor.run {
                        self.qiblaDirection = freshDirection
                        self.optimisticDirection = nil
                        self.isLoading = false
                        self.isUpdatingInBackground = false
                    }
                }
            } else {
                // Handle location error
                await MainActor.run {
                    if self.optimisticDirection == nil {
                        self.error = "Unable to get location"
                        self.isLoading = false
                    }
                    self.isUpdatingInBackground = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StarryBackgroundView: View {
    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.15, blue: 0.25),
                    Color(red: 0.05, green: 0.1, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Stars
            ForEach(0..<50, id: \.self) { _ in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.3...0.8)))
                    .frame(width: Double.random(in: 1...3))
                    .position(
                        x: Double.random(in: 0...UIScreen.main.bounds.width),
                        y: Double.random(in: 0...UIScreen.main.bounds.height)
                    )
            }
        }
    }
}

struct LocationInfoCard: View {
    let qiblaDirection: QiblaDirection

    var body: some View {
        VStack(spacing: 8) {
            Text("London, UK")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("51.5074° N, 0.1278° W")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

            Text("Distance to Mecca: \(qiblaDirection.formattedDistance)")
                .font(.subheadline)
                .foregroundColor(.cyan)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct ModernButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CalibrateButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .fontWeight(.medium)
            .foregroundColor(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.cyan)
            .cornerRadius(20)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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

/// Triangle shape for compass needles
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

// CompassAccuracy and QiblaDirectionCache are now imported from their proper locations
