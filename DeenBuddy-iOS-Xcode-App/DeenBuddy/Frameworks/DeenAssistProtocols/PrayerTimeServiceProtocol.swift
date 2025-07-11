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
    
    /// Current calculation method
    var calculationMethod: CalculationMethod { get set }
    
    /// Current madhab for Asr calculation
    var madhab: Madhab { get set }
    
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
}