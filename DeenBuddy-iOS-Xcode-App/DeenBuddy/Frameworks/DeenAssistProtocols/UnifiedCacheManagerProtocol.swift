import Foundation
import CoreLocation

/// Protocol for unified cache management across all DeenBuddy services
public protocol UnifiedCacheManagerProtocol {
    
    /// Store data in cache
    /// - Parameters:
    ///   - data: Data to cache
    ///   - key: Cache key
    ///   - type: Cache type
    ///   - expiry: Custom expiry time (optional)
    func store<T: Codable>(_ data: T, forKey key: String, type: UnifiedCacheManager.CacheType, expiry: TimeInterval?)
    
    /// Retrieve data from cache
    /// - Parameters:
    ///   - type: Type of data to retrieve
    ///   - key: Cache key
    ///   - cacheType: Cache type
    /// - Returns: Cached data or nil if not found/expired
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String, cacheType: UnifiedCacheManager.CacheType) -> T?
    
    /// Remove specific cache entry
    /// - Parameters:
    ///   - key: Cache key
    ///   - type: Cache type
    func remove(forKey key: String, type: UnifiedCacheManager.CacheType)
    
    /// Clear all cache for a specific type
    /// - Parameter type: Cache type to clear
    func clearCache(for type: UnifiedCacheManager.CacheType)
    
    /// Clear all cache
    func clearAllCache()
    
    /// Check if cache contains key
    /// - Parameters:
    ///   - key: Cache key
    ///   - type: Cache type
    /// - Returns: True if key exists and not expired
    func contains(key: String, type: UnifiedCacheManager.CacheType) -> Bool
    
    /// Get cache size for a specific type
    /// - Parameter type: Cache type
    /// - Returns: Size in bytes
    func getCacheSize(for type: UnifiedCacheManager.CacheType) -> Int
    
    /// Get cache statistics for a specific type
    /// - Parameter type: Cache type
    /// - Returns: Type statistics
    func getStatistics(for type: UnifiedCacheManager.CacheType) -> UnifiedCacheManager.CacheStatistics.TypeStatistics
}

// MARK: - Convenience Methods Protocol

/// Extended protocol with convenience methods for common cache operations
public protocol UnifiedCacheConvenienceProtocol: UnifiedCacheManagerProtocol {
    
    /// Store prayer times
    func storePrayerTimes(_ times: [PrayerTime], forKey key: String)
    
    /// Retrieve prayer times
    func retrievePrayerTimes(forKey key: String) -> [PrayerTime]?
    
    /// Store Qibla direction
    func storeQiblaDirection(_ direction: QiblaDirection, forKey key: String)
    
    /// Retrieve Qibla direction
    func retrieveQiblaDirection(forKey key: String) -> QiblaDirection?
    
    /// Store location data
    func storeLocation(_ location: CLLocation, forKey key: String)
    
    /// Retrieve location data
    func retrieveLocation(forKey key: String) -> CLLocation?
}

// MARK: - Mock Implementation for Testing

public class MockUnifiedCacheManager: UnifiedCacheConvenienceProtocol {
    
    private var storage: [String: Any] = [:]
    
    public init() {}
    
    public func store<T: Codable>(_ data: T, forKey key: String, type: UnifiedCacheManager.CacheType, expiry: TimeInterval? = nil) {
        storage["\(type.rawValue)_\(key)"] = data
    }
    
    public func retrieve<T: Codable>(_ type: T.Type, forKey key: String, cacheType: UnifiedCacheManager.CacheType) -> T? {
        return storage["\(cacheType.rawValue)_\(key)"] as? T
    }
    
    public func remove(forKey key: String, type: UnifiedCacheManager.CacheType) {
        storage.removeValue(forKey: "\(type.rawValue)_\(key)")
    }
    
    public func clearCache(for type: UnifiedCacheManager.CacheType) {
        let prefix = type.rawValue + "_"
        storage = storage.filter { !$0.key.hasPrefix(prefix) }
    }
    
    public func clearAllCache() {
        storage.removeAll()
    }
    
    public func contains(key: String, type: UnifiedCacheManager.CacheType) -> Bool {
        return storage["\(type.rawValue)_\(key)"] != nil
    }
    
    public func getCacheSize(for type: UnifiedCacheManager.CacheType) -> Int {
        return 0 // Simplified for mock
    }
    
    public func getStatistics(for type: UnifiedCacheManager.CacheType) -> UnifiedCacheManager.CacheStatistics.TypeStatistics {
        return UnifiedCacheManager.CacheStatistics.TypeStatistics()
    }
    
    // MARK: - Convenience Methods
    
    public func storePrayerTimes(_ times: [PrayerTime], forKey key: String) {
        store(times, forKey: key, type: .prayerTimes)
    }
    
    public func retrievePrayerTimes(forKey key: String) -> [PrayerTime]? {
        return retrieve([PrayerTime].self, forKey: key, cacheType: .prayerTimes)
    }
    
    public func storeQiblaDirection(_ direction: QiblaDirection, forKey key: String) {
        store(direction, forKey: key, type: .qiblaDirections)
    }
    
    public func retrieveQiblaDirection(forKey key: String) -> QiblaDirection? {
        return retrieve(QiblaDirection.self, forKey: key, cacheType: .qiblaDirections)
    }
    
    public func storeLocation(_ location: CLLocation, forKey key: String) {
        store(location, forKey: key, type: .locationData)
    }
    
    public func retrieveLocation(forKey key: String) -> CLLocation? {
        return retrieve(CLLocation.self, forKey: key, cacheType: .locationData)
    }
}