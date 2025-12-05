import Foundation
import Combine
import UserNotifications
import UIKit

/// Service responsible for coordinating notification scheduling based on prayer times and settings
@MainActor
public class NotificationScheduler: ObservableObject {
    
    // MARK: - Dependencies
    
    private let notificationService: any NotificationServiceProtocol
    private let prayerTimeService: any PrayerTimeServiceProtocol
    private let settingsService: any SettingsServiceProtocol

    // Expose dependencies for identity checks without allowing mutation
    public var notificationServiceRef: any NotificationServiceProtocol { notificationService }
    public var prayerTimeServiceRef: any PrayerTimeServiceProtocol { prayerTimeService }
    public var settingsServiceRef: any SettingsServiceProtocol { settingsService }
    
    // MARK: - Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(
        notificationService: any NotificationServiceProtocol,
        prayerTimeService: any PrayerTimeServiceProtocol,
        settingsService: any SettingsServiceProtocol
    ) {
        self.notificationService = notificationService
        self.prayerTimeService = prayerTimeService
        self.settingsService = settingsService
        
        setupObservers()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        print("📅 NotificationScheduler: Setting up observers")
        
        // Observe prayer time changes
        prayerTimeService.todaysPrayerTimesPublisher
            .receive(on: DispatchQueue.main)
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleNotifications(source: "PrayerTimeService")
            }
            .store(in: &cancellables)
            
        // Observe notification service changes (e.g. permission status)
        notificationService.authorizationStatusPublisher
            .receive(on: DispatchQueue.main)
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleNotifications(source: "NotificationService")
            }
            .store(in: &cancellables)
            
        // Observe settings changes
        settingsService.notificationsEnabledPublisher
            .combineLatest(settingsService.notificationOffsetPublisher)
            .receive(on: DispatchQueue.main)
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleNotifications(source: "SettingsService")
            }
            .store(in: &cancellables)
            
        // Listen for app becoming active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.scheduleNotifications(source: "AppDidBecomeActive")
            }
            .store(in: &cancellables)
            
        // Initial schedule
        scheduleNotifications(source: "Init")
    }
    
    private func scheduleNotifications(source: String) {
        Task {
            // Check permissions first
            let status = notificationService.authorizationStatus
            guard status == .authorized || status == .provisional else {
                // Only log if we expected to be able to schedule
                if source != "Init" {
                    print("⚠️ NotificationScheduler: Notifications not authorized (status: \(status.rawValue)) - Source: \(source)")
                }
                return
            }
            
            // Get prayer times
            let times = prayerTimeService.todaysPrayerTimes
            guard !times.isEmpty else {
                print("⚠️ NotificationScheduler: No prayer times available to schedule - Source: \(source)")
                return
            }
            
            // Schedule
            do {
                print("🔄 NotificationScheduler: Scheduling notifications triggered by \(source)")
                try await notificationService.schedulePrayerNotifications(for: times, date: Date())
                print("✅ NotificationScheduler: Successfully scheduled notifications for \(times.count) prayers")
            } catch {
                print("❌ NotificationScheduler: Failed to schedule notifications: \(error)")
            }
        }
    }
}
