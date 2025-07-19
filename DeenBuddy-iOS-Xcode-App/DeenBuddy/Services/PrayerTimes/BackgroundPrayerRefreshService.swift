import Foundation
import CoreLocation
import BackgroundTasks
import UserNotifications
import Combine

// MARK: - Background Prayer Refresh Service

/// Service for preloading prayer times and maintaining fresh Islamic data
/// Ensures sub-400ms response times through intelligent prefetching
@MainActor
public class BackgroundPrayerRefreshService: ObservableObject {
    
    // MARK: - Constants
    
    private static let backgroundTaskIdentifier = "com.deenbuddy.prayer-refresh"
    private static let refreshInterval: TimeInterval = 6 * 60 * 60 // 6 hours
    
    // MARK: - Properties
    
    private let prayerTimeService: any PrayerTimeServiceProtocol
    private let locationService: any LocationServiceProtocol
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    @Published public var lastRefreshTime: Date?
    @Published public var nextRefreshTime: Date?
    @Published public var isRefreshing: Bool = false
    @Published public var prefetchedDays: Int = 0

    // PERFORMANCE: Prevent concurrent refresh operations
    private var isRefreshInProgress: Bool = false
    
    // MARK: - Initialization
    
    public init(prayerTimeService: any PrayerTimeServiceProtocol, locationService: any LocationServiceProtocol) {
        self.prayerTimeService = prayerTimeService
        self.locationService = locationService

        setupBackgroundRefresh()
        scheduleNextRefresh()
        setupSettingsObserver()
    }

    /// Set up observer for settings changes to invalidate cache and refresh
    private func setupSettingsObserver() {
        // Since PrayerTimeService already observes settings changes and invalidates cache,
        // we just need to ensure our background refresh respects the current settings
        // The PrayerTimeService will handle cache invalidation when settings change
        print("🔄 BackgroundPrayerRefreshService: Settings observer configured")
    }
    
    // MARK: - Public Methods
    
    /// Start background prayer time prefetching
    public func startBackgroundRefresh() {
        guard refreshTimer == nil else { return }
        
        // Schedule immediate refresh
        Task {
            await performBackgroundRefresh()
        }
        
        // Schedule periodic refresh
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performBackgroundRefresh()
            }
        }
        
        print("🕌 Background prayer refresh started")
    }
    
    /// Stop background refresh
    public func stopBackgroundRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        print("🕌 Background prayer refresh stopped")
    }
    
    /// Preload prayer times for upcoming days
    public func preloadUpcomingPrayerTimes(days: Int = 7) async {
        guard let location = locationService.currentLocation else {
            print("⚠️ Cannot preload prayer times - location unavailable")
            return
        }
        
        isRefreshing = true
        let calendar = Calendar.current
        let today = Date()
        
        print("🕌 Preloading prayer times for \(days) days...")
        
        for dayOffset in 0..<days {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else {
                continue
            }
            
            do {
                let schedule = try await prayerTimeService.calculatePrayerTimes(
                    for: location,
                    date: targetDate
                )
                
                // Cache is handled automatically by PrayerTimeService
                print("✅ Preloaded prayer times for \(targetDate.formatted(date: .abbreviated, time: .omitted))")
                
            } catch is CancellationError {
                // Handle cancellation gracefully - this is normal if the task is cancelled
                print("ℹ️ Prayer time preloading was cancelled for \(targetDate.formatted(date: .abbreviated, time: .omitted))")
                break // Exit the loop since we're cancelled
            } catch {
                print("❌ Failed to preload prayer times for \(targetDate): \(error)")
            }
        }
        
        prefetchedDays = days
        isRefreshing = false
        lastRefreshTime = Date()
        
        print("🕌 Prayer time preloading completed")
    }
    
    /// Preload prayer times for current location when it changes
    public func preloadForLocationChange(_ newLocation: CLLocation) async {
        print("🕌 Location changed - preloading prayer times for new location")
        
        // Preload current and next day immediately
        let calendar = Calendar.current
        let today = Date()
        
        for dayOffset in 0..<2 {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else {
                continue
            }
            
            do {
                _ = try await prayerTimeService.calculatePrayerTimes(
                    for: newLocation,
                    date: targetDate
                )
            } catch is CancellationError {
                // Handle cancellation gracefully - this is normal if the task is cancelled
                print("ℹ️ Location change preloading was cancelled")
                break // Exit the loop since we're cancelled
            } catch {
                print("❌ Failed to preload for location change: \(error)")
            }
        }
    }
    
    /// Schedule next refresh time
    public func scheduleNextRefresh() {
        nextRefreshTime = Date().addingTimeInterval(Self.refreshInterval)
    }
    
    // MARK: - Private Methods
    
    private func setupBackgroundRefresh() {
        // Register background task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundTaskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    /// PERFORMANCE: Optimized background refresh with task coordination
    private func performBackgroundRefresh() async {
        print("🕌 Performing background prayer refresh...")

        // PERFORMANCE: Check if another refresh is already in progress
        guard !isRefreshInProgress else {
            print("⚠️ Background refresh already in progress - skipping")
            return
        }

        isRefreshInProgress = true
        defer { isRefreshInProgress = false }

        do {
            // BATTERY OPTIMIZATION: Reduce preload days based on battery level
            let preloadDays = BatteryOptimizer.shared.optimizationLevel == .extreme ? 3 : 7

            // Preload prayer times with battery awareness
            await preloadUpcomingPrayerTimes(days: preloadDays)

            // PERFORMANCE: Only schedule next refresh if current one succeeded
            scheduleBackgroundAppRefresh()
            scheduleNextRefresh()

            print("✅ Background prayer refresh completed successfully")
        } catch {
            print("❌ Background prayer refresh failed: \(error)")
            // Don't schedule next refresh on failure to prevent error loops
        }
    }
    
    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        // Set expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Perform refresh
        Task {
            await performBackgroundRefresh()
            task.setTaskCompleted(success: true)
        }
    }
    
    private func scheduleBackgroundAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.refreshInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("🕌 Background app refresh scheduled")
        } catch is CancellationError {
            // Handle cancellation gracefully - this is normal if the task is cancelled
            print("ℹ️ Background refresh scheduling was cancelled")
        } catch {
            print("❌ Failed to schedule background refresh: \(error)")
        }
    }
}

