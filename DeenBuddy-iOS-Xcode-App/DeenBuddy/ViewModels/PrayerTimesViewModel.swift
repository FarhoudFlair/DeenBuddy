//
//  PrayerTimesViewModel.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-04.
//

import Foundation
import Combine
import CoreLocation
import os.log

@MainActor
class PrayerTimesViewModel: ObservableObject {
    @Published var prayerTimes: PrayerTimes?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var prayerTimeService: any PrayerTimeServiceProtocol
    private var locationService: any LocationServiceProtocol
    var settingsService: any SettingsServiceProtocol
    private let logger = Logger(subsystem: "com.deenbuddy.app", category: "PrayerTimesViewModel")
    private var cancellables = Set<AnyCancellable>()
    
    // Computed property to access settings
    var settings: any SettingsServiceProtocol {
        return settingsService
    }

    init(container: DependencyContainer) {
        guard let prayerTimeService = container.resolve((any PrayerTimeServiceProtocol).self),
              let locationService = container.resolve((any LocationServiceProtocol).self),
              let settingsService = container.resolve((any SettingsServiceProtocol).self) else {
            self.prayerTimeService = MockPrayerTimeService()
            self.locationService = DummyLocationService()
            self.settingsService = DummySettingsService()
            self.errorMessage = "Dependency resolution failed. Please restart the app or contact support."
            return
        }
        self.prayerTimeService = prayerTimeService
        self.locationService = locationService
        self.settingsService = settingsService
    }

    convenience init() {
        self.init(container: DependencyContainer.shared)
    }
    
    // Synchronous convenience initializer for Preview and testing
    convenience init(preview: Bool = false) {
        let mockPrayerTimeService = MockPrayerTimeService()
        let dummyLocationService = DummyLocationService()
        let dummySettingsService = DummySettingsService()
        
        self.init(
            prayerTimeService: mockPrayerTimeService,
            locationService: dummyLocationService,
            settingsService: dummySettingsService
        )
    }
    
    // Direct initializer for dependency injection
    init(
        prayerTimeService: any PrayerTimeServiceProtocol,
        locationService: any LocationServiceProtocol,
        settingsService: any SettingsServiceProtocol
    ) {
        self.prayerTimeService = prayerTimeService
        self.locationService = locationService
        self.settingsService = settingsService
    }

    @MainActor
    func fetchPrayerTimes() async {
        isLoading = true
        do {
            // Use cached location if available and valid, otherwise get fresh location
            let location = try await locationService.getLocationPreferCached()
            let times = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
            self.prayerTimes = PrayerTimes(
                date: Date(),
                fajr: times.first(where: { $0.prayer == .fajr })?.time ?? Date(),
                dhuhr: times.first(where: { $0.prayer == .dhuhr })?.time ?? Date(),
                asr: times.first(where: { $0.prayer == .asr })?.time ?? Date(),
                maghrib: times.first(where: { $0.prayer == .maghrib })?.time ?? Date(),
                isha: times.first(where: { $0.prayer == .isha })?.time ?? Date(),
                calculationMethod: self.prayerTimeService.calculationMethod.displayName,
                location: LocationCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            )

            // Update widget data when prayer times are fetched
            await self.updateWidgetData(with: times, location: location)

            self.isLoading = false
        } catch {
            self.isLoading = false
            if let prayerError = error as? PrayerTimeError {
                self.errorMessage = prayerError.errorDescription ?? "An error occurred."
            } else if let localized = error as? LocalizedError, let desc = localized.errorDescription {
                self.errorMessage = desc
            } else {
                self.errorMessage = "Failed to fetch prayer times. Please try again."
            }
        }
    }

