import Foundation
import Combine
import UIKit

/// Service for monitoring app performance and metrics
@MainActor
public class PerformanceMonitor: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var currentMetrics: PerformanceMetrics = PerformanceMetrics()
    @Published public var isMonitoring = false
    @Published public var performanceIssues: [PerformanceIssue] = []
    
    // MARK: - Private Properties
    
    private var metricsTimer: Timer?
    private var operationTimers: [String: Date] = [:]
    private var performanceHistory: [PerformanceMetrics] = []
    private let maxHistoryCount = 100
    private var cancellables = Set<AnyCancellable>()
    
    private var previousCPUTime: Double = 0
    private var previousWallTime: Double = 0
    
    // MARK: - Singleton
    
    public static let shared = PerformanceMonitor()
    
    private init() {
        setupPerformanceObservers()
    }
    
    deinit {
        Task { await self.stopMonitoring() }
    }
    
    // MARK: - Public Methods
    
    /// Start performance monitoring
    public func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetrics()
            }
        }
        
        print("📊 Performance monitoring started")
    }
    
    /// Stop performance monitoring
    public func stopMonitoring() {
        isMonitoring = false
        metricsTimer?.invalidate()
        metricsTimer = nil
        
        print("📊 Performance monitoring stopped")
    }
    
    /// Start timing an operation
    public func startTiming(operation: String) {
        operationTimers[operation] = Date()
    }
    
    /// End timing an operation and return duration
    @discardableResult
    public func endTiming(operation: String) -> TimeInterval? {
        guard let startTime = operationTimers.removeValue(forKey: operation) else {
            return nil
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Log slow operations
        if duration > 1.0 {
            let issue = PerformanceIssue(
                type: .slowOperation,
                description: "Operation '\(operation)' took \(String(format: "%.2f", duration))s",
                severity: duration > 5.0 ? .high : .medium,
                timestamp: Date(),
                metadata: ["duration": duration]
            )
            addPerformanceIssue(issue)
        }
        
        print("⏱️ Operation '\(operation)' completed in \(String(format: "%.3f", duration))s")
        return duration
    }
    
    /// Measure execution time of a block
    public func measure<T>(operation: String, block: () throws -> T) rethrows -> T {
        startTiming(operation: operation)
        defer { endTiming(operation: operation) }
        return try block()
    }
    
    /// Measure execution time of an async block
    public func measureAsync<T>(operation: String, block: () async throws -> T) async rethrows -> T {
        startTiming(operation: operation)
        defer { endTiming(operation: operation) }
        return try await block()
    }
    
    /// Get performance summary
    public func getPerformanceSummary() -> PerformanceSummary {
        let recentMetrics = performanceHistory.suffix(10)
        let avgCPU = recentMetrics.map { $0.cpuUsage }.reduce(0, +) / Double(recentMetrics.count)
        let avgMemory = recentMetrics.map { $0.memoryUsage }.reduce(0, +) / Double(recentMetrics.count)
        
        return PerformanceSummary(
            currentMetrics: currentMetrics,
            averageCPU: avgCPU,
            averageMemory: avgMemory,
            issueCount: performanceIssues.count,
            criticalIssueCount: performanceIssues.filter { $0.severity == .critical }.count,
            monitoringDuration: isMonitoring ? Date().timeIntervalSince(Date()) : 0
        )
    }
    
    /// Clear performance history
    public func clearHistory() {
        performanceHistory.removeAll()
        performanceIssues.removeAll()
        print("📊 Performance history cleared")
    }
    
    /// Export performance data
    public func exportPerformanceData() -> PerformanceExport {
        return PerformanceExport(
            metrics: performanceHistory,
            issues: performanceIssues,
            summary: getPerformanceSummary(),
            exportDate: Date()
        )
    }
    
    // MARK: - Private Methods
    
    private func setupPerformanceObservers() {
        // Memory warnings
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleMemoryWarning()
                }
            }
            .store(in: &cancellables)
        
        // App lifecycle
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleAppBackgrounded()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleAppForegrounded()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateMetrics() {
        let newMetrics = PerformanceMetrics(
            timestamp: Date(),
            cpuUsage: getCurrentCPUUsage(),
            memoryUsage: getCurrentMemoryUsage(),
            diskUsage: getCurrentDiskUsage(),
            networkLatency: getCurrentNetworkLatency(),
            frameRate: getCurrentFrameRate(),
            batteryLevel: getCurrentBatteryLevel()
        )
        
        currentMetrics = newMetrics
        performanceHistory.append(newMetrics)
        
        // Keep history size manageable
        if performanceHistory.count > maxHistoryCount {
            performanceHistory.removeFirst()
        }
        
        // Check for performance issues
        checkForPerformanceIssues(newMetrics)
    }
    
    private func getCurrentCPUUsage() -> Double {
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
        
        guard kerr == KERN_SUCCESS else {
            return 0.0
        }
        
        // Get thread times for proper CPU usage calculation
        var threadInfo = task_thread_times_info()
        var threadCount = mach_msg_type_number_t(MemoryLayout<task_thread_times_info>.size / MemoryLayout<natural_t>.size)
        
        let threadKerr = withUnsafeMutablePointer(to: &threadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(TASK_THREAD_TIMES_INFO),
                         $0,
                         &threadCount)
            }
        }
        
        guard threadKerr == KERN_SUCCESS else {
            return 0.0
        }
        
        // Calculate total CPU time (user + system time) with proper field names and precision
        let userTime = Double(threadInfo.user_time.seconds) + Double(threadInfo.user_time.microseconds) / 1_000_000.0
        let systemTime = Double(threadInfo.system_time.seconds) + Double(threadInfo.system_time.microseconds) / 1_000_000.0
        let totalTime = userTime + systemTime
        
        // Get current time for calculation
        let currentTime = Date().timeIntervalSince1970
        
        // Calculate CPU usage percentage
        let cpuUsage: Double
        if previousWallTime > 0 {
            let cpuTimeDelta = totalTime - previousCPUTime
            let wallTimeDelta = currentTime - previousWallTime
            cpuUsage = (cpuTimeDelta / wallTimeDelta) * 100.0
        } else {
            cpuUsage = 0.0
        }
        
        // Update previous values
        previousCPUTime = totalTime
        previousWallTime = currentTime
        
        // Clamp to reasonable range (0-100%)
        return min(max(cpuUsage, 0.0), 100.0)
    }
    
    private func getCurrentMemoryUsage() -> Double {
        let memoryManager = MemoryManager.shared
        return memoryManager.currentMemoryUsage.usedMemoryMB
    }
    
    private func getCurrentDiskUsage() -> Double {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            let freeSpace = systemAttributes[.systemFreeSize] as? NSNumber ?? 0
            let totalSpace = systemAttributes[.systemSize] as? NSNumber ?? 1
            
            let usedSpace = totalSpace.doubleValue - freeSpace.doubleValue
            return (usedSpace / totalSpace.doubleValue) * 100
        } catch {
            return 0.0
        }
    }
    
    private func getCurrentNetworkLatency() -> Double {
        // This would require actual network ping implementation
        // For now, return a placeholder value
        return 0.0
    }
    
    private func getCurrentFrameRate() -> Double {
        // This would require CADisplayLink integration
        // For now, return a placeholder value
        return 60.0
    }
    
    private func getCurrentBatteryLevel() -> Double {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        return Double(device.batteryLevel * 100)
    }
    
    private func checkForPerformanceIssues(_ metrics: PerformanceMetrics) {
        // High CPU usage
        if metrics.cpuUsage > 80 {
            addPerformanceIssue(PerformanceIssue(
                type: .highCPUUsage,
                description: "High CPU usage: \(String(format: "%.1f", metrics.cpuUsage))%",
                severity: metrics.cpuUsage > 95 ? .critical : .high,
                timestamp: metrics.timestamp,
                metadata: ["cpu_usage": metrics.cpuUsage]
            ))
        }
        
        // High memory usage
        if metrics.memoryUsage > 500 { // 500MB
            addPerformanceIssue(PerformanceIssue(
                type: .highMemoryUsage,
                description: "High memory usage: \(String(format: "%.1f", metrics.memoryUsage))MB",
                severity: metrics.memoryUsage > 1000 ? .critical : .high,
                timestamp: metrics.timestamp,
                metadata: ["memory_usage": metrics.memoryUsage]
            ))
        }
        
        // Low frame rate
        if metrics.frameRate < 30 {
            addPerformanceIssue(PerformanceIssue(
                type: .lowFrameRate,
                description: "Low frame rate: \(String(format: "%.1f", metrics.frameRate))fps",
                severity: metrics.frameRate < 15 ? .critical : .medium,
                timestamp: metrics.timestamp,
                metadata: ["frame_rate": metrics.frameRate]
            ))
        }
        
        // Low battery
        if metrics.batteryLevel < 20 {
            addPerformanceIssue(PerformanceIssue(
                type: .lowBattery,
                description: "Low battery: \(String(format: "%.0f", metrics.batteryLevel))%",
                severity: metrics.batteryLevel < 10 ? .high : .medium,
                timestamp: metrics.timestamp,
                metadata: ["battery_level": metrics.batteryLevel]
            ))
        }
    }
    
    private func addPerformanceIssue(_ issue: PerformanceIssue) {
        performanceIssues.append(issue)
        
        // Keep only recent issues
        let cutoffDate = Date().addingTimeInterval(-3600) // 1 hour
        performanceIssues = performanceIssues.filter { $0.timestamp > cutoffDate }
        
        // Log critical issues
        if issue.severity == .critical {
            print("🚨 Critical performance issue: \(issue.description)")
        }
        
        // Track in analytics
        AnalyticsService.shared.trackEvent(AnalyticsEvent(
            name: "performance_issue",
            parameters: [
                "type": issue.type.rawValue,
                "severity": issue.severity.rawValue,
                "description": issue.description
            ],
            category: .performance
        ))
    }
    
    private func handleMemoryWarning() {
        addPerformanceIssue(PerformanceIssue(
            type: .memoryWarning,
            description: "Memory warning received",
            severity: .critical,
            timestamp: Date(),
            metadata: [:]
        ))
    }
    
    private func handleAppBackgrounded() {
        print("📊 App backgrounded - pausing performance monitoring")
        // Optionally pause monitoring in background
    }
    
    private func handleAppForegrounded() {
        print("📊 App foregrounded - resuming performance monitoring")
        // Resume monitoring if needed
    }
}

