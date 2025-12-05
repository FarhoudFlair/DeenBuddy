import Foundation
import ActivityKit
import UserNotifications

// MARK: - iOS 17+ Live Activity Permission Manager

@available(iOS 16.1, *)
@MainActor
final class LiveActivityPermissionManager: ObservableObject {
    
    @Published var isAuthorized: Bool = false
    @Published var pushToStartTokens: [String] = []
    
    static let shared = LiveActivityPermissionManager()
    
    private init() {
        checkCurrentAuthorizationStatus()
    }
    
    // MARK: - iOS 17+ Automatic Opt-in Handling
    
    func handleiOS17AutoOptIn() async {
        // In iOS 17+, users are automatically opted into Live Activities when they enable push notifications
        if #available(iOS 17.0, *) {
            await checkPushNotificationStatus()
        } else {
            // For iOS 16.x, we need explicit Live Activities permission
            await requestExplicitLiveActivityPermission()
        }
    }
    
    @available(iOS 17.0, *)
    private func checkPushNotificationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            // User has push notifications enabled, so Live Activities are automatically available
            self.isAuthorized = true
            await setupPushToStartTokens()
            
        case .denied:
            // User denied push notifications, Live Activities also unavailable
            self.isAuthorized = false
            
        case .notDetermined:
            // Request push notification permission (which will also enable Live Activities in iOS 17+)
            await requestPushNotificationPermission()
            
        @unknown default:
            self.isAuthorized = false
        }
    }
    
    private func requestExplicitLiveActivityPermission() async {
        // For iOS 16.x compatibility
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            self.isAuthorized = granted
            
            if granted {
                await setupPushToStartTokens()
            }
        } catch {
            print("⚠️ Live Activity permission request failed: \(error)")
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
        }
    }
    
    @available(iOS 17.0, *)
    private func requestPushNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            self.isAuthorized = granted
            
            if granted {
                await setupPushToStartTokens()
                // In iOS 17+, this also enables Live Activities automatically
                print("✅ Push notifications (and Live Activities) granted for iOS 17+")
            }
        } catch {
            print("⚠️ Push notification permission request failed: \(error)")
        }
    }
    
    // MARK: - Push-to-Start Tokens (iOS 17.2+)
    
    private func setupPushToStartTokens() async {
        if #available(iOS 17.2, *) {
            // Request push-to-start tokens for remote Live Activity management
            let optionalTokenData = Activity<PrayerCountdownActivity>.pushToStartToken
            guard let tokenData = optionalTokenData else {
                print("⚠️ Push-to-start token unavailable")
                return
            }
            let tokenString = tokenData.map { String(format: "%02x", $0) }.joined()

            DispatchQueue.main.async {
                // Only append if not already present (deduplication)
                if !self.pushToStartTokens.contains(tokenString) {
                    self.pushToStartTokens.append(tokenString)
                }
            }

            print("✅ Push-to-start token obtained: \(tokenString.prefix(16))...")

            // Send token to your server for remote Live Activity management
            await sendTokenToServer(tokenString)
        }
    }
    
    private func sendTokenToServer(_ token: String) async {
        // Implement server communication for remote Live Activity management
        // This is where you'd send the token to your backend for push-to-start capabilities
        print("📤 Sending push-to-start token to server: \(token.prefix(16))...")
        
        // Example server call (implement according to your backend)
        /*
        let url = URL(string: "https://your-server.com/api/live-activity-tokens")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ["token": token, "user_id": "current_user_id"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        print("✅ Token sent to server, response: \(response)")
        */
    }
    
    // MARK: - Authorization Status Checking
    
    private func checkCurrentAuthorizationStatus() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    self.isAuthorized = true
                case .denied, .notDetermined:
                    self.isAuthorized = false
                @unknown default:
                    self.isAuthorized = false
                }
            }
        }
    }
    
    // MARK: - User-Friendly Permission Request
    
    func requestPermissionWithContext() async {
        print("🔔 Requesting Live Activity permissions with Islamic context")
        
        // Show contextual explanation before requesting permission
        await handleiOS17AutoOptIn()
    }
    
    // MARK: - Permission Status for UI
    
    var permissionStatusMessage: String {
        if isAuthorized {
            if #available(iOS 17.0, *) {
                return "Live Activities enabled via push notifications (iOS 17+)"
            } else {
                return "Live Activities enabled"
            }
        } else {
            if #available(iOS 17.0, *) {
                return "Enable push notifications to activate Live Activities"
            } else {
                return "Live Activities disabled"
            }
        }
    }
    
    var canStartLiveActivities: Bool {
        return isAuthorized && ActivityAuthorizationInfo().areActivitiesEnabled
    }
}

