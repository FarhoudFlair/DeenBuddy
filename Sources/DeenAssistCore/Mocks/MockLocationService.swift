import Foundation
import Combine

// MARK: - Mock Location Service

public class MockLocationService: LocationServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var permissionStatus: LocationPermissionStatus = .notDetermined
    @Published public var currentLocation: LocationInfo?
    @Published public var isLocationActive: Bool = false
    
    // MARK: - Publishers
    
    private let locationSubject = PassthroughSubject<LocationInfo, LocationError>()
    private let permissionSubject = PassthroughSubject<LocationPermissionStatus, Never>()
    
    public var locationPublisher: AnyPublisher<LocationInfo, LocationError> {
        locationSubject.eraseToAnyPublisher()
    }
    
    public var permissionPublisher: AnyPublisher<LocationPermissionStatus, Never> {
        permissionSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Mock Configuration
    
    public var mockLocations: [LocationInfo] = []
    public var mockPermissionResponse: LocationPermissionStatus = .authorizedWhenInUse
    public var mockLocationDelay: TimeInterval = 1.0
    public var shouldFailLocationRequest: Bool = false
    public var mockLocationError: LocationError = .locationUnavailable
    
    // MARK: - Private Properties
    
    private var cachedLocation: LocationInfo?
    private var updateTimer: Timer?
    
    // MARK: - Initialization
    
    public init() {
        setupDefaultMockData()
    }
    
    // MARK: - Protocol Implementation
    
    public func requestLocationPermission() async -> LocationPermissionStatus {
        await Task.sleep(nanoseconds: UInt64(mockLocationDelay * 1_000_000_000))
        
        permissionStatus = mockPermissionResponse
        permissionSubject.send(permissionStatus)
        
        return permissionStatus
    }
    
    public func getCurrentLocation() async throws -> LocationInfo {
        await Task.sleep(nanoseconds: UInt64(mockLocationDelay * 1_000_000_000))
        
        if shouldFailLocationRequest {
            throw mockLocationError
        }
        
        guard permissionStatus.isAuthorized else {
            throw LocationError.permissionDenied
        }
        
        let location = mockLocations.randomElement() ?? defaultLocation
        currentLocation = location
        locationSubject.send(location)
        
        return location
    }
    
    public func startLocationUpdates() {
        guard permissionStatus.isAuthorized else { return }
        
        isLocationActive = true
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if !self.shouldFailLocationRequest {
                let location = self.mockLocations.randomElement() ?? self.defaultLocation
                self.currentLocation = location
                self.locationSubject.send(location)
            }
        }
    }
    
    public func stopLocationUpdates() {
        isLocationActive = false
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    public func searchCity(_ cityName: String) async throws -> [LocationInfo] {
        await Task.sleep(nanoseconds: UInt64(mockLocationDelay * 1_000_000_000))
        
        if shouldFailLocationRequest {
            throw mockLocationError
        }
        
        // Return mock search results based on city name
        return mockCitySearchResults(for: cityName)
    }
    
    public func getLocationInfo(for coordinate: LocationCoordinate) async throws -> LocationInfo {
        await Task.sleep(nanoseconds: UInt64(mockLocationDelay * 1_000_000_000))
        
        if shouldFailLocationRequest {
            throw mockLocationError
        }
        
        // Find closest mock location or create one
        let location = findClosestMockLocation(to: coordinate) ?? LocationInfo(
            coordinate: coordinate,
            accuracy: 10.0,
            city: "Mock City",
            country: "Mock Country"
        )
        
        return location
    }
    
    public func isLocationServicesAvailable() -> Bool {
        return true // Always available in mock
    }
    
    public func getCachedLocation() -> LocationInfo? {
        return cachedLocation
    }
    
    public func clearLocationCache() {
        cachedLocation = nil
    }
    
    // MARK: - Mock Configuration Methods
    
    public func setMockPermissionStatus(_ status: LocationPermissionStatus) {
        mockPermissionResponse = status
        permissionStatus = status
        permissionSubject.send(status)
    }
    
    public func addMockLocation(_ location: LocationInfo) {
        mockLocations.append(location)
    }
    
    public func setMockLocations(_ locations: [LocationInfo]) {
        mockLocations = locations
    }
    
    public func simulateLocationError(_ error: LocationError) {
        shouldFailLocationRequest = true
        mockLocationError = error
    }
    
    public func clearLocationError() {
        shouldFailLocationRequest = false
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultMockData() {
        mockLocations = [
            // Mecca, Saudi Arabia
            LocationInfo(
                coordinate: LocationCoordinate(latitude: 21.4225, longitude: 39.8262),
                accuracy: 5.0,
                city: "Mecca",
                country: "Saudi Arabia"
            ),
            // New York, USA
            LocationInfo(
                coordinate: LocationCoordinate(latitude: 40.7128, longitude: -74.0060),
                accuracy: 10.0,
                city: "New York",
                country: "United States"
            ),
            // London, UK
            LocationInfo(
                coordinate: LocationCoordinate(latitude: 51.5074, longitude: -0.1278),
                accuracy: 8.0,
                city: "London",
                country: "United Kingdom"
            ),
            // Istanbul, Turkey
            LocationInfo(
                coordinate: LocationCoordinate(latitude: 41.0082, longitude: 28.9784),
                accuracy: 12.0,
                city: "Istanbul",
                country: "Turkey"
            ),
            // Dubai, UAE
            LocationInfo(
                coordinate: LocationCoordinate(latitude: 25.2048, longitude: 55.2708),
                accuracy: 6.0,
                city: "Dubai",
                country: "United Arab Emirates"
            )
        ]
        
        // Set default current location to New York
        currentLocation = mockLocations[1]
        cachedLocation = currentLocation
    }
    
    private var defaultLocation: LocationInfo {
        return mockLocations.first ?? LocationInfo(
            coordinate: LocationCoordinate(latitude: 40.7128, longitude: -74.0060),
            accuracy: 10.0,
            city: "Default City",
            country: "Default Country"
        )
    }
    
    private func mockCitySearchResults(for cityName: String) -> [LocationInfo] {
        let lowercasedQuery = cityName.lowercased()
        
        return mockLocations.filter { location in
            location.city?.lowercased().contains(lowercasedQuery) == true ||
            location.country?.lowercased().contains(lowercasedQuery) == true
        }
    }
    
    private func findClosestMockLocation(to coordinate: LocationCoordinate) -> LocationInfo? {
        return mockLocations.min { location1, location2 in
            let distance1 = calculateDistance(from: coordinate, to: location1.coordinate)
            let distance2 = calculateDistance(from: coordinate, to: location2.coordinate)
            return distance1 < distance2
        }
    }
    
    private func calculateDistance(from: LocationCoordinate, to: LocationCoordinate) -> Double {
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
