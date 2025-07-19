import Foundation
import CoreLocation
import Combine
import UIKit

// MARK: - Location Service Implementation

public class LocationService: NSObject, LocationServiceProtocol, ObservableObject {
    
    // MARK: - Logger
    
    private let logger = AppLogger.location
    
    // MARK: - Published Properties
    
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var currentLocation: CLLocation?
    @Published public var currentLocationInfo: LocationInfo?
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
    private let timerManager = BatteryAwareTimerManager.shared
    private let errorHandler = SharedInstances.errorHandler
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var permissionContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationRequestInProgress = false
    private var permissionRequestInProgress = false
    private let continuationQueue = DispatchQueue(label: "LocationService.continuation", attributes: .concurrent)
    private var cachedLocation: CLLocation?
    private let userDefaults = UserDefaults.standard
    private var settingsService: (any SettingsServiceProtocol)?
    
    // MARK: - Location Services Availability Cache
    
    @Published private var cachedLocationServicesEnabled: Bool = true
    private var locationServicesAvailabilityLastChecked: Date = Date.distantPast
    private var isUpdatingAvailability: Bool = false
    
    // MARK: - Observer Management

    private var appLifecycleObserver: NSObjectProtocol?

    // MARK: - Instance Monitoring

    private static var instanceCount: Int = 0
    private static let instanceCountQueue = DispatchQueue(label: "LocationService.instanceCount", attributes: .concurrent)
    private let instanceId: UUID = UUID()

    /// Returns the current number of LocationService instances for debugging
    public static func getCurrentInstanceCount() -> Int {
        return instanceCountQueue.sync {
            return instanceCount
        }
    }

    // MARK: - Resource Monitoring

    private var activeTaskCount: Int = 0
    private let activeTaskCountQueue = DispatchQueue(label: "LocationService.activeTaskCount", attributes: .concurrent)
    private var observerCount: Int = 0
    private let maxConcurrentTasks: Int = 5
    private let maxObservers: Int = 10

    /// Increments active task count with safety checks
    private func incrementTaskCount() -> Bool {
        return activeTaskCountQueue.sync(flags: .barrier) {
            guard activeTaskCount < maxConcurrentTasks else {
                logger.warning("Maximum concurrent tasks (\(maxConcurrentTasks)) reached, rejecting new task")
                return false
            }
            activeTaskCount += 1
            logger.debug("Active tasks: \(activeTaskCount)/\(maxConcurrentTasks)")
            return true
        }
    }

