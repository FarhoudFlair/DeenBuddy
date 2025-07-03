import Foundation
import UserNotifications
import Combine

// MARK: - Notification Service Implementation

public class NotificationService: NSObject, NotificationServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var permissionStatus: NotificationPermissionStatus = .notDetermined
    @Published public var isNotificationsEnabled: Bool = true
    
    // MARK: - Publishers
    
    private let permissionSubject = PassthroughSubject<NotificationPermissionStatus, Never>()
    
    public var permissionPublisher: AnyPublisher<NotificationPermissionStatus, Never> {
        permissionSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let userDefaults = UserDefaults.standard
    private var notificationSettings = NotificationSettings.default
    
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
    }
    
    // MARK: - Protocol Implementation
    
    public func requestNotificationPermission() async -> NotificationPermissionStatus {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            
            let status: NotificationPermissionStatus = granted ? .authorized : .denied
            
            await MainActor.run {
                permissionStatus = status
                permissionSubject.send(status)
            }
            
            return status
            
        } catch {
            await MainActor.run {
                permissionStatus = .denied
                permissionSubject.send(.denied)
            }
            
            return .denied
        }
    }
    
    public func schedulePrayerNotifications(for prayerTimes: PrayerTimes) async throws {
        guard permissionStatus.isAuthorized else {
            throw NotificationError.permissionDenied
        }
        
        guard isNotificationsEnabled && notificationSettings.isEnabled else {
            return
        }
        
        // Cancel existing notifications for this date
        await cancelNotificationsForDate(prayerTimes.date)
        
        // Schedule new notifications for each enabled prayer
        for prayer in Prayer.allCases {
            if notificationSettings.enabledPrayers.contains(prayer) {
                let prayerTime = prayerTimes.time(for: prayer)
                let notificationTime = notificationTime(for: prayerTime, reminderMinutes: notificationSettings.reminderMinutes)
                
                // Only schedule future notifications
                if notificationTime > Date() {
                    try await scheduleNotification(
                        for: prayer,
                        at: notificationTime,
                        title: createNotificationTitle(for: prayer),
                        body: createNotificationBody(for: prayer, minutesBefore: notificationSettings.reminderMinutes)
                    )
                }
            }
        }
    }
    
    public func scheduleNotification(
        for prayer: Prayer,
        at time: Date,
        title: String?,
        body: String?
    ) async throws {
        guard permissionStatus.isAuthorized else {
            throw NotificationError.permissionDenied
        }
        
        guard time > Date() else {
            throw NotificationError.invalidDate
        }
        
        let identifier = notificationIdentifier(for: prayer, date: time)
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = title ?? createNotificationTitle(for: prayer)
        content.body = body ?? createNotificationBody(for: prayer, minutesBefore: notificationSettings.reminderMinutes)
        content.categoryIdentifier = "PRAYER_REMINDER"
        content.userInfo = [
            "prayer": prayer.rawValue,
            "type": "prayer_reminder",
            "scheduled_time": time.timeIntervalSince1970
        ]
        
        // Configure sound and badge
        if notificationSettings.soundEnabled {
            content.sound = .default
        }
        
        if notificationSettings.badgeEnabled {
            content.badge = 1
        }
        
        // Create trigger
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await notificationCenter.add(request)
            print("Scheduled notification for \(prayer.displayName) at \(time)")
        } catch {
            throw NotificationError.schedulingFailed
        }
    }
    
    public func cancelAllPrayerNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        print("Cancelled all prayer notifications")
    }
    
    public func cancelNotification(for prayer: Prayer, date: Date) {
        let identifier = notificationIdentifier(for: prayer, date: date)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        print("Cancelled notification for \(prayer.displayName) on \(date)")
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
            
            return PendingNotification(
                id: request.identifier,
                prayer: prayer,
                scheduledTime: scheduledDate,
                title: request.content.title,
                body: request.content.body,
                isActive: true
            )
        }.sorted { $0.scheduledTime < $1.scheduledTime }
    }
    
    public func isNotificationScheduled(for prayer: Prayer, date: Date) async -> Bool {
        let identifier = notificationIdentifier(for: prayer, date: date)
        let requests = await notificationCenter.pendingNotificationRequests()
        
        return requests.contains { $0.identifier == identifier }
    }
    
    public func updateNotificationSettings(_ settings: NotificationSettings) {
        notificationSettings = settings
        isNotificationsEnabled = settings.isEnabled
        saveSettings()
        
        print("Updated notification settings - enabled: \(settings.isEnabled), reminder: \(settings.reminderMinutes) minutes")
    }
    
    public func getNotificationSettings() -> NotificationSettings {
        return notificationSettings
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationCenter() {
        notificationCenter.delegate = self
        
        // Define notification categories and actions
        let prayerCategory = UNNotificationCategory(
            identifier: "PRAYER_REMINDER",
            actions: [
                UNNotificationAction(
                    identifier: "OPEN_APP",
                    title: "Open App",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "DISMISS",
                    title: "Dismiss",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([prayerCategory])
    }
    
    private func updatePermissionStatus() {
        Task {
            let settings = await notificationCenter.notificationSettings()
            
            let status: NotificationPermissionStatus
            switch settings.authorizationStatus {
            case .notDetermined:
                status = .notDetermined
            case .denied:
                status = .denied
            case .authorized:
                status = .authorized
            case .provisional:
                status = .provisional
            case .ephemeral:
                status = .ephemeral
            @unknown default:
                status = .notDetermined
            }
            
            await MainActor.run {
                permissionStatus = status
                permissionSubject.send(status)
            }
        }
    }
    
    private func createNotificationTitle(for prayer: Prayer) -> String {
        return "\(prayer.displayName) Prayer Reminder"
    }
    
    private func createNotificationBody(for prayer: Prayer, minutesBefore: Int) -> String {
        if let customMessage = notificationSettings.customMessage, !customMessage.isEmpty {
            return customMessage
        }
        
        if minutesBefore == 0 {
            return "It's time for \(prayer.displayName) prayer"
        } else {
            return "It's time for \(prayer.displayName) prayer in \(minutesBefore) minutes"
        }
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
        userDefaults.set(isNotificationsEnabled, forKey: SettingsKeys.isEnabled)
    }
    
    private func loadSettings() {
        // Load notification settings
        if let data = userDefaults.data(forKey: SettingsKeys.notificationSettings),
           let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
            notificationSettings = settings
        }
        
        // Load enabled state
        if userDefaults.object(forKey: SettingsKeys.isEnabled) != nil {
            isNotificationsEnabled = userDefaults.bool(forKey: SettingsKeys.isEnabled)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
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
        let userInfo = response.notification.request.content.userInfo
        
        if let prayerString = userInfo["prayer"] as? String,
           let prayer = Prayer(rawValue: prayerString) {
            
            switch response.actionIdentifier {
            case "OPEN_APP":
                print("User tapped to open app for \(prayer.displayName) prayer")
                // In a real app, this would trigger navigation to the prayer screen
                
            case "DISMISS":
                print("User dismissed \(prayer.displayName) prayer notification")
                
            default:
                print("User tapped \(prayer.displayName) prayer notification")
            }
        }
        
        completionHandler()
    }
}
