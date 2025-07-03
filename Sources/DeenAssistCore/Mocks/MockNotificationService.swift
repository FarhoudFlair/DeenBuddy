import Foundation
import Combine

// MARK: - Mock Notification Service

public class MockNotificationService: NotificationServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var permissionStatus: NotificationPermissionStatus = .notDetermined
    @Published public var isNotificationsEnabled: Bool = true
    
    // MARK: - Publishers
    
    private let permissionSubject = PassthroughSubject<NotificationPermissionStatus, Never>()
    
    public var permissionPublisher: AnyPublisher<NotificationPermissionStatus, Never> {
        permissionSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Mock Configuration
    
    public var mockPermissionResponse: NotificationPermissionStatus = .authorized
    public var mockDelay: TimeInterval = 0.5
    public var shouldFailScheduling: Bool = false
    public var mockSchedulingError: NotificationError = .schedulingFailed
    
    // MARK: - Mock Data Storage
    
    private var pendingNotifications: [PendingNotification] = []
    private var notificationSettings = NotificationSettings.default
    
    // MARK: - Initialization
    
    public init() {
        setupDefaultMockData()
    }
    
    // MARK: - Protocol Implementation
    
    public func requestNotificationPermission() async -> NotificationPermissionStatus {
        await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        permissionStatus = mockPermissionResponse
        permissionSubject.send(permissionStatus)
        
        return permissionStatus
    }
    
    public func schedulePrayerNotifications(for prayerTimes: PrayerTimes) async throws {
        await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        if shouldFailScheduling {
            throw mockSchedulingError
        }
        
        guard permissionStatus.isAuthorized else {
            throw NotificationError.permissionDenied
        }
        
        // Cancel existing notifications for this date
        cancelNotificationsForDate(prayerTimes.date)
        
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
                        title: "\(prayer.displayName) Prayer Reminder",
                        body: notificationSettings.customMessage ?? "It's time for \(prayer.displayName) prayer in \(notificationSettings.reminderMinutes) minutes"
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
        await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        if shouldFailScheduling {
            throw mockSchedulingError
        }
        
        guard permissionStatus.isAuthorized else {
            throw NotificationError.permissionDenied
        }
        
        guard time > Date() else {
            throw NotificationError.invalidDate
        }
        
        let notification = PendingNotification(
            id: notificationIdentifier(for: prayer, date: time),
            prayer: prayer,
            scheduledTime: time,
            title: title ?? prayer.notificationTitle,
            body: body ?? "Prayer time reminder"
        )
        
        // Remove existing notification for this prayer and date if any
        pendingNotifications.removeAll { $0.id == notification.id }
        
        // Add new notification
        pendingNotifications.append(notification)
        
        print("Mock: Scheduled notification for \(prayer.displayName) at \(time)")
    }
    
    public func cancelAllPrayerNotifications() {
        pendingNotifications.removeAll()
        print("Mock: Cancelled all prayer notifications")
    }
    
    public func cancelNotification(for prayer: Prayer, date: Date) {
        let identifier = notificationIdentifier(for: prayer, date: date)
        pendingNotifications.removeAll { $0.id == identifier }
        print("Mock: Cancelled notification for \(prayer.displayName) on \(date)")
    }
    
    public func getPendingNotifications() async -> [PendingNotification] {
        await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        // Filter out past notifications
        let now = Date()
        pendingNotifications = pendingNotifications.filter { $0.scheduledTime > now }
        
        return pendingNotifications.sorted { $0.scheduledTime < $1.scheduledTime }
    }
    
    public func isNotificationScheduled(for prayer: Prayer, date: Date) async -> Bool {
        let identifier = notificationIdentifier(for: prayer, date: date)
        return pendingNotifications.contains { $0.id == identifier && $0.scheduledTime > Date() }
    }
    
    public func updateNotificationSettings(_ settings: NotificationSettings) {
        notificationSettings = settings
        isNotificationsEnabled = settings.isEnabled
        print("Mock: Updated notification settings - enabled: \(settings.isEnabled), reminder: \(settings.reminderMinutes) minutes")
    }
    
    public func getNotificationSettings() -> NotificationSettings {
        return notificationSettings
    }
    
    // MARK: - Mock Configuration Methods
    
    public func setMockPermissionStatus(_ status: NotificationPermissionStatus) {
        mockPermissionResponse = status
        permissionStatus = status
        permissionSubject.send(status)
    }
    
    public func simulateSchedulingError(_ error: NotificationError) {
        shouldFailScheduling = true
        mockSchedulingError = error
    }
    
    public func clearSchedulingError() {
        shouldFailScheduling = false
    }
    
    public func addMockNotification(_ notification: PendingNotification) {
        pendingNotifications.append(notification)
    }
    
    public func clearAllMockNotifications() {
        pendingNotifications.removeAll()
    }
    
    public func getMockNotifications() -> [PendingNotification] {
        return pendingNotifications
    }
    
    // MARK: - Mock Simulation Methods
    
    public func simulateNotificationDelivery(for prayer: Prayer, date: Date) {
        let identifier = notificationIdentifier(for: prayer, date: date)
        if let index = pendingNotifications.firstIndex(where: { $0.id == identifier }) {
            let notification = pendingNotifications[index]
            print("Mock: Delivered notification - \(notification.title): \(notification.body)")
            pendingNotifications.remove(at: index)
        }
    }
    
    public func simulateNotificationTap(for prayer: Prayer, date: Date) {
        print("Mock: User tapped notification for \(prayer.displayName) on \(date)")
        // In a real app, this would trigger navigation to the prayer screen
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultMockData() {
        // Add some sample pending notifications
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        
        for prayer in Prayer.allCases {
            let baseHour = getBaseHour(for: prayer)
            let notificationTime = Calendar.current.date(bySettingHour: baseHour, minute: 0, second: 0, of: tomorrow) ?? tomorrow
            
            let notification = PendingNotification(
                id: notificationIdentifier(for: prayer, date: notificationTime),
                prayer: prayer,
                scheduledTime: notificationTime,
                title: "\(prayer.displayName) Prayer Reminder",
                body: "It's time for \(prayer.displayName) prayer in 10 minutes"
            )
            
            pendingNotifications.append(notification)
        }
    }
    
    private func getBaseHour(for prayer: Prayer) -> Int {
        switch prayer {
        case .fajr: return 6
        case .dhuhr: return 12
        case .asr: return 15
        case .maghrib: return 18
        case .isha: return 20
        }
    }
    
    private func cancelNotificationsForDate(_ date: Date) {
        let calendar = Calendar.current
        pendingNotifications.removeAll { notification in
            calendar.isDate(notification.scheduledTime, inSameDayAs: date)
        }
    }
}
