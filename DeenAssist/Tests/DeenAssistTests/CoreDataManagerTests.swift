import XCTest
import CoreData
@testable import DeenAssist

final class CoreDataManagerTests: XCTestCase {
    
    var dataManager: CoreDataManager!
    
    override func setUpWithError() throws {
        // Use in-memory store for testing
        dataManager = CoreDataManager.shared
        try dataManager.clearAllData()
    }
    
    override func tearDownWithError() throws {
        try dataManager.clearAllData()
        dataManager = nil
    }
    
    // MARK: - User Settings Tests
    
    func testSaveAndRetrieveUserSettings() throws {
        let settings = UserSettings(
            calculationMethod: CalculationMethod.egyptian.rawValue,
            madhab: Madhab.hanafi.rawValue,
            notificationsEnabled: false,
            theme: "dark"
        )
        
        // Save settings
        try dataManager.saveUserSettings(settings)
        
        // Retrieve settings
        let retrievedSettings = dataManager.getUserSettings()
        
        XCTAssertNotNil(retrievedSettings, "User settings should be retrievable")
        XCTAssertEqual(retrievedSettings?.calculationMethod, settings.calculationMethod)
        XCTAssertEqual(retrievedSettings?.madhab, settings.madhab)
        XCTAssertEqual(retrievedSettings?.notificationsEnabled, settings.notificationsEnabled)
        XCTAssertEqual(retrievedSettings?.theme, settings.theme)
    }
    
    func testUpdateUserSettings() throws {
        // Save initial settings
        let initialSettings = UserSettings(
            calculationMethod: CalculationMethod.muslimWorldLeague.rawValue,
            madhab: Madhab.shafi.rawValue,
            notificationsEnabled: true,
            theme: "light"
        )
        try dataManager.saveUserSettings(initialSettings)
        
        // Update settings
        let updatedSettings = UserSettings(
            id: initialSettings.id,
            calculationMethod: CalculationMethod.karachi.rawValue,
            madhab: Madhab.hanafi.rawValue,
            notificationsEnabled: false,
            theme: "dark"
        )
        try dataManager.saveUserSettings(updatedSettings)
        
        // Verify update
        let retrievedSettings = dataManager.getUserSettings()
        XCTAssertEqual(retrievedSettings?.calculationMethod, updatedSettings.calculationMethod)
        XCTAssertEqual(retrievedSettings?.madhab, updatedSettings.madhab)
        XCTAssertEqual(retrievedSettings?.notificationsEnabled, updatedSettings.notificationsEnabled)
        XCTAssertEqual(retrievedSettings?.theme, updatedSettings.theme)
    }
    
    func testResetUserSettings() throws {
        // Save custom settings
        let customSettings = UserSettings(
            calculationMethod: CalculationMethod.egyptian.rawValue,
            madhab: Madhab.hanafi.rawValue,
            notificationsEnabled: false,
            theme: "dark"
        )
        try dataManager.saveUserSettings(customSettings)
        
        // Reset to defaults
        try dataManager.resetUserSettings()
        
        // Verify reset
        let resetSettings = dataManager.getUserSettings()
        XCTAssertNotNil(resetSettings)
        XCTAssertEqual(resetSettings?.calculationMethod, CalculationMethod.muslimWorldLeague.rawValue)
        XCTAssertEqual(resetSettings?.madhab, Madhab.shafi.rawValue)
        XCTAssertEqual(resetSettings?.notificationsEnabled, true)
        XCTAssertEqual(resetSettings?.theme, "system")
    }
    
    // MARK: - Prayer Cache Tests
    
