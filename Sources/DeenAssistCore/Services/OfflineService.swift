import Foundation

/// Service for managing offline caching and storage for iOS
public actor OfflineService {
    private let cacheDirectory: URL
    private let guidesFileName = "cached_prayer_guides.json"
    
    public init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                                   in: .userDomainMask).first!
        self.cacheDirectory = documentsPath.appendingPathComponent("DeenBuddyCache")
        
        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, 
                                               withIntermediateDirectories: true)
    }
    
    // MARK: - Prayer Guides Caching
    
    public func cacheGuides(_ guides: [PrayerGuide]) async {
        let cacheFile = cacheDirectory.appendingPathComponent(guidesFileName)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(guides)
            try data.write(to: cacheFile)
            print("Successfully cached \(guides.count) prayer guides")
        } catch {
            print("Failed to cache guides: \(error)")
        }
    }
    
    public func getCachedGuides() async -> [PrayerGuide]? {
        let cacheFile = cacheDirectory.appendingPathComponent(guidesFileName)
        
        guard FileManager.default.fileExists(atPath: cacheFile.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: cacheFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let guides = try decoder.decode([PrayerGuide].self, from: data)
            print("Successfully loaded \(guides.count) cached prayer guides")
            return guides
        } catch {
            print("Failed to load cached guides: \(error)")
            return nil
        }
    }
    
    // MARK: - Cache Management
    
    public func clearCache() async {
        let cacheFile = cacheDirectory.appendingPathComponent(guidesFileName)
        try? FileManager.default.removeItem(at: cacheFile)
        print("Cache cleared")
    }
    
    public func getCacheSize() async -> Int64 {
        let cacheFile = cacheDirectory.appendingPathComponent(guidesFileName)
        
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: cacheFile.path) else {
            return 0
        }
        
        return attributes[.size] as? Int64 ?? 0
    }
    
    public func getCacheInfo() async -> CacheInfo {
        let cacheFile = cacheDirectory.appendingPathComponent(guidesFileName)
        let exists = FileManager.default.fileExists(atPath: cacheFile.path)
        
        if exists {
            let attributes = try? FileManager.default.attributesOfItem(atPath: cacheFile.path)
            let size = attributes?[.size] as? Int64 ?? 0
            let modificationDate = attributes?[.modificationDate] as? Date
            
            return CacheInfo(
                exists: true,
                size: size,
                lastModified: modificationDate,
                itemCount: await getCachedGuides()?.count ?? 0
            )
        } else {
            return CacheInfo(exists: false, size: 0, lastModified: nil, itemCount: 0)
        }
    }
    
    // MARK: - Offline Content Management
    
    public func isContentAvailableOffline(guideId: String) async -> Bool {
        guard let cachedGuides = await getCachedGuides() else { return false }
        return cachedGuides.contains { $0.id == guideId && $0.isAvailableOffline }
    }
    
    public func getOfflineGuides() async -> [PrayerGuide] {
        guard let cachedGuides = await getCachedGuides() else { return [] }
        return cachedGuides.filter { $0.isAvailableOffline }
    }
    
    // MARK: - Cache Validation
    
    public func validateCache() async -> Bool {
        guard let cachedGuides = await getCachedGuides() else { return false }
        
        // Check if cache is not empty and has valid data
        return !cachedGuides.isEmpty && cachedGuides.allSatisfy { guide in
            !guide.id.isEmpty && !guide.title.isEmpty
        }
    }
    
    public func shouldRefreshCache(maxAge: TimeInterval = 3600) async -> Bool {
        let cacheInfo = await getCacheInfo()
        
        guard cacheInfo.exists, let lastModified = cacheInfo.lastModified else {
            return true // No cache exists, should refresh
        }
        
        let age = Date().timeIntervalSince(lastModified)
        return age > maxAge
    }
}

// MARK: - Cache Info Model

public struct CacheInfo {
    public let exists: Bool
    public let size: Int64
    public let lastModified: Date?
    public let itemCount: Int
    
    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    public var ageDescription: String {
        guard let lastModified = lastModified else { return "Unknown" }
        
        let age = Date().timeIntervalSince(lastModified)
        let minutes = Int(age / 60)
        let hours = Int(age / 3600)
        let days = Int(age / 86400)
        
        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s") ago"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else {
            return "Just now"
        }
    }
}
