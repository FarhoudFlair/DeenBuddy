import Foundation
import CoreLocation
import Combine

// MARK: - Location Service Implementation

public class LocationService: NSObject, LocationServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var currentLocation: CLLocation?
    @Published public var isUpdatingLocation: Bool = false
    @Published public var locationError: Error?
    
    // MARK: - Protocol Compliance Properties
    
    public var permissionStatus: CLAuthorizationStatus {
        return authorizationStatus
    }
    
    // MARK: - Publishers
    
    private let locationSubject = PassthroughSubject<CLLocation, Error>()
    private let permissionSubject = PassthroughSubject<CLAuthorizationStatus, Never>()
    
    public var locationPublisher: AnyPublisher<CLLocation, Error> {
        locationSubject.eraseToAnyPublisher()
    }
    
    public var permissionPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        permissionSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let batteryOptimizer = BatteryOptimizer.shared
    private let errorHandler = SharedInstances.errorHandler
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var permissionContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var cachedLocation: CLLocation?
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
        Task { @MainActor in
            self.setupLocationManager()
            self.setupBatteryOptimization()
        }
        loadCachedLocation()
        updatePermissionStatus()
    }
    
    // MARK: - Protocol Implementation
    
    public func requestLocationPermission() {
        guard authorizationStatus == .notDetermined else {
            return
        }
        
        locationManager.requestWhenInUseAuthorization()
    }
    
    public func requestLocation() async throws -> CLLocation {
        return try await getCurrentLocation()
    }
    
    public func getCurrentLocation() async throws -> CLLocation {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            throw LocationError.permissionDenied
        }
        
        guard isLocationServicesAvailable() else {
            throw LocationError.locationUnavailable
        }
        
        // Return cached location if recent and accurate
        if let cached = getCachedLocation(), isLocationRecent(cached) && cached.horizontalAccuracy < minimumAccuracy {
            return cached
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            
            // Set timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + locationTimeout) { [weak self] in
                if self?.locationContinuation != nil {
                    self?.locationContinuation?.resume(throwing: LocationError.locationUnavailable)
                    self?.locationContinuation = nil
                }
            }
            
            locationManager.requestLocation()
        }
    }
    
    public func startUpdatingLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else { return }
        guard isLocationServicesAvailable() else { return }
        
        isUpdatingLocation = true
        locationManager.startUpdatingLocation()
    }
    
    public func stopUpdatingLocation() {
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
    }
    
    public func geocodeCity(_ cityName: String) async throws -> CLLocation {
        guard !cityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocationError.geocodingFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            geocoder.geocodeAddressString(cityName) { placemarks, error in
                if let error = error {
                    continuation.resume(throwing: LocationError.networkError)
                    return
                }
                
                guard let placemarks = placemarks, !placemarks.isEmpty,
                      let location = placemarks.first?.location else {
                    continuation.resume(throwing: LocationError.geocodingFailed)
                    return
                }
                
                continuation.resume(returning: location)
            }
        }
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
    
    public func getCachedLocation() -> CLLocation? {
        return cachedLocation
    }
    
    public func clearLocationCache() {
        cachedLocation = nil
        userDefaults.removeObject(forKey: CacheKeys.cachedLocation)
        userDefaults.removeObject(forKey: CacheKeys.cacheTimestamp)
    }
    
    // MARK: - Private Methods
    
    @MainActor private func setupLocationManager() {
        locationManager.delegate = self

        // Apply battery optimizations
        batteryOptimizer.applyOptimizations(to: locationManager)

        print("📍 Location manager configured with battery optimization")
    }

    @MainActor private func setupBatteryOptimization() {
        // Start intelligent location updates
        batteryOptimizer.scheduleIntelligentLocationUpdate { [weak self] in
            Task { @MainActor in
                await self?.refreshLocationIfNeeded()
            }
        }

        print("🔋 Battery optimization enabled for location services")
    }

    private func refreshLocationIfNeeded() async {
        if let cached = cachedLocation {
            let interval = await batteryOptimizer.getOptimizedUpdateInterval()
            if Date().timeIntervalSince(cached.timestamp) < interval {
                return
            }
        }

        // Refresh location
        do {
            _ = try await getCurrentLocation()
        } catch {
            Task { @MainActor in
                errorHandler.handleError(error)
            }
        }
    }
    
    private func updatePermissionStatus() {
        let status: CLAuthorizationStatus
        
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
        
        authorizationStatus = status
        permissionSubject.send(status)
    }
    
    private func processLocation(_ clLocation: CLLocation) {
        // Update current location for protocol conformance
        currentLocation = clLocation
        
        // Cache the location
        cacheLocation(clLocation)
        
        // Notify subscribers
        locationSubject.send(clLocation)
        
        // Complete pending location request
        locationContinuation?.resume(returning: clLocation)
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
    
    private func cacheLocation(_ location: CLLocation) {
        cachedLocation = location
        
        // Cache location data
        let locationData = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "timestamp": location.timestamp.timeIntervalSince1970
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: locationData) {
            userDefaults.set(data, forKey: CacheKeys.cachedLocation)
            userDefaults.set(Date().timeIntervalSince1970, forKey: CacheKeys.cacheTimestamp)
        }
    }
    
    private func loadCachedLocation() {
        guard let data = userDefaults.data(forKey: CacheKeys.cachedLocation),
              let locationData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let latitude = locationData["latitude"] as? Double,
              let longitude = locationData["longitude"] as? Double,
              let accuracy = locationData["accuracy"] as? Double,
              let timestamp = locationData["timestamp"] as? TimeInterval else {
            return
        }
        
        let cacheTimestamp = userDefaults.double(forKey: CacheKeys.cacheTimestamp)
        let cacheDate = Date(timeIntervalSince1970: cacheTimestamp)
        
        // Check if cache is still valid
        if Date().timeIntervalSince(cacheDate) < cacheExpirationTime {
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                altitude: 0,
                horizontalAccuracy: accuracy,
                verticalAccuracy: -1,
                timestamp: Date(timeIntervalSince1970: timestamp)
            )
            cachedLocation = location
            currentLocation = location
        } else {
            clearLocationCache()
        }
    }
    
    private func isLocationRecent(_ location: CLLocation) -> Bool {
        return Date().timeIntervalSince(location.timestamp) < cacheExpirationTime
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: @preconcurrency CLLocationManagerDelegate {
    @MainActor
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
        permissionContinuation?.resume(returning: authorizationStatus)
        permissionContinuation = nil
    }
}
