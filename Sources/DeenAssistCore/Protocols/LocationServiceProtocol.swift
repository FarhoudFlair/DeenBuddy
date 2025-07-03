import Foundation
import Combine

// MARK: - Location Service Protocol

public protocol LocationServiceProtocol: ObservableObject {
    /// Current location permission status
    var permissionStatus: LocationPermissionStatus { get }
    
    /// Current location information
    var currentLocation: LocationInfo? { get }
    
    /// Whether location services are currently active
    var isLocationActive: Bool { get }
    
    /// Publisher for location updates
    var locationPublisher: AnyPublisher<LocationInfo, LocationError> { get }
    
    /// Publisher for permission status changes
    var permissionPublisher: AnyPublisher<LocationPermissionStatus, Never> { get }
    
    /// Request location permission from user
    func requestLocationPermission() async -> LocationPermissionStatus
    
    /// Get current location once
    func getCurrentLocation() async throws -> LocationInfo
    
    /// Start continuous location updates
    func startLocationUpdates()
    
    /// Stop continuous location updates
    func stopLocationUpdates()
    
    /// Search for a city by name and return coordinates
    func searchCity(_ cityName: String) async throws -> [LocationInfo]
    
    /// Get location information from coordinates (reverse geocoding)
    func getLocationInfo(for coordinate: LocationCoordinate) async throws -> LocationInfo
    
    /// Check if location services are available on device
    func isLocationServicesAvailable() -> Bool
    
    /// Get cached location if available
    func getCachedLocation() -> LocationInfo?
    
    /// Clear cached location data
    func clearLocationCache()
}

// MARK: - Default Implementation Helpers

public extension LocationServiceProtocol {
    /// Check if current location is recent (within last 5 minutes)
    var isCurrentLocationRecent: Bool {
        guard let location = currentLocation else { return false }
        return Date().timeIntervalSince(location.timestamp) < 300 // 5 minutes
    }
    
    /// Check if current location has good accuracy (< 100m)
    var hasGoodAccuracy: Bool {
        guard let location = currentLocation else { return false }
        return location.accuracy < 100
    }
    
    /// Get best available location (current or cached)
    func getBestAvailableLocation() -> LocationInfo? {
        if let current = currentLocation, isCurrentLocationRecent && hasGoodAccuracy {
            return current
        }
        return getCachedLocation()
    }
}