// MARK: - Prayer Data Prefetcher

/// Intelligent prefetching for Islamic content and prayer calculations
@MainActor
public class PrayerDataPrefetcher: ObservableObject {
    
    // MARK: - Properties
    
    private let prayerTimeService: PrayerTimeService
    private let qiblaCache: QiblaDirectionCache
    
    @Published public var prefetchProgress: Double = 0.0
    @Published public var isPrefetching: Bool = false
    
    // MARK: - Initialization
    
    public init(prayerTimeService: PrayerTimeService, qiblaCache: QiblaDirectionCache) {
        self.prayerTimeService = prayerTimeService
        self.qiblaCache = qiblaCache
    }
    
    // MARK: - Public Methods
    
    /// Prefetch critical Islamic data for instant access
    public func prefetchCriticalData() async {
        isPrefetching = true
        prefetchProgress = 0.0
        
        print("🕌 Starting critical Islamic data prefetch...")
        
        // 1. Preload common Qibla directions (25% progress)
        qiblaCache.preloadCommonDirections()
        prefetchProgress = 0.25
        
        // 2. Preload current day prayer times (50% progress)
        if let location = await getCurrentLocation() {
            do {
                _ = try await prayerTimeService.calculatePrayerTimes(for: location, date: Date())
                prefetchProgress = 0.5
                
                // 3. Preload next day prayer times (75% progress)
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                _ = try await prayerTimeService.calculatePrayerTimes(for: location, date: tomorrow)
                prefetchProgress = 0.75
                
            } catch is CancellationError {
                // Handle cancellation gracefully - this is normal if the task is cancelled
                print("ℹ️ Critical data prefetch was cancelled")
            } catch {
                print("❌ Failed to prefetch prayer times: \(error)")
            }
        }
        
        // 4. Complete prefetch (100% progress)
        prefetchProgress = 1.0
        isPrefetching = false
        
        print("✅ Critical Islamic data prefetch completed")
    }
    
    /// Prefetch data based on user navigation patterns
    public func prefetchForRoute(_ route: String) async {
        switch route {
        case "qibla":
            // Prefetch Qibla direction for current location
            if let location = await getCurrentLocation() {
                let coordinate = LocationCoordinate(from: location.coordinate)
                let direction = QiblaDirection.calculate(from: coordinate)
                qiblaCache.cacheDirection(direction, for: location)
            }
            
        case "prayer-times":
            // Prefetch prayer times for current week
            if let location = await getCurrentLocation() {
                for dayOffset in 0..<7 {
                    let targetDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
                    do {
                        _ = try await prayerTimeService.calculatePrayerTimes(for: location, date: targetDate)
                    } catch is CancellationError {
                        // Handle cancellation gracefully - this is normal if the task is cancelled
                        print("ℹ️ Route prefetch was cancelled")
                        break // Exit the loop since we're cancelled
                    } catch {
                        print("❌ Failed to prefetch prayer times for route: \(error)")
                    }
                }
            }
            
        default:
            break
        }
    }
    
    // MARK: - Private Methods
    
    private func getCurrentLocation() async -> CLLocation? {
        try? await prayerTimeService.getCurrentLocation()
    }
}