// MARK: - Performance Models

public struct PerformanceMetrics: Codable {
    public let timestamp: Date
    public let cpuUsage: Double // Percentage
    public let memoryUsage: Double // MB
    public let diskUsage: Double // Percentage
    public let networkLatency: Double // ms
    public let frameRate: Double // fps
    public let batteryLevel: Double // Percentage
    
    public init(
        timestamp: Date = Date(),
        cpuUsage: Double = 0,
        memoryUsage: Double = 0,
        diskUsage: Double = 0,
        networkLatency: Double = 0,
        frameRate: Double = 60,
        batteryLevel: Double = 100
    ) {
        self.timestamp = timestamp
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.diskUsage = diskUsage
        self.networkLatency = networkLatency
        self.frameRate = frameRate
        self.batteryLevel = batteryLevel
    }
}

public struct PerformanceIssue: Codable, Identifiable {
    public let id = UUID()
    public let type: IssueType
    public let description: String
    public let severity: Severity
    public let timestamp: Date
    public let metadata: [String: Any]
    
    public enum IssueType: String, Codable, CaseIterable {
        case highCPUUsage = "high_cpu_usage"
        case highMemoryUsage = "high_memory_usage"
        case lowFrameRate = "low_frame_rate"
        case slowOperation = "slow_operation"
        case memoryWarning = "memory_warning"
        case lowBattery = "low_battery"
        case networkIssue = "network_issue"
    }
    
