import Foundation
import Combine

/// Service for managing user preferences, bookmarks, and offline content
@MainActor
public class UserPreferencesService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var preferredMadhab: Madhab = .shafi
    @Published public var notificationsEnabled = true
    @Published public var enabledPrayerNotifications: Set<Prayer> = Set(Prayer.allCases)
    @Published public var bookmarkedGuides: Set<String> = []
    @Published public var offlineGuides: Set<String> = []
    @Published public var readingProgress: [String: Double] = [:]
    @Published public var lastReadDates: [String: Date] = [:]
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Settings Keys
    
    private enum SettingsKeys {
        static let preferredMadhab = "DeenAssist.UserPreferences.PreferredMadhab"
        static let notificationsEnabled = "DeenAssist.UserPreferences.NotificationsEnabled"
        static let enabledPrayerNotifications = "DeenAssist.UserPreferences.EnabledPrayerNotifications"
        static let bookmarkedGuides = "DeenAssist.UserPreferences.BookmarkedGuides"
        static let offlineGuides = "DeenAssist.UserPreferences.OfflineGuides"
        static let readingProgress = "DeenAssist.UserPreferences.ReadingProgress"
        static let lastReadDates = "DeenAssist.UserPreferences.LastReadDates"
    }
    
    // MARK: - Initialization
    
    public init() {
        loadPreferences()
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    public func toggleBookmark(for guideId: String) {
        if bookmarkedGuides.contains(guideId) {
            bookmarkedGuides.remove(guideId)
        } else {
            bookmarkedGuides.insert(guideId)
        }
    }
    
    public func isBookmarked(_ guideId: String) -> Bool {
        return bookmarkedGuides.contains(guideId)
    }
    
    public func toggleOfflineAvailability(for guideId: String) {
        if offlineGuides.contains(guideId) {
            offlineGuides.remove(guideId)
        } else {
            offlineGuides.insert(guideId)
        }
    }
    
    public func isAvailableOffline(_ guideId: String) -> Bool {
        return offlineGuides.contains(guideId)
    }
    
    public func updateReadingProgress(for guideId: String, progress: Double) {
        readingProgress[guideId] = progress
        lastReadDates[guideId] = Date()
    }
    
    public func getReadingProgress(for guideId: String) -> Double {
        return readingProgress[guideId] ?? 0.0
    }
    
    public func getLastReadDate(for guideId: String) -> Date? {
        return lastReadDates[guideId]
    }
    
    public func resetToDefaults() {
        preferredMadhab = .shafi
        notificationsEnabled = true
        enabledPrayerNotifications = Set(Prayer.allCases)
        bookmarkedGuides.removeAll()
        offlineGuides.removeAll()
        readingProgress.removeAll()
        lastReadDates.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func loadPreferences() {
        // Load madhab preference
        if let madhabString = userDefaults.string(forKey: SettingsKeys.preferredMadhab),
           let madhab = Madhab(rawValue: madhabString) {
            preferredMadhab = madhab
        }
        
        // Load notification preferences
        notificationsEnabled = userDefaults.bool(forKey: SettingsKeys.notificationsEnabled)
        
        if let prayerNames = userDefaults.array(forKey: SettingsKeys.enabledPrayerNotifications) as? [String] {
            enabledPrayerNotifications = Set(prayerNames.compactMap { Prayer(rawValue: $0) })
        }
        
        // Load bookmarks
        if let bookmarks = userDefaults.array(forKey: SettingsKeys.bookmarkedGuides) as? [String] {
            bookmarkedGuides = Set(bookmarks)
        }
        
        // Load offline guides
        if let offline = userDefaults.array(forKey: SettingsKeys.offlineGuides) as? [String] {
            offlineGuides = Set(offline)
        }
        
        // Load reading progress
        if let progressData = userDefaults.data(forKey: SettingsKeys.readingProgress),
           let progress = try? JSONDecoder().decode([String: Double].self, from: progressData) {
            readingProgress = progress
        }
        
        // Load last read dates
        if let datesData = userDefaults.data(forKey: SettingsKeys.lastReadDates),
           let dates = try? JSONDecoder().decode([String: Date].self, from: datesData) {
            lastReadDates = dates
        }
    }
    
    private func setupObservers() {
        $preferredMadhab
            .sink { [weak self] madhab in
                self?.userDefaults.set(madhab.rawValue, forKey: SettingsKeys.preferredMadhab)
            }
            .store(in: &cancellables)
        
        $notificationsEnabled
            .sink { [weak self] enabled in
                self?.userDefaults.set(enabled, forKey: SettingsKeys.notificationsEnabled)
            }
            .store(in: &cancellables)
        
        $enabledPrayerNotifications
            .sink { [weak self] prayers in
                let prayerNames = prayers.map { $0.rawValue }
                self?.userDefaults.set(prayerNames, forKey: SettingsKeys.enabledPrayerNotifications)
            }
            .store(in: &cancellables)
        
        $bookmarkedGuides
            .sink { [weak self] bookmarks in
                self?.userDefaults.set(Array(bookmarks), forKey: SettingsKeys.bookmarkedGuides)
            }
            .store(in: &cancellables)
        
        $offlineGuides
            .sink { [weak self] offline in
                self?.userDefaults.set(Array(offline), forKey: SettingsKeys.offlineGuides)
            }
            .store(in: &cancellables)
        
        $readingProgress
            .sink { [weak self] progress in
                if let data = try? JSONEncoder().encode(progress) {
                    self?.userDefaults.set(data, forKey: SettingsKeys.readingProgress)
                }
            }
            .store(in: &cancellables)
        
        $lastReadDates
            .sink { [weak self] dates in
                if let data = try? JSONEncoder().encode(dates) {
                    self?.userDefaults.set(data, forKey: SettingsKeys.lastReadDates)
                }
            }
            .store(in: &cancellables)
    }
}
