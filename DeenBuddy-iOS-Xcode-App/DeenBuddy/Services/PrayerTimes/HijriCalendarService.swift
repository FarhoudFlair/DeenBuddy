//
//  HijriCalendarService.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-04.
//

import Foundation

/// Service for Hijri calendar operations and conversions
public class HijriCalendarService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var currentHijriDate: HijriDate
    @Published public var todaysEvents: [IslamicEvent] = []
    
    // MARK: - Private Properties
    
    private let islamicCalendar: Calendar
    private var updateTimer: Timer?
    
    // MARK: - Initialization
    
    public init() {
        self.islamicCalendar = Calendar(identifier: .islamicUmmAlQura)
        self.currentHijriDate = CalendarConverter.currentHijriDate()
        
        updateTodaysEvents()
        startDailyUpdateTimer()
    }
    
    deinit {
        updateTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Convert Gregorian date to Hijri date
    public func gregorianToHijri(_ gregorianDate: Date) -> HijriDate {
        return CalendarConverter.gregorianToHijri(gregorianDate)
    }
    
    /// Convert Hijri date to Gregorian date
    public func hijriToGregorian(_ hijriDate: HijriDate) -> Date? {
        return CalendarConverter.hijriToGregorian(hijriDate)
    }
    
    /// Get current Hijri date
    public func getCurrentHijriDate() -> HijriDate {
        return CalendarConverter.currentHijriDate()
    }
    
    /// Get dual calendar date for a given Gregorian date
    public func getDualCalendarDate(for gregorianDate: Date) -> DualCalendarDate {
        return DualCalendarDate(gregorianDate: gregorianDate)
    }
    
    /// Get Islamic events for a specific date
    public func getIslamicEvents(for gregorianDate: Date) -> [IslamicEvent] {
        return CalendarConverter.getIslamicEvents(for: gregorianDate)
    }
    
    /// Get Islamic events for current date
    public func getTodaysIslamicEvents() -> [IslamicEvent] {
        return getIslamicEvents(for: Date())
    }
    
    /// Check if a date is in Ramadan
    public func isRamadan(_ gregorianDate: Date) -> Bool {
        let hijriDate = gregorianToHijri(gregorianDate)
        return hijriDate.month == .ramadan
    }
    
    /// Check if a date is in a sacred month
    public func isSacredMonth(_ gregorianDate: Date) -> Bool {
        let hijriDate = gregorianToHijri(gregorianDate)
        return hijriDate.month.isSacred
    }
    
    /// Get the current Islamic year
    public func getCurrentIslamicYear() -> Int {
        return currentHijriDate.year
    }
    
    /// Get days remaining in current Hijri month
    public func getDaysRemainingInMonth() -> Int {
        let approximateDaysInMonth = currentHijriDate.month.approximateDays
        return max(0, approximateDaysInMonth - currentHijriDate.day)
    }
    
    /// Get days remaining in current Islamic year
    public func getDaysRemainingInYear() -> Int {
        let currentDate = Date()
        let calendar = Calendar(identifier: .islamicUmmAlQura)
        
        // Get the last day of the current Islamic year
        var components = calendar.dateComponents([.year], from: currentDate)
        components.month = 12 // Dhu al-Hijjah
        components.day = 29 // Minimum days in last month
        
        guard let endOfYear = calendar.date(from: components) else {
            return 0
        }
        
        // Try to get the actual last day (could be 29 or 30)
        if let lastDayOfYear = calendar.date(byAdding: .day, value: 1, to: endOfYear),
           calendar.dateComponents([.year], from: lastDayOfYear).year != components.year {
            // The next day is in a different year, so endOfYear is correct
        } else {
            // Try 30 days
            components.day = 30
            if let endOfYear30 = calendar.date(from: components) {
                components = calendar.dateComponents([.year, .month, .day], from: endOfYear30)
            }
        }
        
        guard let finalEndOfYear = calendar.date(from: components) else {
            return 0
        }
        
        let daysRemaining = calendar.dateComponents([.day], from: currentDate, to: finalEndOfYear).day ?? 0
        return max(0, daysRemaining)
    }
    
    /// Get upcoming Islamic events in the next 30 days
    public func getUpcomingEvents(days: Int = 30) -> [(date: Date, events: [IslamicEvent])] {
        var upcomingEvents: [(date: Date, events: [IslamicEvent])] = []
        let calendar = Calendar.current
        let today = Date()
        
        for i in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: i, to: today) else {
                continue
            }
            
            let events = getIslamicEvents(for: date)
            if !events.isEmpty {
                upcomingEvents.append((date: date, events: events))
            }
        }
        
        return upcomingEvents
    }
    
    /// Format Hijri date with various styles
    public func formatHijriDate(
        _ hijriDate: HijriDate,
        style: HijriDateStyle = .full,
        language: HijriLanguage = .english
    ) -> String {
        switch style {
        case .full:
            return language == .english ? hijriDate.formatted : hijriDate.arabicFormatted
        case .short:
            return hijriDate.shortFormatted
        case .monthYear:
            return language == .english ? 
                "\(hijriDate.month.displayName) \(hijriDate.year)" :
                "\(hijriDate.month.arabicName) \(hijriDate.year)"
        case .dayMonth:
            return language == .english ?
                "\(hijriDate.day) \(hijriDate.month.displayName)" :
                "\(hijriDate.day) \(hijriDate.month.arabicName)"
        }
    }
    
    /// Get month information for a specific Hijri month
    public func getMonthInfo(_ month: HijriMonth) -> HijriMonthInfo {
        return HijriMonthInfo(
            month: month,
            approximateDays: month.approximateDays,
            isSacred: month.isSacred,
            isRamadan: month.isRamadan,
            isHajjMonth: month.isHajjMonth,
            events: IslamicEvent.allCases.filter { $0.month == month }
        )
    }
    
    /// Calculate age in Hijri years
    public func calculateHijriAge(birthDate: Date, currentDate: Date = Date()) -> Int {
        let birthHijri = gregorianToHijri(birthDate)
        let currentHijri = gregorianToHijri(currentDate)
        
        var age = currentHijri.year - birthHijri.year
        
        // Adjust if birthday hasn't occurred this year
        if currentHijri.month.rawValue < birthHijri.month.rawValue ||
           (currentHijri.month == birthHijri.month && currentHijri.day < birthHijri.day) {
            age -= 1
        }
        
        return max(0, age)
    }
    
    // MARK: - Private Methods
    
    private func startDailyUpdateTimer() {
        // Update at midnight each day
        let calendar = Calendar.current
        let now = Date()
        
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
              let midnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow) else {
            return
        }
        
        let timeInterval = midnight.timeIntervalSince(now)
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            self?.updateCurrentDate()
            self?.startDailyUpdateTimer() // Schedule next update
        }
    }
    
    private func updateCurrentDate() {
        currentHijriDate = CalendarConverter.currentHijriDate()
        updateTodaysEvents()
    }
    
    private func updateTodaysEvents() {
        todaysEvents = getTodaysIslamicEvents()
    }
}

