import Foundation
import UIKit
import CoreLocation

// MARK: - Islamic App Performance Monitor

/// Specialized performance monitoring for Islamic app features
/// Tracks sub-400ms response time targets for prayer-related interactions
@MainActor
public class IslamicAppPerformanceMonitor: ObservableObject {
    
    // MARK: - Performance Metrics
    
    public struct IslamicPerformanceMetrics {
        public var prayerTimeDisplayTime: TimeInterval = 0
        public var qiblaCompassResponseTime: TimeInterval = 0
        public var locationAcquisitionTime: TimeInterval = 0
        public var cacheHitRate: Double = 0
        public var backgroundUpdateSuccess: Bool = false
        public var timestamp: Date = Date()
        
        // Target thresholds
        public static let prayerTimeTarget: TimeInterval = 0.4 // 400ms
        public static let qiblaCompassTarget: TimeInterval = 0.2 // 200ms
        public static let locationTarget: TimeInterval = 2.0 // 2 seconds
        public static let cacheHitTarget: Double = 0.8 // 80%
    }
    
    public enum IslamicFeature: String, CaseIterable {
        case prayerTimeDisplay = "prayer_time_display"
        case qiblaCompass = "qibla_compass"
        case locationAcquisition = "location_acquisition"
        case prayerCalculation = "prayer_calculation"
        case qiblaCalculation = "qibla_calculation"
        case backgroundRefresh = "background_refresh"
        case cacheOperation = "cache_operation"
        case appLaunch = "app_launch"
    }
    
    // MARK: - Properties
    
    @Published public var currentMetrics = IslamicPerformanceMetrics()
    @Published public var performanceHistory: [IslamicPerformanceMetrics] = []
    @Published public var isMonitoring: Bool = false
    @Published public var performanceIssues: [PerformanceIssue] = []
    
    private var operationTimers: [String: Date] = [:]
    private var featureMetrics: [IslamicFeature: [TimeInterval]] = [:]
    private let maxHistorySize = 100
    
    // MARK: - Public Methods
    
    /// Start monitoring Islamic app performance
    public func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        print("🕌 Islamic app performance monitoring started")
        
