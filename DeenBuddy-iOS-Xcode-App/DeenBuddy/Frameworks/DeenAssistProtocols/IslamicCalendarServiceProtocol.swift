import Foundation
import Combine

/// Protocol for Islamic calendar functionality
@MainActor
public protocol IslamicCalendarServiceProtocol: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current Hijri date
    var currentHijriDate: HijriDate { get }
    
    /// Today's Islamic calendar information
    var todayInfo: IslamicCalendarDay { get }
    
    /// Upcoming Islamic events
    var upcomingEvents: [IslamicEvent] { get }
    
    /// All available Islamic events
    var allEvents: [IslamicEvent] { get }
    
    /// Calendar statistics
    var statistics: IslamicCalendarStatistics { get }
    
    /// Loading state for calendar operations
    var isLoading: Bool { get }
    
    /// Error state for calendar operations
    var error: Error? { get }
    
    // MARK: - Date Conversion
    
    /// Convert Gregorian date to Hijri date
    /// - Parameter gregorianDate: The Gregorian date to convert
    /// - Returns: Corresponding Hijri date
    func convertToHijri(_ gregorianDate: Date) async -> HijriDate
    
    /// Convert Hijri date to Gregorian date
    /// - Parameter hijriDate: The Hijri date to convert
    /// - Returns: Corresponding Gregorian date
    func convertToGregorian(_ hijriDate: HijriDate) async -> Date
    
    /// Get current Hijri date
    /// - Returns: Current Hijri date
    func getCurrentHijriDate() async -> HijriDate
    
    /// Check if a Gregorian date corresponds to a specific Hijri date
    /// - Parameters:
    ///   - gregorianDate: The Gregorian date to check
    ///   - hijriDate: The Hijri date to compare against
    /// - Returns: True if dates correspond
    func isDate(_ gregorianDate: Date, equalToHijri hijriDate: HijriDate) async -> Bool
    
    // MARK: - Calendar Information
    
    /// Get Islamic calendar information for a specific date
    /// - Parameter date: The date to get information for
    /// - Returns: Islamic calendar day information
    func getCalendarInfo(for date: Date) async -> IslamicCalendarDay
    
    /// Get Islamic calendar information for a date range
    /// - Parameter period: The date interval to query
    /// - Returns: Array of Islamic calendar days
    func getCalendarInfo(for period: DateInterval) async -> [IslamicCalendarDay]
    
    /// Get Islamic calendar information for a specific month
    /// - Parameters:
    ///   - month: The Hijri month
    ///   - year: The Hijri year
    /// - Returns: Array of Islamic calendar days for the month
    func getMonthInfo(month: HijriMonth, year: Int) async -> [IslamicCalendarDay]
    
    /// Check if a date is a holy day
    /// - Parameter date: The date to check
    /// - Returns: True if the date is a holy day
    func isHolyDay(_ date: Date) async -> Bool
    
    /// Get moon phase for a specific date
    /// - Parameter date: The date to get moon phase for
    /// - Returns: Moon phase if available
    func getMoonPhase(for date: Date) async -> MoonPhase?
    
    // MARK: - Event Management
    
    /// Get all Islamic events
    /// - Returns: Array of all Islamic events
    func getAllEvents() async -> [IslamicEvent]
    
    /// Get events for a specific date
    /// - Parameter date: The date to get events for
    /// - Returns: Array of events on that date
    func getEvents(for date: Date) async -> [IslamicEvent]
    
    /// Get events for a date range
    /// - Parameter period: The date interval to query
    /// - Returns: Array of events in the period
    func getEvents(for period: DateInterval) async -> [IslamicEvent]
    
    /// Get events by category
    /// - Parameter category: The event category to filter by
    /// - Returns: Array of events in the category
    func getEvents(by category: EventCategory) async -> [IslamicEvent]
    
    /// Get events by significance
    /// - Parameter significance: The significance level to filter by
    /// - Returns: Array of events with the specified significance
    func getEvents(by significance: EventSignificance) async -> [IslamicEvent]
    
    /// Get upcoming events
    /// - Parameter limit: Maximum number of events to return
    /// - Returns: Array of upcoming events
    func getUpcomingEvents(limit: Int) async -> [IslamicEvent]
    
    /// Search events by name or description
    /// - Parameter query: Search query
    /// - Returns: Array of matching events
    func searchEvents(_ query: String) async -> [IslamicEvent]
    
    /// Add custom Islamic event
    /// - Parameter event: The event to add
    func addCustomEvent(_ event: IslamicEvent) async
    
    /// Update existing event
    /// - Parameter event: The event to update
    func updateEvent(_ event: IslamicEvent) async
    
    /// Delete custom event
    /// - Parameter eventId: ID of the event to delete
    func deleteEvent(_ eventId: UUID) async
    
    // MARK: - Holy Months & Special Periods
    
    /// Check if currently in Ramadan
    /// - Returns: True if currently in Ramadan
    func isRamadan() async -> Bool

    /// Check if the given Gregorian date falls in Ramadan
    /// - Parameter date: Gregorian date to evaluate
    func isDateInRamadan(_ date: Date) async -> Bool
    
    /// Check if currently in a holy month
    /// - Returns: True if currently in a holy month
    func isHolyMonth() async -> Bool
    
    /// Get days remaining in current month
    /// - Returns: Number of days remaining in current Hijri month
    func getDaysRemainingInMonth() async -> Int
    
    /// Get information about current holy month (if applicable)
    /// - Returns: Information about the current holy month
    func getCurrentHolyMonthInfo() async -> HolyMonthInfo?
    
    /// Get Ramadan start and end dates for a specific year
    /// - Parameter hijriYear: The Hijri year
    /// - Returns: Ramadan period information
    func getRamadanPeriod(for hijriYear: Int) async -> DateInterval?
    
    /// Get Hajj period for a specific year
    /// - Parameter hijriYear: The Hijri year
    /// - Returns: Hajj period information
    func getHajjPeriod(for hijriYear: Int) async -> DateInterval?

    /// Estimate Ramadan period for a Hijri year (planning only)
    func estimateRamadanDates(for hijriYear: Int) async -> DateInterval?

    /// Estimate Eid al-Fitr date for a Hijri year (planning only)
    func estimateEidAlFitr(for hijriYear: Int) async -> Date?

    /// Estimate Eid al-Adha date for a Hijri year (planning only)
    func estimateEidAlAdha(for hijriYear: Int) async -> Date?

    /// Confidence level for an Islamic event based on distance in time
    func getEventConfidence(for date: Date) -> EventConfidence
    
    // MARK: - Notifications & Reminders
    
    /// Set reminder for an Islamic event
    /// - Parameters:
    ///   - event: The event to set reminder for
    ///   - reminderTime: How many days/hours before to remind
    func setEventReminder(_ event: IslamicEvent, reminderTime: TimeInterval) async
    
    /// Get all active event reminders
    /// - Returns: Array of active reminders
    func getActiveReminders() async -> [EventReminder]
    
    /// Cancel event reminder
    /// - Parameter reminderId: ID of the reminder to cancel
    func cancelEventReminder(_ reminderId: UUID) async
    
    // MARK: - Statistics & Analytics
    
    /// Get Islamic calendar statistics
    /// - Returns: Calendar statistics
    func getStatistics() async -> IslamicCalendarStatistics
    
    /// Get events observed this year
    /// - Returns: Array of events observed in current Hijri year
    func getEventsObservedThisYear() async -> [IslamicEvent]
    
    /// Get most active month (month with most events)
    /// - Returns: The month with most events
    func getMostActiveMonth() async -> HijriMonth?
    
    /// Get event frequency by category
    /// - Returns: Dictionary of category to event count
    func getEventFrequencyByCategory() async -> [EventCategory: Int]
    
    // MARK: - Import & Export
    
    /// Export Islamic calendar data
    /// - Parameter period: Date interval to export
    /// - Returns: JSON string of calendar data
    func exportCalendarData(for period: DateInterval) async -> String
    
    /// Import custom events from JSON
    /// - Parameter jsonData: JSON string containing event data
    func importEvents(from jsonData: String) async throws
    
    /// Export events as iCalendar format
    /// - Parameter events: Events to export
    /// - Returns: iCalendar formatted string
    func exportAsICalendar(_ events: [IslamicEvent]) async -> String
    
    // MARK: - Settings & Preferences
    
    /// Set calendar calculation method
    /// - Parameter method: The calculation method to use
    func setCalculationMethod(_ method: IslamicCalendarMethod) async
    
    /// Enable/disable event notifications
    /// - Parameter enabled: Whether notifications are enabled
    func setEventNotifications(_ enabled: Bool) async
    
    /// Set default reminder time for events
    /// - Parameter time: Default reminder time in seconds
    func setDefaultReminderTime(_ time: TimeInterval) async
    
    // MARK: - Cache Management
    
    /// Refresh calendar data
    func refreshCalendarData() async
    
    /// Clear calendar cache
    func clearCache() async
    
    /// Update calendar data from external sources
    func updateFromExternalSources() async
}

