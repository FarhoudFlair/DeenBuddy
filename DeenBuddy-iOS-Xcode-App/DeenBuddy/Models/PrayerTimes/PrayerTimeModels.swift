//
//  PrayerTimeModels.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-04.
//

import Foundation
import SwiftUI
import CoreLocation

// MARK: - Prayer Enum

/// Represents the five daily Islamic prayers
public enum Prayer: String, CaseIterable, Codable, Identifiable {
    case fajr = "fajr"
    case dhuhr = "dhuhr"
    case asr = "asr"
    case maghrib = "maghrib"
    case isha = "isha"
    
    public var id: String { rawValue }
    
    /// Localized display name for the prayer
    public var displayName: String {
        switch self {
        case .fajr: return "Fajr"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        }
    }
    
    /// Arabic name of the prayer
    public var arabicName: String {
        switch self {
        case .fajr: return "الفجر"
        case .dhuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        }
    }
    
    /// System image name for the prayer
    public var systemImageName: String {
        switch self {
        case .fajr: return "sunrise.fill"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "sun.min.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.fill"
        }
    }
    
    /// Color associated with the prayer
    public var color: Color {
        switch self {
        case .fajr: return .orange
        case .dhuhr: return .yellow
        case .asr: return .blue
        case .maghrib: return .red
        case .isha: return .indigo
        }
    }
    
    /// Order index for sorting prayers
    public var orderIndex: Int {
        switch self {
        case .fajr: return 0
        case .dhuhr: return 1
        case .asr: return 2
        case .maghrib: return 3
        case .isha: return 4
        }
    }
}

// MARK: - Prayer Time Model

/// Represents a single prayer time
public struct PrayerTime: Identifiable, Codable, Equatable {
    public let id = UUID()
    public let prayer: Prayer
    public let time: Date
    public let status: PrayerStatus

    public init(prayer: Prayer, time: Date, status: PrayerStatus = .upcoming) {
        self.prayer = prayer
        self.time = time
        self.status = status
    }

    public static func == (lhs: PrayerTime, rhs: PrayerTime) -> Bool {
        return lhs.prayer == rhs.prayer && lhs.time == rhs.time && lhs.status == rhs.status
    }
    
    /// Formatted time string based on user preferences
    public func formattedTime(format: TimeFormat) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = format == .twelveHour ? .short : .none
        
        if format == .twentyFourHour {
            formatter.dateFormat = "HH:mm"
        }
        
        return formatter.string(from: time)
    }
    
    /// Time remaining until this prayer (if upcoming)
    public var timeRemaining: TimeInterval? {
        guard status == .upcoming || status == .current else { return nil }
        let now = Date()
        return time.timeIntervalSince(now) > 0 ? time.timeIntervalSince(now) : nil
    }
    
    /// Formatted time remaining string
    public var timeRemainingFormatted: String? {
        guard let remaining = timeRemaining, remaining > 0 else { return nil }
        
        let hours = Int(remaining) / 3600
        let minutes = Int(remaining) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Prayer Status

/// Status of a prayer time relative to current time
public enum PrayerStatus: String, Codable, CaseIterable {
    case passed = "passed"
    case current = "current"
    case upcoming = "upcoming"
    
    public var displayName: String {
        switch self {
        case .passed: return "Passed"
        case .current: return "Current"
        case .upcoming: return "Upcoming"
        }
    }
    
    public var color: Color {
        switch self {
        case .passed: return .secondary
        case .current: return .green
        case .upcoming: return .primary
        }
    }
}

// MARK: - Prayer Schedule

/// Represents a full day's prayer schedule
public struct PrayerSchedule: Identifiable, Codable {
    public let id = UUID()
    public let date: Date
    public let location: LocationInfo
    public let prayerTimes: [PrayerTime]
    public let calculationMethod: CalculationMethod
    public let madhab: Madhab
    
    public init(
        date: Date,
        location: LocationInfo,
        prayerTimes: [PrayerTime],
        calculationMethod: CalculationMethod,
        madhab: Madhab
    ) {
        self.date = date
        self.location = location
        self.prayerTimes = prayerTimes
        self.calculationMethod = calculationMethod
        self.madhab = madhab
    }
    
    /// Get the next upcoming prayer
    public var nextPrayer: PrayerTime? {
        return prayerTimes.first { $0.status == .upcoming || $0.status == .current }
    }
    
    /// Get the current prayer (if any)
    public var currentPrayer: PrayerTime? {
        return prayerTimes.first { $0.status == .current }
    }
    
    /// Formatted date string
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
}

// MARK: - Location Info

/// Location information for prayer time calculations
public struct LocationInfo: Codable, Equatable {
    public let coordinate: CLLocationCoordinate2D
    public let city: String?
    public let country: String?
    public let timezone: TimeZone
    
    public init(
        coordinate: CLLocationCoordinate2D,
        city: String? = nil,
        country: String? = nil,
        timezone: TimeZone = .current
    ) {
        self.coordinate = coordinate
        self.city = city
        self.country = country
        self.timezone = timezone
    }
    
    /// Display name for the location
    public var displayName: String {
        if let city = city, let country = country {
            return "\(city), \(country)"
        } else if let city = city {
            return city
        } else if let country = country {
            return country
        } else {
            return "Current Location"
        }
    }
    
    /// Coordinate string for debugging
    public var coordinateString: String {
        return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }
}

// MARK: - Codable Extensions

extension CLLocationCoordinate2D: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
    
    private enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }
}

extension TimeZone: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(identifier)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let identifier = try container.decode(String.self)
        guard let timezone = TimeZone(identifier: identifier) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid timezone identifier: \(identifier)"
            )
        }
        self = timezone
    }
}
