//
//  PrayerTimesViewModel.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-04.
//

import Foundation
import SwiftUI
import Combine
import CoreLocation
import Network

/// ViewModel for managing prayer times and related UI state
@MainActor
public class PrayerTimesViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var currentSchedule: PrayerSchedule?
    @Published public var dualCalendarDate: DualCalendarDate
    @Published public var isLoading: Bool = false
    @Published public var error: PrayerTimeError?
    @Published public var showingLocationPermissionAlert: Bool = false
    @Published public var showingSettings: Bool = false
    @Published public var showingCalculationMethodPicker: Bool = false
    
    // Location and permission state
    @Published public var locationPermissionStatus: LocationPermissionStatus = .notDetermined
    @Published public var currentLocationName: String = "Loading location..."
    
    // Settings
    @Published public var settings: PrayerTimeSettings {
        didSet {
            prayerTimeService.updateSettings(settings)
        }
    }
    
    // Islamic events
    @Published public var todaysEvents: [IslamicEvent] = []
    @Published public var upcomingEvents: [(date: Date, events: [IslamicEvent])] = []
    
    // MARK: - Private Properties

    private let prayerTimeService: PrayerTimeService
    private let hijriCalendarService: HijriCalendarService
    private let locationManager: LocationManager
    private var cancellables = Set<AnyCancellable>()
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    // MARK: - Computed Properties
    
    /// Next prayer time
    public var nextPrayer: PrayerTime? {
        return currentSchedule?.nextPrayer
    }
    
    /// Current prayer time
    public var currentPrayer: PrayerTime? {
        return currentSchedule?.currentPrayer
    }
    
    /// Time until next prayer
    public var timeUntilNextPrayer: String? {
        return nextPrayer?.timeRemainingFormatted
    }
    
    /// Whether location services are available
    public var isLocationAvailable: Bool {
        return locationPermissionStatus == .authorized
    }
    
    /// Formatted current location
    public var formattedLocation: String {
        return currentSchedule?.location.displayName ?? currentLocationName
    }
    
    /// Today's prayer times for display
    public var todaysPrayerTimes: [PrayerTime] {
        return currentSchedule?.prayerTimes ?? []
    }
    
    /// Whether it's currently Ramadan
    public var isRamadan: Bool {
        return hijriCalendarService.isRamadan(Date())
    }
    
    /// Whether today is in a sacred month
    public var isSacredMonth: Bool {
        return hijriCalendarService.isSacredMonth(Date())
    }
    
    // MARK: - Initialization

    deinit {
        networkMonitor.cancel()
    }

    public init(
        prayerTimeService: PrayerTimeService? = nil,
        hijriCalendarService: HijriCalendarService? = nil,
        locationManager: LocationManager? = nil
    ) {
        let locationMgr = locationManager ?? LocationManager()
        self.locationManager = locationMgr
        let prayerService = prayerTimeService ?? PrayerTimeService(locationManager: locationMgr)
        self.prayerTimeService = prayerService
        self.hijriCalendarService = hijriCalendarService ?? HijriCalendarService()
        self.settings = prayerService.settings
        self.dualCalendarDate = DualCalendarDate(gregorianDate: Date())
        
        setupBindings()
        setupNetworkMonitoring()
        updateLocationPermissionStatus()
        updateTodaysEvents()

        // Initial load
        Task {
            await loadInitialData()
        }
    }
    
    // MARK: - Public Methods
    
    /// Refresh prayer times
    public func refreshPrayerTimes() async {
        await prayerTimeService.refreshPrayerTimes()
    }
    
    /// Request location permission
    public func requestLocationPermission() async {
        let granted = await prayerTimeService.requestLocationPermission()
        updateLocationPermissionStatus()
        
        if granted {
            await refreshPrayerTimes()
        } else {
            showingLocationPermissionAlert = true
        }
    }
    
    /// Update prayer time settings
    public func updateSettings(_ newSettings: PrayerTimeSettings) {
        settings = newSettings
        validateAndFixSettings()
    }
    
    /// Get prayer times for a date range
    public func getPrayerTimes(from startDate: Date, to endDate: Date) async -> [PrayerSchedule] {
        do {
            return try await prayerTimeService.getPrayerTimes(from: startDate, to: endDate)
        } catch {
            self.error = error as? PrayerTimeError ?? .calculationFailed(error.localizedDescription)
            return []
        }
    }
    
    /// Clear all cached data
    public func clearCache() {
        prayerTimeService.clearCache()
        Task {
            await refreshPrayerTimes()
        }
    }
    
    /// Get recommended calculation methods for current location
    public func getRecommendedCalculationMethods() -> [CalculationMethod] {
        guard let location = locationManager.currentLocation else {
            return [.muslimWorldLeague, .northAmerica, .egyptian]
        }
        return prayerTimeService.getRecommendedCalculationMethods(for: location)
    }

    /// Check if current location has extreme latitude issues
    public func hasExtremeLatitudeIssues() -> Bool {
        guard let location = locationManager.currentLocation else { return false }
        let latitude = abs(location.coordinate.latitude)
        return latitude > 60.0 // Above 60 degrees latitude can have calculation issues
    }

    /// Handle extreme latitude locations with fallback methods
    public func handleExtremeLatitude() async {
        if hasExtremeLatitudeIssues() {
            // Try different calculation methods that handle extreme latitudes better
            let extremeLatitudeMethods: [CalculationMethod] = [.muslimWorldLeague, .karachi, .egyptian]

            for method in extremeLatitudeMethods {
                var testSettings = settings
                testSettings.calculationMethod = method

                // Test if this method works better
                let tempService = PrayerTimeService()
                tempService.updateSettings(testSettings)

                do {
                    if let location = locationManager.currentLocation {
                        _ = try await tempService.calculatePrayerTimes(for: Date(), location: location)
                        // If successful, update settings
                        updateSettings(testSettings)
                        await refreshPrayerTimes()
                        break
                    }
                } catch {
                    // Try next method
                    continue
                }
            }
        }
    }
    
    /// Format prayer time according to user preferences
    public func formatPrayerTime(_ prayerTime: PrayerTime) -> String {
        return prayerTime.formattedTime(format: settings.timeFormat)
    }

    /// Validate and fix calculation settings if needed
    public func validateAndFixSettings() {
        // Check if current settings are valid for the location
        if locationManager.currentLocation != nil {
            let recommendedMethods = getRecommendedCalculationMethods()

            // If current method is not recommended and we have recommendations, suggest change
            if !recommendedMethods.contains(settings.calculationMethod) && !recommendedMethods.isEmpty {
                // Could show a suggestion to user, but for now just log
                print("Current calculation method may not be optimal for this location")
            }
        }

        // Ensure notification offset is reasonable (between 1 minute and 1 hour)
        if settings.notificationOffset < 60 || settings.notificationOffset > 3600 {
            var newSettings = settings
            newSettings.notificationOffset = 300 // Default to 5 minutes
            updateSettings(newSettings)
        }
    }
    
    /// Get status color for prayer time
    public func getStatusColor(for prayerTime: PrayerTime) -> Color {
        return prayerTime.status.color
    }
    
    /// Get prayer icon
    public func getPrayerIcon(for prayer: Prayer) -> String {
        return prayer.systemImageName
    }
    
    /// Get prayer color
    public func getPrayerColor(for prayer: Prayer) -> Color {
        return prayer.color
    }
    
    /// Show settings screen
    public func showSettings() {
        showingSettings = true
    }

    /// Handle network connectivity changes
    public func handleNetworkConnectivityChange(isConnected: Bool) {
        if isConnected && error == .networkError {
            // Network is back, try to refresh prayer times
            Task {
                await refreshPrayerTimes()
            }
        }
    }

    /// Retry failed operation with exponential backoff
    public func retryWithBackoff() async {
        let maxRetries = 3
        var retryCount = 0

        while retryCount < maxRetries {
            await refreshPrayerTimes()
            if error == nil {
                break // Success, exit retry loop
            }

            retryCount += 1
            if retryCount < maxRetries {
                // Exponential backoff: 1s, 2s, 4s
                let delay = pow(2.0, Double(retryCount))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
    
    /// Show calculation method picker
    public func showCalculationMethodPicker() {
        showingCalculationMethodPicker = true
    }
    
    /// Handle app becoming active
    public func handleAppBecameActive() {
        Task {
            // Update location permission status
            updateLocationPermissionStatus()

            // Refresh prayer times if needed
            if isLocationAvailable {
                await refreshPrayerTimes()
            }

            // Update calendar dates and events
            updateDualCalendarDate()
            updateTodaysEvents()
            updateUpcomingEvents()
        }
    }

    /// Handle significant time change (e.g., timezone change)
    public func handleSignificantTimeChange() {
        Task {
            prayerTimeService.clearCache()
            await refreshPrayerTimes()
            updateDualCalendarDate()
        }
    }
    
    // MARK: - Private Methods

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handleNetworkConnectivityChange(isConnected: path.status == .satisfied)
            }
        }
        networkMonitor.start(queue: networkQueue)
    }

    private func setupBindings() {
        // Bind prayer time service
        prayerTimeService.$currentSchedule
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentSchedule, on: self)
            .store(in: &cancellables)
        
        prayerTimeService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        prayerTimeService.$error
            .receive(on: DispatchQueue.main)
            .assign(to: \.error, on: self)
            .store(in: &cancellables)
        
        // Bind Hijri calendar service
        hijriCalendarService.$todaysEvents
            .receive(on: DispatchQueue.main)
            .assign(to: \.todaysEvents, on: self)
            .store(in: &cancellables)
        
        // Update location name when location changes
        locationManager.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                Task { @MainActor in
                    await self?.updateLocationName(for: location)
                }
            }
            .store(in: &cancellables)
        
        // Update location permission status
        locationManager.$authorizationStatus
            .sink { [weak self] _ in
                self?.updateLocationPermissionStatus()
            }
            .store(in: &cancellables)
        
        // Update dual calendar date daily
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateDualCalendarDate()
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() async {
        updateDualCalendarDate()
        updateTodaysEvents()
        updateUpcomingEvents()
        
        if isLocationAvailable {
            await refreshPrayerTimes()
        }
    }
    
    private func updateLocationPermissionStatus() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationPermissionStatus = .notDetermined
        case .denied, .restricted:
            locationPermissionStatus = .denied
        case .authorizedWhenInUse, .authorizedAlways:
            locationPermissionStatus = .authorized
        @unknown default:
            locationPermissionStatus = .denied
        }
    }
    
    private func updateLocationName(for location: CLLocation) async {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let city = placemark.locality ?? ""
                let country = placemark.country ?? ""
                currentLocationName = [city, country].filter { !$0.isEmpty }.joined(separator: ", ")
                
                if currentLocationName.isEmpty {
                    currentLocationName = "Current Location"
                }
            }
        } catch {
            currentLocationName = "Current Location"
        }
    }
    
    private func updateDualCalendarDate() {
        dualCalendarDate = DualCalendarDate(gregorianDate: Date())
    }
    
    private func updateTodaysEvents() {
        todaysEvents = hijriCalendarService.getTodaysIslamicEvents()
    }
    
    private func updateUpcomingEvents() {
        upcomingEvents = hijriCalendarService.getUpcomingEvents(days: 30)
    }
}

// MARK: - Supporting Types

/// Location permission status
public enum LocationPermissionStatus {
    case notDetermined
    case denied
    case authorized
    
    public var displayText: String {
        switch self {
        case .notDetermined:
            return "Location permission not determined"
        case .denied:
            return "Location permission denied"
        case .authorized:
            return "Location permission granted"
        }
    }
}
