import Foundation
import CoreData

// MARK: - User Settings Model

/// User settings for the application
public struct UserSettings {
    public let id: UUID
    public let calculationMethod: String
    public let madhab: String
    public let notificationsEnabled: Bool
    public let theme: String
    
    public init(id: UUID = UUID(), calculationMethod: String, madhab: String, notificationsEnabled: Bool, theme: String) {
        self.id = id
        self.calculationMethod = calculationMethod
        self.madhab = madhab
        self.notificationsEnabled = notificationsEnabled
        self.theme = theme
    }
}

// MARK: - Prayer Cache Model

/// Cached prayer times for a specific date
public struct PrayerCacheEntry {
    public let date: Date
    public let fajr: Date
    public let dhuhr: Date
    public let asr: Date
    public let maghrib: Date
    public let isha: Date
    public let sourceMethod: String
    
    public init(date: Date, fajr: Date, dhuhr: Date, asr: Date, maghrib: Date, isha: Date, sourceMethod: String) {
        self.date = date
        self.fajr = fajr
        self.dhuhr = dhuhr
        self.asr = asr
        self.maghrib = maghrib
        self.isha = isha
        self.sourceMethod = sourceMethod
    }
}

// MARK: - Guide Content Model

/// Prayer guide content
public struct GuideContent {
    public let contentId: String
    public let title: String
    public let rakahCount: Int16
    public let isAvailableOffline: Bool
    public let localData: Data?
    public let videoURL: String?
    public let lastUpdatedAt: Date
    
    public init(contentId: String, title: String, rakahCount: Int16, isAvailableOffline: Bool, localData: Data?, videoURL: String?, lastUpdatedAt: Date) {
        self.contentId = contentId
        self.title = title
        self.rakahCount = rakahCount
        self.isAvailableOffline = isAvailableOffline
        self.localData = localData
        self.videoURL = videoURL
        self.lastUpdatedAt = lastUpdatedAt
    }
}

// MARK: - Data Manager Protocol

/// Protocol for data persistence operations
/// This allows other engineers to work against mocks while the CoreData implementation is being built
public protocol DataManagerProtocol {
    
    // MARK: - User Settings Operations
    
    /// Get the current user settings
    /// - Returns: User settings if available, nil otherwise
    func getUserSettings() -> UserSettings?
    
    /// Save or update user settings
    /// - Parameter settings: The user settings to save
    /// - Throws: DataManagerError if save operation fails
    func saveUserSettings(_ settings: UserSettings) throws
    
    /// Reset user settings to default values
    /// - Throws: DataManagerError if reset operation fails
    func resetUserSettings() throws
    
    // MARK: - Prayer Cache Operations
    
    /// Get cached prayer times for a specific date
    /// - Parameter date: The date to retrieve cached times for
    /// - Returns: Cached prayer times if available, nil otherwise
    func getPrayerCache(for date: Date) -> PrayerCacheEntry?
    
    /// Save prayer times to cache
    /// - Parameter entry: The prayer cache entry to save
    /// - Throws: DataManagerError if save operation fails
    func savePrayerCache(_ entry: PrayerCacheEntry) throws
    
    /// Delete prayer cache entries older than the specified date
    /// - Parameter date: The cutoff date for deletion
    /// - Throws: DataManagerError if delete operation fails
    func deleteOldPrayerCache(before date: Date) throws
    
    /// Get all cached prayer entries within a date range
    /// - Parameters:
    ///   - startDate: The start date of the range
    ///   - endDate: The end date of the range
    /// - Returns: Array of prayer cache entries within the range
    func getPrayerCacheRange(from startDate: Date, to endDate: Date) -> [PrayerCacheEntry]
    
    // MARK: - Guide Content Operations
    
    /// Get guide content by ID
    /// - Parameter contentId: The unique identifier for the guide content
    /// - Returns: Guide content if available, nil otherwise
    func getGuideContent(by contentId: String) -> GuideContent?
    
    /// Get all available guide content
    /// - Returns: Array of all guide content
    func getAllGuideContent() -> [GuideContent]
    
    /// Save or update guide content
    /// - Parameter content: The guide content to save
    /// - Throws: DataManagerError if save operation fails
    func saveGuideContent(_ content: GuideContent) throws
    
    /// Delete guide content by ID
    /// - Parameter contentId: The unique identifier for the guide content to delete
    /// - Throws: DataManagerError if delete operation fails
    func deleteGuideContent(by contentId: String) throws
    
    /// Get offline-available guide content
    /// - Returns: Array of guide content that is available offline
    func getOfflineGuideContent() -> [GuideContent]
    
    // MARK: - General Operations
    
    /// Save all pending changes to persistent storage
    /// - Throws: DataManagerError if save operation fails
    func saveContext() throws
    
    /// Clear all cached data (useful for testing or data reset)
    /// - Throws: DataManagerError if clear operation fails
    func clearAllData() throws
}

// MARK: - Data Manager Errors

public enum DataManagerError: LocalizedError {
    case saveContextFailed(String)
    case fetchFailed(String)
    case deleteFailed(String)
    case invalidData(String)
    case coreDataNotInitialized
    
    public var errorDescription: String? {
        switch self {
        case .saveContextFailed(let message):
            return "Failed to save data: \(message)"
        case .fetchFailed(let message):
            return "Failed to fetch data: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete data: \(message)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .coreDataNotInitialized:
            return "CoreData stack is not initialized"
        }
    }
}
