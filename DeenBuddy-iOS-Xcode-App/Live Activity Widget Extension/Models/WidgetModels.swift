import Foundation
import SwiftUI
import WidgetKit

// MARK: - Widget Data Models

/// Simplified prayer enum for widget extension (scoped to extension)
enum WidgetPrayer: String, CaseIterable, Codable, Sendable {
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
struct PrayerTime: Codable, Identifiable, Sendable {
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
/// Note: The main app's HijriDate includes an 'era' field (HijriEra enum) which we decode robustly
struct HijriDate: Codable, Sendable {
    let day: Int
    let month: String
    let year: Int
    
    private enum CodingKeys: String, CodingKey {
        case day
        case month
        case year
        case era // Main app includes this field - we decode but ignore it
    }

    init(day: Int, month: String, year: Int) {
        self.day = day
        self.month = month
        self.year = year
    }

    init(from date: Date) {
        // Simple implementation - in a real app this would use proper Hijri calendar
        let calendar = Calendar(identifier: .islamicCivil)
        let components = calendar.dateComponents([.day, .month, .year], from: date)
        self.day = components.day ?? 1
        self.year = components.year ?? 1446

        self.month = HijriDate.monthName(for: components.month ?? 1)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Robustly decode day with fallback
        day = (try? container.decode(Int.self, forKey: .day)) ?? 1
        
        // Robustly decode year with fallback
        year = (try? container.decode(Int.self, forKey: .year)) ?? 1445
        
        // Robustly handle 'era' field - could be String, Int, or nested object (HijriEra enum)
        // We don't need it, so we just try to decode and ignore any errors
        if let _ = try? container.decode(String.self, forKey: .era) {
            // Era decoded as String - ignored
        } else if let _ = try? container.decode(Int.self, forKey: .era) {
            // Era decoded as Int - ignored
        } else {
            // Era field missing, invalid, or nested object - ignored
        }

        // Handle month field - can be String (month name), Int (month number), or nested object (HijriMonth enum)
        if let monthString = try? container.decode(String.self, forKey: .month) {
            // If the decoded string is actually a numeric value (e.g. "9"),
            // normalize it to a month name instead of showing the digits.
            if let numeric = Int(monthString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                if numeric < 1 || numeric > 12 {
                    print("⚠️ Widget HijriDate: month value out of range: \(numeric), clamping to valid range")
                }
                month = HijriDate.monthName(for: numeric)
            } else {
                month = monthString
            }
            print("✅ Widget HijriDate: Decoded month as String: \(month)")
        } else if let monthInt = try? container.decode(Int.self, forKey: .month) {
            month = HijriDate.monthName(for: monthInt)
            print("✅ Widget HijriDate: Decoded month as Int: \(monthInt) -> \(month)")
        } else {
            // Log the decoding failure to help diagnose data corruption issues
            print("⚠️ Widget HijriDate: month field missing or invalid (day: \(day), year: \(year)). Falling back to Muharram.")
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
struct WidgetData: Codable, Sendable {
    let nextPrayer: PrayerTime?
    var timeUntilNextPrayer: TimeInterval?
    var currentPrayerInterval: TimeInterval?
    let todaysPrayerTimes: [PrayerTime]
    let hijriDate: HijriDate
    let location: String
    let calculationMethod: CalculationMethod
    let lastUpdated: Date
    
    // Placeholder data for previews and fallbacks
    static let placeholder = WidgetData(
        nextPrayer: PrayerTime(prayer: WidgetPrayer.maghrib, time: Date().addingTimeInterval(3600), location: nil),
        timeUntilNextPrayer: 3600,
        currentPrayerInterval: 7200,
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
        currentPrayerInterval: nil,
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
    
    /// Check if widget data is stale (older than 24 hours)
    var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > 24 * 60 * 60 // 24 hours
    }
    
    /// Check if data needs refresh (older than 5 minutes)
    var needsRefresh: Bool {
        Date().timeIntervalSince(lastUpdated) > 5 * 60 // 5 minutes
    }
}

/// Widget entry
struct PrayerWidgetEntry: TimelineEntry, Sendable {
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
struct PrayerWidgetConfiguration: Codable, Sendable {
    let showArabicText: Bool
    let showCountdown: Bool
    let theme: WidgetTheme
    
    static let `default` = PrayerWidgetConfiguration(
        showArabicText: true,
        showCountdown: true,
        theme: .auto
    )
}

enum WidgetTheme: String, Codable, Sendable {
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
        print("🔄 Widget: loadWidgetData() called")
        
        guard let sharedDefaults = sharedDefaults else {
            print("❌ Widget: Failed to access shared UserDefaults for group: \(groupIdentifier)")
            print("🔍 Widget: This may indicate an app group configuration issue in Xcode")
            print("💡 Widget: Verify App Group capability is enabled for both main app and widget extension")
            return nil
        }
        
        print("✅ Widget: Successfully accessed shared UserDefaults")

        guard let data = sharedDefaults.data(forKey: widgetDataKey) else {
            print("ℹ️ Widget: No widget data found in shared container for key: \(widgetDataKey)")
            let allKeys = Array(sharedDefaults.dictionaryRepresentation().keys).sorted()
            print("🔍 Widget: Available keys in shared container (\(allKeys.count) total):")
            for key in allKeys.prefix(10) {
                print("   - \(key)")
            }
            if allKeys.count > 10 {
                print("   ... and \(allKeys.count - 10) more keys")
            }
            print("💡 Widget: Open the DeenBuddy app to initialize widget data")
            return nil
        }
        
        print("✅ Widget: Found widget data, size: \(data.count) bytes")

        do {
            let widgetData = try JSONDecoder().decode(WidgetData.self, from: data)
            print("✅ Widget: Successfully decoded widget data")
            #if DEBUG
            print("📍 Widget Data Summary:")
            print("   - Next prayer: \(widgetData.nextPrayer?.prayer.displayName ?? "None")")
            print("   - Next prayer time: \(widgetData.nextPrayer?.time.description ?? "N/A")")
            print("   - Time until next: \(widgetData.timeUntilNextPrayer.map { "\(Int($0/60)) minutes" } ?? "N/A")")
            print("   - Location: \(widgetData.location)")
            print("   - Hijri date: \(widgetData.hijriDate.formatted)")
            print("   - Calculation method: \(widgetData.calculationMethod.displayName)")
            print("   - Last updated: \(widgetData.lastUpdated)")
            print("   - Today's prayers count: \(widgetData.todaysPrayerTimes.count)")
            #endif
            return widgetData
        } catch let decodingError as DecodingError {
            print("❌ Widget: JSON decoding error: \(decodingError)")
            // Provide detailed error information
            switch decodingError {
            case .typeMismatch(let type, let context):
                print("🔍 Type mismatch: Expected \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))")
                print("🔍 Debug description: \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                print("🔍 Value not found: \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))")
            case .keyNotFound(let key, let context):
                print("🔍 Key not found: \(key.stringValue) at \(context.codingPath.map(\.stringValue).joined(separator: "."))")
            case .dataCorrupted(let context):
                print("🔍 Data corrupted at \(context.codingPath.map(\.stringValue).joined(separator: ".")): \(context.debugDescription)")
            @unknown default:
                print("🔍 Unknown decoding error")
            }
            #if DEBUG
            // Show raw JSON for debugging (contains PII - location, prayer times, etc.)
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🔍 Widget: Raw JSON data (first 500 chars): \(jsonString.prefix(500))")
            }
            #endif
            return nil
        } catch {
            print("❌ Widget: Unexpected error decoding widget data: \(error)")
            #if DEBUG
            // Show raw JSON for debugging (contains PII - location, prayer times, etc.)
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🔍 Widget: Raw JSON data (first 500 chars): \(jsonString.prefix(500))")
            }
            #endif
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