        // Initialize feature metrics
        for feature in IslamicFeature.allCases {
            featureMetrics[feature] = []
        }
    }
    
    /// Stop monitoring
    public func stopMonitoring() {
        isMonitoring = false
        operationTimers.removeAll()
        print("🕌 Islamic app performance monitoring stopped")
    }
    
    /// Start timing an Islamic feature operation
    public func startTiming(feature: IslamicFeature, operation: String? = nil) {
        let key = operation ?? feature.rawValue
        operationTimers[key] = Date()
        
        print("⏱️ Started timing: \(key)")
    }
    
    /// End timing and record performance
    @discardableResult
    public func endTiming(feature: IslamicFeature, operation: String? = nil) -> TimeInterval? {
        let key = operation ?? feature.rawValue
        
        guard let startTime = operationTimers.removeValue(forKey: key) else {
            print("⚠️ No start time found for: \(key)")
            return nil
        }
        
        let duration = Date().timeIntervalSince(startTime)
        recordFeaturePerformance(feature: feature, duration: duration)
        
        // Check against Islamic app targets
        checkPerformanceTarget(feature: feature, duration: duration)
        
        print("✅ \(key) completed in \(String(format: "%.3f", duration))s")
        return duration
    }
    
    /// Record prayer time display performance
    public func recordPrayerTimeDisplay(duration: TimeInterval, fromCache: Bool) {
        currentMetrics.prayerTimeDisplayTime = duration
        recordFeaturePerformance(feature: .prayerTimeDisplay, duration: duration)
        
        if duration > IslamicPerformanceMetrics.prayerTimeTarget {
            addPerformanceIssue(
                type: .slowPrayerDisplay,
                description: "Prayer time display took \(String(format: "%.3f", duration))s (target: \(IslamicPerformanceMetrics.prayerTimeTarget)s)",
                severity: duration > 1.0 ? .high : .medium,
                metadata: ["duration": duration, "fromCache": fromCache]
            )
        }
    }
    
    /// Record Qibla compass performance
    public func recordQiblaCompassResponse(duration: TimeInterval, fromCache: Bool) {
        currentMetrics.qiblaCompassResponseTime = duration
        recordFeaturePerformance(feature: .qiblaCompass, duration: duration)
        
        if duration > IslamicPerformanceMetrics.qiblaCompassTarget {
            addPerformanceIssue(
                type: .slowQiblaCompass,
                description: "Qibla compass took \(String(format: "%.3f", duration))s (target: \(IslamicPerformanceMetrics.qiblaCompassTarget)s)",
                severity: duration > 0.5 ? .high : .medium,
                metadata: ["duration": duration, "fromCache": fromCache]
            )
        }
    }
    
    /// Record location acquisition performance
    public func recordLocationAcquisition(duration: TimeInterval, accuracy: Double) {
        currentMetrics.locationAcquisitionTime = duration
        recordFeaturePerformance(feature: .locationAcquisition, duration: duration)
        
        if duration > IslamicPerformanceMetrics.locationTarget {
            addPerformanceIssue(
                type: .slowLocationAcquisition,
                description: "Location acquisition took \(String(format: "%.3f", duration))s (target: \(IslamicPerformanceMetrics.locationTarget)s)",
                severity: duration > 5.0 ? .high : .medium,
                metadata: ["duration": duration, "accuracy": accuracy]
            )
        }
    }
    
    /// Record cache performance
    public func recordCachePerformance(hitRate: Double, operation: String) {
        currentMetrics.cacheHitRate = hitRate
        
        if hitRate < IslamicPerformanceMetrics.cacheHitTarget {
            addPerformanceIssue(
                type: .lowCacheHitRate,
                description: "Cache hit rate \(String(format: "%.1f", hitRate * 100))% below target (\(String(format: "%.1f", IslamicPerformanceMetrics.cacheHitTarget * 100))%)",
                severity: hitRate < 0.5 ? .high : .medium,
                metadata: ["hitRate": hitRate, "operation": operation]
            )
        }
    }
    
    /// Get performance summary for Islamic features
    public func getIslamicPerformanceSummary() -> IslamicPerformanceSummary {
        var summary = IslamicPerformanceSummary()
        
        // Calculate averages for each feature
        for (feature, durations) in featureMetrics {
            if !durations.isEmpty {
                let average = durations.reduce(0, +) / Double(durations.count)
                let p95 = calculatePercentile(durations, percentile: 0.95)
                
                summary.featureAverages[feature] = average
                summary.featureP95[feature] = p95
                
                // Check if meeting targets
                switch feature {
                case .prayerTimeDisplay:
                    summary.meetsPrayerTimeTarget = average <= IslamicPerformanceMetrics.prayerTimeTarget
                case .qiblaCompass:
                    summary.meetsQiblaTarget = average <= IslamicPerformanceMetrics.qiblaCompassTarget
                case .locationAcquisition:
                    summary.meetsLocationTarget = average <= IslamicPerformanceMetrics.locationTarget
                default:
                    break
                }
            }
        }
        
        summary.overallScore = calculateOverallPerformanceScore()
        summary.totalIssues = performanceIssues.count
        summary.highPriorityIssues = performanceIssues.filter { $0.severity == .high }.count
        
        return summary
    }
    
    /// Generate performance report for Islamic app
    public func generateIslamicPerformanceReport() -> String {
        let summary = getIslamicPerformanceSummary()
        
        var report = """
        🕌 DEENBUDDY ISLAMIC APP PERFORMANCE REPORT
        ==========================================
        
        📊 PERFORMANCE TARGETS:
        • Prayer Time Display: <400ms (\(summary.meetsPrayerTimeTarget ? "✅" : "❌"))
        • Qibla Compass: <200ms (\(summary.meetsQiblaTarget ? "✅" : "❌"))
        • Location Acquisition: <2000ms (\(summary.meetsLocationTarget ? "✅" : "❌"))
        • Cache Hit Rate: >80% (\(currentMetrics.cacheHitRate > 0.8 ? "✅" : "❌"))
        
        📈 FEATURE PERFORMANCE:
        """
        
        for feature in IslamicFeature.allCases {
            if let average = summary.featureAverages[feature],
               let p95 = summary.featureP95[feature] {
                report += "\n• \(feature.rawValue): avg \(String(format: "%.3f", average))s, p95 \(String(format: "%.3f", p95))s"
            }
        }
        
        report += """
        
        🎯 OVERALL SCORE: \(String(format: "%.1f", summary.overallScore * 100))%
        
        ⚠️ ISSUES: \(summary.totalIssues) total (\(summary.highPriorityIssues) high priority)
        """
        
        if !performanceIssues.isEmpty {
            report += "\n\n🔍 TOP ISSUES:"
            for issue in performanceIssues.prefix(5) {
                report += "\n• [\(issue.severity.rawValue.uppercased())] \(issue.description)"
            }
        }
        
        return report
    }
    
    // MARK: - Private Methods
    
    private func recordFeaturePerformance(feature: IslamicFeature, duration: TimeInterval) {
        featureMetrics[feature, default: []].append(duration)
        
        // Keep only recent measurements
        if featureMetrics[feature]!.count > maxHistorySize {
            featureMetrics[feature]!.removeFirst()
        }
    }
    
    private func checkPerformanceTarget(feature: IslamicFeature, duration: TimeInterval) {
        let target: TimeInterval
        let issueType: PerformanceIssueType
        
        switch feature {
        case .prayerTimeDisplay:
            target = IslamicPerformanceMetrics.prayerTimeTarget
            issueType = .slowPrayerDisplay
        case .qiblaCompass:
            target = IslamicPerformanceMetrics.qiblaCompassTarget
            issueType = .slowQiblaCompass
        case .locationAcquisition:
            target = IslamicPerformanceMetrics.locationTarget
            issueType = .slowLocationAcquisition
        default:
            return
        }
        
        if duration > target {
            addPerformanceIssue(
                type: issueType,
                description: "\(feature.rawValue) exceeded target: \(String(format: "%.3f", duration))s > \(target)s",
                severity: duration > target * 2 ? .high : .medium,
                metadata: ["feature": feature.rawValue, "duration": duration, "target": target]
            )
        }
    }
    
    private func addPerformanceIssue(type: PerformanceIssueType, description: String, severity: PerformanceIssueSeverity, metadata: [String: Any]) {
        let mappedType = mapToStandardType(type)
        let mappedSeverity = mapToStandardSeverity(severity)
        let doubleMetadata = metadata.compactMapValues { $0 as? Double }
        
        let issue = PerformanceIssue(
            type: mappedType,
            description: description,
            severity: mappedSeverity,
            timestamp: Date(),
            metadata: doubleMetadata
        )
        
        performanceIssues.append(issue)
        
        // Keep only recent issues
        if performanceIssues.count > 50 {
            performanceIssues.removeFirst()
        }
        
        print("⚠️ Performance issue: \(description)")
    }
    
    private func calculatePercentile(_ values: [TimeInterval], percentile: Double) -> TimeInterval {
        let sorted = values.sorted()
        let index = Int(Double(sorted.count) * percentile)
        return sorted[min(index, sorted.count - 1)]
    }
    
    private func calculateOverallPerformanceScore() -> Double {
        var score = 1.0
        
        // Deduct points for each performance issue
        let highPriorityPenalty = 0.1
        let mediumPriorityPenalty = 0.05
        let lowPriorityPenalty = 0.02
        
        for issue in performanceIssues {
            switch issue.severity {
            case .high:
                score -= highPriorityPenalty
            case .medium:
                score -= mediumPriorityPenalty
            case .low:
                score -= lowPriorityPenalty
            case .critical:
                score -= highPriorityPenalty * 2.0
            }
        }
        
        return max(0.0, score)
    }
    
    // MARK: - Helper Methods
    
    private func mapToStandardType(_ type: PerformanceIssueType) -> PerformanceIssue.IssueType {
        switch type {
        case .slowPrayerDisplay, .slowQiblaCompass:
            return .slowOperation
        case .slowLocationAcquisition:
            return .slowOperation
        case .lowCacheHitRate:
            return .slowOperation
        case .backgroundRefreshFailure:
            return .networkIssue
        case .memoryPressure:
            return .highMemoryUsage
        case .networkTimeout:
            return .networkIssue
        }
    }
    
    private func mapToStandardSeverity(_ severity: PerformanceIssueSeverity) -> PerformanceIssue.Severity {
        switch severity {
        case .low:
            return .low
        case .medium:
            return .medium
        case .high:
            return .high
        }
    }
}

// MARK: - Supporting Types

public struct IslamicPerformanceSummary {
    public var featureAverages: [IslamicAppPerformanceMonitor.IslamicFeature: TimeInterval] = [:]
    public var featureP95: [IslamicAppPerformanceMonitor.IslamicFeature: TimeInterval] = [:]
    public var meetsPrayerTimeTarget: Bool = false
    public var meetsQiblaTarget: Bool = false
    public var meetsLocationTarget: Bool = false
    public var overallScore: Double = 0.0
    public var totalIssues: Int = 0
    public var highPriorityIssues: Int = 0
}

public enum PerformanceIssueType {
    case slowPrayerDisplay
    case slowQiblaCompass
    case slowLocationAcquisition
    case lowCacheHitRate
    case backgroundRefreshFailure
    case memoryPressure
    case networkTimeout
}

public enum PerformanceIssueSeverity: String {
    case low = "low"
    case medium = "medium"
    case high = "high"
}

