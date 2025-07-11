//
//  PrayerTimesViewModel.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-04.
//

import Foundation
import Combine
import CoreLocation

@MainActor
class PrayerTimesViewModel: ObservableObject {
    @Published var prayerTimes: PrayerTimes?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var prayerTimeService: any PrayerTimeServiceProtocol
    private var locationService: any LocationServiceProtocol
    var settingsService: any SettingsServiceProtocol
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

    convenience init() async {
        await self.init(container: DependencyContainer.shared)
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
            let location = try await locationService.requestLocation()
            let times = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
            await MainActor.run {
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
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
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
    }
    
    @MainActor
    func loadMockData() {
        let now = Date()
        let calendar = Calendar.current
        
        // Create mock prayer times for today
        let fajrTime = calendar.date(bySettingHour: 5, minute: 30, second: 0, of: now) ?? now
        let dhuhrTime = calendar.date(bySettingHour: 12, minute: 15, second: 0, of: now) ?? now
        let asrTime = calendar.date(bySettingHour: 15, minute: 45, second: 0, of: now) ?? now
        let maghribTime = calendar.date(bySettingHour: 18, minute: 30, second: 0, of: now) ?? now
        let ishaTime = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now) ?? now
        
        self.prayerTimes = PrayerTimes(
            date: now,
            fajr: fajrTime,
            dhuhr: dhuhrTime,
            asr: asrTime,
            maghrib: maghribTime,
            isha: ishaTime,
            calculationMethod: "Mock Data (Default)",
            location: LocationCoordinate(latitude: 37.7749, longitude: -122.4194) // San Francisco
        )
        
        self.errorMessage = nil
        self.isLoading = false
    }
}

// MARK: - Dummy Services for Fallback
private class DummyLocationService: LocationServiceProtocol {
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocation?
    var isUpdatingLocation: Bool = false
    var locationError: Error?
    var permissionStatus: CLAuthorizationStatus { .notDetermined }
    var locationPublisher: AnyPublisher<CLLocation, Error> { Empty().eraseToAnyPublisher() }
    func requestLocationPermission() {}
    func requestLocation() async throws -> CLLocation { throw LocationError.locationUnavailable }
    func startUpdatingLocation() {}
    func stopUpdatingLocation() {}
    func geocodeCity(_ cityName: String) async throws -> CLLocation { throw LocationError.geocodingFailed }
}

@MainActor
private class DummySettingsService: SettingsServiceProtocol, ObservableObject {
    @Published var calculationMethod: CalculationMethod = .muslimWorldLeague
    @Published var madhab: Madhab = .shafi
    @Published var notificationsEnabled: Bool = true
    @Published var theme: ThemeMode = .dark
    @Published var timeFormat: TimeFormat = .twelveHour
    @Published var notificationOffset: TimeInterval = 300
    @Published var overrideBatteryOptimization: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    
    var enableNotifications: Bool {
        get { notificationsEnabled }
        set { notificationsEnabled = newValue }
    }
    
    func saveSettings() async throws {}
    func loadSettings() async throws {}
    func resetToDefaults() async throws {}
}

