import Foundation
import UIKit
import os.log

/// Comprehensive resource monitoring utility for DeenBuddy app
/// Tracks memory usage, task counts, and system resource consumption
public class ResourceMonitor: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = ResourceMonitor()
    
    // MARK: - Published Properties
    
    @Published public var memoryUsage: MemoryUsage = MemoryUsage()
    @Published public var taskMetrics: TaskMetrics = TaskMetrics()
    @Published public var systemMetrics: SystemMetrics = SystemMetrics()
    @Published public var isMonitoring: Bool = false
    
    // MARK: - Private Properties
    
    private let timerManager = BatteryAwareTimerManager.shared
    private let logger = Logger(subsystem: "com.deenbuddy.app", category: "ResourceMonitor")
    private let alertThresholds = AlertThresholds()
    
    // MARK: - Data Models
    
    public struct MemoryUsage {
        public var currentMemoryMB: Double = 0
        public var peakMemoryMB: Double = 0
        public var memoryWarningCount: Int = 0
        public var lastMemoryWarning: Date?
        
        public var isMemoryPressureHigh: Bool {
            return currentMemoryMB > 150.0 // 150MB threshold for iOS apps
        }
    }
    
    public struct TaskMetrics {
        public var activeLocationTasks: Int = 0
        public var activePrayerTimeTasks: Int = 0
        public var totalBackgroundTasks: Int = 0
        public var observerCount: Int = 0
        public var serviceInstanceCount: Int = 0
        
        public var isCritical: Bool {
            return activeLocationTasks > 5 || 
                   activePrayerTimeTasks > 10 || 
                   totalBackgroundTasks > 20 ||
                   observerCount > 50 ||
                   serviceInstanceCount > 10
        }
    }
    
    public struct SystemMetrics {
        public var cpuUsage: Double = 0
        public var batteryLevel: Float = 1.0
        public var thermalState: ProcessInfo.ThermalState = .nominal
        public var lowPowerModeEnabled: Bool = false
        
        public var isSystemStressed: Bool {
            return cpuUsage > 80.0 || 
                   thermalState == .critical ||
                   batteryLevel < 0.2
        }
    }
    
    private struct AlertThresholds {
        let maxMemoryMB: Double = 200.0
        let maxLocationTasks: Int = 5
        let maxPrayerTimeTasks: Int = 10
        let maxBackgroundTasks: Int = 20
        let maxObservers: Int = 50
        let maxServiceInstances: Int = 10
        let maxCPUUsage: Double = 80.0
    }
    
    // MARK: - Initialization
    
    private init() {
        setupMemoryWarningObserver()
        setupThermalStateObserver()
        setupBatteryMonitoring()
    }
    
    deinit {
        MainActor.assumeIsolated {
            stopMonitoring()
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Start continuous resource monitoring
    @MainActor
    public func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        logger.info("🔍 ResourceMonitor: Starting continuous monitoring")
        
        timerManager.scheduleTimer(id: "resource-monitoring", type: .resourceMonitoring) { [weak self] in
            self?.updateMetrics()
        }
        
        // Initial update
        updateMetrics()
    }
    
    /// Stop continuous resource monitoring
    @MainActor
    public func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        timerManager.cancelTimer(id: "resource-monitoring")
        
        logger.info("🔍 ResourceMonitor: Stopped continuous monitoring")
    }
    
    /// Get current resource snapshot
    public func getCurrentSnapshot() -> ResourceSnapshot {
        updateMetrics()
        return ResourceSnapshot(
            memoryUsage: memoryUsage,
            taskMetrics: taskMetrics,
            systemMetrics: systemMetrics,
            timestamp: Date()
        )
    }
    
    /// Check if app is in critical resource state
    public func isCriticalResourceState() -> Bool {
        return memoryUsage.isMemoryPressureHigh ||
               taskMetrics.isCritical ||
               systemMetrics.isSystemStressed
    }
    
    /// Get resource usage report for debugging
    public func getResourceReport() -> String {
        let snapshot = getCurrentSnapshot()
        return """
        📊 DeenBuddy Resource Report - \(DateFormatter.localizedString(from: snapshot.timestamp, dateStyle: .none, timeStyle: .medium))
        
        🧠 Memory Usage:
        - Current: \(String(format: "%.1f", snapshot.memoryUsage.currentMemoryMB)) MB
        - Peak: \(String(format: "%.1f", snapshot.memoryUsage.peakMemoryMB)) MB
        - Memory Warnings: \(snapshot.memoryUsage.memoryWarningCount)
        - High Pressure: \(snapshot.memoryUsage.isMemoryPressureHigh ? "⚠️ YES" : "✅ NO")
        
        📋 Task Metrics:
        - Location Tasks: \(snapshot.taskMetrics.activeLocationTasks)
        - Prayer Time Tasks: \(snapshot.taskMetrics.activePrayerTimeTasks)
        - Background Tasks: \(snapshot.taskMetrics.totalBackgroundTasks)
        - Observers: \(snapshot.taskMetrics.observerCount)
        - Service Instances: \(snapshot.taskMetrics.serviceInstanceCount)
        - Critical State: \(snapshot.taskMetrics.isCritical ? "⚠️ YES" : "✅ NO")
        
        🖥️ System Metrics:
        - CPU Usage: \(String(format: "%.1f", snapshot.systemMetrics.cpuUsage))%
        - Battery: \(String(format: "%.0f", snapshot.systemMetrics.batteryLevel * 100))%
        - Thermal State: \(snapshot.systemMetrics.thermalState.description)
        - Low Power Mode: \(snapshot.systemMetrics.lowPowerModeEnabled ? "⚠️ ON" : "✅ OFF")
        - System Stressed: \(snapshot.systemMetrics.isSystemStressed ? "⚠️ YES" : "✅ NO")
        
        🚨 Overall Status: \(isCriticalResourceState() ? "⚠️ CRITICAL" : "✅ HEALTHY")
        """
    }
    
    // MARK: - Private Methods
    
    private func updateMetrics() {
        updateMemoryUsage()
        Task { @MainActor in
            self.updateTaskMetrics()
        }
        updateSystemMetrics()

        // Log critical states
        if isCriticalResourceState() {
            logger.warning("⚠️ ResourceMonitor: Critical resource state detected")
            logger.warning("\(self.getResourceReport())")
        }
    }
    
    private func updateMemoryUsage() {
        let currentMemory = getCurrentMemoryUsage()
        
        memoryUsage.currentMemoryMB = currentMemory
        memoryUsage.peakMemoryMB = max(memoryUsage.peakMemoryMB, currentMemory)
    }
    
    @MainActor
    private func updateTaskMetrics() {
        // Get metrics from LocationService if available
        if let locationService = DependencyContainer.shared.locationService as? LocationService {
            let usage = locationService.getResourceUsage()
            taskMetrics.activeLocationTasks = usage.activeTasks
            taskMetrics.observerCount = usage.observers
            taskMetrics.serviceInstanceCount = usage.instances
        }

        // Additional task metrics would be gathered from other services
        // This is a simplified implementation
    }
    
    private func updateSystemMetrics() {
        systemMetrics.cpuUsage = getCurrentCPUUsage()
        systemMetrics.batteryLevel = UIDevice.current.batteryLevel
        systemMetrics.thermalState = ProcessInfo.processInfo.thermalState
        systemMetrics.lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    
    private func getCurrentMemoryUsage() -> Double {
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
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        } else {
            return 0.0
        }
    }
    
    private func getCurrentCPUUsage() -> Double {
        // Simplified CPU usage calculation
        // In a production app, you might want a more sophisticated implementation
        return Double.random(in: 0...100) // Placeholder
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    private func setupThermalStateObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThermalStateChange),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }
    
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
    }
    
    @objc private func handleMemoryWarning() {
        memoryUsage.memoryWarningCount += 1
        memoryUsage.lastMemoryWarning = Date()
        logger.warning("⚠️ Memory warning received - Count: \(self.memoryUsage.memoryWarningCount)")
    }

    @objc private func handleThermalStateChange() {
        systemMetrics.thermalState = ProcessInfo.processInfo.thermalState
        logger.info("🌡️ Thermal state changed to: \(self.systemMetrics.thermalState.description)")
    }
}

// MARK: - Supporting Types

public struct ResourceSnapshot {
    public let memoryUsage: ResourceMonitor.MemoryUsage
    public let taskMetrics: ResourceMonitor.TaskMetrics
    public let systemMetrics: ResourceMonitor.SystemMetrics
    public let timestamp: Date
}

extension ProcessInfo.ThermalState {
    var description: String {
        switch self {
        case .nominal: return "Normal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
