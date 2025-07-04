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
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color.green.opacity(0.1),
                        Color.blue.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Finding Qibla direction...")
                            .font(.headline)
                    }
                } else if let error = error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("Unable to Find Qibla")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(error)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Retry") {
                            loadQiblaDirection()
                        }
                        .buttonStyle(.borderedProminent)
                    }
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
            loadQiblaDirection()
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
                                Color.gray.opacity(0.1)
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
                    .fill(Color.green)
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
                .font(.body)
                .foregroundColor(.secondary)
            
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
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 2, height: degree % 90 == 0 ? 20 : 15)
                    .offset(y: -140)
                    .rotationEffect(.degrees(Double(degree)))
            }
        }
    }
    
    @ViewBuilder
    private func qiblaNeedle(direction: QiblaDirection) -> some View {
        VStack {
            // Arrow pointing to Qibla
            Image(systemName: "location.north.fill")
                .font(.system(size: 30))
                .foregroundColor(.green)
                .offset(y: -120)
            
            Spacer()
        }
        .rotationEffect(.degrees(direction.direction - compassManager.heading))
        .animation(.easeInOut(duration: 0.3), value: compassManager.heading)
    }
    
    @ViewBuilder
    private var deviceHeadingIndicator: some View {
        VStack {
            Image(systemName: "triangle.fill")
                .font(.system(size: 15))
                .foregroundColor(.red)
                .offset(y: -135)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func directionInfo(_ qiblaDirection: QiblaDirection) -> some View {
        VStack(spacing: 8) {
            Text("\(Int(qiblaDirection.direction))° \(qiblaDirection.compassDirection)")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Distance: \(qiblaDirection.formattedDistance)")
                .font(.body)
                .foregroundColor(.secondary)
            
            Text("Point your device towards the green arrow to face Qibla")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
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