    /// Decrements active task count
    private func decrementTaskCount() {
        activeTaskCountQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.activeTaskCount = max(0, self.activeTaskCount - 1)
            self.logger.debug("Active tasks: \(self.activeTaskCount)/\(self.maxConcurrentTasks)")
        }
    }

    /// Increments observer count with safety checks
    private func incrementObserverCount() -> Bool {
        guard observerCount < maxObservers else {
            logger.warning("Maximum observers (\(maxObservers)) reached, rejecting new observer")
            return false
        }
        observerCount += 1
        logger.debug("Active observers: \(observerCount)/\(maxObservers)")
        return true
    }

    /// Decrements observer count
    private func decrementObserverCount() {
        observerCount = max(0, observerCount - 1)
        logger.debug("Active observers: \(observerCount)/\(maxObservers)")
    }
    
    /// Remove all observers and clean up
    private func cleanupObservers() {
        if let observer = appLifecycleObserver {
            NotificationCenter.default.removeObserver(observer)
            appLifecycleObserver = nil
            observerCount = max(0, observerCount - 1)
        }
        
        // Remove any remaining observers as fallback
        NotificationCenter.default.removeObserver(self)
        
        logger.debug("All observers cleaned up")
    }

    /// Returns current resource usage for debugging
    public func getResourceUsage() -> (activeTasks: Int, observers: Int, instances: Int) {
        let tasks = activeTaskCountQueue.sync { activeTaskCount }
        return (activeTasks: tasks, observers: observerCount, instances: Self.getCurrentInstanceCount())
    }
    
    /// Manual cleanup method for testing or emergency cleanup
    public func manualCleanup() {
        logger.debug("Manual cleanup requested")
        timerManager.cancelTimer(id: "location-update")
        performCleanup()
    }
    
    /// Check for potential memory leaks
    public func checkForMemoryLeaks() -> Bool {
        let resourceUsage = getResourceUsage()
        
        let hasExcessiveInstances = resourceUsage.instances > 1
        let hasExcessiveObservers = resourceUsage.observers > 1
        let hasExcessiveTasks = resourceUsage.activeTasks > 3
        
        if hasExcessiveInstances || hasExcessiveObservers || hasExcessiveTasks {
            logger.warning("Potential memory leak detected: Instances: \(resourceUsage.instances)")
            print("   Observers: \(resourceUsage.observers)")
            print("   Active Tasks: \(resourceUsage.activeTasks)")
            return true
        }
        
        return false
    }
    
    // MARK: - Configuration
    
    private let locationTimeout: TimeInterval = 30.0
    private let minimumAccuracy: Double = 100.0 // meters
    private let cacheExpirationTime: TimeInterval = 300.0 // 5 minutes
    private let extendedCacheExpirationTime: TimeInterval = 1800.0 // 30 minutes when battery optimized
    private let availabilityCacheExpirationTime: TimeInterval = 60.0 // 1 minute for services availability
    
    // MARK: - Cache Keys
    
    private enum CacheKeys {
        static let cachedLocation = "DeenAssist.CachedLocation"
        static let cachedLocationInfo = "DeenAssist.CachedLocationInfo"
        static let cacheTimestamp = "DeenAssist.CacheTimestamp"
    }
    
    // MARK: - Initialization
    
    public override init() {
        super.init()

        // Track instance creation for monitoring
        Self.instanceCountQueue.async(flags: .barrier) {
            Self.instanceCount += 1
            DispatchQueue.main.async {
                print("🏗️ LocationService instance created - ID: \(self.instanceId.uuidString.prefix(8)), Total instances: \(Self.instanceCount)")
                if Self.instanceCount > 1 {
                    print("⚠️ WARNING: Multiple LocationService instances detected! This may cause resource leaks.")
                }
            }
        }

        setupLocationManagerSync()
        loadCachedLocation()

        Task { @MainActor in
            self.setupBatteryOptimization()
            self.setupSettingsService()
            // Update permission status after setup
            self.updatePermissionStatus(with: self.locationManager.authorizationStatus)
            // Initialize location services availability cache
            await self.updateLocationServicesAvailability()
        }
    }
    
    deinit {
        // Cleanup all resources to prevent memory leaks
        MainActor.assumeIsolated {
            performCleanup()
        }
        
        // Track instance destruction for monitoring
        Self.instanceCountQueue.async(flags: .barrier) {
            Self.instanceCount -= 1
            DispatchQueue.main.async {
                print("🧹 LocationService instance destroyed - ID: \(self.instanceId.uuidString.prefix(8)), Remaining instances: \(Self.instanceCount)")
            }
        }

        print("🧹 LocationService deinitialized - all resources cleaned up")
    }
    
    /// Comprehensive cleanup of all resources
    private func performCleanup() {
        // Stop location updates
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        locationManager.delegate = nil
        
        // Clear pending continuations with proper error handling
        continuationQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if let continuation = self.locationContinuation {
                continuation.resume(throwing: LocationError.locationUnavailable("LocationService is being deallocated"))
                self.locationContinuation = nil
            }
            
            if let continuation = self.permissionContinuation {
                continuation.resume(returning: .denied)
                self.permissionContinuation = nil
            }
            
            self.locationRequestInProgress = false
            self.permissionRequestInProgress = false
        }
        
        // Remove specific observer to prevent memory leak
        if let observer = appLifecycleObserver {
            NotificationCenter.default.removeObserver(observer)
            appLifecycleObserver = nil
            // Decrement observer count synchronously in deinit
            observerCount = max(0, observerCount - 1)
            print("👁️ LocationService: Removed app lifecycle observer")
        }

        // Remove any remaining observers as fallback
        NotificationCenter.default.removeObserver(self)
        
        // Cancel location timers
        timerManager.cancelTimer(id: "location-update")
        
        // Clear cached data to prevent memory retention
        cachedLocation = nil
        
        print("🧹 LocationService cleanup completed")
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
            continuationQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: .denied)
                    return
                }
                
                // Check if there's already a pending permission request
                if self.permissionRequestInProgress {
                    continuation.resume(returning: currentAuthStatus)
                    return
                }
                
                self.permissionRequestInProgress = true
                self.permissionContinuation = continuation
                
                DispatchQueue.main.async { [weak self] in
                    self?.locationManager.requestWhenInUseAuthorization()
                }
            }
        }
    }
    
    public func requestLocation() async throws -> CLLocation {
        return try await getCurrentLocation()
    }
    
    public func getCurrentLocation() async throws -> CLLocation {
        // Check for concurrent requests
        guard !locationRequestInProgress else {
            throw LocationError.locationUnavailable("Location request already in progress. Please wait for current request to complete.")
        }
        
        return try await performLocationRequest()
    }
    
    private func performLocationRequest() async throws -> CLLocation {
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
            continuationQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: LocationError.locationUnavailable("LocationService deallocated"))
                    return
                }
                
                // Check if there's already a pending continuation
                if self.locationContinuation != nil {
                    continuation.resume(throwing: LocationError.locationUnavailable("Location request already in progress"))
                    return
                }
                
                self.locationRequestInProgress = true
                self.locationContinuation = continuation
                
                // Set timeout with proper cleanup
                DispatchQueue.main.asyncAfter(deadline: .now() + self.locationTimeout) { [weak self] in
                    self?.continuationQueue.async(flags: .barrier) {
                        guard let self = self,
                              let continuation = self.locationContinuation else { return }
                        
                        self.locationContinuation = nil
                        self.locationRequestInProgress = false
                        continuation.resume(throwing: LocationError.locationUnavailable("Location request timed out. Please try again."))
                    }
                }
                
                print("📍 Requesting location from CLLocationManager")
                // Ensure location request is called on main thread (required for CLLocationManager)
                DispatchQueue.main.async { [weak self] in
                    self?.locationManager.requestLocation()
                }
            }
        }
    }
    
    public func startUpdatingLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else { return }
        guard isLocationServicesAvailable() else { return }
        
        isUpdatingLocation = true
        locationManager.startUpdatingLocation()
    }
    
    /// Start background location updates for traveler mode
    /// This will show the blue location arrow in the status bar
    public func startBackgroundLocationUpdates() {
        guard authorizationStatus == .authorizedAlways else {
            print("❌ Background location requires 'Always' authorization. Current status: \(authorizationStatus)")
            return
        }
        
        guard isLocationServicesAvailable() else {
            print("❌ Location services not available")
            return
        }
        
        // Configure for background updates
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // Start monitoring significant location changes for battery efficiency
        locationManager.startMonitoringSignificantLocationChanges()
        
        isUpdatingLocation = true
        print("🌍 Started background location updates for traveler mode")
    }
    
    /// Stop background location updates
    public func stopBackgroundLocationUpdates() {
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.stopMonitoringSignificantLocationChanges()
        
        isUpdatingLocation = false
        print("🌍 Stopped background location updates")
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
            var isResumed = false
            let resumeOnce = { (result: Result<LocationInfo, Error>) in
                guard !isResumed else { return }
                isResumed = true
                switch result {
                case .success(let locationInfo):
                    continuation.resume(returning: locationInfo)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            // Set a timeout to prevent continuation leaks
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                resumeOnce(.failure(LocationError.networkError("Location info request timed out after 10 seconds.")))
            }

            geocoder.reverseGeocodeLocation(clLocation) { placemarks, error in
                if let error = error {
                    resumeOnce(.failure(LocationError.networkError("Network error occurred while searching for location.")))
                    return
                }

                guard let placemark = placemarks?.first else {
                    resumeOnce(.failure(LocationError.geocodingFailed("Failed to find location for the specified city.")))
                    return
                }

                let locationInfo = LocationInfo(
                    coordinate: coordinate,
                    accuracy: 10.0,
                    city: placemark.locality,
                    country: placemark.country
                )

                resumeOnce(.success(locationInfo))
            }
        }
    }
    
    public func isLocationServicesAvailable() -> Bool {
        // Use cached value to avoid main thread blocking
        // Update cache in background if it's stale and not already updating
        let now = Date()
        if now.timeIntervalSince(locationServicesAvailabilityLastChecked) > availabilityCacheExpirationTime && !isUpdatingAvailability {
            Task {
                await updateLocationServicesAvailability()
            }
        }

        return cachedLocationServicesEnabled
    }
    
    public func getCachedLocation() -> CLLocation? {
        return cachedLocation
    }
    
    /// Check if cached location is valid and recent enough to use
    public func isCachedLocationValid() -> Bool {
        guard let cached = cachedLocation else { return false }
        return isLocationRecent(cached) && cached.horizontalAccuracy < minimumAccuracy
    }
    
    /// Get location preferring cached if valid, otherwise request fresh
    public func getLocationPreferCached() async throws -> CLLocation {
        // First check if we have a valid cached location
        if let cached = cachedLocation, isLocationRecent(cached) && cached.horizontalAccuracy < minimumAccuracy {
            print("📍 Using valid cached location from \(cached.timestamp)")
            // Update currentLocation to ensure UI sees the cached location
            await MainActor.run {
                self.currentLocation = cached
            }
            return cached
        }
        
        // If we have a cached location but it's not recent, still use it as fallback
        if let cached = cachedLocation, cached.horizontalAccuracy < minimumAccuracy * 2 {
            print("📍 Using older cached location from \(cached.timestamp) as fallback")
            await MainActor.run {
                self.currentLocation = cached
            }
            
            // Try to get fresh location in background but return cached immediately
            Task {
                do {
                    _ = try await getCurrentLocation()
                    print("📍 Successfully refreshed location in background")
                } catch is CancellationError {
                    // Handle cancellation gracefully - this is normal if the task is cancelled
                    print("ℹ️ Background location refresh was cancelled")
                } catch {
                    print("📍 Background location refresh failed: \(error)")
                }
            }
            
            return cached
        }
        
        // If no valid cached location, try to get fresh location
        return try await getCurrentLocation()
    }
    
    /// Check if current location is from cache
    public func isCurrentLocationFromCache() -> Bool {
        guard let current = currentLocation, let cached = cachedLocation else {
            return false
        }
        
        return current.coordinate.latitude == cached.coordinate.latitude &&
               current.coordinate.longitude == cached.coordinate.longitude &&
               current.timestamp == cached.timestamp
    }
    
    /// Get location age in seconds
    public func getLocationAge() -> TimeInterval? {
        guard let current = currentLocation else { return nil }
        return Date().timeIntervalSince(current.timestamp)
    }
    
    public func clearLocationCache() {
        cachedLocation = nil
        currentLocationInfo = nil
        userDefaults.removeObject(forKey: CacheKeys.cachedLocation)
        userDefaults.removeObject(forKey: CacheKeys.cachedLocationInfo)
        userDefaults.removeObject(forKey: CacheKeys.cacheTimestamp)
    }
    
    // MARK: - Private Methods
    
    /// Updates the location services availability cache on a background thread to avoid main thread blocking
    private func updateLocationServicesAvailability() async {
        // Prevent task proliferation with deduplication guard
        guard !isUpdatingAvailability else {
            print("📍 Location services availability update already in progress, skipping")
            return
        }

        // Check task limits before proceeding
        guard incrementTaskCount() else {
            print("❌ Failed to update location services availability: task limit reached")
            return
        }

        // Set flag and ensure cleanup on exit
        await MainActor.run {
            self.isUpdatingAvailability = true
        }

        defer {
            decrementTaskCount()
            Task { @MainActor in
                self.isUpdatingAvailability = false
            }
        }

        let availability = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let isEnabled = CLLocationManager.locationServicesEnabled()
                continuation.resume(returning: isEnabled)
            }
        }

        await MainActor.run {
            self.cachedLocationServicesEnabled = availability
            self.locationServicesAvailabilityLastChecked = Date()
            print("📍 Location services availability updated: \(availability)")
        }
    }
    
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

        // Start intelligent location updates using battery-aware timer
        timerManager.scheduleTimer(id: "location-update", type: .locationUpdate) { [weak self] in
            Task { @MainActor in
                await self?.refreshLocationIfNeeded()
            }
        }
        
        // Setup app lifecycle monitoring for location services availability
        setupAppLifecycleObservers()

        print("🔋 Battery optimization enabled for location services")
    }
    
    /// Sets up app lifecycle observers to refresh location services availability cache
    @MainActor private func setupAppLifecycleObservers() {
        // Check observer limits before adding new observer
        guard incrementObserverCount() else {
            print("❌ Failed to setup app lifecycle observer: observer limit reached")
            return
        }
        
        // Clean up existing observer before setting up new one
        if let existingObserver = appLifecycleObserver {
            NotificationCenter.default.removeObserver(existingObserver)
            appLifecycleObserver = nil
            observerCount = max(0, observerCount - 1)
        }

        // Store observer token to prevent memory leak
        appLifecycleObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task {
                await self?.updateLocationServicesAvailability()
            }
        }

        print("📍 App lifecycle observers setup for location services availability")
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
        } catch is CancellationError {
            // Handle cancellation gracefully - this is normal if the task is cancelled
            print("ℹ️ Location refresh was cancelled")
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

        // Perform reverse geocoding to get city information (in background)
        Task {
            do {
                let coordinate = LocationCoordinate(from: clLocation.coordinate)
                let locationInfo = try await getLocationInfo(for: coordinate)

                await MainActor.run {
                    self.currentLocationInfo = locationInfo
                    // Cache the location info
                    self.cacheLocationInfo(locationInfo)
                }

                print("📍 Successfully resolved city: \(locationInfo.city ?? "Unknown")")
            } catch {
                print("📍 Failed to resolve city for location: \(error)")
                // Create basic location info without city
                let coordinate = LocationCoordinate(from: clLocation.coordinate)
                let basicLocationInfo = LocationInfo(
                    coordinate: coordinate,
                    accuracy: clLocation.horizontalAccuracy
                )

                await MainActor.run {
                    self.currentLocationInfo = basicLocationInfo
                    // Cache the basic location info
                    self.cacheLocationInfo(basicLocationInfo)
                }
            }
        }

        // Complete pending location request with thread safety
        continuationQueue.async(flags: .barrier) { [weak self] in
            guard let self = self,
                  let continuation = self.locationContinuation else { return }

            self.locationContinuation = nil
            self.locationRequestInProgress = false
            continuation.resume(returning: clLocation)
        }
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
        
        // Complete pending location request with thread safety
        continuationQueue.async(flags: .barrier) { [weak self] in
            guard let self = self,
                  let continuation = self.locationContinuation else { return }
            
            self.locationContinuation = nil
            self.locationRequestInProgress = false
            continuation.resume(throwing: locationError)
        }
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

    private func cacheLocationInfo(_ locationInfo: LocationInfo) {
        // Cache location info data
        let locationInfoData: [String: Any] = [
            "latitude": locationInfo.coordinate.latitude,
            "longitude": locationInfo.coordinate.longitude,
            "accuracy": locationInfo.accuracy,
            "timestamp": locationInfo.timestamp.timeIntervalSince1970,
            "city": locationInfo.city as Any,
            "country": locationInfo.country as Any
        ]

        if let data = try? JSONSerialization.data(withJSONObject: locationInfoData) {
            userDefaults.set(data, forKey: CacheKeys.cachedLocationInfo)
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

            // Also load cached location info if available
            loadCachedLocationInfo()
        } else {
            clearLocationCache()
        }
    }

    private func loadCachedLocationInfo() {
        guard let data = userDefaults.data(forKey: CacheKeys.cachedLocationInfo),
              let locationInfoData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let latitude = locationInfoData["latitude"] as? Double,
              let longitude = locationInfoData["longitude"] as? Double,
              let accuracy = locationInfoData["accuracy"] as? Double,
              let timestamp = locationInfoData["timestamp"] as? TimeInterval else {
            return
        }

        let coordinate = LocationCoordinate(latitude: latitude, longitude: longitude)
        let city = locationInfoData["city"] as? String
        let country = locationInfoData["country"] as? String

        let locationInfo = LocationInfo(
            coordinate: coordinate,
            accuracy: accuracy,
            timestamp: Date(timeIntervalSince1970: timestamp),
            city: city,
            country: country
        )

        currentLocationInfo = locationInfo
        print("📍 Loaded cached location info: \(city ?? "Unknown city")")
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

        // Complete pending permission request with thread safety
        continuationQueue.async(flags: .barrier) { [weak self] in
            guard let self = self,
                  let continuation = self.permissionContinuation else { return }
            
            self.permissionContinuation = nil
            self.permissionRequestInProgress = false
            continuation.resume(returning: status)
        }
        
        // Update location services availability cache when authorization changes
        Task {
            await updateLocationServicesAvailability()
        }
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
