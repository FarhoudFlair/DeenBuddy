import Foundation

// MARK: - API Cache Implementation

public class APICache: APICacheProtocol {
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let queue = DispatchQueue(label: "APICache", attributes: .concurrent)
    
    // MARK: - Cache Configuration
    
    private let prayerTimesExpirationTime: TimeInterval = 86400 // 24 hours
    private let qiblaDirectionExpirationTime: TimeInterval = 2592000 // 30 days
    private let maxCacheSize: Int64 = 50 * 1024 * 1024 // 50 MB
    
    // MARK: - Cache Keys
    
    private enum CacheKeys {
        static let prayerTimesPrefix = "DeenAssist.PrayerTimes."
        static let qiblaDirectionPrefix = "DeenAssist.QiblaDirection."
        static let cacheMetadata = "DeenAssist.CacheMetadata"
    }
    
    // MARK: - Initialization
    
    public init() {
        // Create cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("DeenAssistCache")
        
        createCacheDirectoryIfNeeded()
        schedulePeriodicCleanup()
    }
    
    // MARK: - Protocol Implementation
    
    public func cachePrayerTimes(_ prayerTimes: PrayerTimes, for date: Date, location: LocationCoordinate) {
        queue.async(flags: .barrier) {
            let key = self.prayerTimesCacheKey(for: date, location: location)
            let cacheEntry = CacheEntry(
                data: prayerTimes,
                timestamp: Date(),
                expirationTime: self.prayerTimesExpirationTime
            )
            
            self.storeCacheEntry(cacheEntry, forKey: key)
        }
    }
    
    public func getCachedPrayerTimes(for date: Date, location: LocationCoordinate) -> PrayerTimes? {
        return queue.sync {
            let key = prayerTimesCacheKey(for: date, location: location)
            
            guard let cacheEntry: CacheEntry<PrayerTimes> = getCacheEntry(forKey: key),
                  !cacheEntry.isExpired else {
                return nil
            }
            
            return cacheEntry.data
        }
    }
    
    public func cacheQiblaDirection(_ direction: QiblaDirection, for location: LocationCoordinate) {
        queue.async(flags: .barrier) {
            let key = self.qiblaDirectionCacheKey(for: location)
            let cacheEntry = CacheEntry(
                data: direction,
                timestamp: Date(),
                expirationTime: self.qiblaDirectionExpirationTime
            )
            
            self.storeCacheEntry(cacheEntry, forKey: key)
        }
    }
    
    public func getCachedQiblaDirection(for location: LocationCoordinate) -> QiblaDirection? {
        return queue.sync {
            let key = qiblaDirectionCacheKey(for: location)
            
            guard let cacheEntry: CacheEntry<QiblaDirection> = getCacheEntry(forKey: key),
                  !cacheEntry.isExpired else {
                return nil
            }
            
            return cacheEntry.data
        }
    }
    
    public func clearExpiredCache() {
        queue.async(flags: .barrier) {
            self.performCacheCleanup()
        }
    }
    
    public func clearAllCache() {
        queue.async(flags: .barrier) {
            // Clear UserDefaults cache
            let keys = self.userDefaults.dictionaryRepresentation().keys
            for key in keys {
                if key.hasPrefix(CacheKeys.prayerTimesPrefix) || 
                   key.hasPrefix(CacheKeys.qiblaDirectionPrefix) {
                    self.userDefaults.removeObject(forKey: key)
                }
            }
            
            // Clear file cache
            try? self.fileManager.removeItem(at: self.cacheDirectory)
            self.createCacheDirectoryIfNeeded()
            
            // Clear metadata
            self.userDefaults.removeObject(forKey: CacheKeys.cacheMetadata)
        }
    }
    
    public func getCacheSize() -> Int64 {
        return queue.sync {
            calculateCacheSize()
        }
    }
    
