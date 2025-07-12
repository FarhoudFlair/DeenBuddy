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
    @Published public var currentHeading: Double = 0
    @Published public var headingAccuracy: Double = -1
    @Published public var isUpdatingHeading: Bool = false
    
    // MARK: - Protocol Compliance Properties
    
    public var permissionStatus: CLAuthorizationStatus {
        return authorizationStatus
    }
    
    // MARK: - Publishers
    
    private let locationSubject = PassthroughSubject<CLLocation, Error>()
    private let permissionSubject = PassthroughSubject<CLAuthorizationStatus, Never>()
    private let headingSubject = PassthroughSubject<CLHeading, Error>()
    
    public var locationPublisher: AnyPublisher<CLLocation, Error> {
        locationSubject.eraseToAnyPublisher()
    }
    
    public var permissionPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        permissionSubject.eraseToAnyPublisher()
    }
    
    public var headingPublisher: AnyPublisher<CLHeading, Error> {
        headingSubject.eraseToAnyPublisher()
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
    private var settingsService: (any SettingsServiceProtocol)?
    
    // MARK: - Configuration
    
    private let locationTimeout: TimeInterval = 30.0
    private let minimumAccuracy: Double = 100.0 // meters
    private let cacheExpirationTime: TimeInterval = 300.0 // 5 minutes
    private let extendedCacheExpirationTime: TimeInterval = 1800.0 // 30 minutes when battery optimized
    
    // MARK: - Cache Keys
    
    private enum CacheKeys {
        static let cachedLocation = "DeenAssist.CachedLocation"
        static let cacheTimestamp = "DeenAssist.CacheTimestamp"
    }
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        setupLocationManagerSync()
        loadCachedLocation()

        Task { @MainActor in
            self.setupBatteryOptimization()
            self.setupSettingsService()
            // Update permission status after setup
            self.updatePermissionStatus(with: self.locationManager.authorizationStatus)
        }
    }
    
    // MARK: - Protocol Implementation
    
    public func requestLocationPermission() {
        Task { @MainActor in
            guard authorizationStatus == .notDetermined else {
                print("📍 Location permission already determined: \(authorizationStatus)")
                return
            }

            print("📍 Requesting location permission...")
            locationManager.requestWhenInUseAuthorization()
        }
    }

    public func requestLocationPermissionAsync() async -> CLAuthorizationStatus {
        let currentAuthStatus = await MainActor.run { authorizationStatus }
        
        // If permission is already authorized, return immediately
        if currentAuthStatus == .authorizedWhenInUse || currentAuthStatus == .authorizedAlways {
            return currentAuthStatus
        }
        
        // If permission is denied or restricted, return current status (can't request again)
        if currentAuthStatus == .denied || currentAuthStatus == .restricted {
            return currentAuthStatus
        }
        
        // Only request permission if status is not determined
        guard currentAuthStatus == .notDetermined else {
            return currentAuthStatus
        }

        return await withCheckedContinuation { continuation in
            permissionContinuation = continuation
            DispatchQueue.main.async { [weak self] in
                self?.locationManager.requestWhenInUseAuthorization()
            }
        }
    }
    
    public func requestLocation() async throws -> CLLocation {
        return try await getCurrentLocation()
    }
    
    public func getCurrentLocation() async throws -> CLLocation {
        // Check authorization on main thread to avoid threading issues
        let currentAuthStatus = await MainActor.run { authorizationStatus }
        print("📍 Getting current location, authorization status: \(currentAuthStatus)")
        
        guard currentAuthStatus == .authorizedWhenInUse || currentAuthStatus == .authorizedAlways else {
            throw LocationError.permissionDenied("Location permission is required. Please enable location access in Settings.")
        }
        
        guard isLocationServicesAvailable() else {
            throw LocationError.locationUnavailable("Location services are not available. Please enable location services in Settings.")
        }
        
        // Return cached location if recent and accurate
        if let cached = getCachedLocation(), isLocationRecent(cached) && cached.horizontalAccuracy < minimumAccuracy {
            print("📍 Returning cached location from \(cached.timestamp)")
            return cached
        }
        
        // Check if user has overridden battery optimization
        let userOverride = await MainActor.run {
            settingsService?.overrideBatteryOptimization ?? false
        }
        
        // For location permission requests, temporarily disable battery optimization interference
        let isPermissionRequest = currentAuthStatus == .notDetermined
        let hasLocationPermission = currentAuthStatus == .authorizedWhenInUse || currentAuthStatus == .authorizedAlways
        let shouldUpdate: Bool
        if isPermissionRequest {
            shouldUpdate = true
        } else {
            shouldUpdate = await batteryOptimizer.shouldPerformLocationUpdate(userOverride: userOverride, hasLocationPermission: hasLocationPermission)
        }
        
        if !shouldUpdate {
            // If we can't update but have cached location, return it even if not recent
            if let cached = getCachedLocation(), cached.horizontalAccuracy < minimumAccuracy * 2 {
                print("📍 Returning less accurate cached location due to battery optimization")
                return cached
            }
            
            // Provide helpful error message with guidance
            let errorMessage = hasLocationPermission ? 
                "Location access is restricted due to battery optimization. You can enable 'Override Battery Optimization' in Settings to always allow location access." :
                "Unable to get current location due to battery optimization. Please try again."
            throw LocationError.locationUnavailable(errorMessage)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            
            // Set timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + locationTimeout) { [weak self] in
                if self?.locationContinuation != nil {
                    self?.locationContinuation?.resume(throwing: LocationError.locationUnavailable("Location request timed out. Please try again."))
                    self?.locationContinuation = nil
                }
            }
            
            print("📍 Requesting location from CLLocationManager")
            // Ensure location request is called on main thread (required for CLLocationManager)
            DispatchQueue.main.async { [weak self] in
                self?.locationManager.requestLocation()
            }
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
    
    public func startUpdatingHeading() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("❌ Heading: Location permission required for compass functionality. Current status: \(authorizationStatus)")
            return
        }
        
        guard CLLocationManager.headingAvailable() else {
            print("❌ Heading: Heading not available on this device")
            return
        }
        
        isUpdatingHeading = true
        locationManager.startUpdatingHeading()
        print("🧭 LocationService: Started updating heading")
    }
    
    public func stopUpdatingHeading() {
        isUpdatingHeading = false
        locationManager.stopUpdatingHeading()
        print("🧭 LocationService: Stopped updating heading")
    }
    
    public func geocodeCity(_ cityName: String) async throws -> CLLocation {
        guard !cityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocationError.geocodingFailed("Failed to find location for the specified city.")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            geocoder.geocodeAddressString(cityName) { placemarks, error in
                if let error = error {
                    continuation.resume(throwing: LocationError.networkError("Network error occurred while searching for location."))
                    return
                }
                
                guard let placemarks = placemarks, !placemarks.isEmpty,
                      let location = placemarks.first?.location else {
                    continuation.resume(throwing: LocationError.geocodingFailed("Failed to find location for the specified city."))
                    return
                }
                
                continuation.resume(returning: location)
            }
        }
    }
    
    public func searchCity(_ cityName: String) async throws -> [LocationInfo] {
        guard !cityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocationError.geocodingFailed("Failed to find location for the specified city.")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            geocoder.geocodeAddressString(cityName) { placemarks, error in
                if let error = error {
                    continuation.resume(throwing: LocationError.networkError("Network error occurred while searching for location."))
                    return
                }
                
                guard let placemarks = placemarks, !placemarks.isEmpty else {
                    continuation.resume(throwing: LocationError.geocodingFailed("Failed to find location for the specified city."))
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
                    continuation.resume(throwing: LocationError.networkError("Network error occurred while searching for location."))
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    continuation.resume(throwing: LocationError.geocodingFailed("Failed to find location for the specified city."))
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
    
    private func setupLocationManagerSync() {
        locationManager.delegate = self
        print("📍 Location manager delegate set")
    }

    @MainActor private func setupLocationManager() {
        // Apply battery optimizations
        batteryOptimizer.applyOptimizations(to: locationManager)
        print("📍 Location manager configured with battery optimization")
    }

    @MainActor private func setupBatteryOptimization() {
        // Complete location manager setup with battery optimizations
        setupLocationManager()

        // Start intelligent location updates
        batteryOptimizer.scheduleIntelligentLocationUpdate { [weak self] in
            Task { @MainActor in
                await self?.refreshLocationIfNeeded()
            }
        }

        print("🔋 Battery optimization enabled for location services")
    }
    
    @MainActor private func setupSettingsService() {
        // Get settings service from shared container
        settingsService = DependencyContainer.shared.settingsService
    }

    private func refreshLocationIfNeeded() async {
        // Check if user has overridden battery optimization
        let userOverride = await MainActor.run {
            settingsService?.overrideBatteryOptimization ?? false
        }
        
        // Check if we should perform location update
        let hasLocationPermission = authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
        let shouldUpdate = await batteryOptimizer.shouldPerformLocationUpdate(userOverride: userOverride, hasLocationPermission: hasLocationPermission)
        
        if !shouldUpdate {
            return
        }
        
        if let cached = cachedLocation {
            let interval = batteryOptimizer.getOptimizedUpdateInterval()
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
    
    private func updatePermissionStatus(with status: CLAuthorizationStatus) {
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
                locationError = .permissionDenied("Location permission denied")
            case .locationUnknown:
                locationError = .locationUnavailable("Location unknown")
            case .network:
                locationError = .networkError("Network error while getting location")
            default:
                locationError = .locationUnavailable("Location unavailable")
            }
        } else {
            locationError = .locationUnavailable("Location service error")
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
        // Use extended cache time when battery optimization is active
        let userOverride = settingsService?.overrideBatteryOptimization ?? false
        let expirationTime = userOverride ? cacheExpirationTime : getEffectiveCacheExpirationTime()
        return Date().timeIntervalSince(location.timestamp) < expirationTime
    }
    
    private func getEffectiveCacheExpirationTime() -> TimeInterval {
        // Use extended cache time when battery optimization is active
        if batteryOptimizer.optimizationLevel == .extreme || batteryOptimizer.isLowPowerModeEnabled {
            return extendedCacheExpirationTime
        }
        return cacheExpirationTime
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: @preconcurrency CLLocationManagerDelegate {
    @MainActor
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        print("📍 Location manager received location: \(location.coordinate.latitude), \(location.coordinate.longitude) with accuracy: \(location.horizontalAccuracy)")
        
        // Filter out inaccurate locations
        guard location.horizontalAccuracy < minimumAccuracy && location.horizontalAccuracy > 0 else {
            print("📍 Location filtered out due to poor accuracy: \(location.horizontalAccuracy)")
            return
        }
        
        processLocation(location)
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 Location manager failed with error: \(error)")
        handleLocationError(error)
    }
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("📍 Location authorization changed to: \(status)")
        updatePermissionStatus(with: status)

        // Complete pending permission request
        permissionContinuation?.resume(returning: status)
        permissionContinuation = nil
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        print("🧭 LocationService received heading: \(newHeading.magneticHeading)° with accuracy: \(newHeading.headingAccuracy)")
        
        // Update published properties
        currentHeading = newHeading.magneticHeading
        headingAccuracy = newHeading.headingAccuracy
        
        // Notify subscribers
        headingSubject.send(newHeading)
    }
}
