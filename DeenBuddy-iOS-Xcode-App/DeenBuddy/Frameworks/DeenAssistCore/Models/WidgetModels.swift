import Foundation
import WidgetKit

// MARK: - Widget Data Models

/// Shared data structure for widget content
public struct WidgetData: Codable {
    public let nextPrayer: PrayerTime?
    public var timeUntilNextPrayer: TimeInterval?
    public let todaysPrayerTimes: [PrayerTime]
    public let hijriDate: HijriDate
    public let location: String
    public let calculationMethod: CalculationMethod
    public let lastUpdated: Date
    
    public init(
        nextPrayer: PrayerTime?,
        timeUntilNextPrayer: TimeInterval?,
        todaysPrayerTimes: [PrayerTime],
        hijriDate: HijriDate,
        location: String,
        calculationMethod: CalculationMethod,
        lastUpdated: Date = Date()
    ) {
        self.nextPrayer = nextPrayer
        self.timeUntilNextPrayer = timeUntilNextPrayer
        self.todaysPrayerTimes = todaysPrayerTimes
        self.hijriDate = hijriDate
        self.location = location
        self.calculationMethod = calculationMethod
        self.lastUpdated = lastUpdated
    }
    
    /// Default empty widget data for placeholders
    public static let placeholder = WidgetData(
        nextPrayer: PrayerTime(prayer: .fajr, time: Date()),
        timeUntilNextPrayer: 3600, // 1 hour
        todaysPrayerTimes: Prayer.allCases.enumerated().map { index, prayer in
            PrayerTime(prayer: prayer, time: Calendar.current.date(byAdding: .hour, value: index * 3, to: Date()) ?? Date())
        },
        hijriDate: HijriDate(from: Date()),
        location: "Mecca, Saudi Arabia",
        calculationMethod: .muslimWorldLeague
    )
    
    /// Check if data is stale and needs refresh
    public var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > 300 // 5 minutes
    }
    
    /// Get formatted time until next prayer
    public var formattedTimeUntilNext: String {
        guard let timeInterval = timeUntilNextPrayer else { return "—" }
        
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Get next prayer after current next prayer
    public var prayerAfterNext: PrayerTime? {
        guard let nextPrayer = nextPrayer else { return nil }
        
        let nextIndex = Prayer.allCases.firstIndex(of: nextPrayer.prayer) ?? 0
        let afterNextIndex = (nextIndex + 1) % Prayer.allCases.count
        let afterNextPrayer = Prayer.allCases[afterNextIndex]
        
        return todaysPrayerTimes.first { $0.prayer == afterNextPrayer }
    }
}

/// Widget configuration for user customization
public struct WidgetConfiguration: Codable, Sendable {
    public let showHijriDate: Bool
    public let showLocation: Bool
    public let showCalculationMethod: Bool
    public let preferredPrayerDisplay: PrayerDisplayStyle
    public let colorScheme: WidgetColorScheme
    
    public init(
        showHijriDate: Bool = true,
        showLocation: Bool = true,
        showCalculationMethod: Bool = false,
        preferredPrayerDisplay: PrayerDisplayStyle = .nextPrayerFocus,
        colorScheme: WidgetColorScheme = .adaptive
    ) {
        self.showHijriDate = showHijriDate
        self.showLocation = showLocation
        self.showCalculationMethod = showCalculationMethod
        self.preferredPrayerDisplay = preferredPrayerDisplay
        self.colorScheme = colorScheme
    }
    
    public static let `default` = WidgetConfiguration()
}

/// Prayer display style options for widgets
public enum PrayerDisplayStyle: String, CaseIterable, Codable, Sendable {
    case nextPrayerFocus = "next_prayer_focus"
    case allPrayersToday = "all_prayers_today"
    case remainingPrayers = "remaining_prayers"
    
    public var displayName: String {
        switch self {
        case .nextPrayerFocus:
            return "Next Prayer Focus"
        case .allPrayersToday:
            return "All Prayers Today"
        case .remainingPrayers:
            return "Remaining Prayers"
        }
    }
    
    public var description: String {
        switch self {
        case .nextPrayerFocus:
            return "Highlights the next upcoming prayer with countdown"
        case .allPrayersToday:
            return "Shows all five daily prayers with times"
        case .remainingPrayers:
            return "Shows only prayers that haven't passed today"
        }
    }
}

/// Widget color scheme options
public enum WidgetColorScheme: String, CaseIterable, Codable, Sendable {
    case adaptive = "adaptive"
    case light = "light"
    case dark = "dark"
    case islamic = "islamic"
    
    public var displayName: String {
        switch self {
        case .adaptive:
            return "Adaptive"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .islamic:
            return "Islamic Green"
        }
    }
}

/// Widget size categories
public enum WidgetSize: String, CaseIterable, Codable, Sendable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    public var displayName: String {
        switch self {
        case .small:
            return "Small"
        case .medium:
            return "Medium"
        case .large:
            return "Large"
        }
    }
    
    /// Maximum number of prayers to show for this size
    public var maxPrayersToShow: Int {
        switch self {
        case .small:
            return 1
        case .medium:
            return 3
        case .large:
            return 5
        }
    }
}

