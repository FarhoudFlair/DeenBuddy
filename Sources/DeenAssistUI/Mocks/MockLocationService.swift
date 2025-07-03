import Foundation
import CoreLocation
import DeenAssistProtocols

/// Mock implementation of LocationServiceProtocol for UI development
@MainActor
public class MockLocationService: LocationServiceProtocol {
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var currentLocation: CLLocation? = nil
    @Published public var isUpdatingLocation: Bool = false
    @Published public var locationError: Error? = nil
    
    public init() {}
    
    public func requestLocationPermission() {
        // Simulate permission request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.authorizationStatus = .authorizedWhenInUse
        }
    }
    
    public func startUpdatingLocation() {
        isUpdatingLocation = true
        
        // Simulate getting location after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Mock location: New York City
            self.currentLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
            self.isUpdatingLocation = false
        }
    }
    
    public func stopUpdatingLocation() {
        isUpdatingLocation = false
    }
    
    public func geocodeCity(_ cityName: String) async throws -> CLLocation {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Mock geocoding results
        switch cityName.lowercased() {
        case "new york", "nyc":
            return CLLocation(latitude: 40.7128, longitude: -74.0060)
        case "london":
            return CLLocation(latitude: 51.5074, longitude: -0.1278)
        case "mecca", "makkah":
            return CLLocation(latitude: 21.4225, longitude: 39.8262)
        case "medina", "madinah":
            return CLLocation(latitude: 24.4539, longitude: 39.6040)
        case "dubai":
            return CLLocation(latitude: 25.2048, longitude: 55.2708)
        case "istanbul":
            return CLLocation(latitude: 41.0082, longitude: 28.9784)
        default:
            throw LocationError.geocodingFailed
        }
    }
}