    /// Update widget data when prayer times are fetched
    private func updateWidgetData(with times: [PrayerTime], location: CLLocation) async {
        // Find next prayer
        let now = Date()
        let upcomingPrayers = times.filter { $0.time > now }
        let nextPrayer: PrayerTime?
        let timeUntilNext: TimeInterval?

        if let upcoming = upcomingPrayers.first {
            // Found upcoming prayer today
            nextPrayer = upcoming
            timeUntilNext = upcoming.time.timeIntervalSince(now)
        } else {
            // No more prayers today, fetch tomorrow's Fajr time
            let calendar = Calendar.current
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
                do {
                    let tomorrowPrayerTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: tomorrow)
                    if let fajrTime = tomorrowPrayerTimes.first(where: { $0.prayer == .fajr }) {
                        nextPrayer = fajrTime
                        timeUntilNext = fajrTime.time.timeIntervalSince(now)
                        logger.info("✅ Successfully fetched tomorrow's Fajr time for widget")
                    } else {
                        nextPrayer = nil
                        timeUntilNext = nil
                        logger.warning("⚠️ Could not find Fajr prayer in tomorrow's prayer times")
                    }
                } catch {
                    nextPrayer = nil
                    timeUntilNext = nil
                    logger.error("❌ Failed to fetch tomorrow's prayer times: \(error.localizedDescription)")
                }
            } else {
                nextPrayer = nil
                timeUntilNext = nil
                logger.error("❌ Could not calculate tomorrow's date")
            }
        }

        // Create widget data with formatted location info
        let widgetData = WidgetData(
            nextPrayer: nextPrayer,
            timeUntilNextPrayer: timeUntilNext,
            todaysPrayerTimes: times,
            hijriDate: HijriDate(from: Date()),
            location: formatLocationForWidget(location),
            calculationMethod: prayerTimeService.calculationMethod,
            lastUpdated: Date()
        )

        // Save widget data
        WidgetDataManager.shared.saveWidgetData(widgetData)

        logger.info("✅ Widget data updated from PrayerTimesViewModel")
    }

    /// Format CLLocation into a user-friendly string for widget display
    private func formatLocationForWidget(_ location: CLLocation) -> String {
        // Use the currentLocationInfo if available (from location service)
        if let locationInfo = locationService.currentLocationInfo,
           let city = locationInfo.city {
            // Determine if we should show "Near" prefix based on accuracy
            let accuracy = location.horizontalAccuracy
            if accuracy > 100 {
                return "Near \(city)"
            } else {
                return city
            }
        }

        // Fallback to coordinates if no city info available
        return String(format: "%.2f°, %.2f°", location.coordinate.latitude, location.coordinate.longitude)
    }

}

// MARK: - Dummy Services for Fallback
@MainActor
private class DummyLocationService: LocationServiceProtocol {
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocation?
    var currentLocationInfo: LocationInfo?
    var isUpdatingLocation: Bool = false
    var locationError: Error?
    var currentHeading: Double = 0
    var headingAccuracy: Double = -1
    var isUpdatingHeading: Bool = false
    var permissionStatus: CLAuthorizationStatus { .notDetermined }
    var locationPublisher: AnyPublisher<CLLocation, Error> { Empty().eraseToAnyPublisher() }
    var headingPublisher: AnyPublisher<CLHeading, Error> { Empty().eraseToAnyPublisher() }
    func requestLocationPermission() {}
    func requestLocationPermissionAsync() async -> CLAuthorizationStatus { .notDetermined }
    func requestLocation() async throws -> CLLocation { throw LocationError.locationUnavailable("Location unavailable in dummy service") }
    func startUpdatingLocation() {}
    func stopUpdatingLocation() {}
    func startBackgroundLocationUpdates() {}
    func stopBackgroundLocationUpdates() {}
    func startUpdatingHeading() {}
    func stopUpdatingHeading() {}
    func geocodeCity(_ cityName: String) async throws -> CLLocation { throw LocationError.geocodingFailed("Geocoding failed in dummy service") }
    func getCachedLocation() -> CLLocation? { return nil }
    func isCachedLocationValid() -> Bool { return false }
    func getLocationPreferCached() async throws -> CLLocation { throw LocationError.locationUnavailable("Location unavailable in dummy service") }
    func isCurrentLocationFromCache() -> Bool { return false }
    func getLocationAge() -> TimeInterval? { return nil }
    func searchCity(_ cityName: String) async throws -> [LocationInfo] { throw LocationError.geocodingFailed("Geocoding failed in dummy service") }
    func getLocationInfo(for coordinate: LocationCoordinate) async throws -> LocationInfo { throw LocationError.geocodingFailed("Geocoding failed in dummy service") }
}

@MainActor
private class DummySettingsService: SettingsServiceProtocol, ObservableObject {
    @Published var calculationMethod: CalculationMethod = .muslimWorldLeague
    @Published var madhab: Madhab = .shafi
    @Published var useAstronomicalMaghrib: Bool = false
    @Published var notificationsEnabled: Bool = true
    @Published var theme: ThemeMode = .dark
    @Published var timeFormat: TimeFormat = .twelveHour
    @Published var notificationOffset: TimeInterval = 300
    @Published var overrideBatteryOptimization: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    @Published var userName: String = ""
    @Published var showArabicSymbolInWidget: Bool = true

    var enableNotifications: Bool {
        get { notificationsEnabled }
        set { notificationsEnabled = newValue }
    }
    
    func saveSettings() async throws {}
    func loadSettings() async throws {}
    func resetToDefaults() async throws {}
    func saveImmediately() async throws {}
    func saveOnboardingSettings() async throws {}
}

