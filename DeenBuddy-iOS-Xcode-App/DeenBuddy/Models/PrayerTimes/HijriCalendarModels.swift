//
//  HijriCalendarModels.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-04.
//

import Foundation

// MARK: - Hijri Date

/// Represents a date in the Islamic (Hijri) calendar
public struct HijriDate: Codable, Equatable {
    public let day: Int
    public let month: HijriMonth
    public let year: Int
    
    public init(day: Int, month: HijriMonth, year: Int) {
        self.day = day
        self.month = month
        self.year = year
    }
    
    /// Formatted Hijri date string
    public var formatted: String {
        return "\(day) \(month.displayName) \(year) AH"
    }
    
    /// Short formatted Hijri date string
    public var shortFormatted: String {
        return "\(day) \(month.shortName) \(year)"
    }
    
    /// Arabic formatted date string
    public var arabicFormatted: String {
        return "\(day) \(month.arabicName) \(year) هـ"
    }
}

// MARK: - Hijri Month

/// Islamic calendar months
public enum HijriMonth: Int, CaseIterable, Codable, Identifiable {
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
    
    public var id: Int { rawValue }
    
    /// English display name
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
        case .dhulQadah: return "Dhu al-Qa'dah"
        case .dhulHijjah: return "Dhu al-Hijjah"
        }
    }
    
    /// Short English name
    public var shortName: String {
        switch self {
        case .muharram: return "Muh"
        case .safar: return "Saf"
        case .rabiAlAwwal: return "R.A"
        case .rabiAlThani: return "R.T"
        case .jumadaAlAwwal: return "J.A"
        case .jumadaAlThani: return "J.T"
        case .rajab: return "Raj"
        case .shaban: return "Sha"
        case .ramadan: return "Ram"
        case .shawwal: return "Shaw"
        case .dhulQadah: return "D.Q"
        case .dhulHijjah: return "D.H"
        }
    }
    
    /// Arabic name
    public var arabicName: String {
        switch self {
        case .muharram: return "محرم"
        case .safar: return "صفر"
        case .rabiAlAwwal: return "ربيع الأول"
        case .rabiAlThani: return "ربيع الثاني"
        case .jumadaAlAwwal: return "جمادى الأولى"
        case .jumadaAlThani: return "جمادى الثانية"
        case .rajab: return "رجب"
        case .shaban: return "شعبان"
        case .ramadan: return "رمضان"
        case .shawwal: return "شوال"
        case .dhulQadah: return "ذو القعدة"
        case .dhulHijjah: return "ذو الحجة"
        }
    }
    
    /// Whether this is a sacred month
    public var isSacred: Bool {
        switch self {
        case .muharram, .rajab, .dhulQadah, .dhulHijjah:
            return true
        default:
            return false
        }
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
}

// MARK: - Islamic Calendar Events

/// Important Islamic calendar events
public enum IslamicEvent: String, CaseIterable, Codable, Identifiable {
    case newYear = "new_year"
    case ashura = "ashura"
    case mawlidNabawi = "mawlid_nabawi"
    case israMiraj = "isra_miraj"
    case ramadanStart = "ramadan_start"
    case laylalQadr = "laylal_qadr"
    case eidAlFitr = "eid_al_fitr"
    case eidAlAdha = "eid_al_adha"
    case hajj = "hajj"
    
    public var id: String { rawValue }
    
    /// Display name of the event
    public var displayName: String {
        switch self {
        case .newYear: return "Islamic New Year"
        case .ashura: return "Day of Ashura"
        case .mawlidNabawi: return "Mawlid an-Nabi"
        case .israMiraj: return "Isra and Mi'raj"
        case .ramadanStart: return "Start of Ramadan"
        case .laylalQadr: return "Laylat al-Qadr"
        case .eidAlFitr: return "Eid al-Fitr"
        case .eidAlAdha: return "Eid al-Adha"
        case .hajj: return "Hajj"
        }
    }
    
    /// Arabic name of the event
    public var arabicName: String {
        switch self {
        case .newYear: return "رأس السنة الهجرية"
        case .ashura: return "يوم عاشوراء"
        case .mawlidNabawi: return "المولد النبوي"
        case .israMiraj: return "الإسراء والمعراج"
        case .ramadanStart: return "بداية رمضان"
        case .laylalQadr: return "ليلة القدر"
        case .eidAlFitr: return "عيد الفطر"
        case .eidAlAdha: return "عيد الأضحى"
        case .hajj: return "الحج"
        }
    }
    
