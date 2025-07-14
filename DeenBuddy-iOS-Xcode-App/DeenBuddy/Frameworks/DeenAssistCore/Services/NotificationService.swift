import Foundation
import UserNotifications
import Combine
import UIKit

// MARK: - Notification Names

extension Notification.Name {
    static let settingsDidChange = Notification.Name("DeenAssist.SettingsDidChange")
    static let prayerMarkedAsPrayed = Notification.Name("DeenAssist.PrayerMarkedAsPrayed")
    static let openQiblaRequested = Notification.Name("DeenAssist.OpenQiblaRequested")
    static let openAppRequested = Notification.Name("DeenAssist.OpenAppRequested")
    static let notificationTapped = Notification.Name("DeenAssist.NotificationTapped")
    static let notificationDismissed = Notification.Name("DeenAssist.NotificationDismissed")
}

// MARK: - Notification Service Implementation

@MainActor
public class NotificationService: NSObject, NotificationServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published public var notificationsEnabled: Bool = true
    
    // MARK: - Publishers
    
    private let permissionSubject = PassthroughSubject<UNAuthorizationStatus, Never>()
    
    public var permissionPublisher: AnyPublisher<UNAuthorizationStatus, Never> {
        permissionSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties

    private let notificationCenter = UNUserNotificationCenter.current()
    private let userDefaults = UserDefaults.standard
    private var notificationSettings = NotificationSettings()

    // Memory leak prevention: Store observer tokens for proper cleanup
    private var settingsObserver: NSObjectProtocol?
    private var appLifecycleObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    // Observer management for memory leak prevention
    private static let maxObservers = 10
    private var observerCount = 0

    // MARK: - Settings Keys

    private enum SettingsKeys {
        static let notificationSettings = "DeenAssist.NotificationSettings"
        static let isEnabled = "DeenAssist.NotificationsEnabled"
    }
    
    // MARK: - Initialization

    public override init() {
        super.init()
        setupNotificationCenter()
        loadSettings()
        updatePermissionStatus()
        setupObservers()
    }

    deinit {
        // Remove specific observers to prevent memory leaks
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
            settingsObserver = nil
            observerCount = max(0, observerCount - 1)
        }

        if let observer = appLifecycleObserver {
            NotificationCenter.default.removeObserver(observer)
            appLifecycleObserver = nil
            observerCount = max(0, observerCount - 1)
        }

        // Cancel all Combine subscriptions
        cancellables.removeAll()

        print("🧹 NotificationService deinit - cleaned up \(observerCount) observers")
    }
    
    // MARK: - Protocol Implementation
    
    /// Request notification permission from user
    public func requestNotificationPermission() async throws -> Bool {
        let settings = await notificationCenter.notificationSettings()
        
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .denied:
            return false
        case .notDetermined:
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await updatePermissionStatus()
            return granted
        case .ephemeral:
            return false
        @unknown default:
            return false
        }
    }
    
    /// Schedules prayer notifications for the given prayer times with enhanced per-prayer configuration.
    /// - Parameters:
    ///   - prayerTimes: Array of PrayerTime objects for a specific date. If empty, only cancels notifications for the date provided.
    ///   - date: The date for which to cancel notifications if prayerTimes is empty. If nil, does nothing.
    public func schedulePrayerNotifications(for prayerTimes: [PrayerTime], date: Date? = nil) async throws {
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            throw NotificationError.permissionDenied
        }

        guard notificationsEnabled else {
            return
        }

        if let firstPrayerTime = prayerTimes.first {
            await cancelNotificationsForDate(firstPrayerTime.time)
        } else if let date = date {
            await cancelNotificationsForDate(date)
        } else {
            throw NotificationError.invalidParameters
        }

        // Schedule new notifications for each prayer with per-prayer configuration
        for prayerTime in prayerTimes {
            let prayerConfig = notificationSettings.configForPrayer(prayerTime.prayer)

            // Skip if prayer notifications are disabled
            guard prayerConfig.isEnabled else {
                print("Skipping notifications for \(prayerTime.prayer.displayName) - disabled in settings")
                continue
            }

            // Schedule multiple notifications based on reminder times
            for reminderMinutes in prayerConfig.reminderTimes {
                let notificationTime = Calendar.current.date(
                    byAdding: .minute,
                    value: -reminderMinutes,
                    to: prayerTime.time
                ) ?? prayerTime.time

                // Only schedule future notifications
                if notificationTime > Date() {
                    try await scheduleEnhancedNotification(
                        for: prayerTime.prayer,
                        prayerTime: prayerTime.time,
                        notificationTime: notificationTime,
                        reminderMinutes: reminderMinutes,
                        config: prayerConfig
                    )
                }
            }
        }
    }
    
    /// Enhanced notification scheduling with per-prayer configuration
    public func scheduleEnhancedNotification(
        for prayer: Prayer,
        prayerTime: Date,
        notificationTime: Date,
        reminderMinutes: Int,
        config: PrayerNotificationConfig
    ) async throws {
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            throw NotificationError.permissionDenied
        }

        guard notificationTime > Date() else {
            throw NotificationError.invalidDate
        }

        // Create unique identifier including reminder minutes to support multiple notifications per prayer
        let identifier = "\(prayer.rawValue)_\(prayerTime.timeIntervalSince1970)_\(reminderMinutes)min"

        // Create notification content with prayer-specific customization
        let content = UNMutableNotificationContent()
        content.title = config.customTitle ?? getNotificationTitle(for: prayer, reminderMinutes: reminderMinutes)
        content.body = config.customBody ?? getNotificationBody(for: prayer, reminderMinutes: reminderMinutes)
        content.categoryIdentifier = "PRAYER_REMINDER"
        content.userInfo = [
            "prayer": prayer.rawValue,
            "type": "prayer_reminder",
            "scheduled_time": notificationTime.timeIntervalSince1970,
            "prayer_time": prayerTime.timeIntervalSince1970,
            "reminder_minutes": reminderMinutes
        ]

        // Configure sound based on prayer-specific and global settings
        if config.soundEnabled && notificationSettings.globalSoundEnabled {
            if let soundName = config.soundName {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
            } else {
                content.sound = .default
            }
        } else {
            content.sound = nil
        }

        // Configure badge based on settings
        if config.badgeEnabled && notificationSettings.globalBadgeEnabled {
            content.badge = 1
        }

        // Create trigger
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        // Create request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
            let timingDesc = reminderMinutes == 0 ? "at prayer time" : "\(reminderMinutes) minutes before"
            print("Scheduled notification for \(prayer.displayName) \(timingDesc) at \(notificationTime)")
        } catch {
            throw NotificationError.schedulingFailed
        }
    }

    /// Legacy notification scheduling method for backward compatibility
    public func scheduleNotification(
        for prayer: Prayer,
        at time: Date,
        title: String?,
        body: String?
    ) async throws {
        // Use enhanced method with default configuration
        let config = PrayerNotificationConfig(
            customTitle: title,
            customBody: body
        )

        try await scheduleEnhancedNotification(
            for: prayer,
            prayerTime: time,
            notificationTime: time,
            reminderMinutes: 0,
            config: config
        )
    }
    
    public func cancelAllNotifications() async {
        notificationCenter.removeAllPendingNotificationRequests()
        print("Cancelled all prayer notifications")
    }
    
    public func cancelNotifications(for prayer: Prayer) async {
        let requests = await notificationCenter.pendingNotificationRequests()
        let identifiersToCancel = requests.compactMap { request -> String? in
            guard let prayerString = request.content.userInfo["prayer"] as? String,
                  prayerString == prayer.rawValue else {
                return nil
            }
            return request.identifier
        }
        
        if !identifiersToCancel.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
            print("Cancelled \(identifiersToCancel.count) notifications for \(prayer.displayName)")
        }
    }
    
    public func getPendingNotifications() async -> [PendingNotification] {
        let requests = await notificationCenter.pendingNotificationRequests()

        return requests.compactMap { request -> PendingNotification? in
            guard let prayerString = request.content.userInfo["prayer"] as? String,
                  let prayer = Prayer(rawValue: prayerString),
                  let trigger = request.trigger as? UNCalendarNotificationTrigger,
                  let scheduledDate = Calendar.current.date(from: trigger.dateComponents) else {
                return nil
            }

            // Extract enhanced metadata from userInfo
            let prayerTimeInterval = request.content.userInfo["prayer_time"] as? TimeInterval
            let reminderMinutes = request.content.userInfo["reminder_minutes"] as? Int ?? 0
            let prayerTime = prayerTimeInterval != nil ? Date(timeIntervalSince1970: prayerTimeInterval!) : scheduledDate

            // Extract sound settings
            let soundEnabled = request.content.sound != nil
            let soundName = (request.content.sound as? UNNotificationSound)?.description

            // Extract badge setting
            let badgeEnabled = request.content.badge != nil

            return PendingNotification(
                id: request.identifier,
                prayer: prayer,
                scheduledTime: scheduledDate,
                prayerTime: prayerTime,
                reminderMinutes: reminderMinutes,
                title: request.content.title,
                body: request.content.body,
                isActive: true,
                soundName: soundName,
                soundEnabled: soundEnabled,
                badgeEnabled: badgeEnabled
            )
        }.sorted { $0.scheduledTime < $1.scheduledTime }
    }
    
    public func isNotificationScheduled(for prayer: Prayer, date: Date) async -> Bool {
        let identifier = "\(prayer.rawValue)_\(date.timeIntervalSince1970)"
        let requests = await notificationCenter.pendingNotificationRequests()
        
        return requests.contains { $0.identifier == identifier }
    }
    
    public func updateNotificationSettings(_ settings: NotificationSettings) {
        notificationSettings = settings
        notificationsEnabled = settings.isEnabled
        saveSettings()
        
        print("Updated notification settings - enabled: \(settings.isEnabled), reminder: \(settings.reminderMinutes) minutes")
    }
    
    public func getNotificationSettings() -> NotificationSettings {
        return notificationSettings
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationCenter() {
        notificationCenter.delegate = self

        // Create enhanced notification actions
        let markPrayedAction = UNNotificationAction(
            identifier: "MARK_PRAYED",
            title: "Mark as Prayed",
            options: [.foreground],
            icon: UNNotificationActionIcon(systemImageName: "checkmark.circle.fill")
        )

        let snooze5Action = UNNotificationAction(
            identifier: "SNOOZE_5MIN",
            title: "Remind in 5 min",
            options: [],
            icon: UNNotificationActionIcon(systemImageName: "clock.fill")
        )

        let snooze10Action = UNNotificationAction(
            identifier: "SNOOZE_10MIN",
            title: "Remind in 10 min",
            options: [],
            icon: UNNotificationActionIcon(systemImageName: "clock.fill")
        )

        let openQiblaAction = UNNotificationAction(
            identifier: "OPEN_QIBLA",
            title: "Find Qibla",
            options: [.foreground],
            icon: UNNotificationActionIcon(systemImageName: "location.north.line.fill")
        )

        let openAppAction = UNNotificationAction(
            identifier: "OPEN_APP",
            title: "Open DeenBuddy",
            options: [.foreground],
            icon: UNNotificationActionIcon(systemImageName: "app.fill")
        )

        // Create notification categories
        let prayerReminderCategory = UNNotificationCategory(
            identifier: "PRAYER_REMINDER",
            actions: [markPrayedAction, snooze5Action, openQiblaAction],
            intentIdentifiers: [],
            options: [.customDismissAction, .allowInCarPlay]
        )

        let prayerTimeCategory = UNNotificationCategory(
            identifier: "PRAYER_TIME",
            actions: [markPrayedAction, snooze5Action, snooze10Action, openQiblaAction],
            intentIdentifiers: [],
            options: [.customDismissAction, .allowInCarPlay]
        )

        let islamicEventCategory = UNNotificationCategory(
            identifier: "ISLAMIC_EVENT",
            actions: [openAppAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        notificationCenter.setNotificationCategories([
            prayerReminderCategory,
            prayerTimeCategory,
            islamicEventCategory
        ])
    }

    /// Setup observers with proper memory leak prevention
    private func setupObservers() {
        // Check observer limits before adding new observers
        guard observerCount < Self.maxObservers else {
            print("❌ Failed to setup notification observers: observer limit reached")
            return
        }

        // Setup settings change observer
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .settingsDidChange,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleSettingsChange()
            }
        }

        if settingsObserver != nil {
            observerCount += 1
        }

        // Setup app lifecycle observer for permission status updates
        appLifecycleObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updatePermissionStatus()
            }
        }

        if appLifecycleObserver != nil {
            observerCount += 1
        }

        print("📱 NotificationService observers setup - active observers: \(observerCount)/\(Self.maxObservers)")
    }

    /// Handle settings changes that affect notifications
    private func handleSettingsChange() async {
        // Reload settings and reschedule notifications if needed
        loadSettings()

        // Note: In a real implementation, you might want to reschedule all notifications
        // when settings change, but this should be done carefully to avoid excessive rescheduling
        print("🔄 Notification settings updated due to settings change")
    }

    private func updatePermissionStatus() {
        Task {
            let settings = await notificationCenter.notificationSettings()
            
            let status = settings.authorizationStatus
            
            await MainActor.run {
                authorizationStatus = status
                permissionSubject.send(status)
            }
        }
    }
    
    /// Generate notification title based on prayer and timing
    private func getNotificationTitle(for prayer: Prayer, reminderMinutes: Int) -> String {
        if reminderMinutes == 0 {
            return "\(prayer.displayName) Prayer Time"
        } else {
            return "\(prayer.displayName) Prayer Reminder"
        }
    }

    /// Generate notification body based on prayer and timing with Islamic accuracy
    private func getNotificationBody(for prayer: Prayer, reminderMinutes: Int) -> String {
        if reminderMinutes == 0 {
            return "It's time for \(prayer.displayName) prayer (\(prayer.arabicName))"
        } else {
            return "\(prayer.displayName) prayer (\(prayer.arabicName)) in \(reminderMinutes) minutes"
        }
    }

    /// Legacy method for backward compatibility
    private func createNotificationTitle(for prayer: Prayer) -> String {
        return getNotificationTitle(for: prayer, reminderMinutes: 0)
    }

    /// Legacy method for backward compatibility
    private func createNotificationBody(for prayer: Prayer, minutesBefore: Int) -> String {
        return getNotificationBody(for: prayer, reminderMinutes: minutesBefore)
    }
    
    private func cancelNotificationsForDate(_ date: Date) async {
        let requests = await notificationCenter.pendingNotificationRequests()
        let calendar = Calendar.current
        
        let identifiersToCancel = requests.compactMap { request -> String? in
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                  let scheduledDate = calendar.date(from: trigger.dateComponents),
                  calendar.isDate(scheduledDate, inSameDayAs: date) else {
                return nil
            }
            
            return request.identifier
        }
        
        if !identifiersToCancel.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
            print("Cancelled \(identifiersToCancel.count) notifications for \(date)")
        }
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(notificationSettings) {
            userDefaults.set(data, forKey: SettingsKeys.notificationSettings)
        }
        userDefaults.set(notificationsEnabled, forKey: SettingsKeys.isEnabled)
    }
    
    private func loadSettings() {
        // Load notification settings
        if let data = userDefaults.data(forKey: SettingsKeys.notificationSettings),
           let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
            notificationSettings = settings
        }
        
        // Load enabled state
        if userDefaults.object(forKey: SettingsKeys.isEnabled) != nil {
            notificationsEnabled = userDefaults.bool(forKey: SettingsKeys.isEnabled)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: @preconcurrency UNUserNotificationCenterDelegate {
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo

        print("Received notification action: \(actionIdentifier)")

        // Extract prayer information
        let prayerString = userInfo["prayer"] as? String
        let prayer = prayerString.flatMap { Prayer(rawValue: $0) }

        // Handle different actions
        switch actionIdentifier {
        case "MARK_PRAYED":
            handleMarkPrayedAction(for: prayer, userInfo: userInfo)

        case "SNOOZE_5MIN":
            handleSnoozeAction(minutes: 5, for: prayer, userInfo: userInfo)

        case "SNOOZE_10MIN":
            handleSnoozeAction(minutes: 10, for: prayer, userInfo: userInfo)

        case "OPEN_QIBLA":
            handleOpenQiblaAction()

        case "OPEN_APP":
            handleOpenAppAction()

        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself
            handleDefaultAction(for: prayer, userInfo: userInfo)

        case UNNotificationDismissActionIdentifier:
            // User dismissed the notification
            handleDismissAction(for: prayer, userInfo: userInfo)

        default:
            print("Unknown notification action: \(actionIdentifier)")
        }

        completionHandler()
    }

    // MARK: - Notification Action Handlers

    private func handleMarkPrayedAction(for prayer: Prayer?, userInfo: [AnyHashable: Any]) {
        guard let prayer = prayer else { return }

        print("✅ User marked \(prayer.displayName) as prayed")

        // Post notification for app to handle
        NotificationCenter.default.post(
            name: .prayerMarkedAsPrayed,
            object: nil,
            userInfo: ["prayer": prayer.rawValue, "timestamp": Date()]
        )

        // Cancel any remaining notifications for this prayer
        Task {
            await cancelNotificationsForPrayer(prayer)
        }
    }

    private func handleSnoozeAction(minutes: Int, for prayer: Prayer?, userInfo: [AnyHashable: Any]) {
        guard let prayer = prayer else { return }

        print("⏰ User snoozed \(prayer.displayName) for \(minutes) minutes")

        // Schedule a new notification after the snooze period
        let snoozeTime = Calendar.current.date(byAdding: .minute, value: minutes, to: Date()) ?? Date()

        Task {
            do {
                try await scheduleEnhancedNotification(
                    for: prayer,
                    prayerTime: snoozeTime,
                    notificationTime: snoozeTime,
                    reminderMinutes: 0,
                    config: notificationSettings.configForPrayer(prayer)
                )

                print("✅ Scheduled snooze notification for \(prayer.displayName)")
            } catch {
                print("❌ Failed to schedule snooze notification: \(error)")
            }
        }
    }

    private func handleOpenQiblaAction() {
        print("🧭 User requested Qibla direction")

        // Post notification for app to handle
        NotificationCenter.default.post(
            name: .openQiblaRequested,
            object: nil
        )
    }

    private func handleOpenAppAction() {
        print("📱 User requested to open app")

        // App will open automatically due to foreground option
        NotificationCenter.default.post(
            name: .openAppRequested,
            object: nil
        )
    }

    private func handleDefaultAction(for prayer: Prayer?, userInfo: [AnyHashable: Any]) {
        print("👆 User tapped notification for \(prayer?.displayName ?? "unknown prayer")")

        // Post notification for app to handle
        NotificationCenter.default.post(
            name: .notificationTapped,
            object: nil,
            userInfo: userInfo
        )
    }

    private func handleDismissAction(for prayer: Prayer?, userInfo: [AnyHashable: Any]) {
        print("❌ User dismissed notification for \(prayer?.displayName ?? "unknown prayer")")

        // Optional: Track dismissal analytics
        NotificationCenter.default.post(
            name: .notificationDismissed,
            object: nil,
            userInfo: userInfo
        )
    }

    private func cancelNotificationsForPrayer(_ prayer: Prayer) async {
        let pendingRequests = await notificationCenter.pendingNotificationRequests()
        let identifiersToCancel = pendingRequests.compactMap { request -> String? in
            if let prayerString = request.content.userInfo["prayer"] as? String,
               prayerString == prayer.rawValue {
                return request.identifier
            }
            return nil
        }

        if !identifiersToCancel.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
            print("🗑️ Cancelled \(identifiersToCancel.count) notifications for \(prayer.displayName)")
        }
    }

    // MARK: - Testing Support

    #if DEBUG
    /// Set mock notification center for testing
    internal func setMockNotificationCenter(_ mockCenter: Any) {
        // This would be implemented to support testing
        // In a real implementation, you might use dependency injection
        print("Mock notification center set for testing")
    }
    #endif
}
