//
//  CalculationModels.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-04.
//

import Foundation
import SwiftUI
import Adhan

// MARK: - Calculation Method

/// Islamic prayer time calculation methods
public enum CalculationMethod: String, CaseIterable, Codable, Identifiable {
    case muslimWorldLeague = "muslim_world_league"
    case egyptian = "egyptian"
    case karachi = "karachi"
    case ummAlQura = "umm_al_qura"
    case dubai = "dubai"
    case moonsightingCommittee = "moonsighting_committee"
    case northAmerica = "north_america"
    case kuwait = "kuwait"
    case qatar = "qatar"
    case singapore = "singapore"
    case tehran = "tehran"
    case jafari = "jafari"
    
    public var id: String { rawValue }
    
    /// Display name for the calculation method
    public var displayName: String {
        switch self {
        case .muslimWorldLeague:
            return "Muslim World League"
        case .egyptian:
            return "Egyptian General Authority"
        case .karachi:
            return "University of Islamic Sciences, Karachi"
        case .ummAlQura:
            return "Umm Al-Qura University"
        case .dubai:
            return "Dubai"
        case .moonsightingCommittee:
            return "Moonsighting Committee Worldwide"
        case .northAmerica:
            return "Islamic Society of North America"
        case .kuwait:
            return "Kuwait"
        case .qatar:
            return "Qatar"
        case .singapore:
            return "Singapore"
        case .tehran:
            return "Institute of Geophysics, University of Tehran"
        case .jafari:
            return "Shia Ithna-Ashari (Jafari)"
        }
    }
    
    /// Short description of the calculation method
    public var description: String {
        switch self {
        case .muslimWorldLeague:
            return "Standard method used by most Islamic organizations worldwide"
        case .egyptian:
            return "Used in Egypt, Syria, Iraq, Lebanon, Malaysia, and parts of the USA"
        case .karachi:
            return "Used in Pakistan, Bangladesh, India, Afghanistan, and parts of Europe"
        case .ummAlQura:
            return "Used in Saudi Arabia"
        case .dubai:
            return "Used in UAE"
        case .moonsightingCommittee:
            return "Used by communities that follow moon sighting"
        case .northAmerica:
            return "Used in North America (ISNA)"
        case .kuwait:
            return "Used in Kuwait"
        case .qatar:
            return "Used in Qatar"
        case .singapore:
            return "Used in Singapore"
        case .tehran:
            return "Used in Iran"
        case .jafari:
            return "Used by Shia Muslims following Jafari jurisprudence"
        }
    }
    
    /// Regions where this method is commonly used
    public var regions: [String] {
        switch self {
        case .muslimWorldLeague:
            return ["Worldwide", "Europe", "Far East", "Parts of USA"]
        case .egyptian:
            return ["Egypt", "Syria", "Iraq", "Lebanon", "Malaysia", "Parts of USA"]
        case .karachi:
            return ["Pakistan", "Bangladesh", "India", "Afghanistan", "Parts of Europe"]
        case .ummAlQura:
            return ["Saudi Arabia"]
        case .dubai:
            return ["UAE"]
        case .moonsightingCommittee:
            return ["Worldwide (Moon Sighting Communities)"]
        case .northAmerica:
            return ["USA", "Canada", "Parts of UK"]
        case .kuwait:
            return ["Kuwait"]
        case .qatar:
            return ["Qatar"]
        case .singapore:
            return ["Singapore"]
        case .tehran:
            return ["Iran"]
        case .jafari:
            return ["Iran", "Iraq", "Lebanon", "Shia Communities Worldwide"]
        }
    }
    
    /// Whether this method is suitable for Shia users
    public var isShiaCompatible: Bool {
        switch self {
        case .jafari, .tehran:
            return true
        case .muslimWorldLeague, .moonsightingCommittee:
            return true // Generally acceptable
        default:
            return false
        }
    }
    
    /// Convert to Adhan library calculation parameters
    public func adhanCalculationParameters() -> CalculationParameters {
        switch self {
        case .muslimWorldLeague:
            return Adhan.CalculationMethod.muslimWorldLeague.params
        case .egyptian:
            return Adhan.CalculationMethod.egyptian.params
        case .karachi:
            return Adhan.CalculationMethod.karachi.params
        case .ummAlQura:
            return Adhan.CalculationMethod.ummAlQura.params
        case .dubai:
            return Adhan.CalculationMethod.dubai.params
        case .moonsightingCommittee:
            return Adhan.CalculationMethod.moonsightingCommittee.params
        case .northAmerica:
            return Adhan.CalculationMethod.northAmerica.params
        case .kuwait:
            return Adhan.CalculationMethod.kuwait.params
        case .qatar:
            return Adhan.CalculationMethod.qatar.params
        case .singapore:
            return Adhan.CalculationMethod.singapore.params
        case .tehran:
            return Adhan.CalculationMethod.tehran.params
        case .jafari:
            // Custom parameters for Jafari method
            var params = Adhan.CalculationMethod.tehran.params
            params.madhab = Adhan.Madhab.shafi // Will be overridden by madhab setting
            return params
        }
    }
}

// MARK: - Madhab

/// Islamic schools of jurisprudence (affects Asr calculation)
public enum Madhab: String, CaseIterable, Codable, Identifiable {
    case shafi = "shafi"
    case hanafi = "hanafi"
    case maliki = "maliki"
    case hanbali = "hanbali"
    case jafari = "jafari"
    
