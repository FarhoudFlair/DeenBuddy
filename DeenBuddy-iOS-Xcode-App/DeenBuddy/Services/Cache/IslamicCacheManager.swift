import Foundation
import CoreData
import CoreLocation

// MARK: - Islamic Cache Manager

/// Comprehensive caching strategy for Islamic app data
/// Implements stale-while-revalidate pattern for sub-400ms performance
@MainActor
public class IslamicCacheManager: ObservableObject {
    
    // MARK: - Cache Types
    
    public enum CacheType {
        case prayerTimes
        case qiblaDirections
        case islamicContent
        case userPreferences
    }
    
    // MARK: - Cache Entry
    
    private struct CacheEntry<T: Codable>: Codable {
        let data: T
        let timestamp: Date
        let expirationDate: Date
        let key: String
    }
    
    // MARK: - Properties
    
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    // Cache configuration
    private let prayerTimeCacheExpiry: TimeInterval = 24 * 60 * 60 // 24 hours
    private let qiblaCacheExpiry: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    private let contentCacheExpiry: TimeInterval = 30 * 24 * 60 * 60 // 30 days
    
    @Published public var cacheStats: CacheStatistics = CacheStatistics()
    
    // MARK: - Initialization
    
    public init() {
        // Create cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("IslamicCache")
        
        createCacheDirectoryIfNeeded()
        loadCacheStatistics()
    }
    
    // MARK: - Public Methods
    
    /// Cache prayer schedule with Islamic calendar awareness
    public func cachePrayerSchedule(_ schedule: PrayerSchedule, for date: Date, location: CLLocation, calculationMethod: CalculationMethod, madhab: Madhab) {
        let key = createPrayerCacheKey(for: date, location: location, calculationMethod: calculationMethod, madhab: madhab)
        let expirationDate = getNextPrayerCalculationUpdate(for: date)

        cacheObject(schedule, key: key, type: .prayerTimes, expirationDate: expirationDate)
        updateCacheStats(type: .prayerTimes, operation: .write)
    }

    /// Get cached prayer schedule with stale-while-revalidate
    public func getCachedPrayerSchedule(for date: Date, location: CLLocation?, calculationMethod: CalculationMethod, madhab: Madhab) -> (schedule: PrayerSchedule?, isStale: Bool) {
        guard let location = location else { return (nil, false) }

        let key = createPrayerCacheKey(for: date, location: location, calculationMethod: calculationMethod, madhab: madhab)
        let result = getCachedObject(PrayerSchedule.self, key: key, type: .prayerTimes)

        updateCacheStats(type: .prayerTimes, operation: .read)
        return (result.content, result.isStale)
    }
    
    /// Cache Qibla direction with location-based expiry
    public func cacheQiblaDirection(_ direction: QiblaDirection, for location: CLLocation) {
        let key = createQiblaCacheKey(for: location)
        let expirationDate = Date().addingTimeInterval(qiblaCacheExpiry)
        
        cacheObject(direction, key: key, type: .qiblaDirections, expirationDate: expirationDate)
        updateCacheStats(type: .qiblaDirections, operation: .write)
    }
    
    /// Get cached Qibla direction
    public func getCachedQiblaDirection(for location: CLLocation, radius: Double = 1000) -> (direction: QiblaDirection?, isStale: Bool) {
        // Check exact location first
        let exactKey = createQiblaCacheKey(for: location)
        let exactResult = getCachedObject(QiblaDirection.self, key: exactKey, type: .qiblaDirections)
        
        if exactResult.content != nil {
            updateCacheStats(type: .qiblaDirections, operation: .read)
            return (exactResult.content, exactResult.isStale)
        }
        
        // Check nearby locations within radius
        let nearbyDirection = findNearbyQiblaDirection(for: location, radius: radius)
        if nearbyDirection != nil {
            updateCacheStats(type: .qiblaDirections, operation: .read)
        }
        
        return (nearbyDirection, false)
    }
    
    /// Cache Islamic content with long expiry
    public func cacheIslamicContent<T: Codable>(_ content: T, key: String) {
        let expirationDate = Date().addingTimeInterval(contentCacheExpiry)
        cacheObject(content, key: key, type: .islamicContent, expirationDate: expirationDate)
        updateCacheStats(type: .islamicContent, operation: .write)
    }
    
