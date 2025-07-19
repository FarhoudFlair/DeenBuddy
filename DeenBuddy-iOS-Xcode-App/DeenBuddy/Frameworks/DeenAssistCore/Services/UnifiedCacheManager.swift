import Foundation
import CoreLocation
import CoreData
import Combine
import UIKit

/// Unified caching system for all DeenBuddy services
/// Replaces individual service caches with a centralized, high-performance solution
@MainActor
public class UnifiedCacheManager: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = UnifiedCacheManager()
    
    // MARK: - Cache Types
    
    public enum CacheType: String, CaseIterable {
        case prayerTimes = "prayer_times"
        case qiblaDirections = "qibla_directions"
        case islamicContent = "islamic_content"
        case userPreferences = "user_preferences"
        case locationData = "location_data"
        case apiResponses = "api_responses"
        case magneticDeclination = "magnetic_declination"
        case calendarEvents = "calendar_events"
        case prayerTracking = "prayer_tracking"
        case temporaryData = "temporary_data"
        
        var defaultExpiry: TimeInterval {
            switch self {
            case .prayerTimes: return 24 * 60 * 60 // 24 hours
            case .qiblaDirections: return 7 * 24 * 60 * 60 // 7 days
            case .islamicContent: return 30 * 24 * 60 * 60 // 30 days
            case .userPreferences: return 365 * 24 * 60 * 60 // 1 year
            case .locationData: return 5 * 60 // 5 minutes
            case .apiResponses: return 60 * 60 // 1 hour
            case .magneticDeclination: return 30 * 24 * 60 * 60 // 30 days
            case .calendarEvents: return 24 * 60 * 60 // 24 hours
            case .prayerTracking: return 7 * 24 * 60 * 60 // 7 days
            case .temporaryData: return 15 * 60 // 15 minutes
            }
        }
        
        var maxSize: Int {
            switch self {
            case .prayerTimes: return 100
            case .qiblaDirections: return 50
            case .islamicContent: return 200
            case .userPreferences: return 500
            case .locationData: return 20
            case .apiResponses: return 100
            case .magneticDeclination: return 50
            case .calendarEvents: return 365
            case .prayerTracking: return 1000
            case .temporaryData: return 50
            }
        }
    }
    
    // MARK: - Cache Entry Protocol

    private protocol CacheEntryProtocol {
        var isExpired: Bool { get }
        var timestamp: Date { get }
        var expirationDate: Date { get }
        var key: String { get }
        var size: Int { get }
        var accessCount: Int { get }
        var lastAccessed: Date { get }
        var cacheType: CacheType { get }
    }

    // MARK: - Cache Entry

    private struct CacheEntry<T: Codable>: Codable, CacheEntryProtocol {
        let data: T
        let timestamp: Date
        let expirationDate: Date
        let key: String
        let type: String // Store as String for Codable conformance
        let size: Int
        let accessCount: Int
        let lastAccessed: Date
        
        init(data: T, timestamp: Date, expirationDate: Date, key: String, type: CacheType, size: Int, accessCount: Int, lastAccessed: Date) {
            self.data = data
            self.timestamp = timestamp
            self.expirationDate = expirationDate
            self.key = key
            self.type = type.rawValue
            self.size = size
            self.accessCount = accessCount
            self.lastAccessed = lastAccessed
        }
        
        var cacheType: CacheType {
            return CacheType(rawValue: type) ?? .temporaryData
        }
        
        var isExpired: Bool {
            return Date() > expirationDate
        }
        
        var age: TimeInterval {
            return Date().timeIntervalSince(timestamp)
        }
    }
    
    // MARK: - Cache Statistics
    
    public struct CacheStatistics: Codable {
        public var totalHits: Int = 0
        public var totalMisses: Int = 0
        public var totalEvictions: Int = 0
        public var totalSize: Int = 0
        public var hitRate: Double {
            let total = totalHits + totalMisses
            return total > 0 ? Double(totalHits) / Double(total) : 0.0
        }
        
        public var typeStats: [String: TypeStatistics] = [:]
        
        // Helper methods for type-safe access
        public mutating func getTypeStats(for type: CacheType) -> TypeStatistics {
            return typeStats[type.rawValue] ?? TypeStatistics()
        }
        
        public mutating func setTypeStats(_ stats: TypeStatistics, for type: CacheType) {
            typeStats[type.rawValue] = stats
        }
        
        public struct TypeStatistics: Codable {
            public var hits: Int = 0
            public var misses: Int = 0
            public var evictions: Int = 0
            public var currentSize: Int = 0
            public var totalSize: Int = 0
            
            public var hitRate: Double {
                let total = hits + misses
                return total > 0 ? Double(hits) / Double(total) : 0.0
            }
        }
    }
    
    // MARK: - Properties
    
    @Published public var statistics: CacheStatistics = CacheStatistics()
    @Published public var isMemoryPressure: Bool = false
    
    private let timerManager = BatteryAwareTimerManager.shared
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    
    private var memoryCache: [String: Any] = [:]
    private var diskCache: [String: Data] = [:]
    private let cacheDirectory: URL
    private var maxMemorySize: Int = 50 * 1024 * 1024 // 50MB
    private let maxDiskSize: Int = 200 * 1024 * 1024 // 200MB
    private var maxEntries: Int = 1000 // Maximum number of cache entries
    
    private let queue = DispatchQueue(label: "UnifiedCacheManager", qos: .utility, attributes: .concurrent)
    private let encodingQueue = DispatchQueue(label: "UnifiedCacheManager.encoding", qos: .utility)
    
    // MARK: - Initialization
    
    private init() {
        // Create cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("UnifiedCache")
        
        createCacheDirectoryIfNeeded()
        loadStatistics()
        setupMemoryPressureMonitoring()
        schedulePeriodicCleanup()
        
        // Initialize type statistics
        for type in CacheType.allCases {
            statistics.typeStats[type.rawValue] = CacheStatistics.TypeStatistics()
        }
    }
    
    // MARK: - Public Methods
    
    /// Store data in cache
    /// - Parameters:
    ///   - data: Data to cache
    ///   - key: Cache key
    ///   - type: Cache type
    ///   - expiry: Custom expiry time (optional)
    public func store<T: Codable>(_ data: T, forKey key: String, type: CacheType, expiry: TimeInterval? = nil) {
        let expirationDate = Date().addingTimeInterval(expiry ?? type.defaultExpiry)
        let size = calculateSize(data)
        
        let entry = CacheEntry(
            data: data,
            timestamp: Date(),
            expirationDate: expirationDate,
            key: key,
            type: type,
            size: size,
            accessCount: 0,
            lastAccessed: Date()
        )
        
        queue.async(flags: .barrier) { [weak self] in
            self?.storeEntry(entry)
        }
    }
    
    /// Retrieve data from cache
    /// - Parameters:
    ///   - key: Cache key
    ///   - type: Cache type
    /// - Returns: Cached data or nil if not found/expired
    public func retrieve<T: Codable>(_ type: T.Type, forKey key: String, cacheType: CacheType) -> T? {
        return queue.sync {
            if let entry = getEntry(forKey: key, type: cacheType) as? CacheEntry<T> {
                if !entry.isExpired {
                    recordHit(for: cacheType)
                    updateAccessStats(for: key, type: cacheType)
                    return entry.data
                } else {
                    // Remove expired entry
                    removeEntry(forKey: key, type: cacheType)
                }
            }
            
            recordMiss(for: cacheType)
            return nil
        }
    }
    
    /// Remove specific cache entry
    /// - Parameters:
    ///   - key: Cache key
    ///   - type: Cache type
    public func remove(forKey key: String, type: CacheType) {
        queue.async(flags: .barrier) { [weak self] in
            self?.removeEntry(forKey: key, type: type)
        }
    }
    
    /// Clear all cache for a specific type
    /// - Parameter type: Cache type to clear
    public func clearCache(for type: CacheType) {
        queue.async(flags: .barrier) { [weak self] in
            self?.clearCacheType(type)
        }
    }
    
    /// Clear all cache
    public func clearAllCache() {
        queue.async(flags: .barrier) { [weak self] in
            self?.clearAllCacheInternal()
        }
    }
    
    /// Check if cache contains key
    /// - Parameters:
    ///   - key: Cache key
    ///   - type: Cache type
    /// - Returns: True if key exists and not expired
    public func contains(key: String, type: CacheType) -> Bool {
        return queue.sync {
            if let entry = getEntry(forKey: key, type: type) {
                return !entry.isExpired
            }
            return false
        }
    }
    
    /// Get cache size for a specific type
    /// - Parameter type: Cache type
    /// - Returns: Size in bytes
    public func getCacheSize(for type: CacheType) -> Int {
        return queue.sync {
            return statistics.typeStats[type.rawValue]?.totalSize ?? 0
        }
    }
    
    /// Preload cache with data
    /// - Parameters:
    ///   - data: Data to preload
    ///   - keys: Array of cache keys
    ///   - type: Cache type
    public func preload<T: Codable>(_ data: [T], keys: [String], type: CacheType) {
        guard data.count == keys.count else { return }
        
        queue.async(flags: .barrier) { [weak self] in
            for (index, item) in data.enumerated() {
                self?.store(item, forKey: keys[index], type: type)
            }
        }
    }
    
    /// Get cache statistics for a specific type
    /// - Parameter type: Cache type
    /// - Returns: Type statistics
    public func getStatistics(for type: CacheType) -> CacheStatistics.TypeStatistics {
        return statistics.typeStats[type.rawValue] ?? CacheStatistics.TypeStatistics()
    }
    
    // MARK: - Private Methods
    
    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func storeEntry<T: Codable>(_ entry: CacheEntry<T>) {
        let fullKey = createFullKey(entry.key, type: entry.cacheType)
        
        // Store in memory cache
        memoryCache[fullKey] = entry
        
        // Store in disk cache if large enough
        if entry.size > 1024 { // 1KB threshold
            encodingQueue.async { [weak self] in
                if let data = try? JSONEncoder().encode(entry) {
                    self?.diskCache[fullKey] = data
                    self?.saveToDisk(data, forKey: fullKey)
                }
            }
        }
        
        // Update statistics
        statistics.typeStats[entry.type]?.totalSize += entry.size
        statistics.totalSize += entry.size
        
        // Check for eviction
        enforceMemoryLimits()
    }
    
    private func getEntry(forKey key: String, type: CacheType) -> CacheEntryProtocol? {
        let fullKey = createFullKey(key, type: type)
        
        // Check memory cache first
        if let entry = memoryCache[fullKey] as? CacheEntryProtocol {
            return entry
        }
        
        // Check disk cache
        if let data = diskCache[fullKey] ?? loadFromDisk(forKey: fullKey) {
            do {
                // Try to decode based on type
                let decoder = JSONDecoder()
                switch type {
                case .prayerTimes:
                    return try decoder.decode(CacheEntry<[PrayerTime]>.self, from: data)
                case .qiblaDirections:
                    return try decoder.decode(CacheEntry<QiblaDirection>.self, from: data)
                case .locationData:
                    return try decoder.decode(CacheEntry<CodableCLLocation>.self, from: data)
                default:
                    return try decoder.decode(CacheEntry<Data>.self, from: data)
                }
            } catch {
                // Remove corrupted entry
                diskCache.removeValue(forKey: fullKey)
                removeDiskFile(forKey: fullKey)
                return nil
            }
        }
        
        return nil
    }
    
    private func removeEntry(forKey key: String, type: CacheType) {
        let fullKey = createFullKey(key, type: type)
        
        // Remove from memory
        if let entry = memoryCache[fullKey] {
            memoryCache.removeValue(forKey: fullKey)
        }
        
        // Remove from disk
        diskCache.removeValue(forKey: fullKey)
        removeDiskFile(forKey: fullKey)
        
        // Update statistics
        statistics.typeStats[type.rawValue]?.evictions += 1
        statistics.totalEvictions += 1
    }
    
    private func clearCacheType(_ type: CacheType) {
        let prefix = type.rawValue + "_"
        
        // Clear memory cache
        memoryCache = memoryCache.filter { !$0.key.hasPrefix(prefix) }
        
        // Clear disk cache
        diskCache = diskCache.filter { !$0.key.hasPrefix(prefix) }
        
        // Clear disk files
        let typeDirectory = cacheDirectory.appendingPathComponent(type.rawValue)
        try? fileManager.removeItem(at: typeDirectory)
        
        // Reset statistics
        statistics.typeStats[type.rawValue] = CacheStatistics.TypeStatistics()
    }
    
    private func clearAllCacheInternal() {
        memoryCache.removeAll()
        diskCache.removeAll()
        
        // Clear disk files
        try? fileManager.removeItem(at: cacheDirectory)
        createCacheDirectoryIfNeeded()
        
        // Reset statistics
        statistics = CacheStatistics()
        for type in CacheType.allCases {
            statistics.typeStats[type.rawValue] = CacheStatistics.TypeStatistics()
        }
    }
    
    private func createFullKey(_ key: String, type: CacheType) -> String {
        return "\(type.rawValue)_\(key)"
    }
    
    private func calculateSize<T: Codable>(_ data: T) -> Int {
        if let encoded = try? JSONEncoder().encode(data) {
            return encoded.count
        }
        return 0
    }
    
    private func recordHit(for type: CacheType) {
        statistics.totalHits += 1
        statistics.typeStats[type.rawValue]?.hits += 1
    }

    private func recordMiss(for type: CacheType) {
        statistics.totalMisses += 1
        statistics.typeStats[type.rawValue]?.misses += 1
    }
    
    private func updateAccessStats(for key: String, type: CacheType) {
        // Update last accessed time in memory cache
        let fullKey = createFullKey(key, type: type)
        let currentTime = Date()
        
        if let entry = memoryCache[fullKey] as? CacheEntryProtocol {
            // Create a new entry with updated access stats
            if let prayerTimesEntry = entry as? CacheEntry<[PrayerTime]> {
                let updatedEntry = CacheEntry(
                    data: prayerTimesEntry.data,
                    timestamp: prayerTimesEntry.timestamp,
                    expirationDate: prayerTimesEntry.expirationDate,
                    key: prayerTimesEntry.key,
                    type: prayerTimesEntry.cacheType,
                    size: prayerTimesEntry.size,
                    accessCount: prayerTimesEntry.accessCount + 1,
                    lastAccessed: currentTime
                )
                memoryCache[fullKey] = updatedEntry
            } else if let qiblaEntry = entry as? CacheEntry<QiblaDirection> {
                let updatedEntry = CacheEntry(
                    data: qiblaEntry.data,
                    timestamp: qiblaEntry.timestamp,
                    expirationDate: qiblaEntry.expirationDate,
                    key: qiblaEntry.key,
                    type: qiblaEntry.cacheType,
                    size: qiblaEntry.size,
                    accessCount: qiblaEntry.accessCount + 1,
                    lastAccessed: currentTime
                )
                memoryCache[fullKey] = updatedEntry
            } else if let locationEntry = entry as? CacheEntry<CodableCLLocation> {
                let updatedEntry = CacheEntry(
                    data: locationEntry.data,
                    timestamp: locationEntry.timestamp,
                    expirationDate: locationEntry.expirationDate,
                    key: locationEntry.key,
                    type: locationEntry.cacheType,
                    size: locationEntry.size,
                    accessCount: locationEntry.accessCount + 1,
                    lastAccessed: currentTime
                )
                memoryCache[fullKey] = updatedEntry
            } else if let dataEntry = entry as? CacheEntry<Data> {
                let updatedEntry = CacheEntry(
                    data: dataEntry.data,
                    timestamp: dataEntry.timestamp,
                    expirationDate: dataEntry.expirationDate,
                    key: dataEntry.key,
                    type: dataEntry.cacheType,
                    size: dataEntry.size,
                    accessCount: dataEntry.accessCount + 1,
                    lastAccessed: currentTime
                )
                memoryCache[fullKey] = updatedEntry
            }
        }
        
        // Also update disk cache if the entry exists there
        if let data = diskCache[fullKey] {
            if let updatedEntry = decodeEntryFromData(data) {
                // Re-encode with updated access time
                if let prayerTimesEntry = updatedEntry as? CacheEntry<[PrayerTime]> {
                    let newEntry = CacheEntry(
                        data: prayerTimesEntry.data,
                        timestamp: prayerTimesEntry.timestamp,
                        expirationDate: prayerTimesEntry.expirationDate,
                        key: prayerTimesEntry.key,
                        type: prayerTimesEntry.cacheType,
                        size: prayerTimesEntry.size,
                        accessCount: prayerTimesEntry.accessCount + 1,
                        lastAccessed: currentTime
                    )
                    if let encodedData = try? JSONEncoder().encode(newEntry) {
                        diskCache[fullKey] = encodedData
                        saveToDisk(encodedData, forKey: fullKey)
                    }
                } else if let qiblaEntry = updatedEntry as? CacheEntry<QiblaDirection> {
                    let newEntry = CacheEntry(
                        data: qiblaEntry.data,
                        timestamp: qiblaEntry.timestamp,
                        expirationDate: qiblaEntry.expirationDate,
                        key: qiblaEntry.key,
                        type: qiblaEntry.cacheType,
                        size: qiblaEntry.size,
                        accessCount: qiblaEntry.accessCount + 1,
                        lastAccessed: currentTime
                    )
                    if let encodedData = try? JSONEncoder().encode(newEntry) {
                        diskCache[fullKey] = encodedData
                        saveToDisk(encodedData, forKey: fullKey)
                    }
                } else if let locationEntry = updatedEntry as? CacheEntry<CodableCLLocation> {
                    let newEntry = CacheEntry(
                        data: locationEntry.data,
                        timestamp: locationEntry.timestamp,
                        expirationDate: locationEntry.expirationDate,
                        key: locationEntry.key,
                        type: locationEntry.cacheType,
                        size: locationEntry.size,
                        accessCount: locationEntry.accessCount + 1,
                        lastAccessed: currentTime
                    )
                    if let encodedData = try? JSONEncoder().encode(newEntry) {
                        diskCache[fullKey] = encodedData
                        saveToDisk(encodedData, forKey: fullKey)
                    }
                } else if let dataEntry = updatedEntry as? CacheEntry<Data> {
                    let newEntry = CacheEntry(
                        data: dataEntry.data,
                        timestamp: dataEntry.timestamp,
                        expirationDate: dataEntry.expirationDate,
                        key: dataEntry.key,
                        type: dataEntry.cacheType,
                        size: dataEntry.size,
                        accessCount: dataEntry.accessCount + 1,
                        lastAccessed: currentTime
                    )
                    if let encodedData = try? JSONEncoder().encode(newEntry) {
                        diskCache[fullKey] = encodedData
                        saveToDisk(encodedData, forKey: fullKey)
                    }
                }
            }
        }
    }
    
    private func enforceMemoryLimits() {
        let memoryKeys = Set(memoryCache.keys)
        let diskKeys = Set(diskCache.keys)
        let uniqueKeys = memoryKeys.union(diskKeys)
        let totalEntries = uniqueKeys.count
        
        // Check if we need to evict based on size, entry count, or memory pressure
        let needsEviction = statistics.totalSize > maxMemorySize || 
                           totalEntries > maxEntries || 
                           isMemoryPressure
        
        if needsEviction {
            evictLeastRecentlyUsed()
        }
    }
    
    private func evictLeastRecentlyUsed() {
        // Collect all cache entries with their access times for proper LRU eviction
        var entriesWithAccessTimes: [(key: String, lastAccessed: Date, size: Int, cacheType: CacheType)] = []
        
        // Collect memory cache entries
        for (key, value) in memoryCache {
            if let entry = value as? CacheEntryProtocol {
                entriesWithAccessTimes.append((
                    key: key,
                    lastAccessed: entry.lastAccessed,
                    size: entry.size,
                    cacheType: entry.cacheType
                ))
            }
        }
        
        // Collect disk cache entries (only if not already in memory)
        for (key, data) in diskCache {
            if memoryCache[key] == nil {
                // Try to decode the entry to get access time
                if let entry = decodeEntryFromData(data) {
                    entriesWithAccessTimes.append((
                        key: key,
                        lastAccessed: entry.lastAccessed,
                        size: entry.size,
                        cacheType: entry.cacheType
                    ))
                }
            }
        }
        
        // Sort by last accessed time (oldest first) for true LRU eviction
        entriesWithAccessTimes.sort { $0.lastAccessed < $1.lastAccessed }
        
        // Calculate how many entries to remove based on both entry count and memory size
        let totalEntries = entriesWithAccessTimes.count
        let currentTotalSize = statistics.totalSize
        
        // Determine eviction criteria
        let needsEntryCountEviction = totalEntries > maxEntries
        let needsMemorySizeEviction = currentTotalSize > maxMemorySize
        
        // Calculate entries to remove for entry count limit
        let entriesToRemoveForCount = needsEntryCountEviction ? totalEntries - maxEntries : 0
        
        // Calculate entries to remove for memory size limit
        var entriesToRemoveForSize = 0
        var cumulativeSize = 0
        if needsMemorySizeEviction {
            for entry in entriesWithAccessTimes {
                cumulativeSize += entry.size
                entriesToRemoveForSize += 1
                if currentTotalSize - cumulativeSize <= maxMemorySize {
                    break
                }
            }
        }
        
        // Use the larger of the two eviction counts to ensure both limits are respected
        // FIXED BUG 1: Ensure entriesToRemove doesn't exceed the actual array size
        let entriesToRemove = min(max(entriesToRemoveForCount, entriesToRemoveForSize), totalEntries)
        
        // Remove the oldest entries
        var totalSizeRemoved = 0
        var typeEvictionCounts: [CacheType: Int] = [:]
        var typeSizeRemoved: [CacheType: Int] = [:]
        
        for i in 0..<entriesToRemove {
            let key = entriesWithAccessTimes[i].key
            let entrySize = entriesWithAccessTimes[i].size
            let cacheType = entriesWithAccessTimes[i].cacheType
            
            memoryCache.removeValue(forKey: key)
            diskCache.removeValue(forKey: key)
            removeDiskFile(forKey: key)
            
            // Update global statistics
            statistics.totalEvictions += 1
            totalSizeRemoved += entrySize
            
            // FIXED BUG 2: Update type-specific statistics
            typeEvictionCounts[cacheType, default: 0] += 1
            typeSizeRemoved[cacheType, default: 0] += entrySize
        }
        
        // Update type-specific statistics
        for (cacheType, evictionCount) in typeEvictionCounts {
            statistics.typeStats[cacheType.rawValue]?.evictions += evictionCount
            statistics.typeStats[cacheType.rawValue]?.currentSize = max(0, 
                (statistics.typeStats[cacheType.rawValue]?.currentSize ?? 0) - (typeSizeRemoved[cacheType] ?? 0))
        }
        
        // Decrement total size for removed entries
        statistics.totalSize = max(0, statistics.totalSize - totalSizeRemoved)
        
        if entriesToRemove > 0 {
            print("🧹 LRU eviction: removed \(entriesToRemove) oldest cache entries, freed \(totalSizeRemoved) bytes")
        }
    }
    
    private func decodeEntryFromData(_ data: Data) -> CacheEntryProtocol? {
        // Try to decode as different entry types to get access time
        let decoder = JSONDecoder()
        
        // Try common types first
        if let entry = try? decoder.decode(CacheEntry<[PrayerTime]>.self, from: data) {
            return entry
        }
        if let entry = try? decoder.decode(CacheEntry<QiblaDirection>.self, from: data) {
            return entry
        }
        if let entry = try? decoder.decode(CacheEntry<CodableCLLocation>.self, from: data) {
            return entry
        }
        if let entry = try? decoder.decode(CacheEntry<Data>.self, from: data) {
            return entry
        }
        
        return nil
    }
    
    private func saveToDisk(_ data: Data, forKey key: String) {
        let filePath = cacheDirectory.appendingPathComponent(key)
        try? data.write(to: filePath)
    }
    
    private func loadFromDisk(forKey key: String) -> Data? {
        let filePath = cacheDirectory.appendingPathComponent(key)
        return try? Data(contentsOf: filePath)
    }
    
    private func removeDiskFile(forKey key: String) {
        let filePath = cacheDirectory.appendingPathComponent(key)
        try? fileManager.removeItem(at: filePath)
    }
    
    private func setupMemoryPressureMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryPressure),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryPressure() {
        isMemoryPressure = true
        print("⚠️ Memory pressure detected - performing aggressive cleanup")

        // PERFORMANCE: Aggressively clean memory cache with metrics
        let initialMemorySize = statistics.totalSize

        queue.async(flags: .barrier) { [weak self] in
            // Clear temporary data first
            self?.clearCacheType(.temporaryData)

            // Evict least recently used items
            self?.evictLeastRecentlyUsed()

            // PERFORMANCE: Clear additional cache types if still under pressure
            self?.clearCacheType(.apiResponses)

            // Force garbage collection
            autoreleasepool { }

            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
                self?.isMemoryPressure = false
                let finalMemorySize = self?.statistics.totalSize ?? 0
                let memoryFreed = initialMemorySize - finalMemorySize
                print("🧹 Memory pressure cleanup completed - freed \(memoryFreed) bytes")
            }
        }
    }
    
    private func schedulePeriodicCleanup() {
        timerManager.scheduleTimer(id: "unified-cache-cleanup", type: .cacheCleanup) { [weak self] in
            self?.performPeriodicCleanup()
        }
    }

    // MARK: - Performance Monitoring

    /// PERFORMANCE: Monitor cache performance and memory usage
    public func getPerformanceMetrics() -> CachePerformanceMetrics {
        return queue.sync {
            let hitRate = statistics.totalHits > 0 ?
                Double(statistics.totalHits) / Double(statistics.totalHits + statistics.totalMisses) : 0.0
            
            // Calculate unique entry count to avoid double-counting entries stored in both memory and disk
            let memoryKeys = Set(memoryCache.keys)
            let diskKeys = Set(diskCache.keys)
            let uniqueKeys = memoryKeys.union(diskKeys)
            let entryCount = uniqueKeys.count
            
            let averageEntrySize = entryCount > 0 ?
                statistics.totalSize / entryCount : 0

            return CachePerformanceMetrics(
                hitRate: hitRate,
                totalSize: statistics.totalSize,
                entryCount: entryCount,
                averageEntrySize: averageEntrySize,
                memoryPressureEvents: isMemoryPressure ? 1 : 0,
                typeStats: statistics.typeStats
            )
        }
    }

    /// PERFORMANCE: Proactive memory management based on device capabilities
    public func optimizeForDevice() {
        let deviceMemory = ProcessInfo.processInfo.physicalMemory
        let availableMemory = deviceMemory / 1024 / 1024 // Convert to MB

        // Adjust cache limits based on device memory
        if availableMemory < 2048 { // Less than 2GB RAM
            maxMemorySize = 50 * 1024 * 1024 // 50MB
            maxEntries = 500
            print("🔧 Optimized cache for low-memory device (50MB limit)")
        } else if availableMemory < 4096 { // Less than 4GB RAM
            maxMemorySize = 100 * 1024 * 1024 // 100MB
            maxEntries = 1000
            print("🔧 Optimized cache for medium-memory device (100MB limit)")
        } else {
            maxMemorySize = 200 * 1024 * 1024 // 200MB
            maxEntries = 2000
            print("🔧 Optimized cache for high-memory device (200MB limit)")
        }

        // Enforce new limits
        enforceMemoryLimits()
    }
    
    private func performPeriodicCleanup() {
        queue.async(flags: .barrier) { [weak self] in
            self?.removeExpiredEntries()
            self?.enforceMemoryLimits()
            self?.saveStatistics()
        }
    }
    
    private func removeExpiredEntries() {
        let currentTime = Date()
        
        // Remove expired memory entries
        memoryCache = memoryCache.filter { key, value in
            // This would check expiration based on entry type
            return true // Simplified
        }
        
        // Remove expired disk entries
        diskCache = diskCache.filter { key, value in
            // This would check expiration based on entry type
            return true // Simplified
        }
    }
    
    private func loadStatistics() {
        if let data = userDefaults.data(forKey: "UnifiedCacheStatistics"),
           let stats = try? JSONDecoder().decode(CacheStatistics.self, from: data) {
            statistics = stats
        }
    }
    
    private func saveStatistics() {
        if let data = try? JSONEncoder().encode(statistics) {
            userDefaults.set(data, forKey: "UnifiedCacheStatistics")
        }
    }
    
    deinit {
        Task { @MainActor in
            timerManager.cancelTimer(id: "unified-cache-cleanup")
        }
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Extensions

extension UnifiedCacheManager {
    /// Convenience method for prayer times
    public func storePrayerTimes(_ times: [PrayerTime], forKey key: String) {
        store(times, forKey: key, type: .prayerTimes)
    }
    
    /// Convenience method for retrieving prayer times
    public func retrievePrayerTimes(forKey key: String) -> [PrayerTime]? {
        return retrieve([PrayerTime].self, forKey: key, cacheType: .prayerTimes)
    }
    
    /// Convenience method for Qibla directions
    public func storeQiblaDirection(_ direction: QiblaDirection, forKey key: String) {
        store(direction, forKey: key, type: .qiblaDirections)
    }
    
    /// Convenience method for retrieving Qibla directions
    public func retrieveQiblaDirection(forKey key: String) -> QiblaDirection? {
        return retrieve(QiblaDirection.self, forKey: key, cacheType: .qiblaDirections)
    }
    
    /// Convenience method for location data
    public func storeLocation(_ location: CLLocation, forKey key: String) {
        let codableLocation = CodableCLLocation(from: location)
        store(codableLocation, forKey: key, type: .locationData)
    }

    /// Convenience method for retrieving location data
    public func retrieveLocation(forKey key: String) -> CLLocation? {
        guard let codableLocation = retrieve(CodableCLLocation.self, forKey: key, cacheType: .locationData) else {
            return nil
        }
        return codableLocation.toCLLocation()
    }
}

// MARK: - Performance Metrics

public struct CachePerformanceMetrics {
    public let hitRate: Double
    public let totalSize: Int
    public let entryCount: Int
    public let averageEntrySize: Int
    public let memoryPressureEvents: Int
    public let typeStats: [String: UnifiedCacheManager.CacheStatistics.TypeStatistics]

    public var description: String {
        return """
        Cache Performance Metrics:
        - Hit Rate: \(String(format: "%.2f%%", hitRate * 100))
        - Total Size: \(totalSize) bytes
        - Entry Count: \(entryCount)
        - Average Entry Size: \(averageEntrySize) bytes
        - Memory Pressure Events: \(memoryPressureEvents)
        """
    }
}