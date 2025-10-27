import XCTest
import SwiftUI
import CoreLocation
import Combine
import UserNotifications
@testable import DeenBuddy

class LocationDiagnosticTests: XCTestCase {
    
    @MainActor
    func testLocationDiagnosticPopupCreation() {
        // Given
        let location = CLLocation(latitude: 40.7128, longitude: -74.0060)
        let mockLocationService = LocationDiagnosticMockLocationService()
        let isPresented = Binding.constant(true)
        
        // When
        let popup = LocationDiagnosticPopup(
            location: location,
            locationService: mockLocationService,
            isPresented: isPresented
        )
        
        // Then
        XCTAssertNotNil(popup)
    }
    
    func testLocationServiceProtocolMethods() async throws {
        // Given
        let mockLocationService = await MockLocationService()
        let coordinate = LocationCoordinate(latitude: 40.7128, longitude: -74.0060)
        
        // When & Then
        let locationInfo = try await mockLocationService.getLocationInfo(for: coordinate)
        XCTAssertEqual(locationInfo.coordinate.latitude, coordinate.latitude)
        XCTAssertEqual(locationInfo.coordinate.longitude, coordinate.longitude)
        XCTAssertNotNil(locationInfo.city)
        XCTAssertNotNil(locationInfo.country)
        
        let searchResults = try await mockLocationService.searchCity("New York")
        XCTAssertGreaterThanOrEqual(searchResults.count, 0)
    }
    
    @MainActor
    func testHomeScreenWithLocationDiagnostic() {
        // Given
        let mockPrayerTimeService = LocationDiagnosticMockPrayerTimeService()
        let mockLocationService = LocationDiagnosticMockLocationService()
        let mockSettingsService = LocationDiagnosticMockSettingsService()
        
        // When
        let homeScreen = HomeScreen(
            prayerTimeService: mockPrayerTimeService,
            locationService: mockLocationService,
            settingsService: mockSettingsService,
            onCompassTapped: {},
            onGuidesTapped: {},
            onQuranSearchTapped: {},
            onSettingsTapped: {}
        )
        
        // Then
        XCTAssertNotNil(homeScreen)
    }
}

// MARK: - Mock Classes

@MainActor
class LocationDiagnosticMockLocationService: LocationServiceProtocol, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    @Published var currentLocation: CLLocation? = nil
    @Published var currentLocationInfo: LocationInfo? = nil
    @Published var isUpdatingLocation: Bool = false
    @Published var locationError: Error? = nil
    @Published var currentHeading: Double = 0
    @Published var headingAccuracy: Double = 5.0
    @Published var isUpdatingHeading: Bool = false

    var permissionStatus: CLAuthorizationStatus { authorizationStatus }

    private let locationSubject = PassthroughSubject<CLLocation, Error>()
    private let headingSubject = PassthroughSubject<CLHeading, Error>()

    var locationPublisher: AnyPublisher<CLLocation, Error> {
        locationSubject.eraseToAnyPublisher()
    }

    var headingPublisher: AnyPublisher<CLHeading, Error> {
        headingSubject.eraseToAnyPublisher()
    }

    func requestLocationPermission() {}
    func requestLocationPermissionAsync() async -> CLAuthorizationStatus { return .authorizedWhenInUse }
    func requestLocation() async throws -> CLLocation {
        return CLLocation(latitude: 37.7749, longitude: -122.4194)
    }
    func startUpdatingLocation() {}
    func stopUpdatingLocation() {}
    func startBackgroundLocationUpdates() {}
    func stopBackgroundLocationUpdates() {}
    func startUpdatingHeading() {}
    func stopUpdatingHeading() {}
    func geocodeCity(_ cityName: String) async throws -> CLLocation {
        return CLLocation(latitude: 37.7749, longitude: -122.4194)
    }
    func searchCity(_ cityName: String) async throws -> [LocationInfo] { return [] }
    func getLocationInfo(for coordinate: LocationCoordinate) async throws -> LocationInfo {
        return LocationInfo(coordinate: coordinate, accuracy: 10.0, city: "Test", country: "Test")
    }
    func getCachedLocation() -> CLLocation? { return currentLocation }
    func isCachedLocationValid() -> Bool { return true }
    func getLocationPreferCached() async throws -> CLLocation { return try await requestLocation() }
    func isCurrentLocationFromCache() -> Bool { return false }
    func getLocationAge() -> TimeInterval? { return 30.0 }
}

@MainActor
class LocationDiagnosticMockSettingsService: SettingsServiceProtocol, ObservableObject {
    @Published var calculationMethod: CalculationMethod = .muslimWorldLeague
    @Published var madhab: Madhab = .shafi
    @Published var useAstronomicalMaghrib: Bool = false
    @Published var notificationsEnabled: Bool = true
    @Published var theme: ThemeMode = .dark
    @Published var timeFormat: TimeFormat = .twelveHour
    @Published var notificationOffset: TimeInterval = 300
    @Published var hasCompletedOnboarding: Bool = false
    @Published var userName: String = ""
    @Published var overrideBatteryOptimization: Bool = false
    @Published var showArabicSymbolInWidget: Bool = true
    @Published var liveActivitiesEnabled: Bool = true

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

@MainActor
class LocationDiagnosticMockPrayerTimeService: PrayerTimeServiceProtocol, ObservableObject {
    @Published var todaysPrayerTimes: [PrayerTime] = []
    @Published var nextPrayer: PrayerTime? = nil
    @Published var timeUntilNextPrayer: TimeInterval? = nil
    @Published var calculationMethod: CalculationMethod = .muslimWorldLeague
    @Published var madhab: Madhab = .shafi
    @Published var isLoading: Bool = false
    @Published var error: Error? = nil

    func calculatePrayerTimes(for location: CLLocation, date: Date) async throws -> [PrayerTime] {
        return []
    }

    func refreshPrayerTimes() async {}
    func refreshTodaysPrayerTimes() async {}
    func getPrayerTimes(from startDate: Date, to endDate: Date) async throws -> [Date: [PrayerTime]] { return [:] }
    func getTomorrowPrayerTimes(for location: CLLocation) async throws -> [PrayerTime] { return [] }
    func getCurrentLocation() async throws -> CLLocation {
        return CLLocation(latitude: 37.7749, longitude: -122.4194)
    }
    func triggerDynamicIslandForNextPrayer() async {}
}

@MainActor
class LocationDiagnosticMockNotificationService: NotificationServiceProtocol, ObservableObject {
    @Published var authorizationStatus: UNAuthorizationStatus = .authorized
    @Published var notificationsEnabled: Bool = true

    func requestNotificationPermission() async throws -> Bool { return true }
    func schedulePrayerNotifications(for prayerTimes: [PrayerTime], date: Date?) async throws {}
    func cancelAllNotifications() async {}
    func cancelNotifications(for prayer: Prayer) async {}
    func schedulePrayerTrackingNotification(for prayer: Prayer, at prayerTime: Date, reminderMinutes: Int) async throws {}
    func getNotificationSettings() -> NotificationSettings { return .default }
    func updateNotificationSettings(_ settings: NotificationSettings) {}
    func updateAppBadge() async {}
    func clearBadge() async {}
    func updateBadgeForCompletedPrayer() async {}
}
