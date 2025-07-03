import Foundation
import CoreLocation

// MARK: - Prayer Time Models

/// Represents the five daily prayer times
public struct PrayerTimes {
    public let date: Date
    public let fajr: Date
    public let dhuhr: Date
    public let asr: Date
    public let maghrib: Date
    public let isha: Date
    public let calculationMethod: String
    
    public init(date: Date, fajr: Date, dhuhr: Date, asr: Date, maghrib: Date, isha: Date, calculationMethod: String) {
        self.date = date
        self.fajr = fajr
        self.dhuhr = dhuhr
        self.asr = asr
        self.maghrib = maghrib
        self.isha = isha
        self.calculationMethod = calculationMethod
    }
}

/// Prayer calculation methods supported by the app
public enum CalculationMethod: String, CaseIterable {
    case muslimWorldLeague = "MuslimWorldLeague"
    case egyptian = "Egyptian"
    case karachi = "Karachi"
    case ummAlQura = "UmmAlQura"
    case dubai = "Dubai"
    case moonsightingCommittee = "MoonsightingCommittee"
    case northAmerica = "NorthAmerica"
    case kuwait = "Kuwait"
    case qatar = "Qatar"
    case singapore = "Singapore"
    case tehran = "Tehran"
    
    public var displayName: String {
        switch self {
        case .muslimWorldLeague: return "Muslim World League"
        case .egyptian: return "Egyptian General Authority of Survey"
        case .karachi: return "University of Islamic Sciences, Karachi"
        case .ummAlQura: return "Umm Al-Qura University, Makkah"
        case .dubai: return "Dubai"
        case .moonsightingCommittee: return "Moonsighting Committee Worldwide"
        case .northAmerica: return "Islamic Society of North America"
        case .kuwait: return "Kuwait"
        case .qatar: return "Qatar"
        case .singapore: return "Singapore"
        case .tehran: return "Institute of Geophysics, University of Tehran"
        }
    }
}

/// Madhab for Asr calculation
public enum Madhab: String, CaseIterable {
    case shafi = "Shafi"
    case hanafi = "Hanafi"
    
    public var displayName: String {
        switch self {
        case .shafi: return "Shafi, Maliki, Hanbali"
        case .hanafi: return "Hanafi"
        }
    }
}

/// Prayer calculation configuration
public struct PrayerCalculationConfig {
    public let calculationMethod: CalculationMethod
    public let madhab: Madhab
    public let location: CLLocationCoordinate2D
    public let timeZone: TimeZone
    
    public init(calculationMethod: CalculationMethod, madhab: Madhab, location: CLLocationCoordinate2D, timeZone: TimeZone) {
        self.calculationMethod = calculationMethod
        self.madhab = madhab
        self.location = location
        self.timeZone = timeZone
    }
}

// MARK: - Prayer Calculator Protocol

/// Protocol for prayer time calculation services
/// This allows other engineers to work against mocks while the concrete implementation is being built
public protocol PrayerCalculatorProtocol {
    
    /// Calculate prayer times for a specific date and location
    /// - Parameters:
    ///   - date: The date to calculate prayer times for
    ///   - config: Configuration including calculation method, madhab, location, and timezone
    /// - Returns: Prayer times for the specified date
    /// - Throws: PrayerCalculationError if calculation fails
    func calculatePrayerTimes(for date: Date, config: PrayerCalculationConfig) throws -> PrayerTimes
    
    /// Get cached prayer times for a specific date
    /// - Parameter date: The date to retrieve cached times for
    /// - Returns: Cached prayer times if available, nil otherwise
    func getCachedPrayerTimes(for date: Date) -> PrayerTimes?
    
    /// Cache prayer times for future retrieval
    /// - Parameter prayerTimes: The prayer times to cache
    func cachePrayerTimes(_ prayerTimes: PrayerTimes)
    
    /// Get the next prayer time from the current moment
    /// - Parameter config: Configuration for calculation
    /// - Returns: The next prayer time and its name
    /// - Throws: PrayerCalculationError if calculation fails
    func getNextPrayer(config: PrayerCalculationConfig) throws -> (name: String, time: Date)
    
    /// Check if it's currently prayer time (within a tolerance window)
    /// - Parameters:
    ///   - config: Configuration for calculation
    ///   - tolerance: Time tolerance in minutes (default: 5 minutes)
    /// - Returns: Current prayer name if within tolerance, nil otherwise
    func getCurrentPrayer(config: PrayerCalculationConfig, tolerance: TimeInterval) -> String?
}

// MARK: - Prayer Calculation Errors

public enum PrayerCalculationError: LocalizedError {
    case invalidLocation
    case invalidDate
    case calculationFailed(String)
    case cacheError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidLocation:
            return "Invalid location coordinates provided"
        case .invalidDate:
            return "Invalid date provided for calculation"
        case .calculationFailed(let message):
            return "Prayer calculation failed: \(message)"
        case .cacheError(let message):
            return "Cache operation failed: \(message)"
        }
    }
}
