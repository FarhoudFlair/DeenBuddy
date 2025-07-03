import Foundation
import CoreLocation

/// Protocol for prayer time calculation services
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
    
    /// Get prayer times for a date range
    func getPrayerTimes(from startDate: Date, to endDate: Date) async throws -> [Date: [PrayerTime]]
}

/// Prayer calculation methods
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
    
    public var displayName: String {
        switch self {
        case .muslimWorldLeague:
            return "Muslim World League"
        case .egyptian:
            return "Egyptian General Authority"
        case .karachi:
            return "University of Islamic Sciences, Karachi"
        case .ummAlQura:
            return "Umm Al-Qura University, Makkah"
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
        }
    }
    
    public var description: String {
        switch self {
        case .muslimWorldLeague:
            return "Standard method used by most Islamic organizations"
        case .egyptian:
            return "Used in Egypt and nearby regions"
        case .karachi:
            return "Used in Pakistan and India"
        case .ummAlQura:
            return "Used in Saudi Arabia"
        case .dubai:
            return "Used in UAE"
        case .moonsightingCommittee:
            return "Conservative method based on moon sighting"
        case .northAmerica:
            return "Used across North America"
        case .kuwait:
            return "Used in Kuwait"
        case .qatar:
            return "Used in Qatar"
        case .singapore:
            return "Used in Singapore and Malaysia"
        }
    }
}

/// Madhab for Asr calculation
public enum Madhab: String, CaseIterable {
    case shafi = "Shafi"
    case hanafi = "Hanafi"
    
    public var displayName: String {
        return rawValue
    }
    
    public var description: String {
        switch self {
        case .shafi:
            return "Earlier Asr time (shadow = object length)"
        case .hanafi:
            return "Later Asr time (shadow = 2x object length)"
        }
    }
}
