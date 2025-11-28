import Foundation
import CoreLocation

// MARK: - Future Prayer Time Models

public struct FuturePrayerTimeRequest {
    public let location: CLLocation
    public let date: Date
    public let calculationMethod: CalculationMethod
    public let madhab: Madhab
    public let useCurrentTimezone: Bool

    public init(
        location: CLLocation,
        date: Date,
        calculationMethod: CalculationMethod,
        madhab: Madhab,
        useCurrentTimezone: Bool = true
    ) {
        self.location = location
        self.date = date
        self.calculationMethod = calculationMethod
        self.madhab = madhab
        self.useCurrentTimezone = useCurrentTimezone
    }
}

public struct FuturePrayerTimeResult {
    public let date: Date
    public let prayerTimes: [AppPrayerTime]
    public let hijriDate: HijriDate
    public let isRamadan: Bool
    public let disclaimerLevel: DisclaimerLevel
    public let calculationTimezone: TimeZone
    public let isHighLatitude: Bool
    public let precision: PrecisionLevel

    public init(
        date: Date,
        prayerTimes: [AppPrayerTime],
        hijriDate: HijriDate,
        isRamadan: Bool,
        disclaimerLevel: DisclaimerLevel,
        calculationTimezone: TimeZone,
        isHighLatitude: Bool,
        precision: PrecisionLevel
    ) {
        self.date = date
        self.prayerTimes = prayerTimes
        self.hijriDate = hijriDate
        self.isRamadan = isRamadan
        self.disclaimerLevel = disclaimerLevel
        self.calculationTimezone = calculationTimezone
        self.isHighLatitude = isHighLatitude
        self.precision = precision
    }
}

public enum DisclaimerLevel: Equatable {
    case today
    case shortTerm   // 0-12 months
    case mediumTerm  // 12-60 months
    case longTerm    // >60 months (discouraged)

    public var requiresBanner: Bool {
        self != .today
    }

    /// EXACT COPY REQUIRED - NO CREATIVE VARIATIONS
    public var bannerMessage: String {
        switch self {
        case .today:
            return ""
        case .shortTerm:
            return "Calculated times. Subject to DST changes and official mosque schedules."
        case .mediumTerm:
            return "Long-range estimate. DST rules and local authorities may differ. Verify closer to date."
        case .longTerm:
            return "Long-range estimate not recommended. Use for planning only with extreme caution."
        }
    }
}

public struct IslamicEventEstimate: Identifiable, Hashable {
    public let id = UUID()
    public let event: IslamicEvent
    public let estimatedDate: Date
    public let hijriDate: HijriDate
    public let confidenceLevel: EventConfidence

    /// EXACT COPY REQUIRED
    public var disclaimer: String {
        "Estimated by astronomical calculation (planning only). Actual dates set by your local Islamic authority."
    }

    public init(
        event: IslamicEvent,
        estimatedDate: Date,
        hijriDate: HijriDate,
        confidenceLevel: EventConfidence
    ) {
        self.event = event
        self.estimatedDate = estimatedDate
        self.hijriDate = hijriDate
        self.confidenceLevel = confidenceLevel
    }

    public static func == (lhs: IslamicEventEstimate, rhs: IslamicEventEstimate) -> Bool {
        lhs.event == rhs.event &&
        lhs.estimatedDate == rhs.estimatedDate &&
        lhs.hijriDate == rhs.hijriDate &&
        lhs.confidenceLevel == rhs.confidenceLevel
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(event)
        hasher.combine(estimatedDate)
        hasher.combine(hijriDate)
        hasher.combine(confidenceLevel)
    }
}

public enum EventConfidence: Equatable {
    case high       // <12 months
    case medium     // 12-60 months
    case low        // >60 months

    public var displayText: String {
        switch self {
        case .high: return "High confidence"
        case .medium: return "Medium confidence"
        case .low: return "Low confidence"
        }
    }
}

public enum PrecisionLevel: Equatable {
    case exact                          // Show HH:mm
    case window(minutes: Int)           // Show ±window/2
    case timeOfDay                      // Show coarse slot

    public func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()

        switch self {
        case .exact:
            formatter.timeStyle = .short
            return formatter.string(from: date)

        case .window(let minutes):
            formatter.timeStyle = .short
            let calendar = Calendar.current
            guard let startTime = calendar.date(byAdding: .minute, value: -minutes / 2, to: date),
                  let endTime = calendar.date(byAdding: .minute, value: minutes / 2, to: date) else {
                return formatter.string(from: date)
            }
            return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"

        case .timeOfDay:
            let hour = Calendar.current.component(.hour, from: date)
            switch hour {
            case 0..<6: return "Early Morning"
            case 6..<12: return "Morning"
            case 12..<13: return "Noon"
            case 13..<17: return "Afternoon"
            case 17..<20: return "Evening"
            default: return "Night"
            }
        }
    }
}