    func testSaveAndRetrievePrayerCache() throws {
        let testDate = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 15))!
        let cacheEntry = PrayerCacheEntry(
            date: testDate,
            fajr: Calendar.current.date(byAdding: .hour, value: 5, to: Calendar.current.startOfDay(for: testDate))!,
            dhuhr: Calendar.current.date(byAdding: .hour, value: 12, to: Calendar.current.startOfDay(for: testDate))!,
            asr: Calendar.current.date(byAdding: .hour, value: 15, to: Calendar.current.startOfDay(for: testDate))!,
            maghrib: Calendar.current.date(byAdding: .hour, value: 18, to: Calendar.current.startOfDay(for: testDate))!,
            isha: Calendar.current.date(byAdding: .hour, value: 19, to: Calendar.current.startOfDay(for: testDate))!,
            sourceMethod: CalculationMethod.muslimWorldLeague.rawValue
        )
        
        // Save cache entry
        try dataManager.savePrayerCache(cacheEntry)
        
        // Retrieve cache entry
        let retrievedEntry = dataManager.getPrayerCache(for: testDate)
        
        XCTAssertNotNil(retrievedEntry, "Prayer cache should be retrievable")
        XCTAssertEqual(retrievedEntry?.fajr, cacheEntry.fajr)
        XCTAssertEqual(retrievedEntry?.dhuhr, cacheEntry.dhuhr)
        XCTAssertEqual(retrievedEntry?.asr, cacheEntry.asr)
        XCTAssertEqual(retrievedEntry?.maghrib, cacheEntry.maghrib)
        XCTAssertEqual(retrievedEntry?.isha, cacheEntry.isha)
        XCTAssertEqual(retrievedEntry?.sourceMethod, cacheEntry.sourceMethod)
    }
    
    func testPrayerCacheRange() throws {
        let calendar = Calendar.current
        let baseDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 15))!
        
        // Create multiple cache entries
        for i in 0..<5 {
            let date = calendar.date(byAdding: .day, value: i, to: baseDate)!
            let cacheEntry = PrayerCacheEntry(
                date: date,
                fajr: calendar.date(byAdding: .hour, value: 5, to: calendar.startOfDay(for: date))!,
                dhuhr: calendar.date(byAdding: .hour, value: 12, to: calendar.startOfDay(for: date))!,
                asr: calendar.date(byAdding: .hour, value: 15, to: calendar.startOfDay(for: date))!,
                maghrib: calendar.date(byAdding: .hour, value: 18, to: calendar.startOfDay(for: date))!,
                isha: calendar.date(byAdding: .hour, value: 19, to: calendar.startOfDay(for: date))!,
                sourceMethod: CalculationMethod.muslimWorldLeague.rawValue
            )
            try dataManager.savePrayerCache(cacheEntry)
        }
        
        // Retrieve range
        let endDate = calendar.date(byAdding: .day, value: 4, to: baseDate)!
        let rangeEntries = dataManager.getPrayerCacheRange(from: baseDate, to: endDate)
        
        XCTAssertEqual(rangeEntries.count, 5, "Should retrieve all 5 cache entries")
        
        // Verify entries are sorted by date
        for i in 1..<rangeEntries.count {
            XCTAssertLessThanOrEqual(rangeEntries[i-1].date, rangeEntries[i].date, "Entries should be sorted by date")
        }
    }
    
    func testDeleteOldPrayerCache() throws {
        let calendar = Calendar.current
        let oldDate = calendar.date(byAdding: .day, value: -40, to: Date())!
        let recentDate = calendar.date(byAdding: .day, value: -5, to: Date())!
        
        // Create old and recent cache entries
        let oldEntry = PrayerCacheEntry(
            date: oldDate,
            fajr: calendar.date(byAdding: .hour, value: 5, to: calendar.startOfDay(for: oldDate))!,
            dhuhr: calendar.date(byAdding: .hour, value: 12, to: calendar.startOfDay(for: oldDate))!,
            asr: calendar.date(byAdding: .hour, value: 15, to: calendar.startOfDay(for: oldDate))!,
            maghrib: calendar.date(byAdding: .hour, value: 18, to: calendar.startOfDay(for: oldDate))!,
            isha: calendar.date(byAdding: .hour, value: 19, to: calendar.startOfDay(for: oldDate))!,
            sourceMethod: CalculationMethod.muslimWorldLeague.rawValue
        )
        
        let recentEntry = PrayerCacheEntry(
            date: recentDate,
            fajr: calendar.date(byAdding: .hour, value: 5, to: calendar.startOfDay(for: recentDate))!,
            dhuhr: calendar.date(byAdding: .hour, value: 12, to: calendar.startOfDay(for: recentDate))!,
            asr: calendar.date(byAdding: .hour, value: 15, to: calendar.startOfDay(for: recentDate))!,
            maghrib: calendar.date(byAdding: .hour, value: 18, to: calendar.startOfDay(for: recentDate))!,
            isha: calendar.date(byAdding: .hour, value: 19, to: calendar.startOfDay(for: recentDate))!,
            sourceMethod: CalculationMethod.muslimWorldLeague.rawValue
        )
        
        try dataManager.savePrayerCache(oldEntry)
        try dataManager.savePrayerCache(recentEntry)
        
        // Delete old entries (older than 30 days)
        let cutoffDate = calendar.date(byAdding: .day, value: -30, to: Date())!
        try dataManager.deleteOldPrayerCache(before: cutoffDate)
        
        // Verify old entry is deleted and recent entry remains
        XCTAssertNil(dataManager.getPrayerCache(for: oldDate), "Old cache entry should be deleted")
        XCTAssertNotNil(dataManager.getPrayerCache(for: recentDate), "Recent cache entry should remain")
    }
    
    // MARK: - Guide Content Tests
    
    func testSaveAndRetrieveGuideContent() throws {
        let guideContent = GuideContent(
            contentId: "test_guide",
            title: "Test Prayer Guide",
            rakahCount: 4,
            isAvailableOffline: true,
            localData: "Test guide content".data(using: .utf8),
            videoURL: "https://example.com/video.m3u8",
            lastUpdatedAt: Date()
        )
        
        // Save guide content
        try dataManager.saveGuideContent(guideContent)
        
        // Retrieve guide content
        let retrievedContent = dataManager.getGuideContent(by: "test_guide")
        
        XCTAssertNotNil(retrievedContent, "Guide content should be retrievable")
        XCTAssertEqual(retrievedContent?.contentId, guideContent.contentId)
        XCTAssertEqual(retrievedContent?.title, guideContent.title)
        XCTAssertEqual(retrievedContent?.rakahCount, guideContent.rakahCount)
        XCTAssertEqual(retrievedContent?.isAvailableOffline, guideContent.isAvailableOffline)
        XCTAssertEqual(retrievedContent?.localData, guideContent.localData)
        XCTAssertEqual(retrievedContent?.videoURL, guideContent.videoURL)
    }
    
    func testGetOfflineGuideContent() throws {
        let onlineGuide = GuideContent(
            contentId: "online_guide",
            title: "Online Guide",
            rakahCount: 2,
            isAvailableOffline: false,
            localData: nil,
            videoURL: "https://example.com/online.m3u8",
            lastUpdatedAt: Date()
        )
        
        let offlineGuide = GuideContent(
            contentId: "offline_guide",
            title: "Offline Guide",
            rakahCount: 4,
            isAvailableOffline: true,
            localData: "Offline content".data(using: .utf8),
            videoURL: nil,
            lastUpdatedAt: Date()
        )
        
        try dataManager.saveGuideContent(onlineGuide)
        try dataManager.saveGuideContent(offlineGuide)
        
        let offlineContent = dataManager.getOfflineGuideContent()
        
        XCTAssertEqual(offlineContent.count, 1, "Should return only offline content")
        XCTAssertEqual(offlineContent.first?.contentId, "offline_guide")
    }
    
    func testDeleteGuideContent() throws {
        let guideContent = GuideContent(
            contentId: "deletable_guide",
            title: "Deletable Guide",
            rakahCount: 2,
            isAvailableOffline: true,
            localData: "Content to delete".data(using: .utf8),
            videoURL: nil,
            lastUpdatedAt: Date()
        )
        
        // Save and verify
        try dataManager.saveGuideContent(guideContent)
        XCTAssertNotNil(dataManager.getGuideContent(by: "deletable_guide"))
        
        // Delete and verify
        try dataManager.deleteGuideContent(by: "deletable_guide")
        XCTAssertNil(dataManager.getGuideContent(by: "deletable_guide"))
    }
    
    // MARK: - General Operations Tests
    
    func testClearAllData() throws {
        // Add some data
        let settings = UserSettings(
            calculationMethod: CalculationMethod.egyptian.rawValue,
            madhab: Madhab.hanafi.rawValue,
            notificationsEnabled: true,
            theme: "dark"
        )
        try dataManager.saveUserSettings(settings)
        
        let cacheEntry = PrayerCacheEntry(
            date: Date(),
            fajr: Date(),
            dhuhr: Date(),
            asr: Date(),
            maghrib: Date(),
            isha: Date(),
            sourceMethod: CalculationMethod.muslimWorldLeague.rawValue
        )
        try dataManager.savePrayerCache(cacheEntry)
        
        let guideContent = GuideContent(
            contentId: "test_guide",
            title: "Test Guide",
            rakahCount: 2,
            isAvailableOffline: true,
            localData: "Test".data(using: .utf8),
            videoURL: nil,
            lastUpdatedAt: Date()
        )
        try dataManager.saveGuideContent(guideContent)
        
        // Clear all data
        try dataManager.clearAllData()
        
        // Verify all data is cleared
        XCTAssertNil(dataManager.getUserSettings())
        XCTAssertNil(dataManager.getPrayerCache(for: Date()))
        XCTAssertNil(dataManager.getGuideContent(by: "test_guide"))
        XCTAssertTrue(dataManager.getAllGuideContent().isEmpty)
    }
}
