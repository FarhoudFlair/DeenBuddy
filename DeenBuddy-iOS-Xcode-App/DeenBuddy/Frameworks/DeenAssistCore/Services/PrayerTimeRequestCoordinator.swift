//
//  PrayerTimeRequestCoordinator.swift
//  DeenAssistCore
//
//  Created by Claude Code on 2025-07-28.
//

import Foundation
import CoreLocation
import os.log

/// Coordinates all prayer time requests to prevent duplicate calculations
/// and optimize performance by deduplicating simultaneous requests
@MainActor
public class PrayerTimeRequestCoordinator: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.deenbuddy.app", category: "PrayerTimeRequestCoordinator")
    
    /// Active requests keyed by location and date for deduplication
    private var activeRequests: [String: Task<[PrayerTime], Error>] = [:]
    
    /// Debounce timers for different request types
    private var refreshDebounceTask: Task<Void, Never>?
    private var settingsDebounceTask: Task<Void, Never>?
    private var locationDebounceTask: Task<Void, Never>?
    
    /// Request statistics for monitoring
    private var requestStats = RequestStatistics()
    
    /// Cache for tomorrow's prayer times to avoid duplicate calculations
    private var tomorrowPrayerTimesCache: [String: (date: Date, times: [PrayerTime])] = [:]
    
    // MARK: - Configuration
    
    /// Debounce intervals for different request types
    private struct DebounceIntervals {
        static let refresh: TimeInterval = 1.0        // General refresh requests
        static let settings: TimeInterval = 2.0       // Settings changes (longer to prevent rapid changes)
        static let location: TimeInterval = 0.5       // Location changes (shorter for responsiveness)
        static let widget: TimeInterval = 1.5         // Widget updates
    }
    
    /// Location change threshold in meters to trigger recalculation
    private let locationChangeThreshold: CLLocationDistance = 500 // 500 meters
    
    /// Last calculated location for change detection
    private var lastCalculatedLocation: CLLocation?
    
    // MARK: - Public Methods
    
    /// Coordinate a prayer time calculation request with deduplication
    public func requestPrayerTimes(
        for location: CLLocation,
        date: Date = Date(),
        requestType: RequestType = .general,
        calculator: @escaping (CLLocation, Date) async throws -> [PrayerTime]
    ) async throws -> [PrayerTime] {
        
        let requestKey = generateRequestKey(location: location, date: date)
        requestStats.recordRequest(type: requestType)
        
        logger.debug("🔄 Prayer time request: \(requestType.rawValue) for key: \(requestKey)")
        
        // Check if there's already an active request for this location/date
        if let existingTask = activeRequests[requestKey] {
            logger.info("♻️ Reusing active request for \(requestKey)")
            requestStats.recordDeduplicated(type: requestType)
            return try await existingTask.value
        }
        
        // Create new request task
        let requestTask = Task<[PrayerTime], Error> {
            do {
                logger.debug("🆕 Creating new prayer time calculation for \(requestKey)")
                let result = try await calculator(location, date)
                logger.info("✅ Prayer time calculation completed for \(requestKey)")
                requestStats.recordSuccess(type: requestType)
                
                // Update last calculated location
                lastCalculatedLocation = location
                
                return result
            } catch {
                logger.error("❌ Prayer time calculation failed for \(requestKey): \(error)")
                requestStats.recordFailure(type: requestType)
                throw error
            }
        }
        
        // Store the task for deduplication
        activeRequests[requestKey] = requestTask
        
        // Clean up when task completes
        defer {
            activeRequests.removeValue(forKey: requestKey)
        }
        
        return try await requestTask.value
    }
    
    /// Coordinate refresh requests with debouncing
    public func coordinateRefresh(
        requestType: RequestType = .refresh,
        operation: @escaping () async -> Void
    ) {
        let debounceInterval: TimeInterval
        
        switch requestType {
        case .refresh:
            debounceInterval = DebounceIntervals.refresh
            refreshDebounceTask?.cancel()
            refreshDebounceTask = createDebouncedTask(
                interval: debounceInterval,
                operation: operation,
                taskType: "refresh"
            )
        case .settingsChange:
            debounceInterval = DebounceIntervals.settings
            settingsDebounceTask?.cancel()
            settingsDebounceTask = createDebouncedTask(
                interval: debounceInterval,
                operation: operation,  
                taskType: "settings"
            )
        case .locationChange:
            debounceInterval = DebounceIntervals.location
            locationDebounceTask?.cancel()
            locationDebounceTask = createDebouncedTask(
                interval: debounceInterval,
                operation: operation,
                taskType: "location"
            )
        default:
            // For other types, execute immediately without debouncing
            Task {
                await operation()
            }
        }
    }
    
    /// Check if location change is significant enough to trigger recalculation
    public func shouldRecalculateForLocation(_ newLocation: CLLocation) -> Bool {
        guard let lastLocation = lastCalculatedLocation else {
            return true // First calculation
        }
        
        let distance = newLocation.distance(from: lastLocation)
        let shouldRecalculate = distance > locationChangeThreshold
        
        if shouldRecalculate {
            logger.info("📍 Location changed by \(Int(distance))m - triggering recalculation")
        } else {
            logger.debug("📍 Location change of \(Int(distance))m below threshold (\(Int(self.locationChangeThreshold))m)")
        }
        
        return shouldRecalculate
    }
    
    /// Get tomorrow's prayer times with caching to avoid duplicate calculations
    public func getTomorrowPrayerTimes(
        for location: CLLocation,
        calculator: @escaping (CLLocation, Date) async throws -> [PrayerTime]
    ) async throws -> [PrayerTime] {
        
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let cacheKey = generateRequestKey(location: location, date: tomorrow)
        
        // Check cache first
        if let cached = tomorrowPrayerTimesCache[cacheKey],
           Calendar.current.isDate(cached.date, inSameDayAs: tomorrow) {
            logger.debug("📦 Using cached tomorrow's prayer times")
            return cached.times
        }
        
        // Calculate and cache
        let times = try await requestPrayerTimes(
            for: location,
            date: tomorrow,
            requestType: .widget,
            calculator: calculator
        )
        
        tomorrowPrayerTimesCache[cacheKey] = (date: tomorrow, times: times)
        
        // Clean up old cache entries
        cleanupTomorrowCache()
        
        return times
    }
    
    /// Get request statistics for monitoring
    public func getRequestStatistics() -> RequestStatistics {
        return requestStats
    }
    
    /// Reset statistics (useful for testing)
    public func resetStatistics() {
        requestStats = RequestStatistics()
        logger.info("📊 Request statistics reset")
    }
    
    // MARK: - Private Methods
    
    private func generateRequestKey(location: CLLocation, date: Date) -> String {
        let dateString = DateFormatter.requestKeyFormatter.string(from: date)
        // Round coordinates to reduce cache fragmentation while maintaining accuracy
        let lat = (location.coordinate.latitude * 1000).rounded() / 1000
        let lng = (location.coordinate.longitude * 1000).rounded() / 1000
        return "\(lat),\(lng)-\(dateString)"
    }
    
    private func createDebouncedTask(
        interval: TimeInterval,
        operation: @escaping () async -> Void,
        taskType: String
    ) -> Task<Void, Never> {
        return Task {
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            
            guard !Task.isCancelled else {
                logger.debug("🚫 Debounced \(taskType) task cancelled")
                return
            }
            
            logger.debug("⏰ Executing debounced \(taskType) operation after \(interval)s")
            await operation()
        }
    }
    
    private func cleanupTomorrowCache() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        
        tomorrowPrayerTimesCache = tomorrowPrayerTimesCache.filter { _, value in
            value.date > cutoffDate
        }
    }
}

