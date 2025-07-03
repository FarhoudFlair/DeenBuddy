import Foundation
import CoreLocation
import Combine

// MARK: - Location Service Implementation

public class LocationService: NSObject, LocationServiceProtocol, ObservableObject {
    
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
    
    // MARK: - Private Properties
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var locationContinuation: CheckedContinuation<LocationInfo, Error>?
    private var permissionContinuation: CheckedContinuation<LocationPermissionStatus, Never>?
    private var cachedLocation: LocationInfo?
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Configuration
    
    private let locationTimeout: TimeInterval = 30.0
    private let minimumAccuracy: Double = 100.0 // meters
    private let cacheExpirationTime: TimeInterval = 300.0 // 5 minutes
    
    // MARK: - Cache Keys
    
    private enum CacheKeys {
        static let cachedLocation = "DeenAssist.CachedLocation"
        static let cacheTimestamp = "DeenAssist.CacheTimestamp"
    }
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        setupLocationManager()
        loadCachedLocation()
        updatePermissionStatus()
    }
    
    // MARK: - Protocol Implementation
    
    public func requestLocationPermission() async -> LocationPermissionStatus {
        guard permissionStatus == .notDetermined else {
            return permissionStatus
        }
        
        return await withCheckedContinuation { continuation in
            permissionContinuation = continuation
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    public func getCurrentLocation() async throws -> LocationInfo {
        guard permissionStatus.isAuthorized else {
            throw LocationError.permissionDenied
        }
        
        guard isLocationServicesAvailable() else {
            throw LocationError.locationUnavailable
        }
        
        // Return cached location if recent and accurate
        if let cached = getCachedLocation(), isLocationRecent(cached) && cached.accuracy < minimumAccuracy {
            return cached
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            
            // Set timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + locationTimeout) { [weak self] in
                if self?.locationContinuation != nil {
                    self?.locationContinuation?.resume(throwing: LocationError.timeout)
                    self?.locationContinuation = nil
                }
            }
            
            locationManager.requestLocation()
        }
    }
    
    public func startLocationUpdates() {
        guard permissionStatus.isAuthorized else { return }
        guard isLocationServicesAvailable() else { return }
        
        isLocationActive = true
        locationManager.startUpdatingLocation()
    }
    
    public func stopLocationUpdates() {
        isLocationActive = false
        locationManager.stopUpdatingLocation()
    }
    
    public func searchCity(_ cityName: String) async throws -> [LocationInfo] {
        guard !cityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocationError.geocodingFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            geocoder.geocodeAddressString(cityName) { placemarks, error in
                if let error = error {
                    continuation.resume(throwing: LocationError.networkError)
                    return
                }
                
                guard let placemarks = placemarks, !placemarks.isEmpty else {
                    continuation.resume(throwing: LocationError.geocodingFailed)
                    return
                }
                
                let locations = placemarks.compactMap { placemark -> LocationInfo? in
                    guard let coordinate = placemark.location?.coordinate else { return nil }
                    
                    return LocationInfo(
                        coordinate: LocationCoordinate(from: coordinate),
                        accuracy: 10.0, // Geocoded locations have good accuracy
                        city: placemark.locality,
                        country: placemark.country
                    )
                }
                
                continuation.resume(returning: locations)
            }
        }
    }
    
    public func getLocationInfo(for coordinate: LocationCoordinate) async throws -> LocationInfo {
        let clLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        return try await withCheckedThrowingContinuation { continuation in
            geocoder.reverseGeocodeLocation(clLocation) { placemarks, error in
                if let error = error {
                    continuation.resume(throwing: LocationError.networkError)
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    continuation.resume(throwing: LocationError.geocodingFailed)
                    return
                }
                
                let locationInfo = LocationInfo(
                    coordinate: coordinate,
                    accuracy: 10.0,
                    city: placemark.locality,
                    country: placemark.country
                )
                
                continuation.resume(returning: locationInfo)
            }
        }
    }
    
    public func isLocationServicesAvailable() -> Bool {
        return CLLocationManager.locationServicesEnabled()
    }
    
    public func getCachedLocation() -> LocationInfo? {
        return cachedLocation
    }
    
    public func clearLocationCache() {
        cachedLocation = nil
        userDefaults.removeObject(forKey: CacheKeys.cachedLocation)
        userDefaults.removeObject(forKey: CacheKeys.cacheTimestamp)
    }
    
    // MARK: - Private Methods
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10.0 // Update every 10 meters
    }
    
    private func updatePermissionStatus() {
        let status: LocationPermissionStatus
        
        switch locationManager.authorizationStatus {
        case .notDetermined:
            status = .notDetermined
        case .denied:
            status = .denied
        case .restricted:
            status = .restricted
        case .authorizedWhenInUse:
            status = .authorizedWhenInUse
        case .authorizedAlways:
            status = .authorizedAlways
        @unknown default:
            status = .notDetermined
        }
        
        permissionStatus = status
        permissionSubject.send(status)
    }
    
    private func processLocation(_ clLocation: CLLocation) {
        let locationInfo = LocationInfo(
            coordinate: LocationCoordinate(from: clLocation.coordinate),
            accuracy: clLocation.horizontalAccuracy,
            timestamp: clLocation.timestamp
        )
        
        // Update current location
        currentLocation = locationInfo
        
        // Cache the location
        cacheLocation(locationInfo)
        
        // Notify subscribers
        locationSubject.send(locationInfo)
        
        // Complete pending location request
        locationContinuation?.resume(returning: locationInfo)
        locationContinuation = nil
    }
    
    private func handleLocationError(_ error: Error) {
        let locationError: LocationError
        
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                locationError = .permissionDenied
            case .locationUnknown:
                locationError = .locationUnavailable
            case .network:
                locationError = .networkError
            default:
                locationError = .locationUnavailable
            }
        } else {
            locationError = .locationUnavailable
        }
        
        locationSubject.send(completion: .failure(locationError))
        locationContinuation?.resume(throwing: locationError)
        locationContinuation = nil
    }
    
    private func cacheLocation(_ location: LocationInfo) {
        cachedLocation = location
        
        if let data = try? JSONEncoder().encode(location) {
            userDefaults.set(data, forKey: CacheKeys.cachedLocation)
            userDefaults.set(Date().timeIntervalSince1970, forKey: CacheKeys.cacheTimestamp)
        }
    }
    
    private func loadCachedLocation() {
        guard let data = userDefaults.data(forKey: CacheKeys.cachedLocation),
              let location = try? JSONDecoder().decode(LocationInfo.self, from: data) else {
            return
        }
        
        let cacheTimestamp = userDefaults.double(forKey: CacheKeys.cacheTimestamp)
        let cacheDate = Date(timeIntervalSince1970: cacheTimestamp)
        
        // Check if cache is still valid
        if Date().timeIntervalSince(cacheDate) < cacheExpirationTime {
            cachedLocation = location
            currentLocation = location
        } else {
            clearLocationCache()
        }
    }
    
    private func isLocationRecent(_ location: LocationInfo) -> Bool {
        return Date().timeIntervalSince(location.timestamp) < cacheExpirationTime
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Filter out inaccurate locations
        guard location.horizontalAccuracy < minimumAccuracy && location.horizontalAccuracy > 0 else {
            return
        }
        
        processLocation(location)
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        handleLocationError(error)
    }
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        updatePermissionStatus()
        
        // Complete pending permission request
        permissionContinuation?.resume(returning: permissionStatus)
        permissionContinuation = nil
    }
}
