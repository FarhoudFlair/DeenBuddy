// MARK: - DeenAssist Core Module
// This module provides all the core functionality for the Deen Assist iOS app
// including location services, API integration, and notification management.

import Foundation

// MARK: - Models
@_exported import struct DeenAssistCore.LocationCoordinate
@_exported import struct DeenAssistCore.LocationInfo
@_exported import enum DeenAssistCore.LocationError
@_exported import enum DeenAssistCore.LocationPermissionStatus

@_exported import enum DeenAssistCore.Prayer
@_exported import struct DeenAssistCore.PrayerTimes
@_exported import enum DeenAssistCore.CalculationMethod
@_exported import enum DeenAssistCore.Madhab

@_exported import struct DeenAssistCore.QiblaDirection
@_exported import struct DeenAssistCore.KaabaLocation

@_exported import struct DeenAssistCore.AlAdhanTimingsResponse
@_exported import struct DeenAssistCore.AlAdhanQiblaResponse
@_exported import enum DeenAssistCore.APIError
@_exported import struct DeenAssistCore.APIConfiguration
@_exported import struct DeenAssistCore.APIRateLimitStatus

@_exported import enum DeenAssistCore.NotificationPermissionStatus
@_exported import struct DeenAssistCore.PendingNotification
@_exported import struct DeenAssistCore.NotificationSettings
@_exported import struct DeenAssistCore.NotificationContent
@_exported import enum DeenAssistCore.NotificationSound
@_exported import enum DeenAssistCore.NotificationError
@_exported import enum DeenAssistCore.ThemeMode
@_exported import enum DeenAssistCore.SettingsError
@_exported import enum DeenAssistCore.PrayerTimeError

// MARK: - Protocols
@_exported import protocol DeenAssistCore.LocationServiceProtocol
@_exported import protocol DeenAssistCore.APIClientProtocol
@_exported import protocol DeenAssistCore.NotificationServiceProtocol
@_exported import protocol DeenAssistCore.APICacheProtocol

// MARK: - Services
@_exported import class DeenAssistCore.LocationService
@_exported import class DeenAssistCore.APIClient
@_exported import class DeenAssistCore.NotificationService
@_exported import class DeenAssistCore.APICache
@_exported import class DeenAssistCore.PrayerTimeService
@_exported import class DeenAssistCore.SettingsService
@_exported import class DeenAssistCore.ContentService
@_exported import class DeenAssistCore.SupabaseService
@_exported import class DeenAssistCore.ConfigurationManager

// MARK: - Phase 2: Error Handling & Reliability
@_exported import class DeenAssistCore.ErrorHandler
@_exported import class DeenAssistCore.NetworkMonitor
@_exported import class DeenAssistCore.OfflineManager
@_exported import class DeenAssistCore.RetryMechanism
@_exported import class DeenAssistCore.MemoryManager
@_exported import class DeenAssistCore.BatteryOptimizer

// MARK: - Phase 3+4: Infrastructure & UX
@_exported import class DeenAssistCore.AnalyticsService
@_exported import class DeenAssistCore.AccessibilityService
@_exported import class DeenAssistCore.LocalizationService
@_exported import class DeenAssistCore.PerformanceMonitor

// MARK: - Mocks (for testing and parallel development)
@_exported import class DeenAssistCore.MockLocationService
@_exported import class DeenAssistCore.MockAPIClient
@_exported import class DeenAssistCore.MockNotificationService

// MARK: - Dependency Injection
@_exported import class DeenAssistCore.DependencyContainer
@_exported import class DeenAssistCore.ServiceFactory

// MARK: - Version Information

public struct DeenAssistCore {
    public static let version = "1.0.0"
    public static let buildNumber = "1"
    
    /// Initialize the core module with default configuration
    public static func initialize() {
        print("DeenAssist Core v\(version) (\(buildNumber)) initialized")
    }
    
    /// Create a dependency container for the app
    public static func createDependencyContainer(isTest: Bool = false) -> DependencyContainer {
        return DependencyContainer(isTestEnvironment: isTest)
    }
    
    /// Create a dependency container with custom services
    public static func createDependencyContainer(
        locationService: LocationServiceProtocol? = nil,
        apiClient: APIClientProtocol? = nil,
        notificationService: NotificationServiceProtocol? = nil,
        isTest: Bool = false
    ) -> DependencyContainer {
        return DependencyContainer(
            locationService: locationService,
            apiClient: apiClient,
            notificationService: notificationService,
            isTestEnvironment: isTest
        )
    }
}

// MARK: - Convenience Extensions

public extension LocationServiceProtocol {
    /// Get location with timeout and accuracy requirements
    func getLocationWithRequirements(
        timeout: TimeInterval = 30,
        minimumAccuracy: Double = 100
    ) async throws -> LocationInfo {
        let location = try await getCurrentLocation()
        
        guard location.accuracy <= minimumAccuracy else {
            throw LocationError.accuracyTooLow(location.accuracy)
        }
        
        return location
    }
}

public extension APIClientProtocol {
    /// Get prayer times with automatic fallback to cached data
    func getPrayerTimesWithFallback(
        for date: Date,
        location: LocationCoordinate,
        calculationMethod: CalculationMethod = .muslimWorldLeague,
        madhab: Madhab = .shafi
    ) async -> PrayerTimes? {
        do {
            return try await getPrayerTimes(
                for: date,
                location: location,
                calculationMethod: calculationMethod,
                madhab: madhab
            )
        } catch {
            print("Failed to get prayer times from API: \(error)")
            return nil
        }
    }
}

public extension NotificationServiceProtocol {
    /// Schedule notifications with automatic permission check
    func scheduleNotificationsIfAuthorized(for prayerTimes: PrayerTimes) async {
        guard permissionStatus.isAuthorized else {
            print("Notification permission not granted, skipping scheduling")
            return
        }
        
        do {
            try await schedulePrayerNotifications(for: prayerTimes)
        } catch {
            print("Failed to schedule prayer notifications: \(error)")
        }
    }
}

// MARK: - Utility Functions

public extension Date {
    /// Check if this date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Check if this date is tomorrow
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }
    
    /// Get a user-friendly relative date string
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

public extension PrayerTimes {
    /// Get the next prayer from current time
    var nextPrayer: (Prayer, Date)? {
        return nextPrayer(from: Date())
    }
    
    /// Get the current prayer at current time
    var currentPrayer: Prayer? {
        return currentPrayer(at: Date())
    }
    
    /// Get time remaining until next prayer
    var timeUntilNextPrayer: TimeInterval? {
        guard let (_, nextPrayerTime) = nextPrayer else { return nil }
        return nextPrayerTime.timeIntervalSinceNow
    }
}

public extension QiblaDirection {
    /// Get a user-friendly direction description
    var directionDescription: String {
        return "\(Int(direction))° \(compassDirection)"
    }
    
    /// Check if the direction is accurate (within reasonable bounds)
    var isAccurate: Bool {
        return direction >= 0 && direction <= 360
    }
}