// MARK: - Supporting Types

/// Hijri date formatting styles
public enum HijriDateStyle {
    case full       // "1 Muharram 1445 AH"
    case short      // "1 Muh 1445"
    case monthYear  // "Muharram 1445"
    case dayMonth   // "1 Muharram"
}

/// Language options for Hijri date formatting
public enum HijriLanguage {
    case english
    case arabic
}

/// Information about a Hijri month
public struct HijriMonthInfo {
    public let month: HijriMonth
    public let approximateDays: Int
    public let isSacred: Bool
    public let isRamadan: Bool
    public let isHajjMonth: Bool
    public let events: [IslamicEvent]
    
    public var description: String {
        var desc = month.displayName
        
        if isSacred {
            desc += " (Sacred Month)"
        }
        if isRamadan {
            desc += " (Month of Fasting)"
        }
        if isHajjMonth {
            desc += " (Month of Hajj)"
        }
        
        return desc
    }
}

// MARK: - Notification Extensions

extension HijriCalendarService {
    
    /// Get notification text for Islamic events
    public func getEventNotificationText(for event: IslamicEvent) -> String {
        switch event {
        case .newYear:
            return "Happy Islamic New Year! May this year bring peace and blessings."
        case .ashura:
            return "Today is the Day of Ashura, a day of fasting and remembrance."
        case .mawlidNabawi:
            return "Today marks the birth of Prophet Muhammad (peace be upon him)."
        case .israMiraj:
            return "Today commemorates the Prophet's night journey and ascension."
        case .ramadanStart:
            return "Ramadan Mubarak! The holy month of fasting has begun."
        case .laylalQadr:
            return "Tonight is Laylat al-Qadr, the Night of Power. Increase your prayers and remembrance."
        case .eidAlFitr:
            return "Eid Mubarak! Celebrating the end of Ramadan with joy and gratitude."
        case .eidAlAdha:
            return "Eid Mubarak! Celebrating the Festival of Sacrifice."
        case .hajj:
            return "The Hajj pilgrimage is taking place. Prayers for all pilgrims."
        }
    }
    
    /// Check if we should show a special notification for today
    public func shouldShowTodayNotification() -> (show: Bool, message: String?) {
        let events = getTodaysIslamicEvents()
        
        if let firstEvent = events.first {
            return (true, getEventNotificationText(for: firstEvent))
        }
        
        // Check for special occasions
        if isRamadan(Date()) {
            return (true, "Ramadan Kareem! Remember to break your fast at Maghrib time.")
        }
        
        return (false, nil)
    }
}
