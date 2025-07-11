import Foundation
import WidgetKit

/// Service for managing iOS widgets and widget data
@MainActor
public class WidgetService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isWidgetAvailable = false
    @Published public var lastWidgetUpdate: Date?
    
    // MARK: - Widget Data Models
    
    public struct WidgetData: Codable {
        public let nextPrayer: PrayerTime?
        public let timeUntilNextPrayer: TimeInterval?
        public let todaysPrayerTimes: [PrayerTime]
        public let location: String?
        public let lastUpdated: Date
        
        public init(
            nextPrayer: PrayerTime?,
            timeUntilNextPrayer: TimeInterval?,
            todaysPrayerTimes: [PrayerTime],
            location: String?,
            lastUpdated: Date = Date()
        ) {
            self.nextPrayer = nextPrayer
            self.timeUntilNextPrayer = timeUntilNextPrayer
            self.todaysPrayerTimes = todaysPrayerTimes
            self.location = location
            self.lastUpdated = lastUpdated
        }
    }
    
    // MARK: - Private Properties
    
    private let userDefaults: UserDefaults
    private let widgetDataKey = "DeenAssist.WidgetData"
    
    // MARK: - Dependencies
    
    private let prayerTimeService: PrayerTimeService?
    private let locationService: LocationService?
    
    // MARK: - Initialization
    
    public init(
        prayerTimeService: PrayerTimeService? = nil,
        locationService: LocationService? = nil
    ) {
        self.prayerTimeService = prayerTimeService
        self.locationService = locationService
        
        // Use App Group UserDefaults for widget data sharing
        self.userDefaults = UserDefaults(suiteName: "group.com.deenbuddy.app") ?? UserDefaults.standard
        
        checkWidgetAvailability()
    }
    
    // MARK: - Public Methods
    
    public func updateWidgetData() async {
        guard isWidgetAvailable else { return }
        
        do {
            let widgetData = try await createWidgetData()
            saveWidgetData(widgetData)
            reloadAllWidgets()
            
            lastWidgetUpdate = Date()
            print("📱 Widget data updated successfully")
            
        } catch {
            print("❌ Failed to update widget data: \(error)")
        }
    }
    
    public func reloadAllWidgets() {
        guard isWidgetAvailable else { return }
        
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 Reloaded all widget timelines")
    }
    
    public func reloadWidget(ofKind kind: String) {
        guard isWidgetAvailable else { return }
        
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
        print("🔄 Reloaded widget timeline for kind: \(kind)")
    }
    
    public func getWidgetData() -> WidgetData? {
        guard let data = userDefaults.data(forKey: widgetDataKey),
              let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return nil
        }
        
        return widgetData
    }
    
    public func scheduleWidgetUpdates() {
        // Schedule widget updates for prayer times
        guard let prayerTimeService = prayerTimeService else { return }
        
        let prayerTimes = prayerTimeService.todaysPrayerTimes
        
        for prayerTime in prayerTimes {
            // Schedule update 5 minutes before each prayer
            let updateTime = prayerTime.time.addingTimeInterval(-5 * 60)
            
            if updateTime > Date() {
                scheduleWidgetUpdate(at: updateTime)
            }
        }
        
        // Schedule update at midnight for next day's prayer times
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let midnight = calendar.startOfDay(for: tomorrow)
        
        scheduleWidgetUpdate(at: midnight)
    }
    
    // MARK: - Private Methods
    
    private func checkWidgetAvailability() {
        // Check if WidgetKit is available (iOS 14+)
        if #available(iOS 14.0, *) {
            isWidgetAvailable = true
        } else {
            isWidgetAvailable = false
        }
    }
    
    private func createWidgetData() async throws -> WidgetData {
        guard let prayerTimeService = prayerTimeService else {
            throw WidgetError.serviceUnavailable
        }
        
        let todaysPrayerTimes = prayerTimeService.todaysPrayerTimes
        let nextPrayer = prayerTimeService.nextPrayer
        let timeUntilNextPrayer = prayerTimeService.timeUntilNextPrayer
        
        // Get location name if available
        var locationName: String?
        if let locationService = locationService,
           let currentLocation = locationService.currentLocation {
            // Try to get location info from the current location
            do {
                let locationInfo = try await locationService.getLocationInfo(
                    for: LocationCoordinate(
                        latitude: currentLocation.coordinate.latitude,
                        longitude: currentLocation.coordinate.longitude
                    )
                )
                locationName = locationInfo.city ?? "Current Location"
            } catch {
                locationName = "Current Location"
            }
        }
        
        return WidgetData(
            nextPrayer: nextPrayer,
            timeUntilNextPrayer: timeUntilNextPrayer,
            todaysPrayerTimes: todaysPrayerTimes,
            location: locationName
        )
    }
    
    private func saveWidgetData(_ widgetData: WidgetData) {
        do {
            let data = try JSONEncoder().encode(widgetData)
            userDefaults.set(data, forKey: widgetDataKey)
            userDefaults.synchronize()
        } catch {
            print("❌ Failed to save widget data: \(error)")
        }
    }
    
    private func scheduleWidgetUpdate(at date: Date) {
        // In a real implementation, you would use Background Tasks
        // or other scheduling mechanisms to update widgets
        print("📅 Scheduled widget update for \(date)")
    }
}

// MARK: - Widget Error Types

extension WidgetService {
    
    public enum WidgetError: Error, LocalizedError {
        case serviceUnavailable
        case dataCreationFailed
        case encodingFailed
        
        public var errorDescription: String? {
            switch self {
            case .serviceUnavailable:
                return "Prayer time service is not available"
            case .dataCreationFailed:
                return "Failed to create widget data"
            case .encodingFailed:
                return "Failed to encode widget data"
            }
        }
    }
}

// MARK: - Widget Configuration

extension WidgetService {
    
    /// Configuration for different widget types
    public enum WidgetKind: String, CaseIterable {
        case nextPrayer = "NextPrayerWidget"
        case todaysPrayerTimes = "TodaysPrayerTimesWidget"
        case prayerCountdown = "PrayerCountdownWidget"
        
        public var displayName: String {
            switch self {
            case .nextPrayer:
                return "Next Prayer"
            case .todaysPrayerTimes:
                return "Today's Prayer Times"
            case .prayerCountdown:
                return "Prayer Countdown"
            }
        }
        
        public var description: String {
            switch self {
            case .nextPrayer:
                return "Shows the next upcoming prayer time"
            case .todaysPrayerTimes:
                return "Shows all prayer times for today"
            case .prayerCountdown:
                return "Shows countdown to next prayer"
            }
        }
    }
    
    public func getSupportedWidgetKinds() -> [WidgetKind] {
        return WidgetKind.allCases
    }
    
    public func reloadWidget(_ kind: WidgetKind) {
        reloadWidget(ofKind: kind.rawValue)
    }
}