// MARK: - Default Implementations (non-breaking for mocks)

public extension IslamicCalendarServiceProtocol {
    func isDateInRamadan(_ date: Date) async -> Bool {
        let hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
        return hijriCalendar.component(.month, from: date) == HijriMonth.ramadan.rawValue
    }

    func estimateRamadanDates(for hijriYear: Int) async -> DateInterval? {
        let hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
        var components = DateComponents()
        components.year = hijriYear
        components.month = 9
        components.day = 1

        guard let ramadanStart = hijriCalendar.date(from: components),
              let ramadanEnd = hijriCalendar.date(byAdding: .day, value: 29, to: ramadanStart) else {
            return nil
        }

        return DateInterval(start: ramadanStart, end: ramadanEnd)
    }

    func estimateEidAlFitr(for hijriYear: Int) async -> Date? {
        let hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
        var components = DateComponents()
        components.year = hijriYear
        components.month = 10
        components.day = 1
        return hijriCalendar.date(from: components)
    }

    func estimateEidAlAdha(for hijriYear: Int) async -> Date? {
        let hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
        var components = DateComponents()
        components.year = hijriYear
        components.month = 12
        components.day = 10
        return hijriCalendar.date(from: components)
    }

    func getEventConfidence(for date: Date) -> EventConfidence {
        let calendar = Calendar.current
        let today = Date()
        guard let monthsDiff = calendar.dateComponents([.month], from: today, to: date).month else {
            return .low
        }

        switch monthsDiff {
        case 0...12: return .high
        case 13...60: return .medium
        default: return .low
        }
    }
}

