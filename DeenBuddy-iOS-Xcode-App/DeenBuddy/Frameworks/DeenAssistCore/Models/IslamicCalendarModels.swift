import Foundation
import SwiftUI

// MARK: - Islamic Calendar Models

/// Represents a Hijri (Islamic) date
public struct HijriDate: Codable, Equatable, Comparable, Hashable {
    public let day: Int
    public let month: HijriMonth
    public let year: Int
    public let era: HijriEra
    
    public init(day: Int, month: HijriMonth, year: Int, era: HijriEra = .afterHijra) {
        self.day = day
        self.month = month
        self.year = year
        self.era = era
    }
    
    /// Create HijriDate from Gregorian date
    public init(from gregorianDate: Date) {
        // Simplified conversion - in production, use proper Islamic calendar conversion
        let calendar = Calendar(identifier: .islamicCivil)
        let components = calendar.dateComponents([.day, .month, .year], from: gregorianDate)
        
        self.day = components.day ?? 1
        self.month = HijriMonth(rawValue: components.month ?? 1) ?? .muharram
        self.year = components.year ?? 1445
        self.era = .afterHijra
    }

    /// Create HijriDate from Gregorian date using specified calculation method (calendar identifier)
    public init(from gregorianDate: Date, calculationMethod: IslamicCalendarMethod) {
        let identifier: Calendar.Identifier
        switch calculationMethod {
        case .ummalqura:
            identifier = .islamicUmmAlQura
        case .civil:
            identifier = .islamicCivil
        case .astronomical:
            identifier = .islamicTabular
        case .tabular:
            identifier = .islamicTabular
        }

        let calendar = Calendar(identifier: identifier)
        let components = calendar.dateComponents([.day, .month, .year], from: gregorianDate)

        self.day = components.day ?? 1
        self.month = HijriMonth(rawValue: components.month ?? 1) ?? .muharram
        self.year = components.year ?? 1445
        self.era = .afterHijra
    }
    
    /// Convert to Gregorian date
    public func toGregorianDate() -> Date {
        let calendar = Calendar(identifier: .islamicCivil)
        let components = DateComponents(year: year, month: month.rawValue, day: day)
        return calendar.date(from: components) ?? Date()
    }
    
    /// Formatted string representation
    public var formatted: String {
        return "\(day) \(month.displayName) \(year) \(era.abbreviation)"
    }
    
    /// Short formatted string
    public var shortFormatted: String {
        return "\(day)/\(month.rawValue)/\(year)"
    }

    /// Arabic formatted date string
    public var arabicFormatted: String {
        return "\(day) \(month.arabicName) \(year) هـ"
    }
    
    // MARK: - Comparable
    
    public static func < (lhs: HijriDate, rhs: HijriDate) -> Bool {
        if lhs.year != rhs.year {
            return lhs.year < rhs.year
        }
        if lhs.month != rhs.month {
            return lhs.month.rawValue < rhs.month.rawValue
        }
        return lhs.day < rhs.day
    }
}

/// Hijri months
public enum HijriMonth: Int, Codable, CaseIterable {
    case muharram = 1
    case safar = 2
    case rabiAlAwwal = 3
    case rabiAlThani = 4
    case jumadaAlAwwal = 5
    case jumadaAlThani = 6
    case rajab = 7
    case shaban = 8
    case ramadan = 9
    case shawwal = 10
    case dhulQadah = 11
    case dhulHijjah = 12
    
    public var displayName: String {
        switch self {
        case .muharram: return "Muharram"
        case .safar: return "Safar"
        case .rabiAlAwwal: return "Rabi' al-Awwal"
        case .rabiAlThani: return "Rabi' al-Thani"
        case .jumadaAlAwwal: return "Jumada al-Awwal"
        case .jumadaAlThani: return "Jumada al-Thani"
        case .rajab: return "Rajab"
        case .shaban: return "Sha'ban"
        case .ramadan: return "Ramadan"
        case .shawwal: return "Shawwal"
        case .dhulQadah: return "Dhul-Qa'dah"
        case .dhulHijjah: return "Dhul-Hijjah"
        }
    }
    