// MARK: - Supporting Types

/// Types of prayer time requests for categorization and debouncing
public enum RequestType: String, CaseIterable {
    case general = "general"
    case refresh = "refresh"
    case settingsChange = "settings"
    case locationChange = "location"
    case widget = "widget"
    case background = "background"
    case onAppear = "onAppear"
    case pullToRefresh = "pullToRefresh"
}

/// Request statistics for monitoring and debugging
public struct RequestStatistics {
    public private(set) var totalRequests: [RequestType: Int] = [:]
    public private(set) var deduplicatedRequests: [RequestType: Int] = [:]
    public private(set) var successfulRequests: [RequestType: Int] = [:]
    public private(set) var failedRequests: [RequestType: Int] = [:]
    public private(set) var lastRequestTime: Date?
    
    mutating func recordRequest(type: RequestType) {
        totalRequests[type, default: 0] += 1
        lastRequestTime = Date()
    }
    
    mutating func recordDeduplicated(type: RequestType) {
        deduplicatedRequests[type, default: 0] += 1
    }
    
    mutating func recordSuccess(type: RequestType) {
        successfulRequests[type, default: 0] += 1
    }
    
    mutating func recordFailure(type: RequestType) {
        failedRequests[type, default: 0] += 1
    }
    
    /// Calculate deduplication effectiveness
    public var deduplicationRate: Double {
        let total = totalRequests.values.reduce(0, +)
        let deduplicated = deduplicatedRequests.values.reduce(0, +)
        return total > 0 ? Double(deduplicated) / Double(total) : 0
    }
    
    /// Get summary for debugging
    public var summary: String {
        let total = totalRequests.values.reduce(0, +)
        let deduplicated = deduplicatedRequests.values.reduce(0, +)
        let successful = successfulRequests.values.reduce(0, +)
        let failed = failedRequests.values.reduce(0, +)
        
        return """
        📊 Prayer Time Request Statistics:
        Total: \(total), Deduplicated: \(deduplicated) (\(String(format: "%.1f", deduplicationRate * 100))%)
        Successful: \(successful), Failed: \(failed)
        """
    }
}

// MARK: - Extensions

private extension DateFormatter {
    static let requestKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}