/// Widget timeline entry
public struct PrayerWidgetEntry: TimelineEntry {
    public let date: Date
    public let widgetData: WidgetData
    public let configuration: WidgetConfiguration
    public let relevance: TimelineEntryRelevance?
    
    public init(
        date: Date,
        widgetData: WidgetData,
        configuration: WidgetConfiguration = .default,
        relevance: TimelineEntryRelevance? = nil
    ) {
        self.date = date
        self.widgetData = widgetData
        self.configuration = configuration
        self.relevance = relevance
    }
    
    /// Create placeholder entry
    public static func placeholder(configuration: WidgetConfiguration = .default) -> PrayerWidgetEntry {
        return PrayerWidgetEntry(
            date: Date(),
            widgetData: .placeholder,
            configuration: configuration
        )
    }
}

// MARK: - Widget Errors

/// Errors that can occur in widget operations
public enum WidgetError: Error, LocalizedError {
    case dataUnavailable
    case locationUnavailable
    case prayerTimesUnavailable
    case configurationError
    
    public var errorDescription: String? {
        switch self {
        case .dataUnavailable:
            return "Widget data is not available"
        case .locationUnavailable:
            return "Location data is not available for prayer times"
        case .prayerTimesUnavailable:
            return "Prayer times could not be calculated"
        case .configurationError:
            return "Widget configuration error"
        }
    }
}

// MARK: - App Group Constants

/// Constants for App Group sharing between main app and widget
public enum AppGroupConstants {
    public static let groupIdentifier = "group.com.deenbuddy.app"
    public static let widgetDataKey = "DeenBuddy.WidgetData"
    public static let widgetConfigurationKey = "DeenBuddy.WidgetConfiguration"
    public static let lastWidgetUpdateKey = "DeenBuddy.LastWidgetUpdate"
    
    /// Get shared UserDefaults for App Group
    public static var sharedDefaults: UserDefaults? {
        guard let defaults = UserDefaults(suiteName: groupIdentifier) else {
            print("❌ Main App: Failed to create shared UserDefaults for group: \(groupIdentifier)")
            return nil
        }

        // Ensure proper container access without persona issues
        return defaults
    }
}

// MARK: - Widget Data Manager

/// Manager for widget data operations
public class WidgetDataManager {
    
    // MARK: - Singleton
    
    public static let shared = WidgetDataManager()
    
    private init() {}
    
    // MARK: - Data Operations
    
    /// Save widget data to shared container
    public func saveWidgetData(_ data: WidgetData) {
        guard let sharedDefaults = AppGroupConstants.sharedDefaults else {
            print("❌ Failed to access shared UserDefaults for widget data")
            return
        }
        
        do {
            let encodedData = try JSONEncoder().encode(data)
            sharedDefaults.set(encodedData, forKey: AppGroupConstants.widgetDataKey)
            sharedDefaults.set(Date(), forKey: AppGroupConstants.lastWidgetUpdateKey)
            sharedDefaults.synchronize()
            
            print("✅ Widget data saved successfully")
        } catch {
            print("❌ Failed to encode widget data: \(error)")
        }
    }
    
    /// Load widget data from shared container
    public func loadWidgetData() -> WidgetData? {
        guard let sharedDefaults = AppGroupConstants.sharedDefaults else {
            print("❌ Failed to access shared UserDefaults for widget data")
            return nil
        }
        
        guard let data = sharedDefaults.data(forKey: AppGroupConstants.widgetDataKey) else {
            print("⚠️ No widget data found in shared container")
            return nil
        }
        
        do {
            let widgetData = try JSONDecoder().decode(WidgetData.self, from: data)
            return widgetData
        } catch {
            print("❌ Failed to decode widget data: \(error)")
            return nil
        }
    }
    
    /// Save widget configuration
    public func saveWidgetConfiguration(_ configuration: WidgetConfiguration) {
        guard let sharedDefaults = AppGroupConstants.sharedDefaults else { return }
        
        do {
            let encodedData = try JSONEncoder().encode(configuration)
            sharedDefaults.set(encodedData, forKey: AppGroupConstants.widgetConfigurationKey)
            sharedDefaults.synchronize()
        } catch {
            print("❌ Failed to save widget configuration: \(error)")
        }
    }
    
    /// Load widget configuration
    public func loadWidgetConfiguration() -> WidgetConfiguration {
        guard let sharedDefaults = AppGroupConstants.sharedDefaults,
              let data = sharedDefaults.data(forKey: AppGroupConstants.widgetConfigurationKey) else {
            return .default
        }
        
        do {
            return try JSONDecoder().decode(WidgetConfiguration.self, from: data)
        } catch {
            print("❌ Failed to decode widget configuration: \(error)")
            return .default
        }
    }
    
    /// Get last widget update time
    public func getLastUpdateTime() -> Date? {
        return AppGroupConstants.sharedDefaults?.object(forKey: AppGroupConstants.lastWidgetUpdateKey) as? Date
    }
    
    /// Check if widget data needs refresh
    public func needsRefresh() -> Bool {
        guard let lastUpdate = getLastUpdateTime() else { return true }
        return Date().timeIntervalSince(lastUpdate) > 300 // 5 minutes
    }
}