    public var arabicName: String {
        switch self {
        case .muharram: return "مُحَرَّم"
        case .safar: return "صَفَر"
        case .rabiAlAwwal: return "رَبِيع الأَوَّل"
        case .rabiAlThani: return "رَبِيع الثَّانِي"
        case .jumadaAlAwwal: return "جُمَادَى الأَوَّل"
        case .jumadaAlThani: return "جُمَادَى الثَّانِي"
        case .rajab: return "رَجَب"
        case .shaban: return "شَعْبَان"
        case .ramadan: return "رَمَضَان"
        case .shawwal: return "شَوَّال"
        case .dhulQadah: return "ذُو القَعْدَة"
        case .dhulHijjah: return "ذُو الحِجَّة"
        }
    }
    
    public var isHolyMonth: Bool {
        switch self {
        case .muharram, .rajab, .dhulQadah, .dhulHijjah:
            return true
        default:
            return false
        }
    }

    /// Whether this is a sacred month (same as isHolyMonth for compatibility)
    public var isSacred: Bool {
        return isHolyMonth
    }

    /// Whether this is the month of Ramadan
    public var isRamadan: Bool {
        return self == .ramadan
    }

    /// Whether this is the month of Hajj
    public var isHajjMonth: Bool {
        return self == .dhulHijjah
    }

    /// Number of days in this month (approximate, as it varies)
    public var approximateDays: Int {
        // Islamic months alternate between 29 and 30 days
        // This is an approximation as actual length depends on moon sighting
        switch rawValue % 2 {
        case 1: return 30 // Odd months typically have 30 days
        case 0: return 29 // Even months typically have 29 days
        default: return 29
        }
    }
    
    public var color: Color {
        switch self {
        case .muharram: return .red
        case .safar: return .orange
        case .rabiAlAwwal, .rabiAlThani: return .green
        case .jumadaAlAwwal, .jumadaAlThani: return .blue
        case .rajab: return .purple
        case .shaban: return .indigo
        case .ramadan: return .yellow
        case .shawwal: return .pink
        case .dhulQadah: return .teal
        case .dhulHijjah: return .brown
        }
    }
}

/// Hijri era
public enum HijriEra: String, Codable {
    case afterHijra = "AH"
    case beforeHijra = "BH"
    
    public var displayName: String {
        switch self {
        case .afterHijra: return "After Hijra"
        case .beforeHijra: return "Before Hijra"
        }
    }
    
    public var abbreviation: String {
        return rawValue
    }
}

