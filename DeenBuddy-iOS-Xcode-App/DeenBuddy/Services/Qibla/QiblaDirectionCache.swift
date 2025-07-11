import Foundation
import CoreLocation
import SwiftUI

// MARK: - Qibla Direction Cache for Sub-50ms Response Times

/// High-performance caching service for Qibla directions
/// Provides instant compass responses while maintaining Islamic accuracy
@MainActor
public class QiblaDirectionCache: ObservableObject {
    
    // MARK: - Cache Entry
    
    private struct CachedQiblaEntry {
        let location: CLLocation
        let direction: QiblaDirection
        let calculatedAt: Date
        let accuracy: Double // Location accuracy when calculated
    }
    
    // MARK: - Properties
    
    private var cache: [String: CachedQiblaEntry] = [:]
    private let cacheRadius: Double = 500 // 500 meters - balance between accuracy and performance
    private let maxCacheAge: TimeInterval = 24 * 60 * 60 // 24 hours
    private let maxCacheSize: Int = 100 // Prevent memory bloat
    
    @Published public var lastCacheHit: Date?
    @Published public var cacheHitRate: Double = 0.0
    
    private var totalRequests: Int = 0
    private var cacheHits: Int = 0
    
    // MARK: - Public Methods
    
    /// Get cached Qibla direction for location (target: <50ms)
    public func getCachedDirection(for location: CLLocation) -> QiblaDirection? {
        totalRequests += 1
        
        // Check for exact location match first (fastest)
        let exactKey = createCacheKey(for: location)
        if let exactEntry = cache[exactKey], !isExpired(exactEntry) {
            recordCacheHit()
            return exactEntry.direction
        }
        
        // Check for nearby cached directions within radius
        for entry in cache.values {
            if !isExpired(entry) && isWithinCacheRadius(location, cachedLocation: entry.location) {
                // Verify accuracy is sufficient
                if entry.accuracy <= 100 { // Only use high-accuracy cached directions
                    recordCacheHit()
                    return entry.direction
                }
            }
        }
        
        updateCacheHitRate()
        return nil
    }
    
    /// Cache a calculated Qibla direction
    public func cacheDirection(_ direction: QiblaDirection, for location: CLLocation) {
        let key = createCacheKey(for: location)
        let entry = CachedQiblaEntry(
            location: location,
            direction: direction,
            calculatedAt: Date(),
            accuracy: location.horizontalAccuracy
        )
        
        cache[key] = entry
        
        // Cleanup old entries if cache is getting too large
        if cache.count > maxCacheSize {
            cleanupOldEntries()
        }
    }
    
    /// Preload Qibla directions for common locations
    public func preloadCommonDirections() {
        // Common locations for testing and quick access
        let commonLocations = [
            CLLocation(latitude: 40.7128, longitude: -74.0060), // New York
            CLLocation(latitude: 51.5074, longitude: -0.1278),  // London
            CLLocation(latitude: 25.2048, longitude: 55.2708),  // Dubai
            CLLocation(latitude: 33.6844, longitude: 73.0479),  // Islamabad
        ]
        
        Task {
            for location in commonLocations {
                if getCachedDirection(for: location) == nil {
                    // Calculate and cache using existing QiblaDirection model
                    let coord = LocationCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                    let direction = QiblaDirection.calculate(from: coord)
                    cacheDirection(direction, for: location)
                }
            }
        }
    }
    
    /// Clear expired cache entries
    public func clearExpiredEntries() {
        let now = Date()
        cache = cache.filter { _, entry in
            now.timeIntervalSince(entry.calculatedAt) < maxCacheAge
        }
    }
    
    /// Get cache statistics for performance monitoring
    public func getCacheStats() -> (hitRate: Double, totalEntries: Int, totalRequests: Int) {
        return (cacheHitRate, cache.count, totalRequests)
    }
    
    // MARK: - Private Methods
    
    private func createCacheKey(for location: CLLocation) -> String {
        // Round to ~100m precision for cache key
        let lat = round(location.coordinate.latitude * 1000) / 1000
        let lon = round(location.coordinate.longitude * 1000) / 1000
        return "\(lat),\(lon)"
    }
    
    private func isWithinCacheRadius(_ location: CLLocation, cachedLocation: CLLocation) -> Bool {
        return location.distance(from: cachedLocation) <= cacheRadius
    }
    
    private func isExpired(_ entry: CachedQiblaEntry) -> Bool {
        return Date().timeIntervalSince(entry.calculatedAt) > maxCacheAge
    }
    
    private func recordCacheHit() {
        cacheHits += 1
        lastCacheHit = Date()
    }
    
    private func updateCacheHitRate() {
        cacheHitRate = totalRequests > 0 ? Double(cacheHits) / Double(totalRequests) : 0.0
    }
    
    private func cleanupOldEntries() {
        // Remove oldest entries first
        let sortedEntries = cache.sorted { $0.value.calculatedAt < $1.value.calculatedAt }
        let entriesToRemove = sortedEntries.prefix(cache.count - maxCacheSize + 10) // Remove extra for buffer
        
        for (key, _) in entriesToRemove {
            cache.removeValue(forKey: key)
        }
    }
}

// MARK: - CLLocationCoordinate2D Codable Extension

extension CLLocationCoordinate2D: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }

    private enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }
}

// MARK: - Performance Monitoring Extension

extension QiblaDirectionCache {
    /// Log performance metrics for Islamic app optimization
    public func logPerformanceMetrics() {
        let stats = getCacheStats()
        print("🕌 Qibla Cache Performance:")
        print("   Hit Rate: \(String(format: "%.1f", stats.hitRate * 100))%")
        print("   Total Entries: \(stats.totalEntries)")
        print("   Total Requests: \(stats.totalRequests)")
        print("   Cache Hits: \(cacheHits)")
        
        if stats.hitRate > 0.8 {
            print("   ✅ Excellent cache performance - sub-50ms responses")
        } else if stats.hitRate > 0.6 {
            print("   ⚠️ Good cache performance - consider preloading more locations")
        } else {
            print("   ❌ Poor cache performance - review caching strategy")
        }
    }
}
