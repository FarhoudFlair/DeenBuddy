import Foundation
import UIKit
import Combine

/// Battery-aware timer management system for optimal resource usage
@MainActor
public class BatteryAwareTimerManager: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = BatteryAwareTimerManager()
    
    // MARK: - Timer Types
    
    public enum TimerType {
        case prayerUpdate       // Update prayer times every minute
        case countdownUI        // UI countdown updates
        case backgroundRefresh  // Background data refresh
        case memoryMonitoring   // Memory usage monitoring
        case hijriCalendar     // Daily calendar updates
        case resourceMonitoring // Resource usage monitoring
        case locationUpdate     // Location service updates
        case cacheCleanup      // Periodic cache cleanup
        
        var baseInterval: TimeInterval {
            switch self {
            case .prayerUpdate: return 60.0
            case .countdownUI: return 1.0
            case .backgroundRefresh: return 300.0 // 5 minutes
            case .memoryMonitoring: return 5.0
            case .hijriCalendar: return 86400.0 // 24 hours
            case .resourceMonitoring: return 10.0
            case .locationUpdate: return 30.0
            case .cacheCleanup: return 3600.0 // 1 hour
            }
        }
        
        var priority: TimerPriority {
            switch self {
            case .prayerUpdate: return .high
            case .countdownUI: return .medium
            case .backgroundRefresh: return .low
            case .memoryMonitoring: return .low
            case .hijriCalendar: return .low
            case .resourceMonitoring: return .low
            case .locationUpdate: return .medium
            case .cacheCleanup: return .veryLow
            }
        }
    }
    
    public enum TimerPriority {
        case high, medium, low, veryLow
        
        var multiplier: Double {
            switch self {
            case .high: return 1.0
            case .medium: return 1.5
            case .low: return 2.0
            case .veryLow: return 3.0
            }
        }
    }
    
    public enum PowerMode {
        case normal, lowPower, extreme
        
        var globalMultiplier: Double {
            switch self {
            case .normal: return 1.0
            case .lowPower: return 2.0
            case .extreme: return 4.0
            }
        }
    }
    
    // MARK: - Properties
    
    @Published public private(set) var currentPowerMode: PowerMode = .normal
    @Published public private(set) var activeTimers: [String: TimerInfo] = [:]
    @Published public private(set) var isBackgroundMode: Bool = false
    @Published public private(set) var isLowPowerModeEnabled: Bool = false
    
    private var timers: [String: Timer] = [:]
    private var timerCallbacks: [String: () -> Void] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Timer Info
    
    public struct TimerInfo {
        let id: String
        let type: TimerType
        let currentInterval: TimeInterval
        let isActive: Bool
        let lastFired: Date?
        let fireCount: Int
        
        public init(id: String, type: TimerType, currentInterval: TimeInterval, isActive: Bool, lastFired: Date? = nil, fireCount: Int = 0) {
            self.id = id
            self.type = type
            self.currentInterval = currentInterval
            self.isActive = isActive
            self.lastFired = lastFired
            self.fireCount = fireCount
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        setupPowerModeMonitoring()
        setupAppStateMonitoring()
        updatePowerMode()
    }
    
    // MARK: - Public Methods
    
    /// Schedule a battery-aware timer
    public func scheduleTimer(
        id: String,
        type: TimerType,
        callback: @escaping () -> Void
    ) {
        let optimizedInterval = getOptimizedInterval(for: type)
        
        // Cancel existing timer if present
        cancelTimer(id: id)
        
        // Store callback
        timerCallbacks[id] = callback
        
        // Create new timer
        let timer = Timer.scheduledTimer(withTimeInterval: optimizedInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleTimerFire(id: id, type: type)
            }
        }
        
        // Add to common run loop modes to continue during scrolling
        RunLoop.current.add(timer, forMode: .common)
        
        timers[id] = timer
        activeTimers[id] = TimerInfo(
            id: id,
            type: type,
            currentInterval: optimizedInterval,
            isActive: true,
            lastFired: nil,
            fireCount: 0
        )
        
        print("⏰ Scheduled \(type) timer '\(id)' with interval: \(optimizedInterval)s")
    }
    
    /// Cancel a specific timer
    public func cancelTimer(id: String) {
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
        timerCallbacks.removeValue(forKey: id)
        activeTimers.removeValue(forKey: id)
        
        print("⏰ Cancelled timer '\(id)'")
    }
    
    /// Cancel all timers
    public func cancelAllTimers() {
        for timer in timers.values {
            timer.invalidate()
        }
        timers.removeAll()
        timerCallbacks.removeAll()
        activeTimers.removeAll()
        
        print("⏰ Cancelled all timers")
    }
    
    /// Pause all timers (useful for background transitions)
    public func pauseAllTimers() {
        for (id, timer) in timers {
            timer.invalidate()
            if let info = activeTimers[id] {
                activeTimers[id] = TimerInfo(
                    id: info.id,
                    type: info.type,
                    currentInterval: info.currentInterval,
                    isActive: false,
                    lastFired: info.lastFired,
                    fireCount: info.fireCount
                )
            }
        }
        timers.removeAll()
        print("⏸️ Paused all timers")
    }
    
    /// Resume all paused timers
    public func resumeAllTimers() {
        for (id, info) in activeTimers {
            if !info.isActive, let callback = timerCallbacks[id] {
                scheduleTimer(id: id, type: info.type, callback: callback)
            }
        }
        print("▶️ Resumed all timers")
    }
    
    /// Update timer intervals based on current conditions
    public func updateTimerIntervals() {
        let currentTimers = timers
        let currentCallbacks = timerCallbacks
        
        // Cancel all timers
        cancelAllTimers()
        
        // Reschedule with new intervals
        for (id, callback) in currentCallbacks {
            if let info = activeTimers[id] {
                scheduleTimer(id: id, type: info.type, callback: callback)
            }
        }
        
        print("🔄 Updated all timer intervals for current power mode: \(currentPowerMode)")
    }
    
    /// Get current timer statistics
    public func getTimerStatistics() -> String {
        var stats = "Timer Statistics:\n"
        stats += "Power Mode: \(currentPowerMode)\n"
        stats += "Background Mode: \(isBackgroundMode)\n"
        stats += "Low Power Mode: \(isLowPowerModeEnabled)\n"
        stats += "Active Timers: \(activeTimers.count)\n\n"
        
        for (id, info) in activeTimers.sorted(by: { $0.key < $1.key }) {
            stats += "• \(id): \(info.type) - \(info.currentInterval)s"
            if let lastFired = info.lastFired {
                stats += " (last fired: \(lastFired.timeIntervalSinceNow.formatted(.number.precision(.fractionLength(1))))s ago)"
            }
            stats += " - \(info.fireCount) fires\n"
        }
        
        return stats
    }
    
    // MARK: - Private Methods
    
    private func setupPowerModeMonitoring() {
        // Monitor low power mode changes
        NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePowerMode()
            }
            .store(in: &cancellables)
    }
    
    private func setupAppStateMonitoring() {
        // Monitor app state changes
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAppWillEnterForeground()
            }
            .store(in: &cancellables)
    }
    
    private func updatePowerMode() {
        let oldMode = currentPowerMode
        
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        // Determine power mode based on multiple factors
        if isLowPowerModeEnabled {
            currentPowerMode = .lowPower
        } else if isBackgroundMode {
            currentPowerMode = .extreme
        } else {
            currentPowerMode = .normal
        }
        
        // Update timers if power mode changed
        if oldMode != currentPowerMode {
            updateTimerIntervals()
        }
    }
    
    private func handleAppDidEnterBackground() {
        isBackgroundMode = true
        updatePowerMode()
        
        // Pause non-essential timers in background
        pauseNonEssentialTimers()
    }
    
    private func handleAppWillEnterForeground() {
        isBackgroundMode = false
        updatePowerMode()
        
        // Resume all timers
        resumeAllTimers()
    }
    
    private func pauseNonEssentialTimers() {
        let nonEssentialTypes: [TimerType] = [.countdownUI, .memoryMonitoring, .resourceMonitoring]
        
        for (id, info) in activeTimers {
            if nonEssentialTypes.contains(info.type) {
                cancelTimer(id: id)
            }
        }
    }
    
    private func getOptimizedInterval(for type: TimerType) -> TimeInterval {
        let baseInterval = type.baseInterval
        let priorityMultiplier = type.priority.multiplier
        let powerMultiplier = currentPowerMode.globalMultiplier
        
        let optimizedInterval = baseInterval * priorityMultiplier * powerMultiplier
        
        // Ensure minimum and maximum intervals
        let minInterval = max(baseInterval * 0.5, 1.0)
        let maxInterval = baseInterval * 10.0
        
        return max(minInterval, min(maxInterval, optimizedInterval))
    }
    
    private func handleTimerFire(id: String, type: TimerType) {
        // Update timer info
        if let info = activeTimers[id] {
            activeTimers[id] = TimerInfo(
                id: info.id,
                type: info.type,
                currentInterval: info.currentInterval,
                isActive: info.isActive,
                lastFired: Date(),
                fireCount: info.fireCount + 1
            )
        }
        
        // Execute callback
        timerCallbacks[id]?()
    }
    
    deinit {
        Task { @MainActor in
            cancelAllTimers()
        }
        cancellables.removeAll()
    }
}