    public enum Severity: String, Codable, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
        
        public var color: String {
            switch self {
            case .low: return "green"
            case .medium: return "yellow"
            case .high: return "orange"
            case .critical: return "red"
            }
        }
    }
}

// MARK: - PerformanceIssue Codable Implementation

extension PerformanceIssue {
    private enum CodingKeys: String, CodingKey {
        case id, type, description, severity, timestamp, metadata
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(IssueType.self, forKey: .type)
        description = try container.decode(String.self, forKey: .description)
        severity = try container.decode(Severity.self, forKey: .severity)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        
        // Decode metadata as JSON and convert to [String: Any]
        let metadataData = try container.decode(Data.self, forKey: .metadata)
        if let metadataDict = try? JSONSerialization.jsonObject(with: metadataData) as? [String: Any] {
            metadata = metadataDict
        } else {
            metadata = [:]
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(description, forKey: .description)
        try container.encode(severity, forKey: .severity)
        try container.encode(timestamp, forKey: .timestamp)
        
        // Safely encode metadata by filtering out non-JSON-serializable values
        let safeMetadata = filterJSONSerializableValues(from: metadata)
        let metadataData = try JSONSerialization.data(withJSONObject: safeMetadata)
        try container.encode(metadataData, forKey: .metadata)
    }
    
