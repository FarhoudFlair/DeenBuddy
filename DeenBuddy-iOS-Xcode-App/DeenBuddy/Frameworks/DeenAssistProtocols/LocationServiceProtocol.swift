import Foundation
import CoreLocation
import Combine

/// Protocol for location services used throughout the app
@MainActor
public protocol LocationServiceProtocol: ObservableObject {
    /// Current location authorization status
    var authorizationStatus: CLAuthorizationStatus { get }
    
    /// Current user location
    var currentLocation: CLLocation? { get }
    
    /// Whether location services are currently updating
    var isUpdatingLocation: Bool { get }
    
    /// Any location-related error
    var locationError: Error? { get }
    
    /// Current heading in degrees (0-360)
    var currentHeading: Double { get }
    
    /// Heading accuracy in degrees
    var headingAccuracy: Double { get }
    
    /// Whether heading services are currently updating
    var isUpdatingHeading: Bool { get }
    
    /// Publisher for location updates
    var locationPublisher: AnyPublisher<CLLocation, Error> { get }
    
    /// Publisher for heading updates
    var headingPublisher: AnyPublisher<CLHeading, Error> { get }
    
    /// Permission status for easier access
    var permissionStatus: CLAuthorizationStatus { get }
    
    /// Request location permission from user
    func requestLocationPermission()

    /// Request location permission from user and wait for result
    func requestLocationPermissionAsync() async -> CLAuthorizationStatus

    /// Request current location once
    func requestLocation() async throws -> CLLocation
    
    /// Start updating location
    func startUpdatingLocation()
    
    /// Stop updating location
    func stopUpdatingLocation()
    
    /// Start updating heading for compass functionality
    func startUpdatingHeading()
    
    /// Stop updating heading
    func stopUpdatingHeading()
    
    /// Get location for a specific city name
    func geocodeCity(_ cityName: String) async throws -> CLLocation
}

/// Location-related errors
public enum LocationError: LocalizedError {
    case permissionDenied(String)
    case locationUnavailable(String)
    case geocodingFailed(String)
    case networkError(String)
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let message):
            return message
        case .locationUnavailable(let message):
            return message
        case .geocodingFailed(let message):
            return message
        case .networkError(let message):
            return message
        }
    }
}