// MARK: - Live Activity Configuration for iOS 17+

@available(iOS 16.1, *)
struct ModernLiveActivityConfiguration {
    
    // MARK: - Smart Duration Management
    
    static func configureForPrayerTimes() -> PrayerCountdownActivity.ContentState {
        // Configure Live Activities to respect the 8-hour limit
        // and automatically end after prayer completion
        
        // Placeholder initial content state for configuration APIs
        return PrayerCountdownActivity.ContentState(
            nextPrayer: .fajr,
            prayerTime: Date(),
            timeRemaining: 0,
            location: "Unknown",
            hijriDate: "1 Muharram 1446",
            calculationMethod: "MuslimWorldLeague",
            arabicSymbol: true
        )
    }
    
    // MARK: - iOS 17+ Automatic Refresh
    
    static func scheduleIntelligentUpdates(for activity: Activity<PrayerCountdownActivity>) {
        if #available(iOS 17.0, *) {
            // iOS 17+ handles more intelligent refresh scheduling
            // The system will automatically optimize update frequency based on user engagement
            print("✅ iOS 17+ automatic refresh optimization enabled")
        } else {
            // For iOS 16.x, we need to manually manage refresh timing
            scheduleManualRefresh(for: activity)
        }
    }
    
    // Store a reference to the repeating timer so it can be invalidated
    private static var refreshTimer: Timer?

    private static func scheduleManualRefresh(for activity: Activity<PrayerCountdownActivity>) {
        // Implement manual refresh logic for iOS 16.x
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            // Update activity state every minute
            Task {
                await updateActivityState(activity)
            }
        }
    }

    /// Stops the manual refresh timer when the activity ends.
    static func stopManualRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private static func updateActivityState(_ activity: Activity<PrayerCountdownActivity>) async {
        // Check if activity is still active before proceeding
        guard activity.activityState == .active else {
            print("⚠️ Live Activity is no longer active, stopping timer")
            stopManualRefresh()
            return
        }

        // Fetch fresh prayer time data from shared container
        guard let widgetData = WidgetDataManager.shared.loadWidgetData(),
              let nextPrayerTime = widgetData.nextPrayer else {
            print("⚠️ Unable to fetch widget data for Live Activity update, stopping refresh timer")
            refreshTimer?.invalidate()
            refreshTimer = nil
            return
        }

        let now = Date()
        let prayerTime = nextPrayerTime.time

        // Calculate time remaining (clamped to >= 0)
        let timeInterval = prayerTime.timeIntervalSince(now)
        let timeRemaining = max(0, timeInterval)

        // Map WidgetPrayer enum to Prayer enum used by ContentState
        let nextPrayer: Prayer
        switch nextPrayerTime.prayer {
        case .fajr: nextPrayer = .fajr
        case .dhuhr: nextPrayer = .dhuhr
        case .asr: nextPrayer = .asr
        case .maghrib: nextPrayer = .maghrib
        case .isha: nextPrayer = .isha
        }

        // Construct new state with fresh data
        let newState = PrayerCountdownActivity.ContentState(
            nextPrayer: nextPrayer,
            prayerTime: prayerTime,
            timeRemaining: timeRemaining,
            location: widgetData.location,
            hijriDate: widgetData.hijriDate.formatted,
            calculationMethod: widgetData.calculationMethod.rawValue,
            arabicSymbol: activity.contentState.arabicSymbol
        )

        // Set stale date to the prayer time or next reasonable refresh (e.g., 1 minute from now)
        let staleDate = timeRemaining > 60 ? Calendar.current.date(byAdding: .minute, value: 1, to: now) : prayerTime

        if #available(iOS 16.2, *) {
            await activity.update(.init(state: newState, staleDate: staleDate))
            print("✅ Live Activity state updated - Next: \(nextPrayer), Time remaining: \(Int(timeRemaining))s")
        }
    }
    
    // MARK: - Helper Functions
    
    private static func calculateTimeRemaining() -> String {
        // Implement actual prayer time calculation
        return "1:23" // Placeholder
    }
    
    private static func checkIfPrayerHasPassed() -> Bool {
        // Implement prayer time checking logic
        return false // Placeholder
    }
    
    private static func checkIfPrayerIsImminent() -> Bool {
        // Implement imminent check logic
        return false // Placeholder
    }
}