// MARK: - Supporting Types

/// Information about a holy month
public struct HolyMonthInfo: Codable, Equatable {
    public let month: HijriMonth
    public let year: Int
    public let significance: String
    public let observances: [String]
    public let specialDays: [IslamicEvent]
    public let daysRemaining: Int
    
    public init(
        month: HijriMonth,
        year: Int,
        significance: String,
        observances: [String] = [],
        specialDays: [IslamicEvent] = [],
        daysRemaining: Int = 0
    ) {
        self.month = month
        self.year = year
        self.significance = significance
        self.observances = observances
        self.specialDays = specialDays
        self.daysRemaining = daysRemaining
    }
}

/// Event reminder information
public struct EventReminder: Codable, Identifiable, Equatable {
    public let id: UUID
    public let event: IslamicEvent
    public let reminderTime: TimeInterval
    public let isActive: Bool
    public let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        event: IslamicEvent,
        reminderTime: TimeInterval,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.event = event
        self.reminderTime = reminderTime
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

/// Islamic calendar calculation methods
public enum IslamicCalendarMethod: String, Codable, CaseIterable {
    case ummalqura = "ummalqura"
    case civil = "civil"
    case astronomical = "astronomical"
    case tabular = "tabular"
    
    public var displayName: String {
        switch self {
        case .ummalqura: return "Umm al-Qura"
        case .civil: return "Islamic Civil"
        case .astronomical: return "Astronomical"
        case .tabular: return "Tabular"
        }
    }
    
    public var description: String {
        switch self {
        case .ummalqura: return "Used in Saudi Arabia, based on lunar observations"
        case .civil: return "Simplified calendar with alternating 29/30 day months"
        case .astronomical: return "Based on astronomical calculations"
        case .tabular: return "Traditional tabular calendar"
        }
    }
}
