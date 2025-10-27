import Foundation
import SwiftUI

/// Represents the five daily Islamic prayers with iOS-specific features
public enum Prayer: String, CaseIterable, Codable, Sendable {
    case fajr = "fajr"
    case dhuhr = "dhuhr"
    case asr = "asr"
    case maghrib = "maghrib"
    case isha = "isha"
    
    /// Initialize from any raw value string (e.g., from widget enums) in a type-safe way
    public init?(widgetRawValue: String) {
        self.init(rawValue: widgetRawValue)
    }
    
    // MARK: - Display Properties
    
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
    
    /// Transliteration of the Arabic name
    public var transliteration: String {
        switch self {
        case .fajr: return "Al-Fajr"
        case .dhuhr: return "Az-Zuhr"
        case .asr: return "Al-'Asr"
        case .maghrib: return "Al-Maghrib"
        case .isha: return "Al-'Isha"
        }
    }
    
    // MARK: - Prayer Information
    
    /// Default number of rakah for this prayer
    public var defaultRakahCount: Int {
        switch self {
        case .fajr: return 2
        case .dhuhr: return 4
        case .asr: return 4
        case .maghrib: return 3
        case .isha: return 4
        }
    }
    
    /// Brief description of the prayer timing
    public var timingDescription: String {
        switch self {
        case .fajr: return "Dawn prayer before sunrise"
        case .dhuhr: return "Midday prayer after sun passes zenith"
        case .asr: return "Afternoon prayer in the late afternoon"
        case .maghrib: return "Sunset prayer just after sunset"
        case .isha: return "Night prayer after twilight disappears"
        }
    }
    
    // MARK: - iOS UI Properties
    
    /// SF Symbol name for this prayer
    public var systemImageName: String {
        switch self {
        case .fajr: return "sunrise"
        case .dhuhr: return "sun.max"
        case .asr: return "sun.and.horizon"
        case .maghrib: return "sunset"
        case .isha: return "moon.stars"
        }
    }
    
    /// SwiftUI color associated with this prayer
    public var color: Color {
        switch self {
        case .fajr: return .orange
        case .dhuhr: return .yellow
        case .asr: return .blue
        case .maghrib: return .red
        case .isha: return .purple
        }
    }
    
    /// Gradient colors for this prayer
    public var gradientColors: [Color] {
        switch self {
        case .fajr: return [.orange, .pink]
        case .dhuhr: return [.yellow, .orange]
        case .asr: return [.blue, .cyan]
        case .maghrib: return [.red, .orange]
        case .isha: return [.purple, .indigo]
        }
    }
    
    // MARK: - Notification Properties
    
    /// Title for push notifications
    public var notificationTitle: String {
        return "\(displayName) Prayer Time"
    }
    
    /// Body text for push notifications
    public var notificationBody: String {
        return "It's time for \(displayName) prayer (\(arabicName))"
    }
    
    // MARK: - Accessibility
    
    /// Accessibility label for VoiceOver
    public var accessibilityLabel: String {
        return "\(displayName) prayer, \(transliteration), \(defaultRakahCount) rakah"
    }
    
    /// Accessibility hint for VoiceOver
    public var accessibilityHint: String {
        return timingDescription
    }
    
    // MARK: - Utility Methods
    
    /// Returns the next prayer in the daily sequence
    public var nextPrayer: Prayer {
        switch self {
        case .fajr: return .dhuhr
        case .dhuhr: return .asr
        case .asr: return .maghrib
        case .maghrib: return .isha
        case .isha: return .fajr
        }
    }
    
    /// Returns the previous prayer in the daily sequence
    public var previousPrayer: Prayer {
        switch self {
        case .fajr: return .isha
        case .dhuhr: return .fajr
        case .asr: return .dhuhr
        case .maghrib: return .asr
        case .isha: return .maghrib
        }
    }
    
    /// Returns all prayers in chronological order
    public static var chronologicalOrder: [Prayer] {
        return [.fajr, .dhuhr, .asr, .maghrib, .isha]
    }
}

// MARK: - Extensions

extension Prayer: Comparable {
    public static func < (lhs: Prayer, rhs: Prayer) -> Bool {
        let order = Prayer.chronologicalOrder
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

extension Prayer: CustomStringConvertible {
    public var description: String {
        return "\(displayName) (\(arabicName))"
    }
}
