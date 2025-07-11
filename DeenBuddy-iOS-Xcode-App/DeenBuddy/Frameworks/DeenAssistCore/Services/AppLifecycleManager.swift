import Foundation
import UIKit
import Combine

/// Manages iOS app lifecycle events and state transitions
@MainActor
public class AppLifecycleManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var appState: AppState = .active
    @Published public var isInBackground = false
    @Published public var backgroundTimeRemaining: TimeInterval = 0
    
    // MARK: - Public Properties
    
    public var appStatePublisher: AnyPublisher<AppState, Never> {
        $appState.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var backgroundTimer: Timer?
    private let notificationCenter = NotificationCenter.default
    
    // MARK: - Dependencies
    
    private let prayerTimeService: PrayerTimeService?
    private let notificationService: NotificationService?
    
    // MARK: - App State Enum
    
    public enum AppState {
        case active
        case inactive
        case background
        case terminated
    }
    
    // MARK: - Initialization
    
    public init(
        prayerTimeService: PrayerTimeService? = nil,
        notificationService: NotificationService? = nil
    ) {
        self.prayerTimeService = prayerTimeService
        self.notificationService = notificationService
        setupLifecycleObservers()
    }
    
    deinit {
        // Ensure UIKit cleanup is always performed on the main thread
        if Thread.isMainThread {
            backgroundTimer?.invalidate()
            backgroundTimer = nil

            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                print("⏹️ Ended background task from deinit: \(backgroundTask.rawValue)")
                backgroundTask = .invalid
            }
        } else {
            DispatchQueue.main.async { [backgroundTimer, backgroundTask] in
                backgroundTimer?.invalidate()
                // backgroundTimer is a local copy, so we can't nil the instance var here
                if backgroundTask != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTask)
                    print("⏹️ Ended background task from deinit: \(backgroundTask.rawValue)")
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    public func handleAppDidBecomeActive() {
        appState = .active
        isInBackground = false
        endBackgroundTask()
        
        // Refresh prayer times when app becomes active
        Task {
            await refreshPrayerTimesIfNeeded()
        }
        
        print("📱 App became active")
    }
    
    public func handleAppWillResignActive() {
        appState = .inactive
        print("📱 App will resign active")
    }
    
    public func handleAppDidEnterBackground() {
        appState = .background
        isInBackground = true
        startBackgroundTask()
        
        print("📱 App entered background")
    }
    
    public func handleAppWillEnterForeground() {
        appState = .active
        isInBackground = false
        endBackgroundTask()
        
        // Refresh data when returning from background
        Task {
            await refreshDataAfterBackground()
        }
        
        print("📱 App will enter foreground")
    }
    
    public func handleAppWillTerminate() {
        appState = .terminated
        endBackgroundTask()
        
        print("📱 App will terminate")
    }
    
    // MARK: - Private Methods
    
    private func setupLifecycleObservers() {
        // App lifecycle notifications
        notificationCenter.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleAppDidBecomeActive()
                }
            }
            .store(in: &cancellables)
        
        notificationCenter.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleAppWillResignActive()
                }
            }
            .store(in: &cancellables)
        
        notificationCenter.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleAppDidEnterBackground()
                }
            }
            .store(in: &cancellables)
        
        notificationCenter.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleAppWillEnterForeground()
                }
            }
            .store(in: &cancellables)
        
        notificationCenter.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleAppWillTerminate()
                }
            }
            .store(in: &cancellables)
    }
    
    private func startBackgroundTask() {
        endBackgroundTask() // End any existing task
        
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "DeenBuddy Background Task") { [weak self] in
            self?.endBackgroundTask()
        }
        
        // Start timer to track background time
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateBackgroundTimeRemaining()
            }
        }
        
        print("🔄 Started background task: \(backgroundTask.rawValue)")
    }
    
    private func endBackgroundTask() {
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            print("⏹️ Ended background task: \(backgroundTask.rawValue)")
            backgroundTask = .invalid
        }
        
        backgroundTimeRemaining = 0
    }
    
    private func updateBackgroundTimeRemaining() {
        backgroundTimeRemaining = UIApplication.shared.backgroundTimeRemaining
        
        // If we're running low on background time, clean up
        if backgroundTimeRemaining < 10 {
            print("⚠️ Background time running low: \(backgroundTimeRemaining)s")
            endBackgroundTask()
        }
    }
    
    private func refreshPrayerTimesIfNeeded() async {
        // Refresh prayer times if they're stale
        guard let prayerTimeService = prayerTimeService else { return }
        
        // Check if we need to refresh (e.g., if it's a new day)
        let calendar = Calendar.current
        let today = Date()
        
        if prayerTimeService.todaysPrayerTimes.isEmpty ||
           !calendar.isDateInToday(prayerTimeService.todaysPrayerTimes.first?.time ?? Date.distantPast) {
            
            do {
                await prayerTimeService.refreshPrayerTimes()
                print("🕌 Refreshed prayer times on app activation")
            } catch {
                print("❌ Failed to refresh prayer times: \(error)")
            }
        }
    }
    
    private func refreshDataAfterBackground() async {
        // Refresh prayer times
        await refreshPrayerTimesIfNeeded()
        
        // Update notification permissions status if needed
        if notificationService != nil {
            // Use NotificationCenter to check for notification settings changes
            // This is a simpler approach that avoids the concurrency issues
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    print("🔔 Notification status after background: \(settings.authorizationStatus.rawValue)")
                }
            }
        }
    }
}