    /// Filters out non-JSON-serializable values from the metadata dictionary
    private func filterJSONSerializableValues(from dict: [String: Any]) -> [String: Any] {
        var safeDict: [String: Any] = [:]
        
        for (key, value) in dict {
            if isJSONSerializable(value) {
                safeDict[key] = value
            } else {
                // Replace non-serializable values with a string representation
                safeDict[key] = "\(value)"
            }
        }
        
        return safeDict
    }
    
    /// Checks if a value is JSON-serializable
    private func isJSONSerializable(_ value: Any) -> Bool {
        return isJSONSerializable(value, visited: Set<ObjectIdentifier>())
    }
    
    /// Checks if a value is JSON-serializable with cycle detection
    private func isJSONSerializable(_ value: Any, visited: Set<ObjectIdentifier>) -> Bool {
        switch value {
        case is String, is NSNumber, is Bool, is NSNull:
            return true
        case is Int, is Int8, is Int16, is Int32, is Int64,
             is UInt, is UInt8, is UInt16, is UInt32, is UInt64,
             is Float, is Double:
            return true
        case let array as [Any]:
            return array.allSatisfy { isJSONSerializable($0, visited: visited) }
        case let dict as [String: Any]:
            return dict.values.allSatisfy { isJSONSerializable($0, visited: visited) }
        case let object as AnyObject:
            // Check for circular references
            let objectId = ObjectIdentifier(object)
            if visited.contains(objectId) {
                return false // Circular reference detected
            }
            var newVisited = visited
            newVisited.insert(objectId)
            
            // For objects, we'll be conservative and only allow if they can be converted to JSON
            return false
        default:
            return false
        }
    }
}

public struct PerformanceSummary {
    public let currentMetrics: PerformanceMetrics
    public let averageCPU: Double
    public let averageMemory: Double
    public let issueCount: Int
    public let criticalIssueCount: Int
    public let monitoringDuration: TimeInterval
    
    public var healthScore: Double {
        var score = 100.0
        
        // Deduct for high resource usage
        if averageCPU > 50 { score -= 20 }
        if averageMemory > 300 { score -= 20 }
        
        // Deduct for issues
        score -= Double(issueCount) * 5
        score -= Double(criticalIssueCount) * 15
        
        return max(0, score)
    }
    
    public var healthGrade: String {
        switch healthScore {
        case 90...100: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default: return "F"
        }
    }
}

public struct PerformanceExport: Codable {
    public let metrics: [PerformanceMetrics]
    public let issues: [PerformanceIssue]
    public let summary: PerformanceSummary
    public let exportDate: Date
}

// MARK: - Extensions

extension PerformanceSummary: Codable {
    enum CodingKeys: String, CodingKey {
        case currentMetrics, averageCPU, averageMemory, issueCount, criticalIssueCount, monitoringDuration
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentMetrics = try container.decode(PerformanceMetrics.self, forKey: .currentMetrics)
        averageCPU = try container.decode(Double.self, forKey: .averageCPU)
        averageMemory = try container.decode(Double.self, forKey: .averageMemory)
        issueCount = try container.decode(Int.self, forKey: .issueCount)
        criticalIssueCount = try container.decode(Int.self, forKey: .criticalIssueCount)
        monitoringDuration = try container.decode(TimeInterval.self, forKey: .monitoringDuration)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currentMetrics, forKey: .currentMetrics)
        try container.encode(averageCPU, forKey: .averageCPU)
        try container.encode(averageMemory, forKey: .averageMemory)
        try container.encode(issueCount, forKey: .issueCount)
        try container.encode(criticalIssueCount, forKey: .criticalIssueCount)
        try container.encode(monitoringDuration, forKey: .monitoringDuration)
    }
}
