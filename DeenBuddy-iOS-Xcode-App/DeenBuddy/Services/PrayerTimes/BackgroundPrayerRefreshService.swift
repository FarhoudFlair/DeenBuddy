import Foundation
import CoreLocation
import BackgroundTasks
import UserNotifications

// MARK: - Background Prayer Refresh Service

/// Service for preloading prayer times and maintaining fresh Islamic data
/// Ensures sub-400ms response times through intelligent prefetching
@MainActor
public class BackgroundPrayerRefreshService: ObservableObject {
    
    // MARK: - Constants
    
    private static let backgroundTaskIdentifier = "com.deenbuddy.prayer-refresh"
    private static let refreshInterval: TimeInterval = 6 * 60 * 60 // 6 hours
    
    // MARK: - Properties
    
    private let prayerTimeService: PrayerTimeService
    private let locationService: LocationService
    private var refreshTimer: Timer?
    
    @Published public var lastRefreshTime: Date?
    @Published public var nextRefreshTime: Date?
    @Published public var isRefreshing: Bool = false
    @Published public var prefetchedDays: Int = 0
    
    // MARK: - Initialization
    
    public init(prayerTimeService: PrayerTimeService, locationService: LocationService) {
        self.prayerTimeService = prayerTimeService
        self.locationService = locationService
        
        setupBackgroundRefresh()
        scheduleNextRefresh()
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
    
    private func performBackgroundRefresh() async {
        print("🕌 Performing background prayer refresh...")
        
        // Preload prayer times for the next week
        await preloadUpcomingPrayerTimes(days: 7)
        
        // Schedule next background refresh
        scheduleBackgroundAppRefresh()
        scheduleNextRefresh()
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
