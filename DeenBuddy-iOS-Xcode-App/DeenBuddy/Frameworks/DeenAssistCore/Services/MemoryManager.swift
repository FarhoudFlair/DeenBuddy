import Foundation
import Combine
import UIKit

/// Service for monitoring and managing app memory usage
@MainActor
public class MemoryManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var currentMemoryUsage: MemoryUsage = MemoryUsage()
    @Published public var memoryWarningLevel: MemoryWarningLevel = .normal
    @Published public var isMemoryOptimizationEnabled = true
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let timerManager = BatteryAwareTimerManager.shared
    private let memoryThresholds = MemoryThresholds()
    
    // MARK: - Singleton
    
    public static let shared = MemoryManager()
    
    private init() {
        setupMemoryMonitoring()
        setupMemoryWarningObserver()
    }
    
    deinit {
        timerManager.cancelTimer(id: "memory-monitoring")
    }
    
    // MARK: - Public Methods
    
    /// Start memory monitoring
    public func startMonitoring() {
        timerManager.scheduleTimer(id: "memory-monitoring", type: .memoryMonitoring) { [weak self] in
            Task { @MainActor in
                self?.updateMemoryUsage()
            }
        }
        
        updateMemoryUsage()
        print("📊 Memory monitoring started")
    }
    
    /// Stop memory monitoring
    public func stopMonitoring() {
        timerManager.cancelTimer(id: "memory-monitoring")
        memoryTimer = nil
        print("📊 Memory monitoring stopped")
    }
    
    /// Force memory cleanup
    public func performMemoryCleanup() {
        print("🧹 Performing memory cleanup...")
        
        // Clear image caches
        clearImageCaches()
        
        // Clear temporary data
        clearTemporaryData()
        
        // Trigger garbage collection
        triggerGarbageCollection()
        
        // Update memory usage
        updateMemoryUsage()
        
        print("🧹 Memory cleanup completed")
    }
    
    /// Get detailed memory report
    public func getMemoryReport() -> MemoryReport {
        let usage = getCurrentMemoryUsage()
        let deviceInfo = getDeviceMemoryInfo()
        
        return MemoryReport(
            currentUsage: usage,
            deviceInfo: deviceInfo,
            warningLevel: memoryWarningLevel,
            recommendations: getMemoryRecommendations()
        )
    }
    
    /// Check if memory optimization should be applied
    public func shouldOptimizeForMemory() -> Bool {
        return isMemoryOptimizationEnabled && 
               (memoryWarningLevel == .warning || memoryWarningLevel == .critical)
    }
    
    /// Get memory usage percentage
    public var memoryUsagePercentage: Double {
        let deviceMemory = getDeviceMemoryInfo()
        guard deviceMemory.totalMemory > 0 else { return 0.0 }
        
        return (currentMemoryUsage.usedMemory / deviceMemory.totalMemory) * 100.0
    }
    
    // MARK: - Private Methods
    
    private func setupMemoryMonitoring() {
        startMonitoring()
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleMemoryWarning()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateMemoryUsage() {
        currentMemoryUsage = getCurrentMemoryUsage()
        memoryWarningLevel = determineWarningLevel()
        
        // Auto-cleanup if memory is critical
        if memoryWarningLevel == .critical {
            performMemoryCleanup()
        }
    }
    
    private func getCurrentMemoryUsage() -> MemoryUsage {
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
            let usedMemory = Double(info.resident_size)
            let virtualMemory = Double(info.virtual_size)
            
            return MemoryUsage(
                usedMemory: usedMemory,
                virtualMemory: virtualMemory,
                timestamp: Date()
            )
        } else {
            return MemoryUsage()
        }
    }
    
    private func getDeviceMemoryInfo() -> DeviceMemoryInfo {
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
        let availableMemory = totalMemory - currentMemoryUsage.usedMemory
        
        return DeviceMemoryInfo(
            totalMemory: totalMemory,
            availableMemory: availableMemory
        )
    }
    
    private func determineWarningLevel() -> MemoryWarningLevel {
        let percentage = memoryUsagePercentage
        
        if percentage >= memoryThresholds.criticalThreshold {
            return .critical
        } else if percentage >= memoryThresholds.warningThreshold {
            return .warning
        } else {
            return .normal
        }
    }
    
    private func handleMemoryWarning() {
        print("⚠️ Memory warning received")
        memoryWarningLevel = .critical
        performMemoryCleanup()
        
        // Notify other services
        NotificationCenter.default.post(name: .memoryWarningReceived, object: nil)
    }
    
    private func clearImageCaches() {
        // Clear URLSession cache
        URLCache.shared.removeAllCachedResponses()
        
        // Clear any custom image caches
        // This would be implemented based on your image caching strategy
        print("🖼️ Image caches cleared")
    }
    
    private func clearTemporaryData() {
        // Clear temporary files
        let tempDirectory = FileManager.default.temporaryDirectory
        do {
            let tempFiles = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            for file in tempFiles {
                try? FileManager.default.removeItem(at: file)
            }
            print("🗂️ Temporary data cleared")
        } catch {
            print("❌ Failed to clear temporary data: \(error)")
        }
    }
    
    private func triggerGarbageCollection() {
        // Force autoreleasepool drain
        autoreleasepool {
            // This helps release any pending autorelease objects
        }
    }
    
    private func getMemoryRecommendations() -> [String] {
        var recommendations: [String] = []
        
        switch memoryWarningLevel {
        case .normal:
            recommendations.append("Memory usage is normal")
            
        case .warning:
            recommendations.append("Consider reducing image quality")
            recommendations.append("Clear unnecessary cached data")
            recommendations.append("Limit background processing")
            
        case .critical:
            recommendations.append("Reduce app functionality")
            recommendations.append("Clear all caches immediately")
            recommendations.append("Disable non-essential features")
            recommendations.append("Consider restarting the app")
        }
        
        return recommendations
    }
}

