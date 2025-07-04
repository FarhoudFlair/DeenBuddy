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
    
    public init(
        prayerTimeService: PrayerTimeService = PrayerTimeService(),
        hijriCalendarService: HijriCalendarService = HijriCalendarService(),
        locationManager: LocationManager = LocationManager()
    ) {
        self.prayerTimeService = prayerTimeService
        self.hijriCalendarService = hijriCalendarService
        self.locationManager = locationManager
        self.settings = prayerTimeService.settings
        self.dualCalendarDate = DualCalendarDate(gregorianDate: Date())
        
        setupBindings()
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
    
    /// Format prayer time according to user preferences
    public func formatPrayerTime(_ prayerTime: PrayerTime) -> String {
        return prayerTime.formattedTime(format: settings.timeFormat)
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
    
    /// Show calculation method picker
    public func showCalculationMethodPicker() {
        showingCalculationMethodPicker = true
    }
    
    /// Handle app becoming active (refresh data)
    public func handleAppBecameActive() {
        Task {
            await refreshPrayerTimes()
            updateTodaysEvents()
            updateDualCalendarDate()
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