    /// Get cached Islamic content
    public func getCachedIslamicContent<T: Codable>(_ type: T.Type, key: String) -> (content: T?, isStale: Bool) {
        let result = getCachedObject(type, key: key, type: .islamicContent)
        updateCacheStats(type: .islamicContent, operation: .read)
        return (result.content, result.isStale)
    }
    
    /// Cache user preferences
    public func cacheUserPreferences<T: Codable>(_ preferences: T, key: String) {
        // User preferences don't expire but can be overwritten
        let expirationDate = Date.distantFuture
        cacheObject(preferences, key: key, type: .userPreferences, expirationDate: expirationDate)
    }
    
    /// Get cached user preferences
    public func getCachedUserPreferences<T: Codable>(_ type: T.Type, key: String) -> T? {
        let result = getCachedObject(type, key: key, type: .userPreferences)
        return result.content
    }
    
    /// Clear expired cache entries
    public func clearExpiredEntries() {
        let now = Date()
        let cacheFiles = getAllCacheFiles()
        
        for file in cacheFiles {
            // Try to load entry metadata to check expiration
            if let data = try? Data(contentsOf: file),
               let metadata = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let expirationTimestamp = metadata["expirationDate"] as? TimeInterval {
                let expirationDate = Date(timeIntervalSince1970: expirationTimestamp)
                if expirationDate < now {
                    try? fileManager.removeItem(at: file)
                    print("🗑️ Removed expired cache entry: \(file.lastPathComponent)")
                }
            }
        }
        
        updateCacheStatistics()
    }
    
    /// Get cache statistics for performance monitoring
    public func getCacheStatistics() -> CacheStatistics {
        return cacheStats
    }
    
