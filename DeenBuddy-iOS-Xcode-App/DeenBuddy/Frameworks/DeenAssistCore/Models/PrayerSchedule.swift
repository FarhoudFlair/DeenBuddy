import Foundation

// MARK: - Prayer Schedule Models

/// Represents a prayer schedule for a specific date range
public struct PrayerSchedule: Codable, Equatable {
    public let startDate: Date
    public let endDate: Date
    public let location: LocationCoordinate
    public let calculationMethod: CalculationMethod
    public let madhab: Madhab
    public let dailySchedules: [DailyPrayerSchedule]
    
    public init(
        startDate: Date,
        endDate: Date,
        location: LocationCoordinate,
        calculationMethod: CalculationMethod,
        madhab: Madhab,
        dailySchedules: [DailyPrayerSchedule]
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.calculationMethod = calculationMethod
        self.madhab = madhab
        self.dailySchedules = dailySchedules
    }
}

/// Represents prayer times for a single day
public struct DailyPrayerSchedule: Codable, Equatable {
    public let date: Date
    public let fajr: Date
    public let dhuhr: Date
    public let asr: Date
    public let maghrib: Date
    public let isha: Date
    
    public init(date: Date, fajr: Date, dhuhr: Date, asr: Date, maghrib: Date, isha: Date) {
        self.date = date
        self.fajr = fajr
        self.dhuhr = dhuhr
        self.asr = asr
        self.maghrib = maghrib
        self.isha = isha
    }
    
    /// Get prayer time for a specific prayer
    public func time(for prayer: Prayer) -> Date {
        switch prayer {
        case .fajr: return fajr
        case .dhuhr: return dhuhr
        case .asr: return asr
        case .maghrib: return maghrib
        case .isha: return isha
        }
    }
}

/// Time format preferences
public enum TimeFormat: String, CaseIterable, Codable, Identifiable {
    case twelveHour = "12h"
    case twentyFourHour = "24h"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .twelveHour: return "12 Hour"
        case .twentyFourHour: return "24 Hour"
        }
    }
    
    public var example: String {
        switch self {
        case .twelveHour: return "6:30 PM"
        case .twentyFourHour: return "18:30"
        }
    }
}