/// Islamic event or observance
public struct IslamicEvent: Codable, Identifiable, Equatable, Hashable {
    public let id: UUID
    public let name: String
    public let arabicName: String?
    public let description: String
    public let hijriDate: HijriDate
    public let category: EventCategory
    public let significance: EventSignificance
    public let observances: [String]
    public let isRecurring: Bool
    public let duration: Int // Number of days
    public let source: String?
    public let isUserAdded: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        arabicName: String? = nil,
        description: String,
        hijriDate: HijriDate,
        category: EventCategory,
        significance: EventSignificance,
        observances: [String] = [],
        isRecurring: Bool = true,
        duration: Int = 1,
        source: String? = nil,
        isUserAdded: Bool = false
    ) {
        self.id = id
        self.name = name
        self.arabicName = arabicName
        self.description = description
        self.hijriDate = hijriDate
        self.category = category
        self.significance = significance
        self.observances = observances
        self.isRecurring = isRecurring
        self.duration = duration
        self.source = source
        self.isUserAdded = isUserAdded
    }
    
    /// Get the Gregorian date for this event in a specific year
    public func gregorianDate(for hijriYear: Int) -> Date {
        let eventDate = HijriDate(day: hijriDate.day, month: hijriDate.month, year: hijriYear)
        return eventDate.toGregorianDate()
    }

    /// Display name for UI components - follows the same pattern as other types in the codebase
    public var displayName: String {
        return name
    }

    // MARK: - Predefined Islamic Events

    /// Islamic New Year (1st Muharram)
    public static let newYear = IslamicEvent(
        name: "Islamic New Year",
        arabicName: "رأس السنة الهجرية",
        description: "The first day of Muharram, marking the beginning of the Islamic year",
        hijriDate: HijriDate(day: 1, month: .muharram, year: 1445),
        category: .religious,
        significance: .major
    )

    /// Day of Ashura (10th Muharram)
    public static let ashura = IslamicEvent(
        name: "Day of Ashura",
        arabicName: "يوم عاشوراء",
        description: "The 10th day of Muharram, a day of fasting and remembrance",
        hijriDate: HijriDate(day: 10, month: .muharram, year: 1445),
        category: .religious,
        significance: .major
    )

    /// Mawlid al-Nabi (12th Rabi' al-Awwal)
    public static let mawlidNabawi = IslamicEvent(
        name: "Mawlid al-Nabi",
        arabicName: "المولد النبوي",
        description: "Celebration of the birth of Prophet Muhammad (peace be upon him)",
        hijriDate: HijriDate(day: 12, month: .rabiAlAwwal, year: 1445),
        category: .religious,
        significance: .major
    )

    /// Isra and Mi'raj (27th Rajab)
    public static let israMiraj = IslamicEvent(
        name: "Isra and Mi'raj",
        arabicName: "الإسراء والمعراج",
        description: "Commemoration of the Prophet's night journey and ascension",
        hijriDate: HijriDate(day: 27, month: .rajab, year: 1445),
        category: .religious,
        significance: .major
    )

    /// Beginning of Ramadan (1st Ramadan)
    public static let ramadanStart = IslamicEvent(
        name: "Beginning of Ramadan",
        arabicName: "بداية رمضان",
        description: "Beginning of the holy month of fasting",
        hijriDate: HijriDate(day: 1, month: .ramadan, year: 1445),
        category: .religious,
        significance: .major
    )

    /// Laylat al-Qadr (27th Ramadan)
    public static let laylalQadr = IslamicEvent(
        name: "Laylat al-Qadr",
        arabicName: "ليلة القدر",
        description: "The Night of Power, when the Quran was first revealed",
        hijriDate: HijriDate(day: 27, month: .ramadan, year: 1445),
        category: .religious,
        significance: .major
    )

    /// Eid al-Fitr (1st Shawwal)
    public static let eidAlFitr = IslamicEvent(
        name: "Eid al-Fitr",
        arabicName: "عيد الفطر",
        description: "Festival celebrating the end of Ramadan",
        hijriDate: HijriDate(day: 1, month: .shawwal, year: 1445),
        category: .religious,
        significance: .major
    )

    /// Eid al-Adha (10th Dhul Hijjah)
    public static let eidAlAdha = IslamicEvent(
        name: "Eid al-Adha",
        arabicName: "عيد الأضحى",
        description: "Festival of Sacrifice, commemorating Ibrahim's willingness to sacrifice",
        hijriDate: HijriDate(day: 10, month: .dhulHijjah, year: 1445),
        category: .religious,
        significance: .major
    )

    /// Hajj (8th-12th Dhul Hijjah)
    public static let hajj = IslamicEvent(
        name: "Hajj",
        arabicName: "الحج",
        description: "Annual pilgrimage to Mecca",
        hijriDate: HijriDate(day: 8, month: .dhulHijjah, year: 1445),
        category: .religious,
        significance: .major,
        duration: 5
    )

    /// All predefined Islamic events
    public static let allCases: [IslamicEvent] = [
        newYear, ashura, mawlidNabawi, israMiraj, ramadanStart,
        laylalQadr, eidAlFitr, eidAlAdha, hajj
    ]
}

/// Categories of Islamic events
public enum EventCategory: String, Codable, CaseIterable {
    case religious = "religious"
    case historical = "historical"
    case cultural = "cultural"
    case personal = "personal"
    case community = "community"
    
    public var displayName: String {
        return rawValue.capitalized
    }
    
    public var color: Color {
        switch self {
        case .religious: return .green
        case .historical: return .blue
        case .cultural: return .orange
        case .personal: return .purple
        case .community: return .teal
        }
    }
    
    public var icon: String {
        switch self {
        case .religious: return "moon.stars"
        case .historical: return "book.closed"
        case .cultural: return "globe"
        case .personal: return "person"
        case .community: return "people"
        }
    }
}

/// Significance levels of Islamic events
public enum EventSignificance: String, Codable, CaseIterable {
    case major = "major"
    case moderate = "moderate"
    case minor = "minor"
    case personal = "personal"
    