// MARK: - Convenience Extensions

extension BatteryAwareTimerManager {
    /// Quick method to schedule a prayer update timer
    public func schedulePrayerUpdateTimer(callback: @escaping () -> Void) {
        scheduleTimer(id: "prayer-update", type: .prayerUpdate, callback: callback)
    }
    
    /// Quick method to schedule a countdown UI timer
    public func scheduleCountdownTimer(id: String, callback: @escaping () -> Void) {
        scheduleTimer(id: id, type: .countdownUI, callback: callback)
    }
    
    /// Quick method to schedule a background refresh timer
    public func scheduleBackgroundRefreshTimer(callback: @escaping () -> Void) {
        scheduleTimer(id: "background-refresh", type: .backgroundRefresh, callback: callback)
    }
}

// MARK: - Timer Type Conformances

extension BatteryAwareTimerManager.TimerType: Equatable {}
extension BatteryAwareTimerManager.TimerType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .prayerUpdate: return "Prayer Update"
        case .countdownUI: return "Countdown UI"
        case .backgroundRefresh: return "Background Refresh"
        case .memoryMonitoring: return "Memory Monitoring"
        case .hijriCalendar: return "Hijri Calendar"
        case .resourceMonitoring: return "Resource Monitoring"
        case .locationUpdate: return "Location Update"
        case .cacheCleanup: return "Cache Cleanup"
        }
    }
}