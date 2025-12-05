import Foundation
import CoreLocation
import Combine

// MARK: - Location Models

public struct LocationCoordinate: Codable, Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public init(from clLocation: CLLocationCoordinate2D) {
        self.latitude = clLocation.latitude
        self.longitude = clLocation.longitude
    }

    public var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

public struct LocationInfo: Codable, Equatable {
    public let coordinate: LocationCoordinate
    public let accuracy: Double
    public let timestamp: Date
    public let city: String?
    public let country: String?

    public init(
        coordinate: LocationCoordinate,
        accuracy: Double,
        timestamp: Date = Date(),
        city: String? = nil,
        country: String? = nil
    ) {
        self.coordinate = coordinate
        self.accuracy = accuracy
        self.timestamp = timestamp
        self.city = city
        self.country = country
    }
}

/// Protocol for location services used throughout the app
@MainActor
public protocol LocationServiceProtocol: ObservableObject {
    /// Current location authorization status
    var authorizationStatus: CLAuthorizationStatus { get }
    
    /// Current user location
    var currentLocation: CLLocation? { get }

    /// Current location info with city and country if available
    var currentLocationInfo: LocationInfo? { get }

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
    
    /// Start background location updates for traveler mode (shows status bar indicator)
    func startBackgroundLocationUpdates()
    
    /// Stop background location updates
    func stopBackgroundLocationUpdates()
    
    /// Start updating heading for compass functionality
    func startUpdatingHeading()
    
    /// Stop updating heading
    func stopUpdatingHeading()
    
    /// Get location for a specific city name
    func geocodeCity(_ cityName: String) async throws -> CLLocation

    /// Search for cities by name
    func searchCity(_ cityName: String) async throws -> [LocationInfo]

    /// Get location info (city, country) for coordinates
    func getLocationInfo(for coordinate: LocationCoordinate) async throws -> LocationInfo

    /// Get cached location if available
    func getCachedLocation() -> CLLocation?

    /// Check if cached location is valid and recent enough to use
    func isCachedLocationValid() -> Bool

    /// Get location preferring cached if valid, otherwise request fresh
    func getLocationPreferCached() async throws -> CLLocation

    /// Set a manual location (e.g., from city search) and notify subscribers
    func setManualLocation(_ location: CLLocation) async

    /// Check if current location is from cache
    func isCurrentLocationFromCache() -> Bool

    /// Get location age in seconds
    func getLocationAge() -> TimeInterval?
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
