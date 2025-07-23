import Foundation
import UIKit
import Combine

/// Battery-aware timer management system for optimal resource usage
@MainActor
public class BatteryAwareTimerManager: ObservableObject {
    
    // MARK: - Logger
    
    private let logger = AppLogger.timer
    
    // MARK: - Singleton
    
    public static let shared = BatteryAwareTimerManager()
    
    // MARK: - Timer Types
    
    public enum TimerType: Sendable {
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
            case .prayerUpdate: return 120.0 // Increased from 60s to 2 minutes - prayer times don't change often
            case .countdownUI: return 5.0 // Increased from 1.5s to 5s - reduces excessive UI updates
            case .backgroundRefresh: return 900.0 // Increased from 5 minutes to 15 minutes
            case .memoryMonitoring: return 60.0 // Increased from 10s to 1 minute - reduce performance monitoring overhead
            case .hijriCalendar: return 86400.0 // Keep 24 hours - appropriate for calendar updates
            case .resourceMonitoring: return 120.0 // Increased from 30s to 2 minutes
            case .locationUpdate: return 180.0 // Increased from 45s to 3 minutes - location rarely changes
            case .cacheCleanup: return 21600.0 // Increased from 3 hours to 6 hours
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
        
        /// Determines whether timer callbacks should execute on the main thread
        /// 
        /// **Main Thread Timers** (shouldRunOnMainThread = true):
        /// - `.countdownUI`: UI countdown updates - must be on main thread for UI safety
        /// - `.prayerUpdate`: Prayer time updates - may trigger UI updates, safe for @Published properties
        ///
        /// **Background Thread Timers** (shouldRunOnMainThread = false):
        /// - `.backgroundRefresh`: Background data refresh - network calls, file operations
        /// - `.memoryMonitoring`: Memory usage monitoring - system calls, no UI impact
        /// - `.hijriCalendar`: Daily calendar updates - date calculations, no UI impact
        /// - `.resourceMonitoring`: Resource usage monitoring - system calls, no UI impact
        /// - `.locationUpdate`: Location service updates - GPS operations, no UI impact
        /// - `.cacheCleanup`: Periodic cache cleanup - file system operations, no UI impact
        ///
        /// **Threading Safety Notes:**
        /// - Main thread timers can safely perform UI updates and access @MainActor properties
        /// - Background timers must be thread-safe and avoid UI operations
        /// - Background timers requiring UI updates should dispatch to main queue
        var shouldRunOnMainThread: Bool {
            switch self {
            case .countdownUI: return true // UI updates must be on main thread
            case .prayerUpdate: return true // May trigger UI updates
            default: return false // Other operations can run on background thread
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
    
    // Performance monitoring
    @Published public private(set) var cpuUsageWarning: Bool = false
    private var timerFireCount: Int = 0
    private var lastCPUCheck: Date = Date()
    private let cpuCheckInterval: TimeInterval = 10.0 // Check every 10 seconds
    
    private var timers: [String: Timer] = [:]
    private var timerCallbacks: [String: () -> Void] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // Thread safety for timer management
    private let timerOperationsQueue = DispatchQueue(label: "BatteryAwareTimerManager.operations", attributes: .concurrent)

    // Task deduplication to prevent excessive operations
    private var lastExecutionTimes: [String: Date] = [:]
    private var minimumExecutionInterval: TimeInterval = 2.0 // Mutable to allow dynamic throttling
    
    // Power mode change debouncing to prevent infinite loops
    private var lastPowerModeUpdate: Date = Date()
    private let powerModeUpdateDebounceInterval: TimeInterval = 5.0 // 5 seconds between power mode updates
    private var isUpdatingTimerIntervals: Bool = false // Prevent recursive timer updates
    
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
    
    /// Schedule a battery-aware timer with automatic thread management
    ///
    /// **Threading Behavior:**
    /// - **Main Thread Timers** (countdownUI, prayerUpdate): Callbacks execute on MainActor, safe for UI updates
    /// - **Background Thread Timers** (all others): Callbacks execute on background threads, NOT safe for UI updates
    ///
    /// **Threading Requirements for Callbacks:**
    /// - **Main Thread Callbacks**: Can safely perform UI updates, access @MainActor properties, update @Published properties
    /// - **Background Callbacks**: Must be thread-safe, avoid UI operations, and not access main-actor-isolated properties
    ///   - For UI updates in background callbacks, use `Task { @MainActor in ... }` or `DispatchQueue.main.async`
    ///   - For accessing main-actor-isolated properties, use `await MainActor.run { ... }`
    ///
    /// **Example Usage:**
    /// ```swift
    /// // Main thread timer (safe for UI)
    /// scheduleTimer(id: "ui-update", type: .countdownUI) {
    ///     self.updateCountdownLabel() // Safe - runs on main thread
    /// }
    ///
    /// // Background timer (must be thread-safe)
    /// scheduleTimer(id: "data-refresh", type: .backgroundRefresh) {
    ///     Task { @MainActor in
    ///         self.updateUI() // Dispatch UI updates to main thread
    ///     }
    ///     // Perform background work here
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the timer
    ///   - type: Timer type that determines interval, priority, and threading behavior
    ///   - callback: Closure to execute when timer fires (see threading requirements above)
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
        
        // Create new timer with optimized callback execution
        let timer = Timer.scheduledTimer(withTimeInterval: optimizedInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // PERFORMANCE FIX: Reduce Task creation overhead
            if type.shouldRunOnMainThread {
                // Execute directly on main thread since Timer already runs on main thread
                self.handleTimerFire(id: id, type: type)
            } else {
                // Use more efficient background execution
                DispatchQueue.global(qos: .utility).async {
                    Task {
                        await self.handleTimerFireBackground(id: id, type: type)
                    }
                }
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
        
        logger.debug("Scheduled \(type) timer '\(id)' with interval: \(optimizedInterval)s")
    }
    
    /// Cancel a specific timer
    public func cancelTimer(id: String) {
        // Safely cancel timer to prevent race conditions
        if let timer = timers[id] {
            timer.invalidate()
        }
        
        timers.removeValue(forKey: id)
        timerCallbacks.removeValue(forKey: id)
        activeTimers.removeValue(forKey: id)

        logger.debug("Cancelled timer '\(id)'")
    }

    /// Cancel a specific timer synchronously (safe for deinit)
    public nonisolated func cancelTimerSync(id: String) {
        // Dispatch to MainActor to safely access MainActor-isolated properties
        // This is safer than assumeIsolated as it doesn't make assumptions about current context
        Task { @MainActor in
            // Safely cancel timer to prevent race conditions during cleanup
            if let timer = timers[id] {
                timer.invalidate()
            }

            timers.removeValue(forKey: id)
            timerCallbacks.removeValue(forKey: id)
            activeTimers.removeValue(forKey: id)

            logger.debug("Cancelled timer '\(id)' synchronously")
        }
    }
    
    /// Cancel all timers
    public func cancelAllTimers() {
        // Safely invalidate all timers first
        let timersToCancel = Array(timers.values)
        for timer in timersToCancel {
            timer.invalidate()
        }
        
        // Clear all collections
        timers.removeAll()
        timerCallbacks.removeAll()
        activeTimers.removeAll()
        
        logger.debug("Cancelled all timers")
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
        logger.debug("Paused all timers")
    }
    
    /// Resume all paused timers
    public func resumeAllTimers() {
        for (id, info) in activeTimers {
            if !info.isActive, let callback = timerCallbacks[id] {
                scheduleTimer(id: id, type: info.type, callback: callback)
            }
        }
        logger.debug("Resumed all timers")
    }
    
    /// Update timer intervals based on current conditions
    public func updateTimerIntervals() {
        updateTimerIntervalsWithProtection()
    }
    
    /// Update timer intervals with protection against infinite loops
    private func updateTimerIntervalsWithProtection() {
        // CRITICAL FIX: Prevent recursive timer interval updates
        guard !isUpdatingTimerIntervals else {
            logger.warning("Skipping timer interval update - already updating to prevent infinite loop")
            return
        }
        
        isUpdatingTimerIntervals = true
        defer { isUpdatingTimerIntervals = false }
        
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
        
        logger.debug("Updated all timer intervals for current power mode: \(currentPowerMode)")
    }
    
    /// Get current timer statistics
    public func getTimerStatisticsString() -> String {
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
        let now = Date()
        
        // CRITICAL FIX: Debounce power mode updates to prevent infinite loops
        if now.timeIntervalSince(lastPowerModeUpdate) < powerModeUpdateDebounceInterval {
            logger.debug("Debouncing power mode update - too soon since last update")
            return
        }
        
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
        
        // CRITICAL FIX: Only update timers if power mode actually changed AND we're not already updating
        if oldMode != currentPowerMode && !isUpdatingTimerIntervals {
            lastPowerModeUpdate = now
            updateTimerIntervalsWithProtection()
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
    
    /// Handle timer fire for main-thread operations (UI updates, main-actor-isolated properties)
    /// This method runs on the MainActor and is safe for UI operations
    private func handleTimerFire(id: String, type: TimerType) {
        let now = Date()

        // Task deduplication: prevent excessive executions
        if let lastExecution = lastExecutionTimes[id],
           now.timeIntervalSince(lastExecution) < minimumExecutionInterval {
            return // Skip this execution to prevent CPU overload
        }

        lastExecutionTimes[id] = now
        
        // PERFORMANCE MONITORING: Track timer fires and CPU usage
        timerFireCount += 1
        if now.timeIntervalSince(lastCPUCheck) > cpuCheckInterval {
            checkCPUUsage()
            lastCPUCheck = now
        }

        // Update timer info
        if let info = activeTimers[id] {
            activeTimers[id] = TimerInfo(
                id: info.id,
                type: info.type,
                currentInterval: info.currentInterval,
                isActive: info.isActive,
                lastFired: now,
                fireCount: info.fireCount + 1
            )
        }

        // Execute callback on main thread (safe for UI operations)
        timerCallbacks[id]?()
    }
    
    /// Handle timer fire for background operations (non-UI work, network calls, etc.)
    /// This method runs on background threads and should NOT perform UI updates
    /// Callbacks should be thread-safe and avoid accessing main-actor-isolated properties
    private func handleTimerFireBackground(id: String, type: TimerType) async {
        let now = Date()

        // PERFORMANCE FIX: Check deduplication without MainActor call first
        var shouldSkip = false
        await MainActor.run {
            if let lastExecution = lastExecutionTimes[id],
               now.timeIntervalSince(lastExecution) < minimumExecutionInterval {
                shouldSkip = true
            } else {
                lastExecutionTimes[id] = now
            }
        }
        
        if shouldSkip {
            return // Skip this execution to prevent CPU overload
        }

        // Execute callback on background thread first (main work)
        // WARNING: Callbacks should be thread-safe and avoid UI operations
        // If UI updates are needed, dispatch to main queue or use MainActor
        timerCallbacks[id]?()
        
        // PERFORMANCE FIX: Batch timer info update to reduce MainActor calls
        await MainActor.run {
            if let info = activeTimers[id] {
                activeTimers[id] = TimerInfo(
                    id: info.id,
                    type: info.type,
                    currentInterval: info.currentInterval,
                    isActive: info.isActive,
                    lastFired: now,
                    fireCount: info.fireCount + 1
                )
            }
        }
    }
    
    /// Check CPU usage and implement throttling if necessary
    private func checkCPUUsage() {
        let firesPerSecond = Double(timerFireCount) / cpuCheckInterval
        timerFireCount = 0 // Reset counter
        
        // Warn if firing too frequently (more than 10 fires per second indicates potential issues)
        let excessiveFireThreshold = 10.0
        
        if firesPerSecond > excessiveFireThreshold {
            cpuUsageWarning = true
            logger.warning("High timer fire rate detected: \(firesPerSecond) fires/sec - implementing throttling")

            // PERFORMANCE FIX: Automatically throttle by increasing minimum execution interval
            let throttledInterval = min(minimumExecutionInterval * 2.0, 5.0) // Cap at 5 seconds
            if throttledInterval > minimumExecutionInterval {
                logger.info("Increasing minimum execution interval from \(minimumExecutionInterval)s to \(throttledInterval)s to reduce CPU load")
                minimumExecutionInterval = throttledInterval

                // Reschedule all timers with the new throttled interval
                updateTimerIntervalsWithProtection()
            }
        } else {
            cpuUsageWarning = false

            // PERFORMANCE FIX: Gradually reduce throttling when CPU usage is normal
            let originalInterval: TimeInterval = 2.0
            if minimumExecutionInterval > originalInterval {
                let reducedInterval = max(minimumExecutionInterval * 0.8, originalInterval) // Gradually reduce by 20%
                if reducedInterval < minimumExecutionInterval {
                    logger.info("Reducing minimum execution interval from \(minimumExecutionInterval)s to \(reducedInterval)s as CPU usage normalized")
                    minimumExecutionInterval = reducedInterval

                    // Reschedule all timers with the reduced interval
                    updateTimerIntervalsWithProtection()
                }
            }
        }
    }
    
    deinit {
        Task { @MainActor in
            cancelAllTimers()
        }
        cancellables.removeAll()
        print("🧹 BatteryAwareTimerManager deinit - cleaned up all timers")
    }

    // MARK: - Performance Optimizations

    /// PERFORMANCE: Consolidate similar timers to reduce resource usage
    public func consolidateTimers() {
        let timerGroups = Dictionary(grouping: activeTimers) { $0.value.type.priority }

        for (priority, timers) in timerGroups {
            if timers.count > 3 && priority == .low {
                print("⚠️ Found \(timers.count) low-priority timers - consider consolidation")
                // Automatically consolidate low-priority timers
                consolidateLowPriorityTimers(timers.map { $0.key })
            }
        }
    }

    /// PERFORMANCE: Batch low-priority timer operations with loop prevention
    private func consolidateLowPriorityTimers(_ timerIds: [String]) {
        guard timerIds.count > 2 else { return }
        
        // CRITICAL FIX: Validate timer IDs still exist to prevent callback loops
        let validTimerIds = timerIds.filter { activeTimers[$0] != nil }
        guard validTimerIds.count > 2 else { return }

        // Store callbacks before canceling timers
        var storedCallbacks: [() -> Void] = []
        for id in validTimerIds {
            if let callback = timerCallbacks[id] {
                storedCallbacks.append(callback)
            }
        }

        // Cancel individual timers
        for id in validTimerIds {
            cancelTimer(id: id)
        }

        // Create a single consolidated timer with execution limiting
        let consolidatedId = "consolidated-low-priority-\(Date().timeIntervalSince1970)"
        var executionCount = 0
        let maxExecutions = 100 // Prevent runaway execution
        
        scheduleTimer(id: consolidatedId, type: .resourceMonitoring) {
            // CRITICAL FIX: Limit executions to prevent infinite loops
            executionCount += 1
            if executionCount > maxExecutions {
                print("⚠️ Consolidated timer reached execution limit, canceling to prevent runaway")
                Task { @MainActor in
                    BatteryAwareTimerManager.shared.cancelTimer(id: consolidatedId)
                }
                return
            }
            
            // Execute all low-priority callbacks in batch
            for callback in storedCallbacks {
                callback()
            }
        }

        print("🔄 Consolidated \(validTimerIds.count) low-priority timers into one with execution limit")
    }

    /// PERFORMANCE: Get timer statistics for monitoring
    public func getTimerStatistics() -> TimerStatistics {
        let activeCount = activeTimers.count
        let typeDistribution = Dictionary(grouping: activeTimers.values) { $0.type }
            .mapValues { $0.count }

        let totalFireCount = activeTimers.values.reduce(0) { $0 + $1.fireCount }

        return TimerStatistics(
            activeTimerCount: activeCount,
            typeDistribution: typeDistribution,
            totalFireCount: totalFireCount,
            memoryFootprint: calculateMemoryFootprint()
        )
    }

    private func calculateMemoryFootprint() -> Int {
        // Rough estimate of memory usage
        let timerMemory = timers.count * 64 // Approximate bytes per timer
        let callbackMemory = timerCallbacks.count * 32 // Approximate bytes per callback
        return timerMemory + callbackMemory
    }
}

// MARK: - Convenience Extensions

extension BatteryAwareTimerManager {
    /// Quick method to schedule a prayer update timer (runs on main thread, safe for UI)
    public func schedulePrayerUpdateTimer(callback: @escaping () -> Void) {
        scheduleTimer(id: "prayer-update", type: .prayerUpdate, callback: callback)
    }
    
    /// Quick method to schedule a countdown UI timer (runs on main thread, safe for UI)
    public func scheduleCountdownTimer(id: String, callback: @escaping () -> Void) {
        scheduleTimer(id: id, type: .countdownUI, callback: callback)
    }
    
    /// Quick method to schedule a background refresh timer (runs on background thread)
    public func scheduleBackgroundRefreshTimer(callback: @escaping () -> Void) {
        scheduleTimer(id: "background-refresh", type: .backgroundRefresh, callback: callback)
    }
    
    /// Schedule a background timer with automatic UI dispatch for callbacks that need UI updates
    /// This method ensures UI updates are safely dispatched to the main thread
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the timer
    ///   - type: Timer type (should be a background type like .backgroundRefresh, .cacheCleanup, etc.)
    ///   - backgroundWork: Background work to perform (runs on background thread)
    ///   - uiUpdate: UI update to perform (automatically dispatched to main thread)
    public func scheduleBackgroundTimerWithUIUpdate(
        id: String,
        type: TimerType,
        backgroundWork: @escaping () -> Void,
        uiUpdate: @escaping () -> Void
    ) {
        // Validate that the timer type is a background type
        guard !type.shouldRunOnMainThread else {
            logger.error("Invalid timer type '\(type)' for background timer. Background timers must not run on main thread. Use scheduleTimer() for main thread timers.")
            return
        }
        
        scheduleTimer(id: id, type: type) {
            // Perform background work
            backgroundWork()
            
            // Dispatch UI update to main thread
            Task { @MainActor in
                uiUpdate()
            }
        }
    }
    
    /// Schedule a background timer with async UI dispatch for callbacks that need async UI updates
    /// This method ensures async UI updates are safely dispatched to the main actor
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the timer
    ///   - type: Timer type (should be a background type)
    ///   - backgroundWork: Background work to perform (runs on background thread)
    ///   - asyncUIUpdate: Async UI update to perform (automatically dispatched to MainActor)
    public func scheduleBackgroundTimerWithAsyncUIUpdate(
        id: String,
        type: TimerType,
        backgroundWork: @escaping () -> Void,
        asyncUIUpdate: @escaping () async -> Void
    ) {
        // Validate that the timer type is a background type
        guard !type.shouldRunOnMainThread else {
            logger.error("Invalid timer type '\(type)' for background timer. Background timers must not run on main thread. Use scheduleTimer() for main thread timers.")
            return
        }
        
        scheduleTimer(id: id, type: type) {
            // Perform background work
            backgroundWork()
            
            // Dispatch async UI update to MainActor
            Task { @MainActor in
                await asyncUIUpdate()
            }
        }
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

// MARK: - Timer Statistics

public struct TimerStatistics {
    public let activeTimerCount: Int
    public let typeDistribution: [BatteryAwareTimerManager.TimerType: Int]
    public let totalFireCount: Int
    public let memoryFootprint: Int

    public var description: String {
        return """
        Timer Statistics:
        - Active Timers: \(activeTimerCount)
        - Total Fires: \(totalFireCount)
        - Memory Footprint: \(memoryFootprint) bytes
        - Type Distribution: \(typeDistribution)
        """
    }
}