    // MARK: - Private Methods
    
    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func prayerTimesCacheKey(for date: Date, location: LocationCoordinate) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        return "\(CacheKeys.prayerTimesPrefix)\(dateString)_\(location.latitude)_\(location.longitude)"
    }
    
    private func qiblaDirectionCacheKey(for location: LocationCoordinate) -> String {
        // Round coordinates to reduce cache fragmentation
        let roundedLat = round(location.latitude * 100) / 100
        let roundedLon = round(location.longitude * 100) / 100
        
        return "\(CacheKeys.qiblaDirectionPrefix)\(roundedLat)_\(roundedLon)"
    }
    
    private func storeCacheEntry<T: Codable>(_ entry: CacheEntry<T>, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(entry)
            
            // Store in UserDefaults for small data
            if data.count < 1024 { // 1KB threshold
                userDefaults.set(data, forKey: key)
            } else {
                // Store in file system for larger data
                let fileURL = cacheDirectory.appendingPathComponent(key.replacingOccurrences(of: ".", with: "_"))
                try data.write(to: fileURL)
            }
            
            updateCacheMetadata(key: key, size: Int64(data.count))
            
        } catch {
            print("Failed to cache entry for key \(key): \(error)")
        }
    }
    
    private func getCacheEntry<T: Codable>(forKey key: String) -> CacheEntry<T>? {
        // Try UserDefaults first
        if let data = userDefaults.data(forKey: key) {
            return try? JSONDecoder().decode(CacheEntry<T>.self, from: data)
        }
        
        // Try file system
        let fileURL = cacheDirectory.appendingPathComponent(key.replacingOccurrences(of: ".", with: "_"))
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        
        return try? JSONDecoder().decode(CacheEntry<T>.self, from: data)
    }
    
    private func updateCacheMetadata(key: String, size: Int64) {
        var metadata = getCacheMetadata()
        metadata[key] = CacheMetadataEntry(size: size, timestamp: Date())
        
        if let data = try? JSONEncoder().encode(metadata) {
            userDefaults.set(data, forKey: CacheKeys.cacheMetadata)
        }
    }
    
    private func getCacheMetadata() -> [String: CacheMetadataEntry] {
        guard let data = userDefaults.data(forKey: CacheKeys.cacheMetadata),
              let metadata = try? JSONDecoder().decode([String: CacheMetadataEntry].self, from: data) else {
            return [:]
        }
        
        return metadata
    }
    
    private func performCacheCleanup() {
        let metadata = getCacheMetadata()
        var updatedMetadata = metadata
        
        // Remove expired entries
        for (key, entry) in metadata {
            let expirationTime: TimeInterval
            
            if key.hasPrefix(CacheKeys.prayerTimesPrefix) {
                expirationTime = prayerTimesExpirationTime
            } else if key.hasPrefix(CacheKeys.qiblaDirectionPrefix) {
                expirationTime = qiblaDirectionExpirationTime
            } else {
                continue
            }
            
            if Date().timeIntervalSince(entry.timestamp) > expirationTime {
                // Remove from storage
                userDefaults.removeObject(forKey: key)
                
                let fileURL = cacheDirectory.appendingPathComponent(key.replacingOccurrences(of: ".", with: "_"))
                try? fileManager.removeItem(at: fileURL)
                
                // Remove from metadata
                updatedMetadata.removeValue(forKey: key)
            }
        }
        
        // Check cache size and remove oldest entries if needed
        let totalSize = updatedMetadata.values.reduce(0) { $0 + $1.size }
        
        if totalSize > maxCacheSize {
            let sortedEntries = updatedMetadata.sorted { $0.value.timestamp < $1.value.timestamp }
            var currentSize = totalSize
            
            for (key, entry) in sortedEntries {
                if currentSize <= maxCacheSize {
                    break
                }
                
                // Remove entry
                userDefaults.removeObject(forKey: key)
                
                let fileURL = cacheDirectory.appendingPathComponent(key.replacingOccurrences(of: ".", with: "_"))
                try? fileManager.removeItem(at: fileURL)
                
                updatedMetadata.removeValue(forKey: key)
                currentSize -= entry.size
            }
        }
        
        // Update metadata
        if let data = try? JSONEncoder().encode(updatedMetadata) {
            userDefaults.set(data, forKey: CacheKeys.cacheMetadata)
        }
    }
    
    private func calculateCacheSize() -> Int64 {
        let metadata = getCacheMetadata()
        return metadata.values.reduce(0) { $0 + $1.size }
    }
    
    private func schedulePeriodicCleanup() {
        // Schedule cleanup every hour
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.clearExpiredCache()
        }
    }
}

// MARK: - Cache Entry Models

private struct CacheEntry<T: Codable>: Codable {
    let data: T
    let timestamp: Date
    let expirationTime: TimeInterval
    
    var isExpired: Bool {
        return Date().timeIntervalSince(timestamp) > expirationTime
    }
}

private struct CacheMetadataEntry: Codable {
    let size: Int64
    let timestamp: Date
}