    public var id: String { rawValue }
    
    /// Display name for the madhab
    public var displayName: String {
        switch self {
        case .shafi: return "Shafi"
        case .hanafi: return "Hanafi"
        case .maliki: return "Maliki"
        case .hanbali: return "Hanbali"
        case .jafari: return "Jafari (Shia)"
        }
    }
    
    /// Description of the madhab
    public var description: String {
        switch self {
        case .shafi:
            return "Shafi school - Asr when shadow equals object length"
        case .hanafi:
            return "Hanafi school - Asr when shadow equals twice object length"
        case .maliki:
            return "Maliki school - Asr when shadow equals object length"
        case .hanbali:
            return "Hanbali school - Asr when shadow equals object length"
        case .jafari:
            return "Jafari school (Shia) - Asr when shadow equals object length"
        }
    }
    
    /// Whether this is a Shia madhab
    public var isShia: Bool {
        return self == .jafari
    }

    /// Sect display name (Sunni/Shia)
    public var sectDisplayName: String {
        return isShia ? "Shia" : "Sunni"
    }

    /// Color associated with this madhab
    public var color: Color {
        switch self {
        case .hanafi:
            return .blue
        case .shafi:
            return .green
        case .maliki:
            return .orange
        case .hanbali:
            return .purple
        case .jafari:
            return .indigo
        }
    }
    
    /// Convert to Adhan library madhab
    public func adhanMadhab() -> Adhan.Madhab {
        switch self {
        case .hanafi:
            return .hanafi
        case .shafi, .maliki, .hanbali, .jafari:
            return .shafi
        }
    }
}

// MARK: - Time Format

/// Time display format preference
public enum TimeFormat: String, CaseIterable, Codable, Identifiable {
    case twelveHour = "12_hour"
    case twentyFourHour = "24_hour"
    
    public var id: String { rawValue }
    
    /// Display name for the time format
    public var displayName: String {
        switch self {
        case .twelveHour: return "12 Hour (AM/PM)"
        case .twentyFourHour: return "24 Hour"
        }
    }
    
    /// Example time string
    public var example: String {
        switch self {
        case .twelveHour: return "6:30 AM"
        case .twentyFourHour: return "06:30"
        }
    }
}

// MARK: - Prayer Time Settings

/// User preferences for prayer time calculations
public struct PrayerTimeSettings: Codable {
    public var calculationMethod: CalculationMethod
    public var madhab: Madhab
    public var timeFormat: TimeFormat
    public var enableNotifications: Bool
    public var notificationOffset: TimeInterval // Minutes before prayer time
    
    public init(
        calculationMethod: CalculationMethod = .muslimWorldLeague,
        madhab: Madhab = .shafi,
        timeFormat: TimeFormat = .twelveHour,
        enableNotifications: Bool = true,
        notificationOffset: TimeInterval = 300 // 5 minutes
    ) {
        self.calculationMethod = calculationMethod
        self.madhab = madhab
        self.timeFormat = timeFormat
        self.enableNotifications = enableNotifications
        self.notificationOffset = notificationOffset
    }
    
    /// Validate that calculation method and madhab are compatible
    public var isValid: Bool {
        // Jafari madhab should use Jafari or Tehran calculation method
        if madhab == .jafari {
            return calculationMethod == .jafari || calculationMethod == .tehran
        }
        return true
    }
    
    /// Get recommended calculation methods for the current madhab
    public var recommendedCalculationMethods: [CalculationMethod] {
        if madhab == .jafari {
            return [.jafari, .tehran, .muslimWorldLeague]
        } else {
            return CalculationMethod.allCases.filter { !$0.isShiaCompatible || $0 == .muslimWorldLeague }
        }
    }
}

// MARK: - Prayer Time Error

/// Errors that can occur during prayer time calculation
public enum PrayerTimeError: LocalizedError, Equatable {
    case locationUnavailable
    case invalidLocation
    case calculationFailed(String)
    case permissionDenied
    case networkError
    case cacheError
    
    public var errorDescription: String? {
        switch self {
        case .locationUnavailable:
            return "Location is not available. Please enable location services."
        case .invalidLocation:
            return "Invalid location coordinates."
        case .calculationFailed(let reason):
            return "Prayer time calculation failed: \(reason)"
        case .permissionDenied:
            return "Location permission denied. Please enable location access in Settings."
        case .networkError:
            return "Network error occurred while fetching prayer times."
        case .cacheError:
            return "Error accessing cached prayer times."
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .locationUnavailable, .permissionDenied:
            return "Go to Settings > Privacy & Security > Location Services and enable location access for DeenBuddy."
        case .invalidLocation:
            return "Please try again or manually set your location."
        case .calculationFailed:
            return "Please try again or contact support if the problem persists."
        case .networkError:
            return "Check your internet connection and try again."
        case .cacheError:
            return "Clear app data and try again."
        }
    }

    public static func == (lhs: PrayerTimeError, rhs: PrayerTimeError) -> Bool {
        switch (lhs, rhs) {
        case (.locationUnavailable, .locationUnavailable),
             (.invalidLocation, .invalidLocation),
             (.permissionDenied, .permissionDenied),
             (.networkError, .networkError),
             (.cacheError, .cacheError):
            return true
        case (.calculationFailed(let lhsReason), .calculationFailed(let rhsReason)):
            return lhsReason == rhsReason
        default:
            return false
        }
    }
}
