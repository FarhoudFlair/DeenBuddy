import Foundation
import CoreLocation

/// Protocol for prayer time calculation services
@MainActor
public protocol PrayerTimeServiceProtocol: ObservableObject {
    /// Current prayer times for today
    var todaysPrayerTimes: [PrayerTime] { get }
    
    /// Next upcoming prayer
    var nextPrayer: PrayerTime? { get }
    
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
    func calculatePrayerTimes(for location: CLLocation, date: Date) async throws -> [PrayerTime]
    
    /// Refresh current prayer times
    func refreshPrayerTimes() async
    
    /// Refresh today's prayer times specifically (required by BackgroundTaskManager)
    func refreshTodaysPrayerTimes() async
    
    /// Get prayer times for a date range
    func getPrayerTimes(from startDate: Date, to endDate: Date) async throws -> [Date: [PrayerTime]]

    /// Get tomorrow's prayer times with caching optimization (for widgets)
    func getTomorrowPrayerTimes(for location: CLLocation) async throws -> [PrayerTime]

    /// Get current location (for background services)
    func getCurrentLocation() async throws -> CLLocation
    
    /// Trigger Dynamic Island for next prayer (for testing/debugging)
    func triggerDynamicIslandForNextPrayer() async
}