    /// Clear all cache data
    public func clearAllCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        createCacheDirectoryIfNeeded()
        cacheStats = CacheStatistics()
        print("🗑️ All Islamic cache data cleared")
    }

    /// Clear only prayer time cache entries (for settings changes)
    public func clearPrayerTimeCache() {
        print("🗑️ Clearing IslamicCacheManager prayer time entries...")

        let cacheFiles = getAllCacheFiles()
        var clearedCount = 0

        for file in cacheFiles {
            let fileName = file.lastPathComponent
            // Check if this is a prayer time cache file
            if fileName.hasPrefix("prayerTimes_") {
                try? fileManager.removeItem(at: file)
                clearedCount += 1
            }
        }

        updateCacheStatistics()
        print("✅ IslamicCacheManager: Cleared \(clearedCount) prayer time cache entries")
    }

    /// Clear prayer time cache for specific calculation method and madhab
    /// This is used when settings change to only invalidate cache for the new method/madhab combination
    public func clearPrayerTimeCache(for calculationMethod: CalculationMethod, madhab: Madhab) {
        print("🗑️ Clearing IslamicCacheManager prayer time entries for method: \(calculationMethod.rawValue), madhab: \(madhab.rawValue)...")

        let methodKey = calculationMethod.rawValue
        let madhabKey = madhab.rawValue
        let targetSuffix = "_\(methodKey)_\(madhabKey).cache"

        let cacheFiles = getAllCacheFiles()
        var clearedCount = 0

        for file in cacheFiles {
            let fileName = file.lastPathComponent
            // Check if this is a prayer time cache file for the specific method/madhab
            if fileName.hasPrefix("prayerTimes_") && fileName.hasSuffix(targetSuffix) {
                try? fileManager.removeItem(at: file)
                clearedCount += 1
            }
        }

        updateCacheStatistics()
        print("✅ IslamicCacheManager: Cleared \(clearedCount) prayer time cache entries for \(methodKey)/\(madhabKey)")
    }
    
    // MARK: - Private Methods
    
    private func cacheObject<T: Codable>(_ object: T, key: String, type: CacheType, expirationDate: Date) {
        let entry = CacheEntry(
            data: object,
            timestamp: Date(),
            expirationDate: expirationDate,
            key: key
        )
        
        let fileName = "\(type.rawValue)_\(key).cache"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        do {
            let data = try JSONEncoder().encode(entry)
            try data.write(to: fileURL)
        } catch {
            print("❌ Failed to cache object: \(error)")
        }
    }
    
    private func getCachedObject<T: Codable>(_ type: T.Type, key: String, type cacheType: CacheType) -> (content: T?, isStale: Bool) {
        let fileName = "\(cacheType.rawValue)_\(key).cache"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        guard let entry: CacheEntry<T> = loadCacheEntry(from: fileURL) else {
            return (nil, false)
        }
        
        let now = Date()
        let isStale = now > entry.expirationDate
        
        return (entry.data, isStale)
    }
    
    private func loadCacheEntry<T: Codable>(from url: URL) -> CacheEntry<T>? {
        guard let data = try? Data(contentsOf: url),
              let entry = try? JSONDecoder().decode(CacheEntry<T>.self, from: data) else {
            return nil
        }
        return entry
    }
    
    private func createPrayerCacheKey(for date: Date, location: CLLocation, calculationMethod: CalculationMethod, madhab: Madhab) -> String {
        let dateString = DateFormatter.cacheKeyFormatter.string(from: date)
        let lat = round(location.coordinate.latitude * 1000) / 1000
        let lon = round(location.coordinate.longitude * 1000) / 1000
        let methodKey = calculationMethod.rawValue
        let madhabKey = madhab.rawValue
        return "prayer_\(dateString)_\(lat)_\(lon)_\(methodKey)_\(madhabKey)"
    }
    
    private func createQiblaCacheKey(for location: CLLocation) -> String {
        let lat = round(location.coordinate.latitude * 1000) / 1000
        let lon = round(location.coordinate.longitude * 1000) / 1000
        return "qibla_\(lat)_\(lon)"
    }
    
    private func getNextPrayerCalculationUpdate(for date: Date) -> Date {
        // Prayer times should be recalculated daily at Fajr time
        let calendar = Calendar.current
        let nextDay = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        return calendar.startOfDay(for: nextDay).addingTimeInterval(4 * 60 * 60) // 4 AM next day
    }
    
    private func findNearbyQiblaDirection(for location: CLLocation, radius: Double) -> QiblaDirection? {
        let cacheFiles = getAllCacheFiles().filter { $0.lastPathComponent.hasPrefix("qiblaDirections_") }
        
        for file in cacheFiles {
            if let entry: CacheEntry<QiblaDirection> = loadCacheEntry(from: file) {
                let cachedLocation = CLLocation(
                    latitude: entry.data.location.latitude,
                    longitude: entry.data.location.longitude
                )
                
                if location.distance(from: cachedLocation) <= radius {
                    return entry.data
                }
            }
        }
        
        return nil
    }
    
    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func getAllCacheFiles() -> [URL] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        return files.filter { $0.pathExtension == "cache" }
    }
    
    private func updateCacheStats(type: CacheType, operation: CacheOperation) {
        switch operation {
        case .read:
            cacheStats.totalReads += 1
        case .write:
            cacheStats.totalWrites += 1
        }
        
        // Update cache size
        updateCacheStatistics()
    }
    
    private func updateCacheStatistics() {
        let files = getAllCacheFiles()
        cacheStats.totalEntries = files.count
        
        let totalSize = files.reduce(0) { total, file in
            let attributes = try? fileManager.attributesOfItem(atPath: file.path)
            let size = attributes?[.size] as? Int64 ?? 0
            return total + Int(size)
        }
        cacheStats.totalSizeBytes = Int64(totalSize)
        
        cacheStats.lastUpdated = Date()
    }
    
    private func loadCacheStatistics() {
        updateCacheStatistics()
    }
}

// MARK: - Supporting Types

public struct CacheStatistics {
    public var totalEntries: Int = 0
    public var totalSizeBytes: Int64 = 0
    public var totalReads: Int = 0
    public var totalWrites: Int = 0
    public var lastUpdated: Date = Date()
    
    public var hitRate: Double {
        let total = totalReads + totalWrites
        return total > 0 ? Double(totalReads) / Double(total) : 0.0
    }
    
    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        return formatter.string(fromByteCount: totalSizeBytes)
    }
}

private enum CacheOperation {
    case read
    case write
}

extension IslamicCacheManager.CacheType {
    var rawValue: String {
        switch self {
        case .prayerTimes: return "prayerTimes"
        case .qiblaDirections: return "qiblaDirections"
        case .islamicContent: return "islamicContent"
        case .userPreferences: return "userPreferences"
        }
    }
}

extension DateFormatter {
    static let cacheKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
