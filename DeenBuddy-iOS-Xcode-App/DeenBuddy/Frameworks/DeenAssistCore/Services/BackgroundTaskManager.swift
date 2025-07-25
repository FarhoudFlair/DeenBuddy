import Foundation
import BackgroundTasks
import UIKit
import CoreLocation

/// Manages background app refresh and background tasks for iOS
@MainActor
public class BackgroundTaskManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isBackgroundRefreshEnabled = false
    @Published public var lastBackgroundRefresh: Date?
    
    // MARK: - Private Properties
    
    private let backgroundTaskIdentifier = "com.deenbuddy.app.refresh"
    private let prayerUpdateIdentifier = "com.deenbuddy.app.prayer-update"
    
    // MARK: - Dependencies

    internal let prayerTimeService: (any PrayerTimeServiceProtocol)?
    private let notificationService: (any NotificationServiceProtocol)?
    private let locationService: (any LocationServiceProtocol)?
    
    // MARK: - Initialization
    
    public init(
        prayerTimeService: (any PrayerTimeServiceProtocol)? = nil,
        notificationService: (any NotificationServiceProtocol)? = nil,
        locationService: (any LocationServiceProtocol)? = nil
    ) {
        self.prayerTimeService = prayerTimeService
        self.notificationService = notificationService
        self.locationService = locationService
        
        setupBackgroundTasks()
        checkBackgroundRefreshStatus()
    }
    
    // MARK: - Public Methods
    
    public func registerBackgroundTasks() {
        // Register background app refresh task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleBackgroundAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        // Register prayer time update task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: prayerUpdateIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handlePrayerTimeUpdate(task: task as! BGProcessingTask)
        }
        
        print("📋 Registered background tasks")
    }
    
    public func scheduleBackgroundAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 Scheduled background app refresh")
        } catch {
            print("❌ Failed to schedule background app refresh: \(error)")
        }
    }
    
    public func schedulePrayerTimeUpdate() {
        let request = BGProcessingTaskRequest(identifier: prayerUpdateIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        // Schedule for next day at midnight
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let midnight = calendar.startOfDay(for: tomorrow)
        
        request.earliestBeginDate = midnight
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("🕌 Scheduled prayer time update for \(midnight)")
        } catch {
            print("❌ Failed to schedule prayer time update: \(error)")
        }
    }
    
    @MainActor
    public func checkBackgroundRefreshStatus() {
        isBackgroundRefreshEnabled = UIApplication.shared.backgroundRefreshStatus == .available
        print("🔄 Background refresh status: \(isBackgroundRefreshEnabled ? "enabled" : "disabled")")
    }
    
    // MARK: - Private Methods
    
    private func setupBackgroundTasks() {
        // Monitor background refresh status changes
        NotificationCenter.default.addObserver(
            forName: UIApplication.backgroundRefreshStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkBackgroundRefreshStatus()
            }
        }
    }
    
    private func handleBackgroundAppRefresh(task: BGAppRefreshTask) {
        print("🔄 Handling background app refresh")
        
        // Schedule the next background refresh
        scheduleBackgroundAppRefresh()
        
        // Create a task to refresh data
        let refreshTask = Task {
            await performBackgroundRefresh()
        }
        
        // Handle task expiration
        task.expirationHandler = {
            print("⏰ Background refresh task expired")
            refreshTask.cancel()
        }
        
        // Complete the task when done
        Task {
            await refreshTask.value
            task.setTaskCompleted(success: true)
            await MainActor.run {
                self.lastBackgroundRefresh = Date()
            }
            print("✅ Background refresh completed")
        }
    }
    
    private func handlePrayerTimeUpdate(task: BGProcessingTask) {
        print("🕌 Handling prayer time update")
        
        // Schedule the next prayer time update
        schedulePrayerTimeUpdate()
        
        // Create a task to update prayer times
        let updateTask = Task {
            await performPrayerTimeUpdate()
        }
        
        // Handle task expiration
        task.expirationHandler = {
            print("⏰ Prayer time update task expired")
            updateTask.cancel()
        }
        
        // Complete the task when done
        Task {
            await updateTask.value
            task.setTaskCompleted(success: true)
            print("✅ Prayer time update completed")
        }
    }
    
    private func performBackgroundRefresh() async {
        do {
            // Refresh prayer times if needed
            if let prayerTimeService = prayerTimeService {
                await prayerTimeService.refreshTodaysPrayerTimes()
            }
            
            // Update location if needed (with minimal battery usage)
            if let locationService = locationService,
               locationService.permissionStatus == .authorizedWhenInUse || locationService.permissionStatus == .authorizedAlways {
                _ = try? await locationService.requestLocation()
            }
            
            print("🔄 Background refresh completed successfully")
            
        } catch {
            print("❌ Background refresh failed: \(error)")
        }
    }
    
    private func performPrayerTimeUpdate() async {
        do {
            // Get current location
            guard let locationService = locationService,
                  locationService.permissionStatus == .authorizedWhenInUse || locationService.permissionStatus == .authorizedAlways else {
                print("📍 Location not available for prayer time update")
                return
            }
            
            // Fix: Use requestLocation which returns CLLocation directly
            let location = try await locationService.requestLocation()
            
            // Calculate prayer times for today and tomorrow
            if let prayerTimeService = prayerTimeService {
                let today = Date()
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
                
                let todayTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: today)
                let tomorrowTimes = try await prayerTimeService.calculatePrayerTimes(for: location, date: tomorrow)
                
                // Schedule notifications for tomorrow's prayers
                if let notificationService = notificationService {
                    // Pass [PrayerTime] to schedulePrayerNotifications
                    try await notificationService.schedulePrayerNotifications(for: tomorrowTimes, date: tomorrow)
                }
                
                print("🕌 Prayer times updated for today and tomorrow")
            }
            
        } catch {
            print("❌ Prayer time update failed: \(error)")
        }
    }
}
