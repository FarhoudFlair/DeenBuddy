import Foundation
import CoreLocation

/// Protocol for location services used throughout the app
public protocol LocationServiceProtocol: ObservableObject {
    /// Current location authorization status
    var authorizationStatus: CLAuthorizationStatus { get }
    
    /// Current user location
    var currentLocation: CLLocation? { get }
    
    /// Whether location services are currently updating
    var isUpdatingLocation: Bool { get }
    
    /// Any location-related error
    var locationError: Error? { get }
    
    /// Request location permission from user
    func requestLocationPermission()
    
    /// Start updating location
    func startUpdatingLocation()
    
    /// Stop updating location
    func stopUpdatingLocation()
    
    /// Get location for a specific city name
    func geocodeCity(_ cityName: String) async throws -> CLLocation
}

/// Location-related errors
public enum LocationError: LocalizedError {
    case permissionDenied
    case locationUnavailable
    case geocodingFailed
    case networkError
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission denied"
        case .locationUnavailable:
            return "Location unavailable"
        case .geocodingFailed:
            return "Failed to find location for city"
        case .networkError:
            return "Network error while getting location"
        }
    }
}