// MARK: - Memory Models

public struct MemoryUsage {
    public let usedMemory: Double // in bytes
    public let virtualMemory: Double // in bytes
    public let timestamp: Date
    
    public init(usedMemory: Double = 0, virtualMemory: Double = 0, timestamp: Date = Date()) {
        self.usedMemory = usedMemory
        self.virtualMemory = virtualMemory
        self.timestamp = timestamp
    }
    
    public var usedMemoryMB: Double {
        return usedMemory / (1024 * 1024)
    }
    
    public var virtualMemoryMB: Double {
        return virtualMemory / (1024 * 1024)
    }
    
    public var formattedUsedMemory: String {
        return String(format: "%.1f MB", usedMemoryMB)
    }
    
    public var formattedVirtualMemory: String {
        return String(format: "%.1f MB", virtualMemoryMB)
    }
}

public struct DeviceMemoryInfo {
    public let totalMemory: Double // in bytes
    public let availableMemory: Double // in bytes
    
    public init(totalMemory: Double, availableMemory: Double) {
        self.totalMemory = totalMemory
        self.availableMemory = availableMemory
    }
    
    public var totalMemoryGB: Double {
        return totalMemory / (1024 * 1024 * 1024)
    }
    
    public var availableMemoryMB: Double {
        return availableMemory / (1024 * 1024)
    }
    
    public var formattedTotalMemory: String {
        return String(format: "%.1f GB", totalMemoryGB)
    }
    
    public var formattedAvailableMemory: String {
        return String(format: "%.1f MB", availableMemoryMB)
    }
}

public enum MemoryWarningLevel: String, CaseIterable {
    case normal = "normal"
    case warning = "warning"
    case critical = "critical"
    
    public var displayName: String {
        return rawValue.capitalized
    }
    
    public var color: String {
        switch self {
        case .normal:
            return "green"
        case .warning:
            return "orange"
        case .critical:
            return "red"
        }
    }
}

public struct MemoryThresholds {
    public let warningThreshold: Double = 70.0 // 70% of device memory
    public let criticalThreshold: Double = 85.0 // 85% of device memory
}

public struct MemoryReport {
    public let currentUsage: MemoryUsage
    public let deviceInfo: DeviceMemoryInfo
    public let warningLevel: MemoryWarningLevel
    public let recommendations: [String]
    
    public init(
        currentUsage: MemoryUsage,
        deviceInfo: DeviceMemoryInfo,
        warningLevel: MemoryWarningLevel,
        recommendations: [String]
    ) {
        self.currentUsage = currentUsage
        self.deviceInfo = deviceInfo
        self.warningLevel = warningLevel
        self.recommendations = recommendations
    }
}

// MARK: - Notification Extensions

public extension Notification.Name {
    static let memoryWarningReceived = Notification.Name("memoryWarningReceived")
    static let memoryCleanupPerformed = Notification.Name("memoryCleanupPerformed")
}
