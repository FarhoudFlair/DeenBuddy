import Foundation
import UIKit
import Combine

/// Comprehensive performance monitoring service for DeenBuddy
/// Monitors memory usage, battery drain, timer performance, and cache efficiency
@MainActor
public class PerformanceMonitoringService: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = PerformanceMonitoringService()
    
    // MARK: - Published Properties
    
    @Published public var currentMetrics: MonitoringPerformanceMetrics = MonitoringPerformanceMetrics()
    @Published public var isMonitoring: Bool = false
    @Published public var alertLevel: PerformanceAlertLevel = .normal
    
    // MARK: - Private Properties
    
    private let timerManager = BatteryAwareTimerManager.shared
    private let memoryManager = MemoryManager.shared
    private let cacheManager = UnifiedCacheManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Performance thresholds
    private let memoryWarningThreshold: Int = 150 * 1024 * 1024 // 150MB
    private let batteryDrainThreshold: Double = 0.15 // 15% per hour
    private let cacheHitRateThreshold: Double = 0.8 // 80%
    
    private init() {
        setupMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start comprehensive performance monitoring
    public func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        // Schedule performance monitoring timer
        timerManager.scheduleTimer(id: "performance-monitoring", type: .resourceMonitoring) { [weak self] in
            Task { @MainActor in
                await self?.updatePerformanceMetrics()
            }
        }
        
        // Start memory monitoring
        memoryManager.startMonitoring()
        
        // Optimize cache for current device
        cacheManager.optimizeForDevice()
        
        print("📊 Performance monitoring started")
    }
    
    /// Stop performance monitoring
    public func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        timerManager.cancelTimer(id: "performance-monitoring")
        memoryManager.stopMonitoring()
        
        print("📊 Performance monitoring stopped")
    }
    
    /// Get comprehensive performance report
    public func getPerformanceReport() -> PerformanceReport {
        let memoryReport = memoryManager.getMemoryReport()
        let timerStats = timerManager.getTimerStatistics()
        let cacheMetrics = cacheManager.getPerformanceMetrics()
        
        return PerformanceReport(
            memoryReport: memoryReport,
            timerStatistics: timerStats,
            cacheMetrics: cacheMetrics,
            currentMetrics: currentMetrics,
            alertLevel: alertLevel,
            recommendations: generateRecommendations()
        )
    }
    
    /// Force performance optimization
    public func optimizePerformance() {
        print("🔧 Performing comprehensive performance optimization...")
        
        // Consolidate timers
        timerManager.consolidateTimers()
        
        // Clean up memory
        memoryManager.performMemoryCleanup()
        
        // Optimize cache
        cacheManager.optimizeForDevice()
        
        // Update metrics
        Task {
            await updatePerformanceMetrics()
        }
        
        print("✅ Performance optimization completed")
    }
    
    // MARK: - Private Methods
    
    private func setupMonitoring() {
        // Monitor memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Monitor app lifecycle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        alertLevel = .critical
        print("⚠️ Memory warning - triggering emergency optimization")
        optimizePerformance()
    }
    
    @objc private func handleAppDidEnterBackground() {
        // Reduce monitoring frequency in background
        if isMonitoring {
            timerManager.cancelTimer(id: "performance-monitoring")
            
            // Schedule less frequent background monitoring
            timerManager.scheduleTimer(id: "background-performance-monitoring", type: .backgroundRefresh) { [weak self] in
                Task { @MainActor in
                    await self?.updatePerformanceMetrics()
                }
            }
        }
    }
    
    @objc private func handleAppWillEnterForeground() {
        // Resume normal monitoring frequency
        if isMonitoring {
            timerManager.cancelTimer(id: "background-performance-monitoring")
            startMonitoring()
        }
    }
    
    private func updatePerformanceMetrics() async {
        let memoryUsage = getCurrentMemoryUsage()
        let batteryLevel = UIDevice.current.batteryLevel
        let timerStats = timerManager.getTimerStatistics()
        let cacheMetrics = cacheManager.getPerformanceMetrics()
        
        currentMetrics = MonitoringPerformanceMetrics(
            memoryUsage: memoryUsage,
            batteryLevel: Double(batteryLevel),
            activeTimerCount: timerStats.activeTimerCount,
            cacheHitRate: cacheMetrics.hitRate,
            cacheSize: cacheMetrics.totalSize,
            timestamp: Date()
        )
        
        // Update alert level based on metrics
        updateAlertLevel()
    }
    
    private func updateAlertLevel() {
        if currentMetrics.memoryUsage > memoryWarningThreshold {
            alertLevel = .critical
        } else if currentMetrics.cacheHitRate < cacheHitRateThreshold {
            alertLevel = .warning
        } else if currentMetrics.activeTimerCount > 10 {
            alertLevel = .warning
        } else {
            alertLevel = .normal
        }
    }
    
    private func generateRecommendations() -> [String] {
        var recommendations: [String] = []
        
        if currentMetrics.memoryUsage > memoryWarningThreshold {
            recommendations.append("High memory usage detected - consider clearing caches")
        }
        
        if currentMetrics.cacheHitRate < cacheHitRateThreshold {
            recommendations.append("Low cache hit rate - review caching strategy")
        }
        
        if currentMetrics.activeTimerCount > 10 {
            recommendations.append("High timer count - consider consolidating timers")
        }
        
        if currentMetrics.batteryLevel < 0.2 {
            recommendations.append("Low battery - enable battery optimization mode")
        }
        
        return recommendations
    }
    
    private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size)
        } else {
            return 0
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        cancellables.removeAll()
    }
}

// MARK: - Performance Models

public struct MonitoringPerformanceMetrics {
    public let memoryUsage: Int
    public let batteryLevel: Double
    public let activeTimerCount: Int
    public let cacheHitRate: Double
    public let cacheSize: Int
    public let timestamp: Date

    public init(
        memoryUsage: Int = 0,
        batteryLevel: Double = 1.0,
        activeTimerCount: Int = 0,
        cacheHitRate: Double = 0.0,
        cacheSize: Int = 0,
        timestamp: Date = Date()
    ) {
        self.memoryUsage = memoryUsage
        self.batteryLevel = batteryLevel
        self.activeTimerCount = activeTimerCount
        self.cacheHitRate = cacheHitRate
        self.cacheSize = cacheSize
        self.timestamp = timestamp
    }
}

// MARK: - Backward Compatibility

/// Backward compatibility typealias for the renamed PerformanceMetrics type
@available(*, deprecated, renamed: "MonitoringPerformanceMetrics")
public typealias PerformanceMetrics = MonitoringPerformanceMetrics

public enum PerformanceAlertLevel {
    case normal
    case warning
    case critical
    
    public var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
}

public struct PerformanceReport {
    public let memoryReport: MemoryReport
    public let timerStatistics: TimerStatistics
    public let cacheMetrics: CachePerformanceMetrics
    public let currentMetrics: MonitoringPerformanceMetrics
    public let alertLevel: PerformanceAlertLevel
    public let recommendations: [String]
    
    public var summary: String {
        return """
        Performance Report (\(alertLevel.displayName)):
        - Memory: \(currentMetrics.memoryUsage / 1024 / 1024)MB
        - Battery: \(Int(currentMetrics.batteryLevel * 100))%
        - Active Timers: \(currentMetrics.activeTimerCount)
        - Cache Hit Rate: \(String(format: "%.1f%%", currentMetrics.cacheHitRate * 100))
        - Recommendations: \(recommendations.count)
        """
    }
}
