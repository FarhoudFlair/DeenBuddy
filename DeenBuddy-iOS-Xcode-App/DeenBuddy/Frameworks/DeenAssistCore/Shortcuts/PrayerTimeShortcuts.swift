import Foundation
import Intents
import IntentsUI

// MARK: - Prayer Time Intent

@available(iOS 12.0, *)
public class GetPrayerTimesIntent: INIntent {
    
    @NSManaged public var date: Date?
    @NSManaged public var location: CLPlacemark?
    @NSManaged public var calculationMethod: String?
    
    public override init() {
        super.init()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

// MARK: - Next Prayer Intent

@available(iOS 12.0, *)
public class GetNextPrayerIntent: INIntent {
    
    @NSManaged public var includeTimeRemaining: NSNumber?
    @NSManaged public var location: CLPlacemark?
    
    public override init() {
        super.init()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

// MARK: - Qibla Direction Intent

@available(iOS 12.0, *)
public class GetQiblaDirectionIntent: INIntent {
    
    @NSManaged public var location: CLPlacemark?
    @NSManaged public var includeDistance: NSNumber?
    
    public override init() {
        super.init()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

// MARK: - Prayer Shortcuts Manager

@available(iOS 12.0, *)
public class PrayerShortcutsManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = PrayerShortcutsManager()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Dependencies
    
    private var prayerTimeService: (any PrayerTimeServiceProtocol)?
    // Note: QiblaServiceProtocol not available in current implementation
    private var locationService: (any LocationServiceProtocol)?
    
    public func configure(
        prayerTimeService: any PrayerTimeServiceProtocol,
        locationService: any LocationServiceProtocol
    ) {
        self.prayerTimeService = prayerTimeService
        self.locationService = locationService
    }
    
    // MARK: - Shortcut Registration
    
    /// Register all prayer-related shortcuts with Siri
    public func registerPrayerShortcuts() {
        let shortcuts = createPrayerShortcuts()
        
        INVoiceShortcutCenter.shared.setShortcutSuggestions(shortcuts)
        print("✅ Registered \(shortcuts.count) prayer shortcuts with Siri")
    }
    
    /// Create suggested shortcuts for prayer times
    private func createPrayerShortcuts() -> [INShortcut] {
        var shortcuts: [INShortcut] = []
        
        // Next Prayer shortcut
        if let nextPrayerShortcut = createNextPrayerShortcut() {
            shortcuts.append(nextPrayerShortcut)
        }
        
        // Today's Prayer Times shortcut
        if let todaysPrayersShortcut = createTodaysPrayersShortcut() {
            shortcuts.append(todaysPrayersShortcut)
        }
        
        // Qibla Direction shortcut
        if let qiblaShortcut = createQiblaDirectionShortcut() {
            shortcuts.append(qiblaShortcut)
        }
        
        // Individual prayer shortcuts
        for prayer in Prayer.allCases {
            if let prayerShortcut = createPrayerTimeShortcut(for: prayer) {
                shortcuts.append(prayerShortcut)
            }
        }
        
        return shortcuts
    }
    
    private func createNextPrayerShortcut() -> INShortcut? {
        let intent = GetNextPrayerIntent()
        intent.includeTimeRemaining = NSNumber(value: true)
        intent.suggestedInvocationPhrase = "What's the next prayer time?"
        
        return INShortcut(intent: intent)
    }
    
    private func createTodaysPrayersShortcut() -> INShortcut? {
        let intent = GetPrayerTimesIntent()
        intent.date = Date()
        intent.suggestedInvocationPhrase = "Show me today's prayer times"
        
        return INShortcut(intent: intent)
    }
    
    private func createQiblaDirectionShortcut() -> INShortcut? {
        let intent = GetQiblaDirectionIntent()
        intent.includeDistance = NSNumber(value: true)
        intent.suggestedInvocationPhrase = "Which way is Qibla?"
        
        return INShortcut(intent: intent)
    }
    
    private func createPrayerTimeShortcut(for prayer: Prayer) -> INShortcut? {
        let intent = GetPrayerTimesIntent()
        intent.date = Date()
        intent.suggestedInvocationPhrase = "When is \(prayer.displayName) prayer?"
        
        return INShortcut(intent: intent)
    }
    
    // MARK: - Intent Handling
    
    /// Handle next prayer intent
    public func handleNextPrayerIntent(_ intent: GetNextPrayerIntent) async -> GetNextPrayerIntentResponse {
        guard let prayerTimeService = prayerTimeService else {
            return GetNextPrayerIntentResponse(code: .failure, userActivity: nil)
        }
        
        guard let nextPrayer = await prayerTimeService.nextPrayer else {
            return GetNextPrayerIntentResponse(code: .failure, userActivity: nil)
        }
        
        let response = GetNextPrayerIntentResponse(code: .success, userActivity: nil)
        
        // Format response
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let timeString = timeFormatter.string(from: nextPrayer.time)
        
        var responseText = "The next prayer is \(nextPrayer.prayer.displayName) at \(timeString)"
        
        if intent.includeTimeRemaining?.boolValue == true,
           let timeRemaining = await prayerTimeService.timeUntilNextPrayer {
            let hours = Int(timeRemaining) / 3600
            let minutes = Int(timeRemaining) % 3600 / 60
            
            if hours > 0 {
                responseText += ", in \(hours) hours and \(minutes) minutes"
            } else {
                responseText += ", in \(minutes) minutes"
            }
        }
        
        response.userActivity = createUserActivity(
            for: .nextPrayer,
            data: [
                "prayer": nextPrayer.prayer.rawValue,
                "time": nextPrayer.time.timeIntervalSince1970
            ],
            responseText: responseText
        )
        
        return response
    }
    
    /// Handle prayer times intent
    public func handlePrayerTimesIntent(_ intent: GetPrayerTimesIntent) async -> GetPrayerTimesIntentResponse {
        guard let prayerTimeService = prayerTimeService else {
            return GetPrayerTimesIntentResponse(code: .failure, userActivity: nil)
        }
        
        let prayerTimes = await prayerTimeService.todaysPrayerTimes
        guard !prayerTimes.isEmpty else {
            return GetPrayerTimesIntentResponse(code: .failure, userActivity: nil)
        }
        
        let response = GetPrayerTimesIntentResponse(code: .success, userActivity: nil)
        
        // Format prayer times
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        let prayerStrings = prayerTimes.map { prayerTime in
            "\(prayerTime.prayer.displayName): \(timeFormatter.string(from: prayerTime.time))"
        }
        
        let responseText = "Today's prayer times are: " + prayerStrings.joined(separator: ", ")
        
        response.userActivity = createUserActivity(
            for: .prayerTimes,
            data: [
                "date": intent.date?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
                "prayer_times": prayerTimes.map { ["prayer": $0.prayer.rawValue, "time": $0.time.timeIntervalSince1970] }
            ],
            responseText: responseText
        )
        
        return response
    }
    
    /// Handle Qibla direction intent
    public func handleQiblaDirectionIntent(_ intent: GetQiblaDirectionIntent) async -> GetQiblaDirectionIntentResponse {
        guard let locationService = locationService else {
            return GetQiblaDirectionIntentResponse(code: .failure, userActivity: nil)
        }
        
        do {
            let location = try await locationService.requestLocation()
            
            // Calculate Qibla direction using QiblaDirection model
            let coord = LocationCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            let qiblaDirection = QiblaDirection.calculate(from: coord)
            
            let response = GetQiblaDirectionIntentResponse(code: .success, userActivity: nil)
            
            // Format response text
            var responseText = "The Qibla direction from your location is \(String(format: "%.1f", qiblaDirection.direction))° (\(qiblaDirection.compassDirection))"
            
            if intent.includeDistance?.boolValue == true {
                responseText += ", approximately \(qiblaDirection.formattedDistance) from the Kaaba in Mecca"
            }
            
            response.userActivity = createUserActivity(
                for: .qiblaDirection,
                data: [
                    "direction": qiblaDirection.direction,
                    "compassDirection": qiblaDirection.compassDirection,
                    "distance": qiblaDirection.distance,
                    "location": [
                        "latitude": location.coordinate.latitude,
                        "longitude": location.coordinate.longitude
                    ]
                ],
                responseText: responseText
            )
            
            return response
            
        } catch {
            print("❌ Failed to get Qibla direction: \(error)")
            return GetQiblaDirectionIntentResponse(code: .failure, userActivity: nil)
        }
    }
    
    // MARK: - User Activity
    
    private func createUserActivity(for type: ShortcutType, data: [String: Any], responseText: String? = nil) -> NSUserActivity {
        let activity = NSUserActivity(activityType: type.activityType)
        var userInfo = data
        if let responseText {
            activity.title = responseText
            userInfo["responseText"] = responseText
        } else {
            activity.title = type.title
        }
        activity.userInfo = userInfo
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        
        return activity
    }
}

// MARK: - Shortcut Types

public enum ShortcutType {
    case nextPrayer
    case prayerTimes
    case qiblaDirection
    
    public var activityType: String {
        switch self {
        case .nextPrayer:
            return "com.deenbuddy.nextprayer"
        case .prayerTimes:
            return "com.deenbuddy.prayertimes"
        case .qiblaDirection:
            return "com.deenbuddy.qibladirection"
        }
    }
    
    public var title: String {
        switch self {
        case .nextPrayer:
            return "Next Prayer Time"
        case .prayerTimes:
            return "Prayer Times"
        case .qiblaDirection:
            return "Qibla Direction"
        }
    }
}

// MARK: - Intent Responses

@available(iOS 12.0, *)
public class GetNextPrayerIntentResponse: INIntentResponse {
    public convenience init(code: GetNextPrayerIntentResponseCode, userActivity: NSUserActivity?) {
        self.init()
        self.code = code
        self.userActivity = userActivity
    }
    
    public var code: GetNextPrayerIntentResponseCode = .unspecified
}

@available(iOS 12.0, *)
public enum GetNextPrayerIntentResponseCode: Int {
    case unspecified = 0
    case ready = 1
    case continueInApp = 2
    case inProgress = 3
    case success = 4
    case failure = 5
    case failureRequiringAppLaunch = 6
}

@available(iOS 12.0, *)
public class GetPrayerTimesIntentResponse: INIntentResponse {
    public convenience init(code: GetPrayerTimesIntentResponseCode, userActivity: NSUserActivity?) {
        self.init()
        self.code = code
        self.userActivity = userActivity
    }
    
    public var code: GetPrayerTimesIntentResponseCode = .unspecified
}

@available(iOS 12.0, *)
public enum GetPrayerTimesIntentResponseCode: Int {
    case unspecified = 0
    case ready = 1
    case continueInApp = 2
    case inProgress = 3
    case success = 4
    case failure = 5
    case failureRequiringAppLaunch = 6
}

@available(iOS 12.0, *)
public class GetQiblaDirectionIntentResponse: INIntentResponse {
    public convenience init(code: GetQiblaDirectionIntentResponseCode, userActivity: NSUserActivity?) {
        self.init()
        self.code = code
        self.userActivity = userActivity
    }
    
    public var code: GetQiblaDirectionIntentResponseCode = .unspecified
}

@available(iOS 12.0, *)
public enum GetQiblaDirectionIntentResponseCode: Int {
    case unspecified = 0
    case ready = 1
    case continueInApp = 2
    case inProgress = 3
    case success = 4
    case failure = 5
    case failureRequiringAppLaunch = 6
}
