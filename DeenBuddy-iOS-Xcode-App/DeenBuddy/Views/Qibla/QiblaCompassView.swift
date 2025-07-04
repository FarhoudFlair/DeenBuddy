import SwiftUI
import CoreLocation
import CoreMotion

// MARK: - Qibla Compass View

struct QiblaCompassView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var compassManager = CompassManager()

    let onDismiss: () -> Void

    @State private var qiblaDirection: QiblaDirection?
    @State private var isLoading = true
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

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Finding Qibla direction...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                } else if let error = error {
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

            // Qibla needle (green arrow)
            if let qiblaDirection = qiblaDirection {
                qiblaNeedle(direction: qiblaDirection)
            }

            // Device heading indicator (red needle)
            deviceHeadingIndicator

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
                        Text(compassManager.accuracy.displayName)
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
        // Green arrow pointing to Qibla
        Rectangle()
            .fill(Color.green)
            .frame(width: 3, height: 80)
            .offset(y: -40)
            .rotationEffect(.degrees(direction.direction - compassManager.heading))
            .animation(.easeInOut(duration: 0.3), value: compassManager.heading)
    }

    @ViewBuilder
    private var deviceHeadingIndicator: some View {
        // Red needle showing device heading (North)
        Rectangle()
            .fill(Color.red)
            .frame(width: 2, height: 60)
            .offset(y: -30)
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
        isLoading = true
        error = nil

        locationManager.requestLocationPermission { result in
            switch result {
            case .success(let location):
                self.qiblaDirection = QiblaDirection.calculate(from: location.coordinate)
                self.isLoading = false
            case .failure(let locationError):
                self.error = locationError.localizedDescription
                self.isLoading = false
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

// MARK: - Extensions

extension CompassAccuracy {
    var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        case .unknown: return "Unknown"
        }
    }
}
