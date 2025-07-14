import Foundation
import UserNotifications

/// Service for managing critical alerts for Islamic events and special occasions
public class IslamicEventNotificationService: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = IslamicEventNotificationService()
    
    private init() {}
    
    // MARK: - Properties
    
    private let notificationCenter = UNUserNotificationCenter.current()
    @Published public var criticalAlertsEnabled: Bool = false
    
    // MARK: - Critical Alert Management
    
    /// Request permission for critical alerts (requires special entitlement)
    public func requestCriticalAlertPermission() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .criticalAlert]
        
        do {
            let granted = try await notificationCenter.requestAuthorization(options: options)
            
            await MainActor.run {
                self.criticalAlertsEnabled = granted
            }
            
            print(granted ? "✅ Critical alerts permission granted" : "❌ Critical alerts permission denied")
            return granted
        } catch {
            print("❌ Failed to request critical alerts permission: \(error)")
            throw IslamicEventNotificationError.permissionDenied
        }
    }
    
    /// Schedule critical alert for important Islamic event
    public func scheduleCriticalAlert(for event: IslamicEvent) async throws {
        guard criticalAlertsEnabled else {
            throw IslamicEventNotificationError.criticalAlertsNotEnabled
        }
        
        let identifier = "critical_\(event.id.uuidString)"
        
        // Create critical alert content
        let content = UNMutableNotificationContent()
        content.title = "🕌 \(event.title)"
        content.body = event.description
        content.categoryIdentifier = "ISLAMIC_EVENT"
        content.sound = UNNotificationSound.defaultCritical
        content.interruptionLevel = .critical
        
        // Add Islamic event metadata
        content.userInfo = [
            "event_id": event.id.uuidString,
            "event_type": event.type.rawValue,
            "importance": event.importance.rawValue,
            "hijri_date": event.hijriDate.formatted,
            "is_critical": true
        ]
        
        // Create trigger based on event timing
        let trigger = createTriggerForEvent(event)
        
        // Create request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await notificationCenter.add(request)
            print("✅ Scheduled critical alert for \(event.title)")
        } catch {
            print("❌ Failed to schedule critical alert: \(error)")
            throw IslamicEventNotificationError.schedulingFailed
        }
    }
    
    /// Schedule notification for regular Islamic event
    public func scheduleIslamicEventNotification(for event: IslamicEvent) async throws {
        let identifier = "event_\(event.id.uuidString)"
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = getEventTitle(for: event)
        content.body = getEventBody(for: event)
        content.categoryIdentifier = "ISLAMIC_EVENT"
        content.sound = getEventSound(for: event)
        content.badge = 1
        
        // Set interruption level based on importance
        content.interruptionLevel = getInterruptionLevel(for: event)
        
        // Add Islamic event metadata
        content.userInfo = [
            "event_id": event.id.uuidString,
            "event_type": event.type.rawValue,
            "importance": event.importance.rawValue,
            "hijri_date": event.hijriDate.formatted,
            "is_critical": false
        ]
        
        // Create trigger
        let trigger = createTriggerForEvent(event)
        
        // Create request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await notificationCenter.add(request)
            print("✅ Scheduled Islamic event notification for \(event.title)")
        } catch {
            print("❌ Failed to schedule Islamic event notification: \(error)")
            throw IslamicEventNotificationError.schedulingFailed
        }
    }
    
    /// Schedule multiple notifications for Ramadan period
    public func scheduleRamadanNotifications(year: Int) async throws {
        let ramadanEvents = generateRamadanEvents(for: year)
        
        for event in ramadanEvents {
            if event.importance == .critical {
                try await scheduleCriticalAlert(for: event)
            } else {
                try await scheduleIslamicEventNotification(for: event)
            }
        }
        
        print("✅ Scheduled \(ramadanEvents.count) Ramadan notifications")
    }
    
    /// Cancel Islamic event notifications
    public func cancelIslamicEventNotifications(for eventIds: [UUID]) {
        let identifiers = eventIds.map { "event_\($0.uuidString)" } + eventIds.map { "critical_\($0.uuidString)" }
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        print("🗑️ Cancelled \(identifiers.count) Islamic event notifications")
    }
    
    // MARK: - Private Helper Methods
    
    private func createTriggerForEvent(_ event: IslamicEvent) -> UNNotificationTrigger? {
        let gregorianDate = event.hijriDate.toGregorianDate()
        let calendar = Calendar.current
        
        // Schedule for the event date at a meaningful time
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: gregorianDate)
        
        // Set time based on event type
        switch event.type {
        case .religious:
            dateComponents.hour = 6 // Early morning for religious events
            dateComponents.minute = 0
        case .cultural:
            dateComponents.hour = 9 // Morning for cultural events
            dateComponents.minute = 0
        case .historical:
            dateComponents.hour = 12 // Noon for historical events
            dateComponents.minute = 0
        }
        
        return UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: event.isRecurring)
    }
    
    private func getEventTitle(for event: IslamicEvent) -> String {
        let emoji = getEventEmoji(for: event)
        return "\(emoji) \(event.title)"
    }
    
    private func getEventBody(for event: IslamicEvent) -> String {
        var body = event.description
        
        // Add Hijri date
        body += "\n\n📅 \(event.hijriDate.formatted)"
        
        // Add location if available
        if let location = event.location {
            body += "\n📍 \(location)"
        }
        
        return body
    }
    
    private func getEventEmoji(for event: IslamicEvent) -> String {
        switch event.type {
        case .religious:
            switch event.importance {
            case .critical:
                return "🕌"
            case .high:
                return "🌙"
            case .medium:
                return "⭐"
            case .low:
                return "📿"
            }
        case .cultural:
            return "🎉"
        case .historical:
            return "📚"
        }
    }
    
    private func getEventSound(for event: IslamicEvent) -> UNNotificationSound {
        switch event.importance {
        case .critical:
            return .defaultCritical
        case .high:
            return .default
        case .medium, .low:
            return .default
        }
    }
    
    private func getInterruptionLevel(for event: IslamicEvent) -> UNNotificationInterruptionLevel {
        switch event.importance {
        case .critical:
            return .critical
        case .high:
            return .active
        case .medium:
            return .active
        case .low:
            return .passive
        }
    }
    
    private func generateRamadanEvents(for year: Int) -> [IslamicEvent] {
        var events: [IslamicEvent] = []
        
        // Ramadan start
        let ramadanStart = HijriDate(day: 1, month: .ramadan, year: year)
        events.append(IslamicEvent(
            id: UUID(),
            title: "Ramadan Mubarak",
            description: "The blessed month of Ramadan has begun. May Allah accept your fasting and prayers.",
            hijriDate: ramadanStart,
            type: .religious,
            importance: .critical,
            isRecurring: false,
            location: nil,
            reminder: nil
        ))
        
        // Laylat al-Qadr (Night of Power) - estimated dates
        for day in [21, 23, 25, 27, 29] {
            let laylahDate = HijriDate(day: day, month: .ramadan, year: year)
            events.append(IslamicEvent(
                id: UUID(),
                title: "Laylat al-Qadr",
                description: "Tonight could be the Night of Power. Increase your prayers and remembrance of Allah.",
                hijriDate: laylahDate,
                type: .religious,
                importance: .high,
                isRecurring: false,
                location: nil,
                reminder: nil
            ))
        }
        
        // Eid al-Fitr
        let eidDate = HijriDate(day: 1, month: .shawwal, year: year)
        events.append(IslamicEvent(
            id: UUID(),
            title: "Eid al-Fitr Mubarak",
            description: "Eid Mubarak! May this blessed day bring joy, peace, and prosperity to you and your family.",
            hijriDate: eidDate,
            type: .religious,
            importance: .critical,
            isRecurring: false,
            location: nil,
            reminder: nil
        ))
        
        return events
    }
}

// MARK: - Islamic Event Notification Errors

public enum IslamicEventNotificationError: Error, LocalizedError {
    case permissionDenied
    case criticalAlertsNotEnabled
    case schedulingFailed
    case eventNotFound
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Permission denied for Islamic event notifications"
        case .criticalAlertsNotEnabled:
            return "Critical alerts are not enabled for Islamic events"
        case .schedulingFailed:
            return "Failed to schedule Islamic event notification"
        case .eventNotFound:
            return "Islamic event not found"
        }
    }
}