    /// Description of the event
    public var description: String {
        switch self {
        case .newYear:
            return "The first day of Muharram, marking the beginning of the Islamic year"
        case .ashura:
            return "The 10th day of Muharram, a day of fasting and remembrance"
        case .mawlidNabawi:
            return "Celebration of the birth of Prophet Muhammad (peace be upon him)"
        case .israMiraj:
            return "Commemoration of the Prophet's night journey and ascension"
        case .ramadanStart:
            return "Beginning of the holy month of fasting"
        case .laylalQadr:
            return "The Night of Power, when the Quran was first revealed"
        case .eidAlFitr:
            return "Festival celebrating the end of Ramadan"
        case .eidAlAdha:
            return "Festival of Sacrifice, commemorating Ibrahim's willingness to sacrifice"
        case .hajj:
            return "Annual pilgrimage to Mecca"
        }
    }
    
    /// Month when this event typically occurs
    public var month: HijriMonth {
        switch self {
        case .newYear: return .muharram
        case .ashura: return .muharram
        case .mawlidNabawi: return .rabiAlAwwal
        case .israMiraj: return .rajab
        case .ramadanStart: return .ramadan
        case .laylalQadr: return .ramadan
        case .eidAlFitr: return .shawwal
        case .eidAlAdha: return .dhulHijjah
        case .hajj: return .dhulHijjah
        }
    }
    
    /// Approximate day of the month (where applicable)
    public var approximateDay: Int? {
        switch self {
        case .newYear: return 1
        case .ashura: return 10
        case .mawlidNabawi: return 12
        case .israMiraj: return 27
        case .ramadanStart: return 1
        case .laylalQadr: return 27 // Often observed on 27th
        case .eidAlFitr: return 1
        case .eidAlAdha: return 10
        case .hajj: return nil // Multiple days
        }
    }
}

// MARK: - Calendar Conversion

/// Utility for converting between Gregorian and Hijri calendars
public struct CalendarConverter {
    
    /// Convert Gregorian date to approximate Hijri date
    /// Note: This is an approximation. For precise dates, astronomical calculations are needed
    public static func gregorianToHijri(_ gregorianDate: Date) -> HijriDate {
        let calendar = Calendar(identifier: .islamicUmmAlQura)
        let components = calendar.dateComponents([.year, .month, .day], from: gregorianDate)
        
        let year = components.year ?? 1445
        let monthNumber = components.month ?? 1
        let day = components.day ?? 1
        
        let month = HijriMonth(rawValue: monthNumber) ?? .muharram
        
        return HijriDate(day: day, month: month, year: year)
    }
    
    /// Convert approximate Hijri date to Gregorian date
    /// Note: This is an approximation. For precise dates, astronomical calculations are needed
    public static func hijriToGregorian(_ hijriDate: HijriDate) -> Date? {
        let calendar = Calendar(identifier: .islamicUmmAlQura)
        let components = DateComponents(
            year: hijriDate.year,
            month: hijriDate.month.rawValue,
            day: hijriDate.day
        )
        
        return calendar.date(from: components)
    }
    
    /// Get current Hijri date
    public static func currentHijriDate() -> HijriDate {
        return gregorianToHijri(Date())
    }
    
    /// Check if a given Gregorian date corresponds to an Islamic event
    public static func getIslamicEvents(for gregorianDate: Date) -> [IslamicEvent] {
        let hijriDate = gregorianToHijri(gregorianDate)
        var events: [IslamicEvent] = []
        
        for event in IslamicEvent.allCases {
            if event.month == hijriDate.month,
               let eventDay = event.approximateDay,
               abs(eventDay - hijriDate.day) <= 1 { // Allow 1 day tolerance
                events.append(event)
            }
        }
        
        return events
    }
}

// MARK: - Date Display Helper

/// Helper for displaying both Gregorian and Hijri dates
public struct DualCalendarDate {
    public let gregorianDate: Date
    public let hijriDate: HijriDate
    
    public init(gregorianDate: Date) {
        self.gregorianDate = gregorianDate
        self.hijriDate = CalendarConverter.gregorianToHijri(gregorianDate)
    }
    
    /// Formatted string showing both calendars
    public var formattedBoth: String {
        let gregorianFormatter = DateFormatter()
        gregorianFormatter.dateStyle = .long
        
        let gregorianString = gregorianFormatter.string(from: gregorianDate)
        let hijriString = hijriDate.formatted
        
        return "\(gregorianString)\n\(hijriString)"
    }
    
    /// Short formatted string showing both calendars
    public var shortFormattedBoth: String {
        let gregorianFormatter = DateFormatter()
        gregorianFormatter.dateStyle = .medium
        
        let gregorianString = gregorianFormatter.string(from: gregorianDate)
        let hijriString = hijriDate.shortFormatted
        
        return "\(gregorianString) • \(hijriString)"
    }
    
    /// Islamic events occurring on this date
    public var islamicEvents: [IslamicEvent] {
        return CalendarConverter.getIslamicEvents(for: gregorianDate)
    }
}
