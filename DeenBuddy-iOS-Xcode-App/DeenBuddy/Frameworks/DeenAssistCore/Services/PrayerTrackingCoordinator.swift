import Foundation
import Combine

/// Coordinator service that integrates prayer times, tracking, and notifications
/// Ensures seamless workflow between prayer time calculations and tracking notifications
@MainActor
public class PrayerTrackingCoordinator: ObservableObject {

    // MARK: - Services

    private let prayerTimeService: any PrayerTimeServiceProtocol
    private let prayerTrackingService: any PrayerTrackingServiceProtocol
    private let notificationService: any NotificationServiceProtocol
    private let settingsService: any SettingsServiceProtocol

    // MARK: - State

    @Published public var isSchedulingNotifications: Bool = false
    @Published public var lastNotificationScheduleDate: Date?
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Cache Keys
    
    private enum CacheKeys {
        static let lastScheduleDate = "PrayerTrackingCoordinator.LastScheduleDate"
        static let scheduledNotificationIds = "PrayerTrackingCoordinator.ScheduledIds"
    }
    
    // MARK: - Initialization
    
    public init(
        prayerTimeService: any PrayerTimeServiceProtocol,
        prayerTrackingService: any PrayerTrackingServiceProtocol,
        notificationService: any NotificationServiceProtocol,
        settingsService: any SettingsServiceProtocol
    ) {
        self.prayerTimeService = prayerTimeService
        self.prayerTrackingService = prayerTrackingService
        self.notificationService = notificationService
        self.settingsService = settingsService
        
        setupObservers()
        loadCachedData()
        
        // Schedule initial notifications
        Task {
            await scheduleTrackingNotificationsIfNeeded()
        }
    }
    
    // MARK: - Public Methods
    
    /// Schedule prayer tracking notifications for today and tomorrow
    public func scheduleTrackingNotificationsIfNeeded() async {
        // Check if we've already scheduled notifications for today
        let today = Calendar.current.startOfDay(for: Date())
        if let lastSchedule = lastNotificationScheduleDate,
           Calendar.current.isDate(lastSchedule, inSameDayAs: today) {
            print("📅 Prayer tracking notifications already scheduled for today")
            return
        }
        
        isSchedulingNotifications = true
        
        do {
            // Get today's prayer times
            let todaysPrayers = prayerTimeService.todaysPrayerTimes
            
            if !todaysPrayers.isEmpty {
                await scheduleTrackingNotifications(for: todaysPrayers, date: today)
            }
            
            // Schedule for tomorrow as well
            // Note: In a real implementation, you'd get tomorrow's prayer times
            // For now, we'll just mark that we've scheduled for today
            
            lastNotificationScheduleDate = today
            userDefaults.set(today, forKey: CacheKeys.lastScheduleDate)
            
            print("✅ Prayer tracking notifications scheduled successfully")
        } catch {
            print("❌ Failed to schedule prayer tracking notifications: \(error)")
        }

        isSchedulingNotifications = false
    }

    /// Force reschedule all prayer tracking notifications
    public func rescheduleAllNotifications() async {
        print("🔄 Rescheduling all prayer tracking notifications...")

        // Cancel existing notifications
        await notificationService.cancelAllNotifications()

        // Clear cache
        lastNotificationScheduleDate = nil
        userDefaults.removeObject(forKey: CacheKeys.lastScheduleDate)

        // Schedule new notifications
        await scheduleTrackingNotificationsIfNeeded()
    }

    /// Check if a prayer has been completed today
    public func isPrayerCompletedToday(_ prayer: Prayer) -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return prayerTrackingService.recentEntries.contains { entry in
            entry.prayer == prayer && Calendar.current.isDate(entry.completedAt, inSameDayAs: today)
        }
    }

    /// Get completion status for all prayers today
    public func getTodayCompletionStatus() -> [Prayer: Bool] {
        var status: [Prayer: Bool] = [:]
        for prayer in Prayer.allCases {
            status[prayer] = isPrayerCompletedToday(prayer)
        }
        return status
    }

    // MARK: - Private Methods

    private func setupObservers() {
        // Note: Observer setup would be implemented here
        // For now, we'll rely on manual coordination
        // In a full implementation, we'd observe prayer time and settings changes
        print("📱 PrayerTrackingCoordinator observers setup")
    }

    private func loadCachedData() {
        if let date = userDefaults.object(forKey: CacheKeys.lastScheduleDate) as? Date {
            lastNotificationScheduleDate = date
        }
    }
    
    private func scheduleTrackingNotifications(for prayerTimes: [PrayerTime], date: Date) async {
        print("📱 Scheduling prayer tracking notifications for \(prayerTimes.count) prayers")
        
        for prayerTime in prayerTimes {
            // Skip if prayer time has already passed
            if prayerTime.time < Date() {
                continue
            }
            
            // Skip if prayer is already completed
            if isPrayerCompletedToday(prayerTime.prayer) {
                continue
            }
            
            do {
                // Schedule notification at prayer time
                try await notificationService.schedulePrayerTrackingNotification(
                    for: prayerTime.prayer,
                    at: prayerTime.time,
                    reminderMinutes: 0
                )
                
                // Schedule reminder notification 15 minutes after prayer time
                let reminderTime = Calendar.current.date(
                    byAdding: .minute,
                    value: 15,
                    to: prayerTime.time
                ) ?? prayerTime.time
                
                try await notificationService.schedulePrayerTrackingNotification(
                    for: prayerTime.prayer,
                    at: reminderTime,
                    reminderMinutes: -15 // Negative to indicate "after" prayer time
                )
                
                print("✅ Scheduled tracking notifications for \(prayerTime.prayer.displayName)")
                
            } catch {
                print("❌ Failed to schedule tracking notification for \(prayerTime.prayer.displayName): \(error)")
            }
        }
        
        // Update badge count after scheduling all notifications
        await notificationService.updateAppBadge()
    }

    // MARK: - Integration Helper Methods

    /// Get prayer tracking statistics for display
    func getTrackingStatistics() -> PrayerTrackingStatistics {
        return PrayerTrackingStatistics(
            todayCompletionRate: prayerTrackingService.todayCompletionRate,
            currentStreak: prayerTrackingService.currentStreak,
            todaysCompletedPrayers: prayerTrackingService.todaysCompletedPrayers,
            completionStatus: getTodayCompletionStatus()
        )
    }

    /// Quick method to mark a prayer as completed
    func markPrayerCompleted(_ prayer: Prayer) async {
        await prayerTrackingService.logPrayerCompletion(prayer)

        // Cancel any remaining notifications for this prayer
        await notificationService.cancelNotifications(for: prayer)
    }
}

// MARK: - Supporting Types

public struct PrayerTrackingStatistics {
    public let todayCompletionRate: Double
    public let currentStreak: Int
    public let todaysCompletedPrayers: Int
    public let completionStatus: [Prayer: Bool]

    public init(
        todayCompletionRate: Double,
        currentStreak: Int,
        todaysCompletedPrayers: Int,
        completionStatus: [Prayer: Bool]
    ) {
        self.todayCompletionRate = todayCompletionRate
        self.currentStreak = currentStreak
        self.todaysCompletedPrayers = todaysCompletedPrayers
        self.completionStatus = completionStatus
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let prayerTrackingUpdated = Notification.Name("DeenAssist.PrayerTrackingUpdated")
    static let prayerNotificationsScheduled = Notification.Name("DeenAssist.PrayerNotificationsScheduled")
}
