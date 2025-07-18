import Foundation
import SwiftUI
import WidgetKit

// MARK: - Widget Data Models

/// Simplified prayer enum for widget extension
enum Prayer: String, CaseIterable, Codable {
    case fajr = "fajr"
    case dhuhr = "dhuhr"
    case asr = "asr"
    case maghrib = "maghrib"
    case isha = "isha"
    
    var displayName: String {
        switch self {
        case .fajr: return "Fajr"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        }
    }
    
    var arabicName: String {
        switch self {
        case .fajr: return "الفجر"
        case .dhuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        }
    }
}

/// Simplified prayer time model for widget extension
struct PrayerTime: Codable, Identifiable {
    let id = UUID()
    let prayer: Prayer
    let time: Date

    enum CodingKeys: String, CodingKey {
        case prayer, time
    }

    var displayName: String {
        return prayer.displayName
    }

    var arabicName: String {
        return prayer.arabicName
    }
}

/// Simplified Hijri date model for widget extension
struct HijriDate: Codable {
    let day: Int
    let month: String
    let year: Int
    
    init(from date: Date) {
        // Simple implementation - in a real app this would use proper Hijri calendar
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .month, .year], from: date)
        self.day = components.day ?? 1
        self.year = (components.year ?? 2024) - 579 // Approximate conversion
        
        let monthNames = ["Muharram", "Safar", "Rabi' al-awwal", "Rabi' al-thani", 
                         "Jumada al-awwal", "Jumada al-thani", "Rajab", "Sha'ban", 
                         "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah"]
        self.month = monthNames[(components.month ?? 1) - 1]
    }
    
    var formatted: String {
        return "\(day) \(month) \(year)"
    }
}

/// Simplified calculation method enum for widget extension
enum CalculationMethod: String, Codable {
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
    
    var displayName: String {
        switch self {
        case .muslimWorldLeague: return "Muslim World League"
        case .egyptian: return "Egyptian General Authority"
        case .karachi: return "University of Islamic Sciences, Karachi"
        case .ummAlQura: return "Umm Al-Qura University, Makkah"
        case .dubai: return "Dubai"
        case .moonsightingCommittee: return "Moonsighting Committee Worldwide"
        case .northAmerica: return "Islamic Society of North America"
        case .kuwait: return "Kuwait"
        case .qatar: return "Qatar"
        case .singapore: return "Singapore"
        }
    }
}

/// Widget data structure
struct WidgetData: Codable {
    let nextPrayer: PrayerTime?
    let timeUntilNextPrayer: TimeInterval?
    let todaysPrayerTimes: [PrayerTime]
    let hijriDate: HijriDate
    let location: String
    let calculationMethod: CalculationMethod
    let lastUpdated: Date
    
    // Placeholder data for previews
    static let placeholder = WidgetData(
        nextPrayer: PrayerTime(prayer: .maghrib, time: Date().addingTimeInterval(3600)),
        timeUntilNextPrayer: 3600,
        todaysPrayerTimes: [
            PrayerTime(prayer: .fajr, time: Date().addingTimeInterval(-18000)),
            PrayerTime(prayer: .dhuhr, time: Date().addingTimeInterval(-7200)),
            PrayerTime(prayer: .asr, time: Date().addingTimeInterval(-3600)),
            PrayerTime(prayer: .maghrib, time: Date().addingTimeInterval(3600)),
            PrayerTime(prayer: .isha, time: Date().addingTimeInterval(7200))
        ],
        hijriDate: HijriDate(from: Date()),
        location: "New York, NY",
        calculationMethod: .muslimWorldLeague,
        lastUpdated: Date()
    )
    
    var formattedTimeUntilNext: String {
        guard let timeInterval = timeUntilNextPrayer else { return "—" }
        
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

/// Widget entry
struct PrayerWidgetEntry: TimelineEntry {
    let date: Date
    let widgetData: WidgetData
    let configuration: WidgetConfiguration
    
    static func placeholder() -> PrayerWidgetEntry {
        return PrayerWidgetEntry(
            date: Date(),
            widgetData: .placeholder,
            configuration: .default
        )
    }
}

/// Widget configuration
struct WidgetConfiguration: Codable {
    let showArabicText: Bool
    let showCountdown: Bool
    let theme: WidgetTheme
    
    static let `default` = WidgetConfiguration(
        showArabicText: true,
        showCountdown: true,
        theme: .auto
    )
}

enum WidgetTheme: String, Codable {
    case light, dark, auto
}

// MARK: - Widget Data Manager

/// Manager for widget data operations
class WidgetDataManager {
    static let shared = WidgetDataManager()
    
    private let groupIdentifier = "group.com.deenbuddy.app"
    private let widgetDataKey = "DeenAssist.WidgetData"
    private let widgetConfigurationKey = "DeenAssist.WidgetConfiguration"
    
    private init() {}
    
    private var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: groupIdentifier)
    }
    
    func loadWidgetData() -> WidgetData? {
        guard let sharedDefaults = sharedDefaults,
              let data = sharedDefaults.data(forKey: widgetDataKey) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(WidgetData.self, from: data)
        } catch {
            print("❌ Failed to decode widget data: \(error)")
            return nil
        }
    }
    
    func saveWidgetData(_ data: WidgetData) {
        guard let sharedDefaults = sharedDefaults else { return }
        
        do {
            let encodedData = try JSONEncoder().encode(data)
            sharedDefaults.set(encodedData, forKey: widgetDataKey)
            sharedDefaults.synchronize()
        } catch {
            print("❌ Failed to encode widget data: \(error)")
        }
    }
    
    func loadWidgetConfiguration() -> WidgetConfiguration {
        guard let sharedDefaults = sharedDefaults,
              let data = sharedDefaults.data(forKey: widgetConfigurationKey) else {
            return .default
        }
        
        do {
            return try JSONDecoder().decode(WidgetConfiguration.self, from: data)
        } catch {
            print("❌ Failed to decode widget configuration: \(error)")
            return .default
        }
    }
    
    func saveWidgetConfiguration(_ configuration: WidgetConfiguration) {
        guard let sharedDefaults = sharedDefaults else { return }
        
        do {
            let encodedData = try JSONEncoder().encode(configuration)
            sharedDefaults.set(encodedData, forKey: widgetConfigurationKey)
            sharedDefaults.synchronize()
        } catch {
            print("❌ Failed to save widget configuration: \(error)")
        }
    }
}
