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
    
    // MARK: - iOS UI Properties for Dynamic Island
    
    /// SF Symbol name for this prayer
    var systemImageName: String {
        switch self {
        case .fajr: return "sunrise"
        case .dhuhr: return "sun.max"
        case .asr: return "sun.and.horizon"
        case .maghrib: return "sunset"
        case .isha: return "moon.stars"
        }
    }
    
    /// SwiftUI color associated with this prayer
    var color: Color {
        switch self {
        case .fajr: return .orange
        case .dhuhr: return .yellow
        case .asr: return .blue
        case .maghrib: return .red
        case .isha: return .purple
        }
    }
}

/// Simplified prayer time model for widget extension
struct PrayerTime: Codable, Identifiable {
    let id = UUID()
    let prayer: Prayer
    let time: Date
    let location: String?

    enum CodingKeys: String, CodingKey {
        case prayer, time, location
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
    var timeUntilNextPrayer: TimeInterval?
    let todaysPrayerTimes: [PrayerTime]
    let hijriDate: HijriDate
    let location: String
    let calculationMethod: CalculationMethod
    let lastUpdated: Date
    
    // Placeholder data for previews
    static let placeholder = WidgetData(
        nextPrayer: PrayerTime(prayer: .maghrib, time: Date().addingTimeInterval(3600), location: nil),
        timeUntilNextPrayer: 3600,
        todaysPrayerTimes: [
            PrayerTime(prayer: .fajr, time: Date().addingTimeInterval(-18000), location: nil),
            PrayerTime(prayer: .dhuhr, time: Date().addingTimeInterval(-7200), location: nil),
            PrayerTime(prayer: .asr, time: Date().addingTimeInterval(-3600), location: nil),
            PrayerTime(prayer: .maghrib, time: Date().addingTimeInterval(3600), location: nil),
            PrayerTime(prayer: .isha, time: Date().addingTimeInterval(7200), location: nil)
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

/// Manager for widget data operations - simplified for widget extension
class WidgetDataManager {
    static let shared = WidgetDataManager()

    private let groupIdentifier = "group.com.deenbuddy.app"
    private let widgetDataKey = "DeenBuddy.WidgetData"
    private let widgetConfigurationKey = "DeenBuddy.WidgetConfiguration"

    private init() {}

    private var sharedDefaults: UserDefaults? {
        guard let defaults = UserDefaults(suiteName: groupIdentifier) else {
            print("⚠️ Widget: Failed to create shared UserDefaults for group: \(groupIdentifier)")
            return nil
        }

        // Ensure we're using the current user's defaults, not any user
        // This prevents the CFPreferences persona error
        return defaults
    }
    
    func loadWidgetData() -> WidgetData? {
        guard let sharedDefaults = sharedDefaults else {
            print("⚠️ Widget: Failed to access shared UserDefaults for group: \(groupIdentifier)")
            return nil
        }

        guard let data = sharedDefaults.data(forKey: widgetDataKey) else {
            print("ℹ️ Widget: No widget data found in shared container for key: \(widgetDataKey)")
            return nil
        }

        do {
            let widgetData = try JSONDecoder().decode(WidgetData.self, from: data)
            print("✅ Widget: Successfully loaded widget data")
            return widgetData
        } catch {
            print("❌ Widget: Failed to decode widget data: \(error)")
            return nil
        }
    }
    
    func saveWidgetData(_ data: WidgetData) {
        guard let sharedDefaults = sharedDefaults else {
            print("⚠️ Widget: Failed to access shared UserDefaults for saving")
            return
        }

        do {
            let encodedData = try JSONEncoder().encode(data)
            sharedDefaults.set(encodedData, forKey: widgetDataKey)
            sharedDefaults.synchronize()
            print("✅ Widget: Successfully saved widget data")
        } catch {
            print("❌ Widget: Failed to encode widget data: \(error)")
        }
    }
    
    func loadWidgetConfiguration() -> WidgetConfiguration {
        guard let sharedDefaults = sharedDefaults else {
            print("⚠️ Widget: Failed to access shared UserDefaults for configuration")
            return WidgetConfiguration(
                showArabicText: shouldShowArabicSymbol(),
                showCountdown: true,
                theme: .auto
            )
        }

        guard let data = sharedDefaults.data(forKey: widgetConfigurationKey) else {
            print("ℹ️ Widget: No widget configuration found, using default with Arabic symbol preference")
            return WidgetConfiguration(
                showArabicText: shouldShowArabicSymbol(),
                showCountdown: true,
                theme: .auto
            )
        }

        do {
            let config = try JSONDecoder().decode(WidgetConfiguration.self, from: data)
            print("✅ Widget: Successfully loaded widget configuration")
            // Override showArabicText with user's preference for Arabic symbols
            return WidgetConfiguration(
                showArabicText: shouldShowArabicSymbol(),
                showCountdown: config.showCountdown,
                theme: config.theme
            )
        } catch {
            print("❌ Widget: Failed to decode widget configuration: \(error)")
            return WidgetConfiguration(
                showArabicText: shouldShowArabicSymbol(),
                showCountdown: true,
                theme: .auto
            )
        }
    }
    
    func saveWidgetConfiguration(_ configuration: WidgetConfiguration) {
        guard let sharedDefaults = sharedDefaults else {
            print("⚠️ Shared defaults not available, cannot save widget configuration")
            return
        }

        do {
            let encodedData = try JSONEncoder().encode(configuration)
            sharedDefaults.set(encodedData, forKey: widgetConfigurationKey)
            let success = sharedDefaults.synchronize()
            if success {
                print("✅ Widget configuration saved successfully")
            } else {
                print("⚠️ Widget configuration save synchronization failed")
            }
        } catch {
            print("❌ Failed to save widget configuration: \(error)")
        }
    }

    /// Get whether to show Arabic symbol in widgets from user settings
    func shouldShowArabicSymbol() -> Bool {
        guard let sharedDefaults = sharedDefaults else {
            print("⚠️ Shared defaults not available, using default Arabic symbol setting")
            return true // Default to showing the symbol
        }

        // Check if the setting exists, if not default to true for backward compatibility
        if sharedDefaults.object(forKey: "DeenBuddy.Settings.ShowArabicSymbolInWidget") != nil {
            return sharedDefaults.bool(forKey: "DeenBuddy.Settings.ShowArabicSymbolInWidget")
        } else {
            return true // Default to true for existing users
        }
    }
}