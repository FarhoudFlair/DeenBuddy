import Foundation
import Combine

/// Service for tracking user analytics and app usage
@MainActor
public class AnalyticsService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isEnabled = true
    @Published public var isDebugMode = false
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let configurationManager = ConfigurationManager.shared
    private var eventQueue: [AnalyticsEvent] = []
    private var sessionId: String = UUID().uuidString
    private var sessionStartTime: Date = Date()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Cache Keys
    
    private enum CacheKeys {
        static let isEnabled = "DeenAssist.Analytics.Enabled"
        static let userId = "DeenAssist.Analytics.UserId"
        static let eventQueue = "DeenAssist.Analytics.EventQueue"
        static let sessionCount = "DeenAssist.Analytics.SessionCount"
    }
    
    // MARK: - Singleton
    
    public static let shared = AnalyticsService()
    
    private init() {
        loadSettings()
        setupSessionTracking()
        setupAppLifecycleObservers()
        
        #if DEBUG
        isDebugMode = true
        #endif
    }
    
    // MARK: - Public Methods
    
    /// Enable or disable analytics tracking
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        userDefaults.set(enabled, forKey: CacheKeys.isEnabled)
        
        if enabled {
            print("📊 Analytics enabled")
            trackEvent(.analyticsEnabled)
        } else {
            print("📊 Analytics disabled")
            clearEventQueue()
        }
    }
    
    /// Track a custom event
    public func trackEvent(_ event: AnalyticsEvent) {
        guard isEnabled else { return }
        
        let enrichedEvent = enrichEvent(event)
        eventQueue.append(enrichedEvent)
        
        if isDebugMode {
            print("📊 Event tracked: \(enrichedEvent.name) - \(enrichedEvent.parameters)")
        }
        
        // Save to persistent storage
        saveEventQueue()
        
        // In a real implementation, this would send to external analytics service
        // For now, we'll just log locally
        processEventQueue()
    }
    
    /// Track screen view
    public func trackScreenView(_ screenName: String, parameters: [String: Any] = [:]) {
        var params = parameters
        params["screen_name"] = screenName
        
        trackEvent(AnalyticsEvent(
            name: "screen_view",
            parameters: params,
            category: .navigation
        ))
    }
    
    /// Track user action
    public func trackUserAction(_ action: String, parameters: [String: Any] = [:]) {
        var params = parameters
        params["action"] = action
        
        trackEvent(AnalyticsEvent(
            name: "user_action",
            parameters: params,
            category: .userInteraction
        ))
    }
    
    /// Track prayer time calculation
    public func trackPrayerTimeCalculation(method: String, madhab: String, location: String) {
        trackEvent(AnalyticsEvent(
            name: "prayer_time_calculated",
            parameters: [
                "calculation_method": method,
                "madhab": madhab,
                "location_type": location
            ],
            category: .prayerTimes
        ))
    }
    
    /// Track Qibla compass usage
    public func trackQiblaCompassUsage(accuracy: String, duration: TimeInterval) {
        trackEvent(AnalyticsEvent(
            name: "qibla_compass_used",
            parameters: [
                "accuracy": accuracy,
                "duration_seconds": Int(duration)
            ],
            category: .qiblaCompass
        ))
    }
    
    /// Track prayer guide usage
    public func trackPrayerGuideUsage(guideId: String, prayer: String, completed: Bool) {
        trackEvent(AnalyticsEvent(
            name: "prayer_guide_used",
            parameters: [
                "guide_id": guideId,
                "prayer": prayer,
                "completed": completed
            ],
            category: .prayerGuides
        ))
    }
    
    /// Track error occurrence
    public func trackError(_ error: Error, context: String) {
        trackEvent(AnalyticsEvent(
            name: "error_occurred",
            parameters: [
                "error_description": error.localizedDescription,
                "context": context,
                "error_type": String(describing: type(of: error))
            ],
            category: .errors
        ))
    }
    
    /// Get analytics summary
    public func getAnalyticsSummary() -> AnalyticsSummary {
        let sessionCount = userDefaults.integer(forKey: CacheKeys.sessionCount)
        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        
        return AnalyticsSummary(
            sessionId: sessionId,
            sessionCount: sessionCount,
            sessionDuration: sessionDuration,
            eventCount: eventQueue.count,
            isEnabled: isEnabled
        )
    }
    
    /// Clear all analytics data
    public func clearAnalyticsData() {
        eventQueue.removeAll()
        userDefaults.removeObject(forKey: CacheKeys.eventQueue)
        userDefaults.removeObject(forKey: CacheKeys.userId)
        userDefaults.removeObject(forKey: CacheKeys.sessionCount)
        
        print("📊 Analytics data cleared")
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() {
        isEnabled = userDefaults.bool(forKey: CacheKeys.isEnabled)
        
        // Load cached events
        if let data = userDefaults.data(forKey: CacheKeys.eventQueue),
           let events = try? JSONDecoder().decode([AnalyticsEvent].self, from: data) {
            eventQueue = events
        }
    }
    
    private func setupSessionTracking() {
        sessionId = UUID().uuidString
        sessionStartTime = Date()
        
        // Increment session count
        let sessionCount = userDefaults.integer(forKey: CacheKeys.sessionCount) + 1
        userDefaults.set(sessionCount, forKey: CacheKeys.sessionCount)
        
        // Track session start
        trackEvent(.sessionStarted)
    }
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.trackEvent(.appBackgrounded)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.trackEvent(.appForegrounded)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.trackEvent(.sessionEnded)
                self?.saveEventQueue()
            }
            .store(in: &cancellables)
    }
    
    private func enrichEvent(_ event: AnalyticsEvent) -> AnalyticsEvent {
        var enrichedParameters = event.parameters
        
        // Add session information
        enrichedParameters["session_id"] = sessionId
        enrichedParameters["timestamp"] = ISO8601DateFormatter().string(from: Date())
        enrichedParameters["app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        enrichedParameters["build_number"] = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        enrichedParameters["platform"] = "iOS"
        enrichedParameters["device_model"] = UIDevice.current.model
        enrichedParameters["os_version"] = UIDevice.current.systemVersion
        
        // Add user ID if available
        if let userId = getUserId() {
            enrichedParameters["user_id"] = userId
        }
        
        return AnalyticsEvent(
            name: event.name,
            parameters: enrichedParameters,
            category: event.category,
            timestamp: event.timestamp
        )
    }
    
    private func getUserId() -> String? {
        if let userId = userDefaults.string(forKey: CacheKeys.userId) {
            return userId
        }
        
        // Generate anonymous user ID
        let userId = UUID().uuidString
        userDefaults.set(userId, forKey: CacheKeys.userId)
        return userId
    }
    
    private func saveEventQueue() {
        if let data = try? JSONEncoder().encode(eventQueue) {
            userDefaults.set(data, forKey: CacheKeys.eventQueue)
        }
    }
    
    private func processEventQueue() {
        // In a real implementation, this would send events to external service
        // For now, we'll just log them locally
        
        if isDebugMode && !eventQueue.isEmpty {
            print("📊 Processing \(eventQueue.count) analytics events")
        }
        
        // Simulate sending to external service
        // In production, this would integrate with Firebase Analytics, Mixpanel, etc.
    }
    
    private func clearEventQueue() {
        eventQueue.removeAll()
        userDefaults.removeObject(forKey: CacheKeys.eventQueue)
    }
}

