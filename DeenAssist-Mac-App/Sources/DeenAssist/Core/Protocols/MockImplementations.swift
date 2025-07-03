import Foundation
import CoreLocation

// MARK: - Mock Prayer Calculator

/// Mock implementation of PrayerCalculatorProtocol for testing and development
public final class MockPrayerCalculator: PrayerCalculatorProtocol {
    
    private var cachedPrayerTimes: [String: PrayerTimes] = [:]
    private let calendar = Calendar.current
    
    public init() {}
    
    public func calculatePrayerTimes(for date: Date, config: PrayerCalculationConfig) throws -> PrayerTimes {
        // Generate mock prayer times based on the date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateFormatter.string(from: date)
        
        // Create realistic mock prayer times
        let startOfDay = calendar.startOfDay(for: date)
        
        let fajr = calendar.date(byAdding: .hour, value: 5, to: startOfDay)!
        let dhuhr = calendar.date(byAdding: .hour, value: 12, to: startOfDay)!
        let asr = calendar.date(byAdding: .hour, value: 15, to: startOfDay)!
        let maghrib = calendar.date(byAdding: .hour, value: 18, to: startOfDay)!
        let isha = calendar.date(byAdding: .hour, value: 19, to: startOfDay)!
        
        let prayerTimes = PrayerTimes(
            date: date,
            fajr: fajr,
            dhuhr: dhuhr,
            asr: asr,
            maghrib: maghrib,
            isha: isha,
            calculationMethod: config.calculationMethod.rawValue
        )
        
        // Cache the mock prayer times
        cachedPrayerTimes[dateKey] = prayerTimes
        
        return prayerTimes
    }
    
    public func getCachedPrayerTimes(for date: Date) -> PrayerTimes? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateFormatter.string(from: date)
        
        return cachedPrayerTimes[dateKey]
    }
    
    public func cachePrayerTimes(_ prayerTimes: PrayerTimes) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateFormatter.string(from: prayerTimes.date)
        
        cachedPrayerTimes[dateKey] = prayerTimes
    }
    
    public func getNextPrayer(config: PrayerCalculationConfig) throws -> (name: String, time: Date) {
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        let prayerTimes = try calculatePrayerTimes(for: today, config: config)
        
        let prayers = [
            ("Fajr", prayerTimes.fajr),
            ("Dhuhr", prayerTimes.dhuhr),
            ("Asr", prayerTimes.asr),
            ("Maghrib", prayerTimes.maghrib),
            ("Isha", prayerTimes.isha)
        ]
        
        for (name, time) in prayers {
            if time > now {
                return (name, time)
            }
        }
        
        // Return tomorrow's Fajr if no prayer left today
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let tomorrowPrayerTimes = try calculatePrayerTimes(for: tomorrow, config: config)
        return ("Fajr", tomorrowPrayerTimes.fajr)
    }
    
    public func getCurrentPrayer(config: PrayerCalculationConfig, tolerance: TimeInterval = 300) -> String? {
        // For mock purposes, return nil (not currently in prayer time)
        return nil
    }
}

// MARK: - Mock Data Manager

/// Mock implementation of DataManagerProtocol for testing and development
public final class MockDataManager: DataManagerProtocol {
    
    private var userSettings: UserSettings?
    private var prayerCache: [String: PrayerCacheEntry] = [:]
    private var guideContent: [String: GuideContent] = [:]
    
    public init() {
        // Initialize with default settings
        userSettings = UserSettings(
            calculationMethod: CalculationMethod.muslimWorldLeague.rawValue,
            madhab: Madhab.shafi.rawValue,
            notificationsEnabled: true,
            theme: "system"
        )
        
        // Add some mock guide content
        let mockGuides = [
            GuideContent(
                contentId: "fajr_sunni_guide",
                title: "Fajr Prayer (Sunni)",
                rakahCount: 2,
                isAvailableOffline: true,
                localData: "Mock Fajr guide content".data(using: .utf8),
                videoURL: "https://example.com/fajr_video.m3u8",
                lastUpdatedAt: Date()
            ),
            GuideContent(
                contentId: "dhuhr_sunni_guide",
                title: "Dhuhr Prayer (Sunni)",
                rakahCount: 4,
                isAvailableOffline: false,
                localData: nil,
                videoURL: "https://example.com/dhuhr_video.m3u8",
                lastUpdatedAt: Date()
            )
        ]
        
        for guide in mockGuides {
            guideContent[guide.contentId] = guide
        }
    }
    
    // MARK: - User Settings Operations
    
    public func getUserSettings() -> UserSettings? {
        return userSettings
    }
    
    public func saveUserSettings(_ settings: UserSettings) throws {
        userSettings = settings
    }
    
    public func resetUserSettings() throws {
        userSettings = UserSettings(
            calculationMethod: CalculationMethod.muslimWorldLeague.rawValue,
            madhab: Madhab.shafi.rawValue,
            notificationsEnabled: true,
            theme: "system"
        )
    }
    
    // MARK: - Prayer Cache Operations
    
    public func getPrayerCache(for date: Date) -> PrayerCacheEntry? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateFormatter.string(from: date)
        
        return prayerCache[dateKey]
    }
    
    public func savePrayerCache(_ entry: PrayerCacheEntry) throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateFormatter.string(from: entry.date)
        
        prayerCache[dateKey] = entry
    }
    
    public func deleteOldPrayerCache(before date: Date) throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let keysToDelete = prayerCache.keys.filter { key in
            if let entryDate = dateFormatter.date(from: key) {
                return entryDate < date
            }
            return false
        }
        
        for key in keysToDelete {
            prayerCache.removeValue(forKey: key)
        }
    }
    
    public func getPrayerCacheRange(from startDate: Date, to endDate: Date) -> [PrayerCacheEntry] {
        return prayerCache.values.filter { entry in
            return entry.date >= startDate && entry.date <= endDate
        }.sorted { $0.date < $1.date }
    }
    
    // MARK: - Guide Content Operations
    
    public func getGuideContent(by contentId: String) -> GuideContent? {
        return guideContent[contentId]
    }
    
    public func getAllGuideContent() -> [GuideContent] {
        return Array(guideContent.values).sorted { $0.title < $1.title }
    }
    
    public func saveGuideContent(_ content: GuideContent) throws {
        guideContent[content.contentId] = content
    }
    
    public func deleteGuideContent(by contentId: String) throws {
        guideContent.removeValue(forKey: contentId)
    }
    
    public func getOfflineGuideContent() -> [GuideContent] {
        return guideContent.values.filter { $0.isAvailableOffline }.sorted { $0.title < $1.title }
    }
    
    // MARK: - General Operations
    
    public func saveContext() throws {
        // Mock implementation - no actual persistence needed
    }
    
    public func clearAllData() throws {
        userSettings = nil
        prayerCache.removeAll()
        guideContent.removeAll()
    }
}
