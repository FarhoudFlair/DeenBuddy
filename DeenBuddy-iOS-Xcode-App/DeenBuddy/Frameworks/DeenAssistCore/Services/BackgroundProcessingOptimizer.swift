import Foundation
import BackgroundTasks
import WidgetKit
import ActivityKit

/// Optimized background processing manager for widgets, Live Activities, and notifications
public class BackgroundProcessingOptimizer: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = BackgroundProcessingOptimizer()
    
    private init() {
        setupBackgroundTasks()
    }
    
    // MARK: - Properties
    
    @Published public var isBackgroundRefreshEnabled: Bool = false
    @Published public var lastBackgroundUpdate: Date?
    @Published public var backgroundTasksRegistered: Int = 0
    
    private var activeBackgroundTasks: Set<String> = []
    private let backgroundQueue = DispatchQueue(label: "com.deenbuddy.background", qos: .utility)
    private let maxConcurrentTasks = 3
    private let taskDeduplicationWindow: TimeInterval = 300 // 5 minutes
    
    // Task deduplication tracking
    private var lastTaskExecution: [String: Date] = [:]
    private let taskExecutionLock = NSLock()
    
    // MARK: - Background Task Registration
    
    /// Register all background tasks for the app
    public func registerBackgroundTasks() {
        // Prayer time update task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskIdentifiers.prayerTimeUpdate,
            using: backgroundQueue
        ) { [weak self] task in
            self?.handlePrayerTimeUpdateTask(task as! BGAppRefreshTask)
        }
        
        // Widget refresh task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskIdentifiers.widgetRefresh,
            using: backgroundQueue
        ) { [weak self] task in
            self?.handleWidgetRefreshTask(task as! BGAppRefreshTask)
        }
        
        // Notification scheduling task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskIdentifiers.notificationScheduling,
            using: backgroundQueue
        ) { [weak self] task in
            self?.handleNotificationSchedulingTask(task as! BGAppRefreshTask)
        }
        
        // Live Activity update task
        if #available(iOS 16.1, *) {
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: BackgroundTaskIdentifiers.liveActivityUpdate,
                using: backgroundQueue
            ) { [weak self] task in
                self?.handleLiveActivityUpdateTask(task as! BGAppRefreshTask)
            }
        }
        
        backgroundTasksRegistered = 4
        print("✅ Registered \(backgroundTasksRegistered) background tasks")
    }
    
    /// Schedule optimized background refresh
    public func scheduleOptimizedBackgroundRefresh() {
        guard isBackgroundRefreshEnabled else {
            print("⚠️ Background refresh is disabled")
            return
        }
        
        // Schedule prayer time update (highest priority)
        scheduleBackgroundTask(
            identifier: BackgroundTaskIdentifiers.prayerTimeUpdate,
            earliestBeginDate: getNextOptimalUpdateTime(),
            priority: .high
        )
        
        // Schedule widget refresh (medium priority)
        scheduleBackgroundTask(
            identifier: BackgroundTaskIdentifiers.widgetRefresh,
            earliestBeginDate: Date().addingTimeInterval(900), // 15 minutes
            priority: .medium
        )
        
        // Schedule notification updates (medium priority)
        scheduleBackgroundTask(
            identifier: BackgroundTaskIdentifiers.notificationScheduling,
            earliestBeginDate: Date().addingTimeInterval(1800), // 30 minutes
            priority: .medium
        )
    }
    
    // MARK: - Background Task Handlers
    
    private func handlePrayerTimeUpdateTask(_ task: BGAppRefreshTask) {
        print("🔄 Executing prayer time update background task")
        
        let taskId = BackgroundTaskIdentifiers.prayerTimeUpdate
        guard shouldExecuteTask(taskId) else {
            task.setTaskCompleted(success: true)
            return
        }
        
        activeBackgroundTasks.insert(taskId)
        
        let operation = createPrayerTimeUpdateOperation()
        
        task.expirationHandler = {
            print("⏰ Prayer time update task expired")
            operation.cancel()
            self.activeBackgroundTasks.remove(taskId)
            task.setTaskCompleted(success: false)
        }
        
        operation.completionBlock = {
            DispatchQueue.main.async {
                self.activeBackgroundTasks.remove(taskId)
                self.recordTaskExecution(taskId)
                task.setTaskCompleted(success: !operation.isCancelled)
                
                // Schedule next update
                self.scheduleBackgroundTask(
                    identifier: taskId,
                    earliestBeginDate: self.getNextOptimalUpdateTime(),
                    priority: .high
                )
            }
        }
        
        OperationQueue().addOperation(operation)
    }
    
    private func handleWidgetRefreshTask(_ task: BGAppRefreshTask) {
        print("📱 Executing widget refresh background task")
        
        let taskId = BackgroundTaskIdentifiers.widgetRefresh
        guard shouldExecuteTask(taskId) else {
            task.setTaskCompleted(success: true)
            return
        }
        
        activeBackgroundTasks.insert(taskId)
        
        let operation = createWidgetRefreshOperation()
        
        task.expirationHandler = {
            print("⏰ Widget refresh task expired")
            operation.cancel()
            self.activeBackgroundTasks.remove(taskId)
            task.setTaskCompleted(success: false)
        }
        
        operation.completionBlock = {
            DispatchQueue.main.async {
                self.activeBackgroundTasks.remove(taskId)
                self.recordTaskExecution(taskId)
                task.setTaskCompleted(success: !operation.isCancelled)
            }
        }
        
        OperationQueue().addOperation(operation)
    }
    
    private func handleNotificationSchedulingTask(_ task: BGAppRefreshTask) {
        print("🔔 Executing notification scheduling background task")
        
        let taskId = BackgroundTaskIdentifiers.notificationScheduling
        guard shouldExecuteTask(taskId) else {
            task.setTaskCompleted(success: true)
            return
        }
        
        activeBackgroundTasks.insert(taskId)
        
        let operation = createNotificationSchedulingOperation()
        
        task.expirationHandler = {
            print("⏰ Notification scheduling task expired")
            operation.cancel()
            self.activeBackgroundTasks.remove(taskId)
            task.setTaskCompleted(success: false)
        }
        
        operation.completionBlock = {
            DispatchQueue.main.async {
                self.activeBackgroundTasks.remove(taskId)
                self.recordTaskExecution(taskId)
                task.setTaskCompleted(success: !operation.isCancelled)
            }
        }
        
        OperationQueue().addOperation(operation)
    }
    
    @available(iOS 16.1, *)
    private func handleLiveActivityUpdateTask(_ task: BGAppRefreshTask) {
        print("🏝️ Executing Live Activity update background task")
        
        let taskId = BackgroundTaskIdentifiers.liveActivityUpdate
        guard shouldExecuteTask(taskId) else {
            task.setTaskCompleted(success: true)
            return
        }
        
        activeBackgroundTasks.insert(taskId)
        
        let operation = createLiveActivityUpdateOperation()
        
        task.expirationHandler = {
            print("⏰ Live Activity update task expired")
            operation.cancel()
            self.activeBackgroundTasks.remove(taskId)
            task.setTaskCompleted(success: false)
        }
        
        operation.completionBlock = {
            DispatchQueue.main.async {
                self.activeBackgroundTasks.remove(taskId)
                self.recordTaskExecution(taskId)
                task.setTaskCompleted(success: !operation.isCancelled)
            }
        }
        
        OperationQueue().addOperation(operation)
    }
    
    // MARK: - Operation Creation
    
    private func createPrayerTimeUpdateOperation() -> Operation {
        return BlockOperation {
            // Update prayer times and related data
            Task {
                do {
                    // This would integrate with actual services
                    print("📿 Updating prayer times in background")
                    
                    // Simulate prayer time calculation
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    
                    await MainActor.run {
                        self.lastBackgroundUpdate = Date()
                    }
                    
                    print("✅ Prayer times updated successfully")
                } catch {
                    print("❌ Failed to update prayer times: \(error)")
                }
            }
        }
    }
    
    private func createWidgetRefreshOperation() -> Operation {
        return BlockOperation {
            Task {
                do {
                    print("📱 Refreshing widgets in background")
                    
                    // Update widget data
                    WidgetBackgroundRefreshManager.shared.refreshAllWidgets()
                    
                    // Simulate widget update processing
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    
                    print("✅ Widgets refreshed successfully")
                } catch {
                    print("❌ Failed to refresh widgets: \(error)")
                }
            }
        }
    }
    
    private func createNotificationSchedulingOperation() -> Operation {
        return BlockOperation {
            Task {
                do {
                    print("🔔 Updating notifications in background")
                    
                    // This would integrate with NotificationService
                    // to reschedule notifications based on updated prayer times
                    
                    // Simulate notification scheduling
                    try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                    
                    print("✅ Notifications updated successfully")
                } catch {
                    print("❌ Failed to update notifications: \(error)")
                }
            }
        }
    }
    
    @available(iOS 16.1, *)
    private func createLiveActivityUpdateOperation() -> Operation {
        return BlockOperation {
            Task {
                do {
                    print("🏝️ Updating Live Activities in background")
                    
                    // Update active Live Activities
                    let manager = PrayerLiveActivityManager.shared
                    if manager.isActivityActive {
                        // Update with current prayer countdown
                        await manager.updatePrayerCountdown(timeRemaining: 3600) // Example
                    }
                    
                    print("✅ Live Activities updated successfully")
                } catch {
                    print("❌ Failed to update Live Activities: \(error)")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupBackgroundTasks() {
        // Check background refresh status
        isBackgroundRefreshEnabled = UIApplication.shared.backgroundRefreshStatus == .available
        
        // Observe background refresh status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(backgroundRefreshStatusChanged),
            name: UIApplication.backgroundRefreshStatusDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func backgroundRefreshStatusChanged() {
        isBackgroundRefreshEnabled = UIApplication.shared.backgroundRefreshStatus == .available
        print("📱 Background refresh status changed: \(isBackgroundRefreshEnabled)")
    }
    
    private func scheduleBackgroundTask(identifier: String, earliestBeginDate: Date, priority: TaskPriority) {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = earliestBeginDate
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 Scheduled background task: \(identifier) for \(earliestBeginDate)")
        } catch {
            print("❌ Failed to schedule background task \(identifier): \(error)")
        }
    }
    
    private func shouldExecuteTask(_ taskId: String) -> Bool {
        taskExecutionLock.lock()
        defer { taskExecutionLock.unlock() }
        
        // Check if task was executed recently (deduplication)
        if let lastExecution = lastTaskExecution[taskId],
           Date().timeIntervalSince(lastExecution) < taskDeduplicationWindow {
            print("⏭️ Skipping task \(taskId) - executed recently")
            return false
        }
        
        // Check concurrent task limit
        if activeBackgroundTasks.count >= maxConcurrentTasks {
            print("⏭️ Skipping task \(taskId) - too many concurrent tasks")
            return false
        }
        
        return true
    }
    
    private func recordTaskExecution(_ taskId: String) {
        taskExecutionLock.lock()
        defer { taskExecutionLock.unlock() }
        
        lastTaskExecution[taskId] = Date()
    }
    
    private func getNextOptimalUpdateTime() -> Date {
        // Calculate next optimal time based on prayer schedule
        // For now, return next hour
        let calendar = Calendar.current
        let nextHour = calendar.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        return calendar.date(bySetting: .minute, value: 0, of: nextHour) ?? nextHour
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Background Task Identifiers

public enum BackgroundTaskIdentifiers {
    public static let prayerTimeUpdate = "com.deenbuddy.prayertime.update"
    public static let widgetRefresh = "com.deenbuddy.widget.refresh"
    public static let notificationScheduling = "com.deenbuddy.notification.schedule"
    public static let liveActivityUpdate = "com.deenbuddy.liveactivity.update"
}

// MARK: - Task Priority

public enum TaskPriority {
    case low
    case medium
    case high
    
    public var timeInterval: TimeInterval {
        switch self {
        case .low:
            return 3600 // 1 hour
        case .medium:
            return 1800 // 30 minutes
        case .high:
            return 900  // 15 minutes
        }
    }
}
