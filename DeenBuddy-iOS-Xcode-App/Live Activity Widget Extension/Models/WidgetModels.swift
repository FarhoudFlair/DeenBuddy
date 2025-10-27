import Foundation
import SwiftUI
import WidgetKit

// MARK: - Widget Data Models

/// Simplified prayer enum for widget extension (scoped to extension)
enum WidgetPrayer: String, CaseIterable, Codable {
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
    let prayer: WidgetPrayer
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
    
    private enum CodingKeys: String, CodingKey {
        case day
        case month
        case year
    }

    init(day: Int, month: String, year: Int) {
        self.day = day
        self.month = month
        self.year = year
    }

    init(from date: Date) {
        // Simple implementation - in a real app this would use proper Hijri calendar
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .month, .year], from: date)
        self.day = components.day ?? 1
        self.year = (components.year ?? 2024) - 579 // Approximate conversion

        self.month = HijriDate.monthName(for: components.month ?? 1)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(Int.self, forKey: .day)
        year = try container.decode(Int.self, forKey: .year)

        if let monthString = try? container.decode(String.self, forKey: .month) {
            // If the decoded string is actually a numeric value (e.g. "9"),
            // normalize it to a month name instead of showing the digits.
            if let numeric = Int(monthString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                if numeric < 1 || numeric > 12 {
                    print("⚠️ HijriDate month value out of range: parsed \(numeric) from '\(monthString)', expected 1-12. Clamping will occur.")
                }
                month = HijriDate.monthName(for: numeric)
            } else {
                month = monthString
            }
        } else if let monthInt = try? container.decode(Int.self, forKey: .month) {
            month = HijriDate.monthName(for: monthInt)
        } else {
            // Log the decoding failure to help diagnose data corruption issues
            print("⚠️ HijriDate decoding failed: month field missing or invalid (day: \(day), year: \(year)). Falling back to Muharram.")
            print("🔍 This may indicate data corruption in the widget data or shared container.")
            // Fall back to a safe default if the payload is missing/invalid
            month = HijriDate.monthName(for: 1)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(day, forKey: .day)
        try container.encode(month, forKey: .month)
        try container.encode(year, forKey: .year)
    }

    var formatted: String {
        return "\(day) \(month) \(year)"
    }

    private static func monthName(for index: Int) -> String {
        let monthNames = [
            "Muharram",
            "Safar",
            "Rabi' al-awwal",
            "Rabi' al-thani",
            "Jumada al-awwal",
            "Jumada al-thani",
            "Rajab",
            "Sha'ban",
            "Ramadan",
            "Shawwal",
            "Dhu al-Qi'dah",
            "Dhu al-Hijjah"
        ]

        let clampedIndex = max(1, min(index, monthNames.count))
        return monthNames[clampedIndex - 1]
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
    // Add cases to mirror main app so decoding shared data succeeds
    case jafariLeva = "JafariLeva"
    case jafariTehran = "JafariTehran"
    case fcnaCanada = "FCNACanada"
    
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
        case .jafariLeva: return "Ja'fari (Leva Institute, Qum)"
        case .jafariTehran: return "Ja'fari (Tehran IOG)"
        case .fcnaCanada: return "FCNA (Canada)"
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
    
    // Placeholder data for previews and fallbacks
    static let placeholder = WidgetData(
        nextPrayer: PrayerTime(prayer: WidgetPrayer.maghrib, time: Date().addingTimeInterval(3600), location: nil),
        timeUntilNextPrayer: 3600,
        todaysPrayerTimes: [
            PrayerTime(prayer: WidgetPrayer.fajr, time: Date().addingTimeInterval(-18000), location: nil),
            PrayerTime(prayer: WidgetPrayer.dhuhr, time: Date().addingTimeInterval(-7200), location: nil),
            PrayerTime(prayer: WidgetPrayer.asr, time: Date().addingTimeInterval(-3600), location: nil),
            PrayerTime(prayer: WidgetPrayer.maghrib, time: Date().addingTimeInterval(3600), location: nil),
            PrayerTime(prayer: WidgetPrayer.isha, time: Date().addingTimeInterval(7200), location: nil)
        ],
        hijriDate: HijriDate(from: Date()),
        location: "Location Loading...",
        calculationMethod: CalculationMethod.muslimWorldLeague,
        lastUpdated: Date()
    )
    
    // Error state when data loading fails
    static let errorState = WidgetData(
        nextPrayer: nil,
        timeUntilNextPrayer: nil,
        todaysPrayerTimes: [],
        hijriDate: HijriDate(from: Date()),
        location: "Open DeenBuddy App",
        calculationMethod: CalculationMethod.muslimWorldLeague,
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
    let configuration: PrayerWidgetConfiguration
    
    static func placeholder() -> PrayerWidgetEntry {
        return PrayerWidgetEntry(
            date: Date(),
            widgetData: .placeholder,
            configuration: .default
        )
    }
    
    static func errorEntry() -> PrayerWidgetEntry {
        return PrayerWidgetEntry(
            date: Date(),
            widgetData: .errorState,
            configuration: .default
        )
    }
}

/// Widget configuration
struct PrayerWidgetConfiguration: Codable {
    let showArabicText: Bool
    let showCountdown: Bool
    let theme: WidgetTheme
    
    static let `default` = PrayerWidgetConfiguration(
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
            print("🔍 Widget: This may indicate an app group configuration issue")
            return nil
        }

        guard let data = sharedDefaults.data(forKey: widgetDataKey) else {
            print("ℹ️ Widget: No widget data found in shared container for key: \(widgetDataKey)")
            print("🔍 Widget: Available keys in shared container: \(Array(sharedDefaults.dictionaryRepresentation().keys))")
            print("🔍 Widget: This usually means the main app hasn't saved widget data yet")
            return nil
        }

        do {
            let widgetData = try JSONDecoder().decode(WidgetData.self, from: data)
            print("✅ Widget: Successfully loaded widget data")
            print("🔍 Widget: Next prayer: \(widgetData.nextPrayer?.prayer.displayName ?? "None")")
            print("🔍 Widget: Location: \(widgetData.location)")
            print("🔍 Widget: Last updated: \(widgetData.lastUpdated)")
            return widgetData
        } catch {
            print("❌ Widget: Failed to decode widget data: \(error)")
            print("🔍 Widget: Data size: \(data.count) bytes")
            // Try to provide a more helpful error message
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🔍 Widget: Raw JSON data: \(jsonString.prefix(200))...")
            }
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
    
    func loadWidgetConfiguration() -> PrayerWidgetConfiguration {
        guard let sharedDefaults = sharedDefaults else {
            print("⚠️ Widget: Failed to access shared UserDefaults for configuration")
            return PrayerWidgetConfiguration(
                showArabicText: shouldShowArabicSymbol(),
                showCountdown: true,
                theme: .auto
            )
        }

        guard let data = sharedDefaults.data(forKey: widgetConfigurationKey) else {
            print("ℹ️ Widget: No widget configuration found, using default with Arabic symbol preference")
            return PrayerWidgetConfiguration(
                showArabicText: shouldShowArabicSymbol(),
                showCountdown: true,
                theme: .auto
            )
        }

        do {
            let config = try JSONDecoder().decode(PrayerWidgetConfiguration.self, from: data)
            print("✅ Widget: Successfully loaded widget configuration")
            // Override showArabicText with user's preference for Arabic symbols
            return PrayerWidgetConfiguration(
                showArabicText: shouldShowArabicSymbol(),
                showCountdown: config.showCountdown,
                theme: config.theme
            )
        } catch {
            print("❌ Widget: Failed to decode widget configuration: \(error)")
            return PrayerWidgetConfiguration(
                showArabicText: shouldShowArabicSymbol(),
                showCountdown: true,
                theme: .auto
            )
        }
    }
    
    func saveWidgetConfiguration(_ configuration: PrayerWidgetConfiguration) {
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
