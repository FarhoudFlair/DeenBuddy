import Foundation
import CoreLocation
import Combine

/// Mock implementation of LocationServiceProtocol for UI development
@MainActor
public class MockLocationService: LocationServiceProtocol {
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var currentLocation: CLLocation? = nil
    @Published public var currentLocationInfo: LocationInfo? = nil
    @Published public var isUpdatingLocation: Bool = false
    @Published public var locationError: Error? = nil
    @Published public var currentHeading: Double = 0
    @Published public var headingAccuracy: Double = 5.0
    @Published public var isUpdatingHeading: Bool = false

    // MARK: - Test Support Properties

    /// Mock location for testing - when set, this location will be returned by requestLocation()
    public var mockLocation: CLLocation? = nil

    // MARK: - Protocol Compliance Properties
    
    public var permissionStatus: CLAuthorizationStatus {
        return authorizationStatus
    }
    
    // MARK: - Publishers
    
    private let locationSubject = PassthroughSubject<CLLocation, Error>()
    private let headingSubject = PassthroughSubject<CLHeading, Error>()
    
    public var locationPublisher: AnyPublisher<CLLocation, Error> {
        locationSubject.eraseToAnyPublisher()
    }
    
    public var headingPublisher: AnyPublisher<CLHeading, Error> {
        headingSubject.eraseToAnyPublisher()
    }
    
    public init() {}
    
