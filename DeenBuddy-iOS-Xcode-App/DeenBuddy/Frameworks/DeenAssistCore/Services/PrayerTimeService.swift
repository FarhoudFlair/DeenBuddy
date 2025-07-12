import Foundation
import CoreLocation
import Combine
import Adhan

// MARK: - Notification Names
extension Notification.Name {
    static let settingsDidChange = Notification.Name("settingsDidChange")
}

/// Real implementation of PrayerTimeServiceProtocol using AdhanSwift
public class PrayerTimeService: PrayerTimeServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var todaysPrayerTimes: [PrayerTime] = []
    @Published public var nextPrayer: PrayerTime? = nil
    @Published public var timeUntilNextPrayer: TimeInterval? = nil
    // Computed properties that reference SettingsService (single source of truth)
    public var calculationMethod: CalculationMethod {
        settingsService.calculationMethod
    }

    public var madhab: Madhab {
        settingsService.madhab
    }
    @Published public var isLoading: Bool = false
    @Published public var error: Error? = nil
    
    // MARK: - Private Properties

    private let locationService: any LocationServiceProtocol
    private let settingsService: any SettingsServiceProtocol
    private let apiClient: any APIClientProtocol
    private let errorHandler: ErrorHandler
    private let retryMechanism: RetryMechanism
    private let networkMonitor: NetworkMonitor
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Cache Keys (Now using UnifiedSettingsKeys)
    // Note: CacheKeys enum removed - now using UnifiedSettingsKeys for consistency
    
    // MARK: - Initialization
    
    public init(locationService: any LocationServiceProtocol, settingsService: any SettingsServiceProtocol, apiClient: any APIClientProtocol, errorHandler: ErrorHandler, retryMechanism: RetryMechanism, networkMonitor: NetworkMonitor) {
        self.locationService = locationService
        self.settingsService = settingsService
        self.apiClient = apiClient
        self.errorHandler = errorHandler
        self.retryMechanism = retryMechanism
        self.networkMonitor = networkMonitor
        setupLocationObserver()
        setupSettingsObservers()
        startTimer()

        // Load any existing cached prayer times
        if let cachedTimes = loadCachedPrayerTimes() {
            todaysPrayerTimes = cachedTimes
            updateNextPrayer()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - Protocol Implementation
    
    public func calculatePrayerTimes(for location: CLLocation, date: Date) async throws -> [PrayerTime] {
        return try await retryMechanism.executeWithRetry(
            operation: {
                return try await self.performPrayerTimeCalculation(for: location, date: date)
            },
            retryPolicy: .conservative,
            operationId: "calculatePrayerTimes-\(date.timeIntervalSince1970)"
        )
    }

    private func performPrayerTimeCalculation(for location: CLLocation, date: Date) async throws -> [PrayerTime] {
        isLoading = true
        error = nil

        defer {
            isLoading = false
        }

        do {
            let coordinates = Coordinates(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            let dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)

            // Convert app's CalculationMethod to Adhan.CalculationMethod
            let adhanMethod = calculationMethod.toAdhanMethod()
            var params = adhanMethod.params
            params.madhab = madhab.adhanMadhab()
            // Use Adhan.PrayerTimes to avoid collision with app's PrayerTimes
            guard let adhanPrayerTimes = Adhan.PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: params) else {
                throw AppError.serviceUnavailable("Prayer time calculation")
            }

            let prayerTimes = [
                PrayerTime(prayer: .fajr, time: adhanPrayerTimes.fajr),
                PrayerTime(prayer: .dhuhr, time: adhanPrayerTimes.dhuhr),
                PrayerTime(prayer: .asr, time: adhanPrayerTimes.asr),
                PrayerTime(prayer: .maghrib, time: adhanPrayerTimes.maghrib),
                PrayerTime(prayer: .isha, time: adhanPrayerTimes.isha)
            ]

            // Cache the results
            cachePrayerTimes(prayerTimes, for: date)

            return prayerTimes

        } catch {
            let appError = convertToAppError(error)
            self.error = appError
            await errorHandler.handleError(appError)
            throw appError
        }
    }
    
    public func refreshPrayerTimes() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Check for cached data first if offline
            if await !networkMonitor.isConnected {
                if let cachedTimes = loadCachedPrayerTimes() {
                    todaysPrayerTimes = cachedTimes
                    updateNextPrayer()
                    return
                }
            }

            // Try to get location if not available
            var location = locationService.currentLocation
            if location == nil {
                // Try to request location if we have permission
                if locationService.authorizationStatus == .authorizedWhenInUse ||
                   locationService.authorizationStatus == .authorizedAlways {
                    do {
                        location = try await locationService.requestLocation()
                    } catch {
                        print("Failed to get location for prayer times: \(error)")
                    }
                }
            }

            guard let validLocation = location else {
                let locationError = AppError.locationUnavailable
                error = locationError
                // Don't log this as an error if permission is not granted
                if locationService.authorizationStatus == .authorizedWhenInUse ||
                   locationService.authorizationStatus == .authorizedAlways {
                    await errorHandler.handleError(locationError)
                }
                return
            }

            let prayerTimes = try await calculatePrayerTimes(for: validLocation, date: Date())
            todaysPrayerTimes = prayerTimes
            updateNextPrayer()
            error = nil // Clear any previous errors
        } catch {
            let appError = convertToAppError(error)
            self.error = appError
            await errorHandler.handleError(appError)
        }
    }

    public func refreshTodaysPrayerTimes() async {
        // Alias for refreshPrayerTimes() to satisfy BackgroundTaskManager requirements
        await refreshPrayerTimes()
    }

    public func getCurrentLocation() async throws -> CLLocation {
        // Delegate to location service
        return try await locationService.requestLocation()
    }
    
    public func getPrayerTimes(from startDate: Date, to endDate: Date) async throws -> [Date: [PrayerTime]] {
        // Fix: Remove .clLocation property access - use currentLocation directly
        guard let location = locationService.currentLocation else {
            throw AppError.locationUnavailable
        }
        
        var result: [Date: [PrayerTime]] = [:]
        let calendar = Calendar.current
        var currentDate = startDate
        
        while currentDate <= endDate {
            let prayerTimes = try await calculatePrayerTimes(for: location, date: currentDate)
            result[currentDate] = prayerTimes
            
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }
        
        return result
    }
    
    // MARK: - Private Methods
    
    // Note: Settings management removed - now handled by SettingsService
    // PrayerTimeService only manages prayer time calculations and caching
    
    private func setupLocationObserver() {
        locationService.locationPublisher
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] _ in
                    Task {
                        await self?.refreshPrayerTimes()
                    }
                }
            )
            .store(in: &cancellables)
    }

    private func setupSettingsObservers() {
        // Use NotificationCenter to avoid the existential type ObjectWillChangePublisher issue
        // This is a robust solution that works with protocol-typed instances
        NotificationCenter.default.publisher(for: .settingsDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.invalidateCacheAndRefresh()
                }
            }
            .store(in: &cancellables)
    }

    /// Invalidates cached prayer times and triggers recalculation when settings change
    private func invalidateCacheAndRefresh() async {
        print("Settings changed - invalidating cache and refreshing prayer times")

        // Clear all cached prayer times from all cache systems
        await invalidateAllPrayerTimeCaches()

        // Recalculate prayer times with new settings
        await refreshPrayerTimes()
    }

    /// Comprehensive cache invalidation across all cache systems
    private func invalidateAllPrayerTimeCaches() async {
        print("🗑️ Starting comprehensive cache invalidation...")

        // 1. Clear local UserDefaults cache (existing implementation)
        clearLocalCachedPrayerTimes()

        // 2. Clear APICache prayer times through APIClient
        apiClient.clearPrayerTimeCache()

        // 3. Clear IslamicCacheManager prayer times
        await clearIslamicCacheManagerPrayerTimes()

        print("✅ Comprehensive cache invalidation completed")
    }

    /// Clears all cached prayer times from UserDefaults (local cache)
    private func clearLocalCachedPrayerTimes() {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let cachePrefix = UnifiedSettingsKeys.cachedPrayerTimes + "_"

        var clearedCount = 0
        for key in allKeys {
            if key.hasPrefix(cachePrefix) {
                userDefaults.removeObject(forKey: key)
                clearedCount += 1
                print("Cleared local cached prayer times for key: \(key)")
            }
        }

        userDefaults.removeObject(forKey: UnifiedSettingsKeys.cacheDate)
        userDefaults.synchronize()

        print("✅ Local cache: Cleared \(clearedCount) prayer time cache entries")
    }

    /// Clears prayer time cache from IslamicCacheManager
    private func clearIslamicCacheManagerPrayerTimes() async {
        // Create a temporary instance to clear cache
        // Note: In a production app, this should be injected as a dependency
        await MainActor.run {
            let cacheManager = IslamicCacheManager()
            // Clear only prayer time related cache
            cacheManager.clearPrayerTimeCache()
            print("IslamicCacheManager prayer times cleared")
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateNextPrayer()
            }
        }
    }
    
    private func updateNextPrayer() {
        let now = Date()
        let upcomingPrayers = todaysPrayerTimes.filter { $0.time > now }
        
        if let next = upcomingPrayers.first {
            nextPrayer = next
            timeUntilNextPrayer = next.time.timeIntervalSince(now)
        } else {
            // No more prayers today, get tomorrow's Fajr
            Task {
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
                if let location = locationService.currentLocation {
                    do {
                        let tomorrowPrayers = try await calculatePrayerTimes(for: location, date: tomorrow)
                        if let fajr = tomorrowPrayers.first(where: { $0.prayer == .fajr }) {
                            nextPrayer = fajr
                            timeUntilNextPrayer = fajr.time.timeIntervalSince(now)
                        }
                    } catch {
                        self.error = error
                    }
                }
            }
        }
    }
    
    private func cachePrayerTimes(_ prayerTimes: [PrayerTime], for date: Date) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateFormatter.string(from: date)

        // Include calculation method and madhab in cache key
        let methodKey = calculationMethod.rawValue
        let madhabKey = madhab.rawValue
        let cacheKey = "\(UnifiedSettingsKeys.cachedPrayerTimes)_\(dateKey)_\(methodKey)_\(madhabKey)"

        if let data = try? JSONEncoder().encode(prayerTimes) {
            userDefaults.set(data, forKey: cacheKey)
            userDefaults.set(dateKey, forKey: UnifiedSettingsKeys.cacheDate)
        }
    }

    private func loadCachedPrayerTimes() -> [PrayerTime]? {
        let today = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = dateFormatter.string(from: today)

        // Include calculation method and madhab in cache key
        let methodKey = calculationMethod.rawValue
        let madhabKey = madhab.rawValue
        let cacheKey = "\(UnifiedSettingsKeys.cachedPrayerTimes)_\(todayKey)_\(methodKey)_\(madhabKey)"

        if let data = userDefaults.data(forKey: cacheKey),
           let cachedPrayers = try? JSONDecoder().decode([PrayerTime].self, from: data) {
            return cachedPrayers
        }
        return nil
    }

    private func convertToAppError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        if error is PrayerTimeError {
            return AppError.serviceUnavailable("Prayer time calculation")
        }

        return AppError.unknownError(error)
    }
}

