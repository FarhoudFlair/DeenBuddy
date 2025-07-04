//
//  PrayerTimeService.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-04.
//

import Foundation
import CoreLocation
import Combine
import Adhan

/// Service for calculating Islamic prayer times
@MainActor
public class PrayerTimeService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var currentSchedule: PrayerSchedule?
    @Published public var isLoading: Bool = false
    @Published public var error: PrayerTimeError?
    @Published public var settings: PrayerTimeSettings
    
    // MARK: - Private Properties
    
    private let locationManager: LocationManager
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    private let userDefaults = UserDefaults.standard
    
    // Cache for prayer times
    private var cachedSchedules: [String: PrayerSchedule] = [:]
    private let maxCacheAge: TimeInterval = 24 * 60 * 60 // 24 hours
    
    // MARK: - Initialization
    
    public init(locationManager: LocationManager = LocationManager()) {
        self.locationManager = locationManager
        self.settings = Self.loadSettings()
        
        setupLocationObserver()
        startUpdateTimer()
        loadCachedData()
    }
    
    deinit {
        updateTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Calculate prayer times for a specific date and location
    public func calculatePrayerTimes(
        for date: Date,
        location: CLLocation,
        settings: PrayerTimeSettings? = nil
    ) async throws -> PrayerSchedule {
        let calculationSettings = settings ?? self.settings
        
        // Create location info
        let locationInfo = await createLocationInfo(from: location)
        
        // Calculate prayer times using Adhan
        let prayerTimes = try calculateAdhanPrayerTimes(
            for: date,
            location: location,
            settings: calculationSettings
        )
        
        // Create prayer schedule
        let schedule = PrayerSchedule(
            date: date,
            location: locationInfo,
            prayerTimes: prayerTimes,
            calculationMethod: calculationSettings.calculationMethod,
            madhab: calculationSettings.madhab
        )
        
        // Cache the schedule
        cacheSchedule(schedule)
        
        return schedule
    }
    
    /// Refresh current prayer times
    public func refreshPrayerTimes() async {
        isLoading = true
        error = nil
        
        do {
            guard let location = await getCurrentLocation() else {
                throw PrayerTimeError.locationUnavailable
            }
            
            let schedule = try await calculatePrayerTimes(
                for: Date(),
                location: location
            )
            
            currentSchedule = schedule
        } catch {
            self.error = error as? PrayerTimeError ?? .calculationFailed(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    /// Get prayer times for a date range
    public func getPrayerTimes(
        from startDate: Date,
        to endDate: Date,
        location: CLLocation? = nil
    ) async throws -> [PrayerSchedule] {
        let targetLocation = location ?? await getCurrentLocation()
        guard let targetLocation = targetLocation else {
            throw PrayerTimeError.locationUnavailable
        }
        
        var schedules: [PrayerSchedule] = []
        let calendar = Calendar.current
        var currentDate = startDate
        
        while currentDate <= endDate {
            // Check cache first
            if let cachedSchedule = getCachedSchedule(for: currentDate, location: targetLocation) {
                schedules.append(cachedSchedule)
            } else {
                let schedule = try await calculatePrayerTimes(
                    for: currentDate,
                    location: targetLocation
                )
                schedules.append(schedule)
            }
            
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }
        
        return schedules
    }
    
    /// Update prayer time settings
    public func updateSettings(_ newSettings: PrayerTimeSettings) {
        settings = newSettings
        saveSettings()
        
        // Refresh prayer times with new settings
        Task {
            await refreshPrayerTimes()
        }
    }
    
    /// Get next prayer from current schedule
    public var nextPrayer: PrayerTime? {
        return currentSchedule?.nextPrayer
    }
    
    /// Get current prayer from current schedule
    public var currentPrayer: PrayerTime? {
        return currentSchedule?.currentPrayer
    }
    
    // MARK: - Private Methods
    
    private func setupLocationObserver() {
        locationManager.$currentLocation
            .compactMap { $0 }
            .removeDuplicates { abs($0.coordinate.latitude - $1.coordinate.latitude) < 0.001 &&
                               abs($0.coordinate.longitude - $1.coordinate.longitude) < 0.001 }
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshPrayerTimes()
                }
            }
            .store(in: &cancellables)
    }
    
    private func startUpdateTimer() {
        // Update prayer statuses every minute
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePrayerStatuses()
            }
        }
    }
    
    private func updatePrayerStatuses() {
        guard var schedule = currentSchedule else { return }
        
        let now = Date()
        var updatedPrayerTimes: [PrayerTime] = []
        
        for (index, prayerTime) in schedule.prayerTimes.enumerated() {
            let status: PrayerStatus
            
            if now < prayerTime.time {
                status = .upcoming
            } else if index < schedule.prayerTimes.count - 1 {
                let nextPrayerTime = schedule.prayerTimes[index + 1].time
                status = now < nextPrayerTime ? .current : .passed
            } else {
                // Last prayer of the day
                let endOfDay = Calendar.current.startOfDay(for: now.addingTimeInterval(24 * 60 * 60))
                status = now < endOfDay ? .current : .passed
            }
            
            let updatedPrayerTime = PrayerTime(
                prayer: prayerTime.prayer,
                time: prayerTime.time,
                status: status
            )
            updatedPrayerTimes.append(updatedPrayerTime)
        }
        
        currentSchedule = PrayerSchedule(
            date: schedule.date,
            location: schedule.location,
            prayerTimes: updatedPrayerTimes,
            calculationMethod: schedule.calculationMethod,
            madhab: schedule.madhab
        )
    }
    
    private func calculateAdhanPrayerTimes(
        for date: Date,
        location: CLLocation,
        settings: PrayerTimeSettings
    ) throws -> [PrayerTime] {
        let coordinates = Coordinates(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        
        let params = settings.calculationMethod.adhanCalculationParameters()
        params.madhab = settings.madhab.adhanMadhab()
        
        guard let adhanPrayerTimes = Adhan.PrayerTimes(
            coordinates: coordinates,
            date: dateComponents,
            calculationParameters: params
        ) else {
            throw PrayerTimeError.calculationFailed("Adhan library failed to calculate prayer times")
        }
        
        let now = Date()
        let prayers: [(Prayer, Date)] = [
            (.fajr, adhanPrayerTimes.fajr),
            (.dhuhr, adhanPrayerTimes.dhuhr),
            (.asr, adhanPrayerTimes.asr),
            (.maghrib, adhanPrayerTimes.maghrib),
            (.isha, adhanPrayerTimes.isha)
        ]
        
        return prayers.map { prayer, time in
            let status: PrayerStatus
            if now < time {
                status = .upcoming
            } else {
                // Determine if this is the current prayer or has passed
                let nextPrayerIndex = prayers.firstIndex { $0.1 > now }
                if let nextIndex = nextPrayerIndex,
                   let currentIndex = prayers.firstIndex(where: { $0.1 == time }),
                   currentIndex == nextIndex - 1 {
                    status = .current
                } else {
                    status = .passed
                }
            }
            
            return PrayerTime(prayer: prayer, time: time, status: status)
        }
    }
    
    private func getCurrentLocation() async -> CLLocation? {
        return await withCheckedContinuation { continuation in
            locationManager.requestLocationPermission { result in
                switch result {
                case .success(let location):
                    continuation.resume(returning: location)
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func createLocationInfo(from location: CLLocation) async -> LocationInfo {
        // Try to get city and country from reverse geocoding
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let placemark = placemarks.first
            
            return LocationInfo(
                coordinate: location.coordinate,
                city: placemark?.locality,
                country: placemark?.country,
                timezone: placemark?.timeZone ?? .current
            )
        } catch {
            return LocationInfo(
                coordinate: location.coordinate,
                city: nil,
                country: nil,
                timezone: .current
            )
        }
    }

    // MARK: - Caching Methods

    private func cacheSchedule(_ schedule: PrayerSchedule) {
        let cacheKey = createCacheKey(for: schedule.date, location: schedule.location.coordinate)
        cachedSchedules[cacheKey] = schedule

        // Also save to UserDefaults for persistence
        if let data = try? JSONEncoder().encode(schedule) {
            userDefaults.set(data, forKey: "cached_schedule_\(cacheKey)")
        }
    }

    private func getCachedSchedule(for date: Date, location: CLLocation) -> PrayerSchedule? {
        let cacheKey = createCacheKey(for: date, location: location.coordinate)

        // Check in-memory cache first
        if let schedule = cachedSchedules[cacheKey] {
            return schedule
        }

        // Check UserDefaults cache
        if let data = userDefaults.data(forKey: "cached_schedule_\(cacheKey)"),
           let schedule = try? JSONDecoder().decode(PrayerSchedule.self, from: data) {
            cachedSchedules[cacheKey] = schedule
            return schedule
        }

        return nil
    }

    private func createCacheKey(for date: Date, location: CLLocationCoordinate2D) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        let locationString = String(format: "%.3f,%.3f", location.latitude, location.longitude)
        return "\(dateString)_\(locationString)_\(settings.calculationMethod.rawValue)_\(settings.madhab.rawValue)"
    }

    private func loadCachedData() {
        // Load any cached schedules from UserDefaults
        let keys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("cached_schedule_") }

        for key in keys {
            if let data = userDefaults.data(forKey: key),
               let schedule = try? JSONDecoder().decode(PrayerSchedule.self, from: data) {
                let cacheKey = String(key.dropFirst("cached_schedule_".count))
                cachedSchedules[cacheKey] = schedule
            }
        }
    }

    private func clearOldCache() {
        let now = Date()
        let calendar = Calendar.current

        cachedSchedules = cachedSchedules.filter { _, schedule in
            guard let daysDifference = calendar.dateComponents([.day], from: schedule.date, to: now).day else {
                return false
            }
            return abs(daysDifference) <= 7 // Keep cache for 7 days
        }
    }

    // MARK: - Settings Methods

    private static func loadSettings() -> PrayerTimeSettings {
        guard let data = UserDefaults.standard.data(forKey: "prayer_time_settings"),
              let settings = try? JSONDecoder().decode(PrayerTimeSettings.self, from: data) else {
            return PrayerTimeSettings() // Default settings
        }
        return settings
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: "prayer_time_settings")
        }
    }

    // MARK: - Public Utility Methods

    /// Clear all cached prayer times
    public func clearCache() {
        cachedSchedules.removeAll()

        // Clear UserDefaults cache
        let keys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("cached_schedule_") }
        for key in keys {
            userDefaults.removeObject(forKey: key)
        }
    }

    /// Get recommended calculation methods for current location
    public func getRecommendedCalculationMethods(for location: CLLocation) -> [CalculationMethod] {
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude

        // Provide recommendations based on geographic regions
        if latitude >= 24 && latitude <= 42 && longitude >= 34 && longitude <= 63 {
            // Middle East region
            return [.ummAlQura, .muslimWorldLeague, .egyptian]
        } else if latitude >= 23 && latitude <= 38 && longitude >= 60 && longitude <= 95 {
            // South Asia region
            return [.karachi, .muslimWorldLeague]
        } else if latitude >= 25 && latitude <= 49 && longitude >= -125 && longitude <= -66 {
            // North America region
            return [.northAmerica, .muslimWorldLeague]
        } else if latitude >= 1 && latitude <= 7 && longitude >= 103 && longitude <= 105 {
            // Singapore region
            return [.singapore, .muslimWorldLeague]
        } else if latitude >= 24 && latitude <= 26 && longitude >= 54 && longitude <= 56 {
            // UAE region
            return [.dubai, .muslimWorldLeague]
        } else {
            // Default recommendations
            return [.muslimWorldLeague, .northAmerica, .egyptian]
        }
    }

    /// Check if location services are available and authorized
    public var isLocationAvailable: Bool {
        return locationManager.authorizationStatus == .authorizedWhenInUse ||
               locationManager.authorizationStatus == .authorizedAlways
    }

    /// Request location permission
    public func requestLocationPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            locationManager.requestLocationPermission { result in
                continuation.resume(returning: result.isSuccess)
            }
        }
    }
}

// MARK: - Result Extension

private extension Result {
    var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }
}