    public func requestLocationPermission() {
        // Simulate permission request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.authorizationStatus = .authorizedWhenInUse
        }
    }

    public func requestLocationPermissionAsync() async -> CLAuthorizationStatus {
        // Simulate permission request
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        authorizationStatus = .authorizedWhenInUse
        return authorizationStatus
    }
    
    public func requestLocation() async throws -> CLLocation {
        // Simulate getting location
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Use mockLocation if set, otherwise default to New York City
        let location = mockLocation ?? CLLocation(latitude: 40.7128, longitude: -74.0060)
        currentLocation = location

        // Mock location info
        let coordinate = LocationCoordinate(from: location.coordinate)
        let cityName = mockLocation != nil ? "Mock City" : "New York"
        let countryName = mockLocation != nil ? "Mock Country" : "United States"

        currentLocationInfo = LocationInfo(
            coordinate: coordinate,
            accuracy: location.horizontalAccuracy,
            city: cityName,
            country: countryName
        )

        locationSubject.send(location)
        return location
    }
    
    public func startUpdatingLocation() {
        isUpdatingLocation = true
        
        // Simulate getting location after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Mock location: New York City
            let location = CLLocation(latitude: 40.7128, longitude: -74.0060)
            self.currentLocation = location

            // Mock location info
            let coordinate = LocationCoordinate(from: location.coordinate)
            self.currentLocationInfo = LocationInfo(
                coordinate: coordinate,
                accuracy: location.horizontalAccuracy,
                city: "New York",
                country: "United States"
            )

            self.locationSubject.send(location)
            self.isUpdatingLocation = false
        }
    }
    
    public func stopUpdatingLocation() {
        isUpdatingLocation = false
    }
    
    public func startBackgroundLocationUpdates() {
        print("🌍 MockLocationService: Started background location updates")
        isUpdatingLocation = true
        // Simulate getting location updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.simulateLocationUpdate()
        }
    }
    
    public func stopBackgroundLocationUpdates() {
        print("🌍 MockLocationService: Stopped background location updates")
        isUpdatingLocation = false
    }
    
    public func startUpdatingHeading() {
        isUpdatingHeading = true
        
        // Simulate heading updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.simulateHeadingUpdate()
        }
    }
    
    public func stopUpdatingHeading() {
        isUpdatingHeading = false
    }
    
    private func simulateLocationUpdate() {
        guard isUpdatingLocation else { return }

        // Simulate slight location variations around New York City
        let baseLatitude = 40.7128
        let baseLongitude = -74.0060

        // Add small random variations to simulate GPS drift
        let latVariation = Double.random(in: -0.001...0.001)
        let lonVariation = Double.random(in: -0.001...0.001)

        let newLocation = CLLocation(
            latitude: baseLatitude + latVariation,
            longitude: baseLongitude + lonVariation
        )

        currentLocation = newLocation

        // Mock location info for background updates
        let coordinate = LocationCoordinate(from: newLocation.coordinate)
        currentLocationInfo = LocationInfo(
            coordinate: coordinate,
            accuracy: newLocation.horizontalAccuracy,
            city: "New York",
            country: "United States"
        )

        locationSubject.send(newLocation)

        // Schedule next update every 5 seconds for background updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.simulateLocationUpdate()
        }
    }

    private func simulateHeadingUpdate() {
        guard isUpdatingHeading else { return }

        // Simulate compass heading that slowly rotates
        currentHeading = (currentHeading + 1).truncatingRemainder(dividingBy: 360)

        // Create a mock CLHeading
        let mockHeading = MockCLHeading(magneticHeading: currentHeading, headingAccuracy: headingAccuracy)
        headingSubject.send(mockHeading)

        // Schedule next update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulateHeadingUpdate()
        }
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
            throw LocationError.geocodingFailed("Failed to find location for city: \(cityName)")
        }
    }

    public func searchCity(_ cityName: String) async throws -> [LocationInfo] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)

        // Mock search results
        switch cityName.lowercased() {
        case "new york", "nyc":
            return [LocationInfo(
                coordinate: LocationCoordinate(latitude: 40.7128, longitude: -74.0060),
                accuracy: 10.0,
                city: "New York",
                country: "United States"
            )]
        case "london":
            return [LocationInfo(
                coordinate: LocationCoordinate(latitude: 51.5074, longitude: -0.1278),
                accuracy: 10.0,
                city: "London",
                country: "United Kingdom"
            )]
        case "mecca", "makkah":
            return [LocationInfo(
                coordinate: LocationCoordinate(latitude: 21.4225, longitude: 39.8262),
                accuracy: 10.0,
                city: "Mecca",
                country: "Saudi Arabia"
            )]
        default:
            return []
        }
    }

    public func getLocationInfo(for coordinate: LocationCoordinate) async throws -> LocationInfo {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)

        // Mock reverse geocoding based on coordinates
        if abs(coordinate.latitude - 40.7128) < 0.1 && abs(coordinate.longitude - (-74.0060)) < 0.1 {
            return LocationInfo(
                coordinate: coordinate,
                accuracy: 10.0,
                city: "New York",
                country: "United States"
            )
        } else if abs(coordinate.latitude - 51.5074) < 0.1 && abs(coordinate.longitude - (-0.1278)) < 0.1 {
            return LocationInfo(
                coordinate: coordinate,
                accuracy: 10.0,
                city: "London",
                country: "United Kingdom"
            )
        } else if abs(coordinate.latitude - 21.4225) < 0.1 && abs(coordinate.longitude - 39.8262) < 0.1 {
            return LocationInfo(
                coordinate: coordinate,
                accuracy: 10.0,
                city: "Mecca",
                country: "Saudi Arabia"
            )
        } else {
            return LocationInfo(
                coordinate: coordinate,
                accuracy: 10.0,
                city: "Unknown City",
                country: "Unknown Country"
            )
        }
    }
    
    // MARK: - Cached Location Methods
    
    public func getCachedLocation() -> CLLocation? {
        return currentLocation
    }
    
    public func isCachedLocationValid() -> Bool {
        return currentLocation != nil
    }
    
    public func getLocationPreferCached() async throws -> CLLocation {
        // For mock service, just return request location
        return try await requestLocation()
    }
    
    public func isCurrentLocationFromCache() -> Bool {
        // For mock service, consider it always fresh
        return false
    }
    
    public func getLocationAge() -> TimeInterval? {
        // For mock service, always return a small age
        return 30.0 // 30 seconds
    }

    public func setManualLocation(_ location: CLLocation) async {
        currentLocation = location
        let coordinate = LocationCoordinate(from: location.coordinate)
        currentLocationInfo = LocationInfo(
            coordinate: coordinate,
            accuracy: location.horizontalAccuracy,
            city: "Manual Location",
            country: "Unknown"
        )
        locationSubject.send(location)
    }
}

// MARK: - Mock CLHeading

private class MockCLHeading: CLHeading {
    private let _magneticHeading: Double
    private let _headingAccuracy: Double
    
    init(magneticHeading: Double, headingAccuracy: Double) {
        self._magneticHeading = magneticHeading
        self._headingAccuracy = headingAccuracy
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var magneticHeading: CLLocationDirection {
        return _magneticHeading
    }
    
    override var headingAccuracy: CLLocationDirection {
        return _headingAccuracy
    }
}