// MARK: - Extensions

extension CalculationMethod {
    /// Converts app's CalculationMethod to Adhan library's CalculationMethod
    func toAdhanMethod() -> Adhan.CalculationMethod {
        switch self {
        case .muslimWorldLeague:
            return .muslimWorldLeague
        case .egyptian:
            return .egyptian
        case .karachi:
            return .karachi
        case .ummAlQura:
            return .ummAlQura
        case .dubai:
            return .dubai
        case .moonsightingCommittee:
            return .moonsightingCommittee
        case .northAmerica:
            return .northAmerica
        case .kuwait:
            return .kuwait
        case .qatar:
            return .qatar
        case .singapore:
            return .singapore
        }
    }
}

extension Madhab {
    func adhanMadhab() -> Adhan.Madhab {
        switch self {
        case .shafi:
            return .shafi
        case .hanafi:
            return .hanafi
        case .sunni:
            return .shafi  // Default to Shafi for general Sunni
        case .shia:
            return .shafi  // Adhan library doesn't have Shia, default to Shafi
        }
    }
}

// MARK: - Error Types

public enum PrayerTimeError: LocalizedError {
    case calculationFailed
    case locationUnavailable
    case invalidDate
    case permissionDenied
    case networkError
    
    public var errorDescription: String? {
        switch self {
        case .calculationFailed:
            return "Failed to calculate prayer times"
        case .locationUnavailable:
            return "Location is not available"
        case .invalidDate:
            return "Invalid date provided"
        case .permissionDenied:
            return "Location permission denied"
        case .networkError:
            return "Network connection error"
        }
    }
}
