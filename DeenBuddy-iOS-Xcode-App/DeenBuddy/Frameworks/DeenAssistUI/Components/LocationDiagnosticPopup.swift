import SwiftUI
import CoreLocation
import DeenAssistCore
import DeenAssistProtocols

/// Diagnostic popup showing detailed location information
public struct LocationDiagnosticPopup: View {
    let location: CLLocation
    let locationService: any LocationServiceProtocol
    @Binding var isPresented: Bool
    
    @State private var locationInfo: LocationInfo?
    @State private var isLoadingLocationInfo = false
    
    public init(
        location: CLLocation,
        locationService: any LocationServiceProtocol,
        isPresented: Binding<Bool>
    ) {
        self.location = location
        self.locationService = locationService
        self._isPresented = isPresented
    }
    
    public var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // Popup content
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Location Diagnostics")
                        .titleMedium()
                        .foregroundColor(ColorPalette.textPrimary)
                    
                    Spacer()
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(ColorPalette.textTertiary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                Divider()
                    .background(ColorPalette.textTertiary.opacity(0.3))
                
                // Content
                ScrollView {
                    VStack(spacing: 16) {
                        // Location Display Name
                        if isLoadingLocationInfo {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Getting location name...")
                                    .bodyMedium()
                                    .foregroundColor(ColorPalette.textSecondary)
                            }
                            .padding(.vertical, 8)
                        } else if let locationInfo = locationInfo {
                            DiagnosticRow(
                                title: "Location",
                                value: locationDisplayName(from: locationInfo),
                                icon: "location.fill"
                            )
                        }
                        
                        // Coordinates
                        DiagnosticRow(
                            title: "Coordinates",
                            value: String(format: "%.6f°, %.6f°", location.coordinate.latitude, location.coordinate.longitude),
                            icon: "globe"
                        )
                        
                        // Accuracy
                        DiagnosticRow(
                            title: "Accuracy",
                            value: String(format: "±%.1f meters", location.horizontalAccuracy),
                            icon: "target"
                        )
                        
                        // Cache Status
                        DiagnosticRow(
                            title: "Cache Status",
                            value: cacheStatusText,
                            icon: cacheStatusIcon
                        )
                        
                        // Cache Age (if applicable)
                        if locationService.isCurrentLocationFromCache(),
                           let age = locationService.getLocationAge() {
                            DiagnosticRow(
                                title: "Cache Age",
                                value: formatCacheAge(age),
                                icon: "clock"
                            )
                        }
                        
                        // Timestamp
                        DiagnosticRow(
                            title: "Last Updated",
                            value: formatTimestamp(location.timestamp),
                            icon: "calendar"
                        )
                        
                        // Additional technical details
                        if location.altitude > 0 {
                            DiagnosticRow(
                                title: "Altitude",
                                value: String(format: "%.1f meters", location.altitude),
                                icon: "mountain.2"
                            )
                        }
                        
                        if location.speed >= 0 {
                            DiagnosticRow(
                                title: "Speed",
                                value: String(format: "%.1f m/s", location.speed),
                                icon: "speedometer"
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                
                // Footer
                Divider()
                    .background(ColorPalette.textTertiary.opacity(0.3))
                
                HStack {
                    Spacer()
                    
                    CustomButton.secondary("Close") {
                        isPresented = false
                    }
                    .frame(width: 100)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(ColorPalette.surfacePrimary)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 32)
            .frame(maxHeight: 600)
        }
        .onAppear {
            loadLocationInfo()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadLocationInfo() {
        guard !isLoadingLocationInfo else { return }
        
        isLoadingLocationInfo = true
        
        Task {
            do {
                let coordinate = LocationCoordinate(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                let info = try await locationService.getLocationInfo(for: coordinate)
                
                await MainActor.run {
                    self.locationInfo = info
                    self.isLoadingLocationInfo = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingLocationInfo = false
                }
            }
        }
    }
    
    private func locationDisplayName(from locationInfo: LocationInfo) -> String {
        if let city = locationInfo.city, let country = locationInfo.country {
            return "\(city), \(country)"
        } else if let city = locationInfo.city {
            return city
        } else if let country = locationInfo.country {
            return country
        } else {
            return "Unknown Location"
        }
    }
    
    private var cacheStatusText: String {
        return locationService.isCurrentLocationFromCache() ? "Cached" : "Fresh"
    }
    
    private var cacheStatusIcon: String {
        return locationService.isCurrentLocationFromCache() ? "externaldrive" : "wifi"
    }
    
    private func formatCacheAge(_ age: TimeInterval) -> String {
        let minutes = Int(age / 60)
        let seconds = Int(age.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s ago"
        } else {
            return "\(seconds)s ago"
        }
    }
    
    private func formatTimestamp(_ timestamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

// MARK: - Diagnostic Row Component

private struct DiagnosticRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(ColorPalette.primary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .bodySmall()
                    .foregroundColor(ColorPalette.textSecondary)
                
                Text(value)
                    .bodyMedium()
                    .foregroundColor(ColorPalette.textPrimary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ColorPalette.surfaceSecondary)
        )
    }
}

// MARK: - Preview

#Preview("Location Diagnostic Popup") {
    LocationDiagnosticPopup(
        location: CLLocation(latitude: 40.7128, longitude: -74.0060),
        locationService: MockLocationService(),
        isPresented: .constant(true)
    )
}
