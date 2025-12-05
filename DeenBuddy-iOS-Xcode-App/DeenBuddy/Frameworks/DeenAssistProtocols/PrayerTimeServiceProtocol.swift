import Foundation
import CoreLocation
import Combine

/// Protocol for prayer time calculation services
@MainActor
public protocol PrayerTimeServiceProtocol: AnyObject, ObservableObject {
    /// Current prayer times for today
    var todaysPrayerTimes: [AppPrayerTime] { get }
    
    /// Publisher for today's prayer times
    var todaysPrayerTimesPublisher: AnyPublisher<[AppPrayerTime], Never> { get }
    
    /// Next upcoming prayer
    var nextPrayer: AppPrayerTime? { get }
    
    /// Time remaining until next prayer
    var timeUntilNextPrayer: TimeInterval? { get }
    
    /// Current calculation method (read-only, sourced from SettingsService)
    var calculationMethod: CalculationMethod { get }

    /// Current madhab for Asr calculation (read-only, sourced from SettingsService)
    var madhab: Madhab { get }
    
    /// Whether prayer times are currently loading
    var isLoading: Bool { get }
    
    /// Any prayer calculation error
    var error: Error? { get }
    
    /// Calculate prayer times for a specific location and date
    func calculatePrayerTimes(for location: CLLocation, date: Date) async throws -> [AppPrayerTime]
    
    /// Refresh current prayer times
    func refreshPrayerTimes() async
    
    /// Refresh today's prayer times specifically (required by BackgroundTaskManager)
    func refreshTodaysPrayerTimes() async
    
    /// Get prayer times for a date range
    func getPrayerTimes(from startDate: Date, to endDate: Date) async throws -> [Date: [AppPrayerTime]]

    /// Get tomorrow's prayer times with caching optimization (for widgets)
    func getTomorrowPrayerTimes(for location: CLLocation) async throws -> [AppPrayerTime]

    /// Calculate prayer times for a future date with Islamic metadata and precision policy
    /// - Parameters:
    ///   - date: Future Gregorian date
    ///   - location: Optional location override; defaults to current location
    func getFuturePrayerTimes(for date: Date, location: CLLocation?) async throws -> FuturePrayerTimeResult

    /// Calculate prayer times for a future date range (max 90 days)
    /// - Parameters:
    ///   - startDate: Start of range
    ///   - endDate: End of range
    ///   - location: Optional location override
    func getFuturePrayerTimes(from startDate: Date, to endDate: Date, location: CLLocation?) async throws -> [FuturePrayerTimeResult]

    /// Validate lookahead date and return disclaimer level or throw if beyond limits
    func validateLookaheadDate(_ date: Date) throws -> DisclaimerLevel

    /// Check if a location is considered high latitude for prayer calculations
    func isHighLatitudeLocation(_ location: CLLocation) -> Bool

    /// Get current location (for background services)
    func getCurrentLocation() async throws -> CLLocation
    
    /// Trigger Dynamic Island for next prayer (for testing/debugging)
    func triggerDynamicIslandForNextPrayer() async
}
