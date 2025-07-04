import Foundation
import CoreLocation
import SwiftUI

// MARK: - Qibla Direction Models

struct QiblaDirection {
    let direction: Double // Degrees from North (0-360)
    let distance: Double // Distance to Kaaba in kilometers
    let location: CLLocationCoordinate2D
    let timestamp: Date
    
    init(
        direction: Double,
        distance: Double,
        location: CLLocationCoordinate2D,
        timestamp: Date = Date()
    ) {
        self.direction = direction
        self.distance = distance
        self.location = location
        self.timestamp = timestamp
    }
    
    var directionRadians: Double {
        return direction * .pi / 180.0
    }
    
    var compassDirection: String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                         "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((direction + 11.25) / 22.5) % 16
        return directions[index]
    }
    
    var formattedDistance: String {
        if distance < 1000 {
            return String(format: "%.0f km", distance)
        } else {
            return String(format: "%.1f km", distance)
        }
    }

    /// Calculate Qibla direction from a given coordinate
    static func calculate(from location: CLLocationCoordinate2D) -> QiblaDirection {
        return KaabaLocation.calculateDirection(from: location)
    }
}

// MARK: - Kaaba Constants

struct KaabaLocation {
    static let coordinate = CLLocationCoordinate2D(
        latitude: 21.4225, // Kaaba latitude
        longitude: 39.8262 // Kaaba longitude
    )
    
    static func calculateDirection(from location: CLLocationCoordinate2D) -> QiblaDirection {
        let lat1 = location.latitude * .pi / 180
        let lat2 = KaabaLocation.coordinate.latitude * .pi / 180
        let deltaLon = (KaabaLocation.coordinate.longitude - location.longitude) * .pi / 180
        
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        var bearing = atan2(y, x) * 180 / .pi
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)
        
        let distance = calculateDistance(from: location, to: KaabaLocation.coordinate)
        
        return QiblaDirection(
            direction: bearing,
            distance: distance,
            location: location
        )
    }
    
    private static func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let earthRadius = 6371.0 // Earth's radius in kilometers
        
        let lat1Rad = from.latitude * .pi / 180
        let lat2Rad = to.latitude * .pi / 180
        let deltaLatRad = (to.latitude - from.latitude) * .pi / 180
        let deltaLonRad = (to.longitude - from.longitude) * .pi / 180
        
        let a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(deltaLonRad / 2) * sin(deltaLonRad / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return earthRadius * c
    }
}

// MARK: - Compass Accuracy

enum CompassAccuracy {
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

// MARK: - Location Error

enum LocationError: LocalizedError {
    case permissionDenied
    case locationUnavailable
    case timeout
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission is required to calculate Qibla direction"
        case .locationUnavailable:
            return "Unable to determine your current location"
        case .timeout:
            return "Location request timed out"
        case .networkError:
            return "Network error occurred while getting location"
        }
    }
}

// MARK: - Calibration View

struct CalibrationView: View {
    let accuracy: CompassAccuracy
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "compass.drawing")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("Compass Calibration")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("For accurate Qibla direction, calibrate your compass by moving your device in a figure-8 pattern.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Calibration animation or instructions
                VStack(spacing: 16) {
                    Text("Current Accuracy: \(accuracy.description)")
                        .font(.body)
                        .foregroundColor(accuracy.color)
                    
                    if accuracy == .low {
                        Text("Move your device in a figure-8 pattern away from magnetic interference")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