// MARK: - Analytics Event

public struct AnalyticsEvent: Codable {
    public let name: String
    public let parameters: [String: AnyCodable]
    public let category: EventCategory
    public let timestamp: Date
    
    public init(name: String, parameters: [String: Any] = [:], category: EventCategory, timestamp: Date = Date()) {
        self.name = name
        self.parameters = parameters.mapValues { AnyCodable($0) }
        self.category = category
        self.timestamp = timestamp
    }
    
    public enum EventCategory: String, Codable, CaseIterable {
        case navigation = "navigation"
        case userInteraction = "user_interaction"
        case prayerTimes = "prayer_times"
        case qiblaCompass = "qibla_compass"
        case prayerGuides = "prayer_guides"
        case settings = "settings"
        case errors = "errors"
        case performance = "performance"
        case system = "system"
    }
}

// MARK: - Predefined Events

public extension AnalyticsEvent {
    static let sessionStarted = AnalyticsEvent(name: "session_started", category: .system)
    static let sessionEnded = AnalyticsEvent(name: "session_ended", category: .system)
    static let appBackgrounded = AnalyticsEvent(name: "app_backgrounded", category: .system)
    static let appForegrounded = AnalyticsEvent(name: "app_foregrounded", category: .system)
    static let analyticsEnabled = AnalyticsEvent(name: "analytics_enabled", category: .system)
    static let analyticsDisabled = AnalyticsEvent(name: "analytics_disabled", category: .system)
}

// MARK: - Analytics Summary

public struct AnalyticsSummary {
    public let sessionId: String
    public let sessionCount: Int
    public let sessionDuration: TimeInterval
    public let eventCount: Int
    public let isEnabled: Bool
    
    public var formattedSessionDuration: String {
        let minutes = Int(sessionDuration / 60)
        let seconds = Int(sessionDuration.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(seconds)s"
    }
}

// MARK: - AnyCodable Helper

public struct AnyCodable: Codable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else {
            value = ""
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        default:
            try container.encode(String(describing: value))
        }
    }
}