    public var displayName: String {
        return rawValue.capitalized
    }
    
    public var priority: Int {
        switch self {
        case .major: return 4
        case .moderate: return 3
        case .minor: return 2
        case .personal: return 1
        }
    }
    
    public var color: Color {
        switch self {
        case .major: return .red
        case .moderate: return .orange
        case .minor: return .yellow
        case .personal: return .gray
        }
    }
}

/// Islamic calendar information for a specific date
public struct IslamicCalendarDay: Codable, Identifiable, Equatable {
    public let id: UUID
    public let gregorianDate: Date
    public let hijriDate: HijriDate
    public let events: [IslamicEvent]
    public let moonPhase: MoonPhase?
    public let isHolyDay: Bool
    public let specialObservances: [String]
    
    public init(
        id: UUID = UUID(),
        gregorianDate: Date,
        hijriDate: HijriDate,
        events: [IslamicEvent] = [],
        moonPhase: MoonPhase? = nil,
        isHolyDay: Bool = false,
        specialObservances: [String] = []
    ) {
        self.id = id
        self.gregorianDate = gregorianDate
        self.hijriDate = hijriDate
        self.events = events
        self.moonPhase = moonPhase
        self.isHolyDay = isHolyDay
        self.specialObservances = specialObservances
    }
    
    /// Check if this day has any major events
    public var hasMajorEvents: Bool {
        return events.contains { $0.significance == .major }
    }
    
    /// Get the most significant event for this day
    public var primaryEvent: IslamicEvent? {
        return events.max { $0.significance.priority < $1.significance.priority }
    }
}

/// Moon phases for Islamic calendar
public enum MoonPhase: String, Codable, CaseIterable {
    case newMoon = "new"
    case waxingCrescent = "waxingCrescent"
    case firstQuarter = "firstQuarter"
    case waxingGibbous = "waxingGibbous"
    case fullMoon = "full"
    case waningGibbous = "waningGibbous"
    case lastQuarter = "lastQuarter"
    case waningCrescent = "waningCrescent"
    
    public var displayName: String {
        switch self {
        case .newMoon: return "New Moon"
        case .waxingCrescent: return "Waxing Crescent"
        case .firstQuarter: return "First Quarter"
        case .waxingGibbous: return "Waxing Gibbous"
        case .fullMoon: return "Full Moon"
        case .waningGibbous: return "Waning Gibbous"
        case .lastQuarter: return "Last Quarter"
        case .waningCrescent: return "Waning Crescent"
        }
    }
    
    public var emoji: String {
        switch self {
        case .newMoon: return "🌑"
        case .waxingCrescent: return "🌒"
        case .firstQuarter: return "🌓"
        case .waxingGibbous: return "🌔"
        case .fullMoon: return "🌕"
        case .waningGibbous: return "🌖"
        case .lastQuarter: return "🌗"
        case .waningCrescent: return "🌘"
        }
    }
    
    public var isSignificant: Bool {
        return self == .newMoon || self == .fullMoon
    }
}

/// Islamic calendar statistics
public struct IslamicCalendarStatistics: Codable, Equatable {
    public let totalEventsTracked: Int
    public let majorEventsThisYear: Int
    public let holyMonthsObserved: Int
    public let personalEventsAdded: Int
    public let mostActiveMonth: HijriMonth?
    public let upcomingEvents: [IslamicEvent]
    public let recentlyObserved: [IslamicEvent]
    
    public init(
        totalEventsTracked: Int = 0,
        majorEventsThisYear: Int = 0,
        holyMonthsObserved: Int = 0,
        personalEventsAdded: Int = 0,
        mostActiveMonth: HijriMonth? = nil,
        upcomingEvents: [IslamicEvent] = [],
        recentlyObserved: [IslamicEvent] = []
    ) {
        self.totalEventsTracked = totalEventsTracked
        self.majorEventsThisYear = majorEventsThisYear
        self.holyMonthsObserved = holyMonthsObserved
        self.personalEventsAdded = personalEventsAdded
        self.mostActiveMonth = mostActiveMonth
        self.upcomingEvents = upcomingEvents
        self.recentlyObserved = recentlyObserved
    }
}
