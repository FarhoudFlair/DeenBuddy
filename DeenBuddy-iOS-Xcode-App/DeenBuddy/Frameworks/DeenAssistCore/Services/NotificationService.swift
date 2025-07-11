import Foundation
import UserNotifications
import Combine

// MARK: - Notification Service Implementation

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
    
    public func requestNotificationPermission() async throws -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            
            let status: UNAuthorizationStatus = granted ? .authorized : .denied
            
            await MainActor.run {
                authorizationStatus = status
                permissionSubject.send(status)
            }
            
            return granted
            
        } catch {
            await MainActor.run {
                authorizationStatus = .denied
                permissionSubject.send(.denied)
            }
            
            throw error
        }
    }
    
    public func schedulePrayerNotifications(for prayerTimes: [PrayerTime]) async throws {
        guard authorizationStatus == .authorized else {
            throw NotificationError.permissionDenied
        }
        
        guard notificationsEnabled else {
            return
        }
        
        // Always cancel existing notifications for this date, regardless of prayerTimes array
        if let firstPrayerTime = prayerTimes.first {
            await cancelNotificationsForDate(firstPrayerTime.time)
        } else {
            // If prayerTimes is empty, cancel all existing notifications
            await cancelAllNotifications()
        }
        
        // Schedule new notifications for each prayer
        for prayerTime in prayerTimes {
            // Use user-configurable reminder minutes instead of hardcoded 10 minutes
            let notificationTime = Calendar.current.date(byAdding: .minute, value: -notificationSettings.reminderMinutes, to: prayerTime.time) ?? prayerTime.time
            
            // Only schedule future notifications
            if notificationTime > Date() {
                try await scheduleNotification(
                    for: prayerTime.prayer,
                    at: notificationTime,
                    title: prayerTime.prayer.notificationTitle,
                    body: prayerTime.prayer.notificationBody
                )
            }
        }
    }
    
    public func scheduleNotification(
        for prayer: Prayer,
        at time: Date,
        title: String?,
        body: String?
    ) async throws {
        guard authorizationStatus == .authorized else {
            throw NotificationError.permissionDenied
        }
        
        guard time > Date() else {
            throw NotificationError.invalidDate
        }
        
        let identifier = "\(prayer.rawValue)_\(time.timeIntervalSince1970)"
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = title ?? prayer.notificationTitle
        content.body = body ?? prayer.notificationBody
        content.categoryIdentifier = "PRAYER_REMINDER"
        content.userInfo = [
            "prayer": prayer.rawValue,
            "type": "prayer_reminder",
            "scheduled_time": time.timeIntervalSince1970
        ]
        
        // Configure sound and badge
        content.sound = .default
        content.badge = 1
        
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
            
            let status = settings.authorizationStatus
            
            await MainActor.run {
                authorizationStatus = status
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
