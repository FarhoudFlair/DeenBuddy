import Foundation
import CoreLocation
import Combine
import Adhan
import ActivityKit


/// Real implementation of PrayerTimeServiceProtocol using AdhanSwift
public class PrayerTimeService: PrayerTimeServiceProtocol, ObservableObject {
    
    // MARK: - Logger
    
    private let logger = AppLogger.prayerTimes
    
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
    private let timerManager = BatteryAwareTimerManager.shared
    private var updateNextPrayerTask: Task<Void, Never>?
    private let userDefaults = UserDefaults.standard
    private let islamicCacheManager: IslamicCacheManager
    private let islamicCalendarService: any IslamicCalendarServiceProtocol
    
    // MARK: - Cache Keys (Now using UnifiedSettingsKeys)
    // Note: CacheKeys enum removed - now using UnifiedSettingsKeys for consistency
    
    // MARK: - Initialization
    
    public init(locationService: any LocationServiceProtocol, settingsService: any SettingsServiceProtocol, apiClient: any APIClientProtocol, errorHandler: ErrorHandler, retryMechanism: RetryMechanism, networkMonitor: NetworkMonitor, islamicCacheManager: IslamicCacheManager, islamicCalendarService: any IslamicCalendarServiceProtocol) {
        self.locationService = locationService
        self.settingsService = settingsService
        self.apiClient = apiClient
        self.errorHandler = errorHandler
        self.retryMechanism = retryMechanism
        self.networkMonitor = networkMonitor
        self.islamicCacheManager = islamicCacheManager
        self.islamicCalendarService = islamicCalendarService
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
        // Cancel all tasks first
        updateNextPrayerTask?.cancel()
        updateNextPrayerTask = nil

        // Cancel all Combine subscriptions
        cancellables.removeAll()

        // Cancel timer synchronously to avoid retain cycles
        // Note: This is safe because timerManager is designed to handle cross-actor calls
        timerManager.cancelTimerSync(id: "prayer-update")

        print("🧹 PrayerTimeService deinit completed")
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
            var params: CalculationParameters

            // Use custom parameters for methods not directly supported by Adhan library
            if let customParams = calculationMethod.customParameters() {
                params = customParams
                logger.info("Using custom parameters for \(calculationMethod.rawValue)")
            } else {
                params = adhanMethod.params
            }

            // CRITICAL: Always set madhab AFTER parameter initialization to ensure Asr calculation priority
            // This ensures Hanafi madhab (2x shadow) takes precedence over any default madhab settings
            let targetMadhab = madhab.adhanMadhab()
            params.madhab = targetMadhab

            // Validate that Hanafi madhab is properly applied (critical for Asr timing accuracy)
            if madhab == .hanafi && params.madhab != .hanafi {
                logger.error("CRITICAL: Hanafi madhab not properly applied - Asr calculation will be incorrect")
                params.madhab = .hanafi // Force correction
            }

            logger.info("Applied madhab: \(params.madhab) for calculation method: \(calculationMethod.rawValue)")

            // Apply Ramadan-specific adjustments for Umm Al-Qura and Qatar methods
            await applyRamadanAdjustments(to: &params, for: date)

            // Apply custom madhab-specific adjustments
            applyMadhabAdjustments(to: &params, madhab: madhab)

            // Final validation to ensure madhab priority is maintained
            validateMadhabApplication(params: params, expectedMadhab: madhab)

            // Use Adhan.PrayerTimes to avoid collision with app's PrayerTimes
            guard let adhanPrayerTimes = Adhan.PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: params) else {
                throw AppError.serviceUnavailable("Prayer time calculation")
            }

            var prayerTimes = [
                PrayerTime(prayer: .fajr, time: adhanPrayerTimes.fajr),
                PrayerTime(prayer: .dhuhr, time: adhanPrayerTimes.dhuhr),
                PrayerTime(prayer: .asr, time: adhanPrayerTimes.asr),
                PrayerTime(prayer: .maghrib, time: adhanPrayerTimes.maghrib),
                PrayerTime(prayer: .isha, time: adhanPrayerTimes.isha)
            ]

            // Apply post-calculation madhab adjustments
            prayerTimes = await applyPostCalculationAdjustments(to: prayerTimes, madhab: madhab)

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
                        logger.warning("Failed to get location for prayer times: \(error)")
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

            // Update widget data when prayer times are updated
            await updateWidgetData()

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
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                // Execute directly on main queue instead of creating a new Task
                // This ensures immediate execution in test environments
                DispatchQueue.main.async {
                    Task { @MainActor in
                        await self?.invalidateCacheAndRefresh()
                    }
                }
            }
            .store(in: &cancellables)
    }

    /// Invalidates cached prayer times and triggers recalculation when settings change
    @MainActor
    private func invalidateCacheAndRefresh() async {
        logger.debug("Settings changed - invalidating cache and refreshing prayer times")

        // Clear all cached prayer times from all cache systems
        await invalidateAllPrayerTimeCaches()

        // Recalculate prayer times with new settings
        await refreshPrayerTimes()
    }

    /// Comprehensive cache invalidation across all cache systems
    private func invalidateAllPrayerTimeCaches() async {
        logger.debug("Starting comprehensive cache invalidation...")

        // 1. Clear local UserDefaults cache (existing implementation)
        clearLocalCachedPrayerTimes()

        // 2. Clear APICache prayer times through APIClient
        apiClient.clearPrayerTimeCache()

        // 3. Clear IslamicCacheManager prayer times
        await clearIslamicCacheManagerPrayerTimes()

        logger.debug("Comprehensive cache invalidation completed")
    }
    
    /// Cancel all pending async tasks
    private func cancelAllTasks() {
        updateNextPrayerTask?.cancel()
        updateNextPrayerTask = nil
        
        // Cancel all Combine subscriptions
        cancellables.removeAll()
        
        logger.debug("All async tasks cancelled")
    }
    
    /// Manual cleanup for testing or debugging
    public func cleanup() {
        // Cancel timer synchronously for consistent cleanup behavior
        timerManager.cancelTimerSync(id: "prayer-update")

        // Cancel all tasks and subscriptions
        cancelAllTasks()

        logger.debug("PrayerTimeService manually cleaned up")
    }
    
    /// Manually trigger Dynamic Island for next prayer (for testing/debugging)
    public func triggerDynamicIslandForNextPrayer() async {
        guard let nextPrayer = nextPrayer else {
            logger.debug("No next prayer available to trigger Dynamic Island")
            return
        }
        
        await startDynamicIslandForPrayer(nextPrayer)
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
                logger.debug("Cleared local cached prayer times for key: \(key)")
            }
        }

        userDefaults.removeObject(forKey: UnifiedSettingsKeys.cacheDate)
        userDefaults.synchronize()

        logger.debug("Local cache: Cleared \(clearedCount) prayer time cache entries")
    }

    /// Clears prayer time cache from IslamicCacheManager
    private func clearIslamicCacheManagerPrayerTimes() async {
        await MainActor.run {
            islamicCacheManager.clearPrayerTimeCache()
            logger.debug("IslamicCacheManager prayer times cleared")
        }
    }
    
    private func startTimer() {
        timerManager.schedulePrayerUpdateTimer { [weak self] in
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
            
            // Auto-trigger Dynamic Island for approaching prayers
            checkAndTriggerDynamicIslandForPrayer(next)
        } else {
            // No more prayers today, get tomorrow's Fajr
            updateNextPrayerTask?.cancel()
            updateNextPrayerTask = Task { [weak self] in
                guard let self = self else { return }
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
                if let location = self.locationService.currentLocation {
                    do {
                        let tomorrowPrayers = try await self.calculatePrayerTimes(for: location, date: tomorrow)
                        if let fajr = tomorrowPrayers.first(where: { $0.prayer == .fajr }) {
                            await MainActor.run {
                                self.nextPrayer = fajr
                                self.timeUntilNextPrayer = fajr.time.timeIntervalSince(now)
                            }

                            // Auto-trigger Dynamic Island for tomorrow's Fajr
                            self.checkAndTriggerDynamicIslandForPrayer(fajr)
                        }
                    } catch {
                        await MainActor.run {
                            self.error = error
                        }
                    }
                }
            }
        }
    }
    
    /// Automatically trigger Dynamic Island when prayer time approaches
    private func checkAndTriggerDynamicIslandForPrayer(_ prayerTime: PrayerTime) {
        guard let timeUntilPrayer = timeUntilNextPrayer else { return }
        
        // Only trigger if notifications are enabled (user preference)
        guard settingsService.notificationsEnabled else { return }
        
        // Trigger Dynamic Island when prayer is within 30 minutes
        let triggerThreshold: TimeInterval = 30 * 60 // 30 minutes
        
        if timeUntilPrayer <= triggerThreshold && timeUntilPrayer > 0 {
            Task {
                await startDynamicIslandForPrayer(prayerTime)
            }
        }
    }
    
    /// Start Dynamic Island Live Activity for the approaching prayer
    private func startDynamicIslandForPrayer(_ prayerTime: PrayerTime) async {
        // Check if iOS 16.1+ is available for Live Activities
        if #available(iOS 16.1, *) {
            do {
                // Check if Live Activities are available and enabled
                let authInfo = ActivityAuthorizationInfo()
                guard authInfo.areActivitiesEnabled else {
                    logger.debug("Live Activities are not enabled, skipping Dynamic Island")
                    return
                }

                // Prevent duplicate Live Activities - check if one is already active
                let liveActivityManager = PrayerLiveActivityManager.shared
                if liveActivityManager.isActivityActive {
                    logger.debug("Live Activity already active, skipping duplicate Dynamic Island creation")
                    return
                }

                // Get current location info
                let locationInfo = locationService.currentLocationInfo?.city ?? "Current Location"
                let hijriDate = HijriDate(from: Date())

                // Use the integration service to start Dynamic Island
                try await DynamicIslandIntegrationService.shared.startPrayerCountdownWithDynamicIsland(
                    prayerTime: prayerTime,
                    location: locationInfo,
                    hijriDate: hijriDate,
                    calculationMethod: calculationMethod
                )

                logger.info("Auto-started Dynamic Island for \(prayerTime.prayer.displayName) prayer")
            } catch {
                // Handle specific Live Activity errors gracefully
                if let activityError = error as? LiveActivityError {
                    switch activityError {
                    case .notAvailable, .permissionDenied:
                        logger.debug("Live Activities not available or permission denied, skipping Dynamic Island")
                    default:
                        logger.error("Failed to auto-start Dynamic Island: \(activityError.localizedDescription)")
                    }
                } else {
                    logger.error("Failed to auto-start Dynamic Island: \(error)")
                }
            }
        }
    }

    /// Update widget data when prayer times change
    private func updateWidgetData() async {
        guard !todaysPrayerTimes.isEmpty else { return }

        // Create widget data
        let widgetData = WidgetData(
            nextPrayer: nextPrayer,
            timeUntilNextPrayer: timeUntilNextPrayer,
            todaysPrayerTimes: todaysPrayerTimes,
            hijriDate: HijriDate(from: Date()),
            location: "Current Location",
            calculationMethod: calculationMethod,
            lastUpdated: Date()
        )

        // Save widget data using the shared manager
        WidgetDataManager.shared.saveWidgetData(widgetData)

        logger.debug("Widget data updated from PrayerTimeService")
    }
    
    private func cachePrayerTimes(_ prayerTimes: [PrayerTime], for date: Date) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateKey = dateFormatter.string(from: date)

        // Include calculation method and madhab in cache key
        let methodKey = calculationMethod.rawValue
        let madhabKey = madhab.rawValue
        let cacheKey = "\(UnifiedSettingsKeys.cachedPrayerTimes)_\(dateKey)_\(methodKey)_\(madhabKey)"

        do {
            let data = try JSONEncoder().encode(prayerTimes)

            // Check data size before storing (limit to 50KB per cache entry to prevent UserDefaults bloat)
            let maxCacheSize = 50 * 1024 // 50KB
            if data.count > maxCacheSize {
                logger.warning("Prayer times data too large (\(data.count) bytes), using file-based cache instead")
                cacheToFile(prayerTimes, cacheKey: cacheKey, dateKey: dateKey)
                return
            }

            // Clean old cache entries before adding new ones to prevent UserDefaults bloat
            cleanOldCacheEntries()

            userDefaults.set(data, forKey: cacheKey)
            userDefaults.set(dateKey, forKey: UnifiedSettingsKeys.cacheDate)
            logger.debug("Cached prayer times for \(dateKey) (\(data.count) bytes)")
        } catch {
            logger.error("Failed to cache prayer times: \(error)")
        }
    }

    /// Cache prayer times to file system for large data
    private func cacheToFile(_ prayerTimes: [PrayerTime], cacheKey: String, dateKey: String) {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("Could not access documents directory for file caching")
            return
        }

        let cacheDirectory = documentsPath.appendingPathComponent("PrayerTimesCache")

        do {
            // Create cache directory if it doesn't exist
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

            let fileURL = cacheDirectory.appendingPathComponent("\(cacheKey).json")
            let data = try JSONEncoder().encode(prayerTimes)
            try data.write(to: fileURL)

            // Store file reference in UserDefaults (much smaller)
            userDefaults.set(fileURL.path, forKey: "\(cacheKey)_file")
            userDefaults.set(dateKey, forKey: UnifiedSettingsKeys.cacheDate)
            logger.debug("Cached prayer times to file: \(fileURL.lastPathComponent)")
        } catch {
            logger.error("Failed to cache prayer times to file: \(error)")
        }
    }

    /// Clean old cache entries to prevent UserDefaults bloat and remove corresponding files
    private func cleanOldCacheEntries() {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Get all UserDefaults keys
        let allKeys = userDefaults.dictionaryRepresentation().keys
        var removedCount = 0
        var removedFileCount = 0

        // Find and remove old prayer time cache entries
        for key in allKeys {
            if key.hasPrefix(UnifiedSettingsKeys.cachedPrayerTimes) {
                // Extract date from key
                let components = key.components(separatedBy: "_")
                if components.count >= 2,
                   let date = dateFormatter.date(from: components[1]),
                   date < cutoffDate {

                    // Check if this is a file-based cache entry
                    let fileKey = "\(key)_file"
                    if let filePath = userDefaults.string(forKey: fileKey) {
                        // Validate that the file path is within the expected cache directory
                        let fileURL = URL(fileURLWithPath: filePath)
                        if isFileInCacheDirectory(fileURL) {
                            // Remove the cached file from disk
                            do {
                                try FileManager.default.removeItem(at: fileURL)
                                removedFileCount += 1
                                logger.debug("Removed cached file: \(fileURL.lastPathComponent)")
                            } catch {
                                logger.warning("Failed to remove cached file \(fileURL.lastPathComponent): \(error)")
                            }
                        } else {
                            logger.warning("Skipping removal of file outside cache directory: \(filePath)")
                        }

                        // Remove the file reference from UserDefaults regardless
                        userDefaults.removeObject(forKey: fileKey)
                    }

                    // Remove the main cache entry
                    userDefaults.removeObject(forKey: key)
                    removedCount += 1
                }
            }
        }

        if removedCount > 0 {
            logger.debug("Cleaned \(removedCount) old cache entries from UserDefaults")
        }

        if removedFileCount > 0 {
            logger.debug("Cleaned \(removedFileCount) old cache files from disk")
        }

        // Also clean up any orphaned cache files
        cleanOrphanedCacheFiles(cutoffDate: cutoffDate, dateFormatter: dateFormatter)
    }

    /// Validates that a file URL is within the expected cache directory
    private func isFileInCacheDirectory(_ fileURL: URL) -> Bool {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }

        let expectedCacheDirectory = documentsPath.appendingPathComponent("PrayerTimesCache")

        // Resolve any symbolic links and normalize paths
        let resolvedFileURL = fileURL.resolvingSymlinksInPath()
        let resolvedCacheDirectory = expectedCacheDirectory.resolvingSymlinksInPath()

        // Check if the file path starts with the cache directory path
        return resolvedFileURL.path.hasPrefix(resolvedCacheDirectory.path + "/") ||
               resolvedFileURL.path == resolvedCacheDirectory.path
    }

    /// Clean up orphaned cache files that may not have UserDefaults references
    private func cleanOrphanedCacheFiles(cutoffDate: Date, dateFormatter: DateFormatter) {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let cacheDirectory = documentsPath.appendingPathComponent("PrayerTimesCache")

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey])
            var orphanedCount = 0

            for fileURL in fileURLs {
                // Extract date from filename if possible
                let filename = fileURL.deletingPathExtension().lastPathComponent
                let components = filename.components(separatedBy: "_")

                if components.count >= 2,
                   let date = dateFormatter.date(from: components[1]),
                   date < cutoffDate {

                    do {
                        try FileManager.default.removeItem(at: fileURL)
                        orphanedCount += 1
                    } catch {
                        logger.warning("Failed to remove orphaned cache file \(fileURL.lastPathComponent): \(error)")
                    }
                }
            }

            if orphanedCount > 0 {
                logger.debug("Cleaned \(orphanedCount) orphaned cache files")
            }
        } catch {
            // Cache directory doesn't exist or can't be read - this is fine
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

        // First try UserDefaults cache
        if let data = userDefaults.data(forKey: cacheKey),
           let cachedPrayers = try? JSONDecoder().decode([PrayerTime].self, from: data) {
            return cachedPrayers
        }

        // Then try file-based cache
        if let filePath = userDefaults.string(forKey: "\(cacheKey)_file"),
           let fileData = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
           let cachedPrayers = try? JSONDecoder().decode([PrayerTime].self, from: fileData) {
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

    // MARK: - Ramadan Adjustments

    /// Apply Ramadan-specific adjustments for calculation methods that require them
    private func applyRamadanAdjustments(to params: inout CalculationParameters, for date: Date) async {
        // Only apply Ramadan adjustments for methods that use fixed Isha intervals
        guard calculationMethod == .ummAlQura || calculationMethod == .qatar else {
            return
        }

        // Check if the date is during Ramadan
        let isRamadan = await islamicCalendarService.isRamadan()

        if isRamadan {
            // During Ramadan, extend Isha interval from 90 to 120 minutes for KSA/Qatar methods
            if calculationMethod == .ummAlQura || calculationMethod == .qatar {
                params.ishaInterval = 120  // 120 minutes during Ramadan
                logger.info("Applied Ramadan Isha adjustment: 120 minutes for \(calculationMethod.rawValue)")
            }
        }
    }

    // MARK: - Madhab Adjustments

    /// Apply madhab-specific adjustments to calculation parameters
    /// Note: Madhab primarily affects Asr shadow calculation, not twilight angles
    /// Twilight angles should be determined by the selected calculation method
    ///
    /// PRIORITY LOGIC:
    /// 1. Madhab ALWAYS takes priority for Asr calculation (shadow multiplier)
    /// 2. Calculation method takes priority for twilight angles (Fajr/Isha)
    /// 3. Hanafi madhab MUST result in 2x shadow length for Asr
    private func applyMadhabAdjustments(to params: inout CalculationParameters, madhab: Madhab) {
        // CRITICAL: Ensure madhab is properly set for Asr shadow calculation
        let targetMadhab = madhab.adhanMadhab()
        params.madhab = targetMadhab

        // Validate Hanafi madhab application (most critical for Asr timing accuracy)
        if madhab == .hanafi {
            if params.madhab != .hanafi {
                logger.error("PRIORITY VIOLATION: Hanafi madhab not applied - forcing correction")
                params.madhab = .hanafi
            }
            logger.info("✅ Hanafi madhab confirmed - Asr will use 2x shadow length calculation")
        }

        // Apply Ja'fari-specific Maghrib delay if using Ja'fari madhab
        if madhab == .jafari {
            // Ja'fari madhab requires a delay after sunset for Maghrib
            // This will be handled in post-calculation adjustments
            logger.info("Ja'fari madhab selected - Maghrib delay will be applied post-calculation")
        }

        // Log final madhab application for debugging
        logger.info("Final madhab applied: \(params.madhab.rawValue) (requested: \(madhab.rawValue))")

        // Note: Twilight angles are determined by calculation method selection
        // Users can choose specific calculation methods for twilight angles
        // The madhab setting ONLY affects Asr prayer timing through shadow length calculation
    }

    /// Validate that madhab has been correctly applied to calculation parameters
    /// This is critical for ensuring Hanafi Asr calculation priority is maintained
    private func validateMadhabApplication(params: CalculationParameters, expectedMadhab: Madhab) {
        let expectedAdhanMadhab = expectedMadhab.adhanMadhab()

        guard params.madhab == expectedAdhanMadhab else {
            logger.error("❌ MADHAB PRIORITY VIOLATION: Expected \(expectedAdhanMadhab), got \(params.madhab)")
            logger.error("This will cause incorrect Asr prayer timing for \(expectedMadhab.displayName) users")

            // This is a critical error that affects prayer timing accuracy
            assertionFailure("Madhab priority logic failed - Asr calculation will be incorrect")
            return
        }

        // Special validation for Hanafi madhab (most critical)
        if expectedMadhab == .hanafi {
            logger.info("✅ HANAFI PRIORITY CONFIRMED: Asr will use 2x shadow length (later timing)")
        } else {
            logger.info("✅ Madhab priority confirmed: \(expectedMadhab.displayName) applied correctly")
        }
    }

    /// Apply post-calculation adjustments for specific madhab requirements
    private func applyPostCalculationAdjustments(to prayerTimes: [PrayerTime], madhab: Madhab) async -> [PrayerTime] {
        var adjustedTimes = prayerTimes

        // Apply Maghrib delay for Ja'fari madhab
        if madhab == .jafari, let maghribIndex = adjustedTimes.firstIndex(where: { $0.prayer == .maghrib }) {

            // Check if user prefers astronomical calculation
            let useAstronomical = await settingsService.useAstronomicalMaghrib

            if useAstronomical, let maghribAngle = madhab.maghribAngle {
                // Use astronomical calculation (4° below horizon)
                let adjustedMaghribTime = try? await calculateAstronomicalMaghrib(
                    for: adjustedTimes[maghribIndex].time,
                    angle: maghribAngle
                )

                if let astronomicalTime = adjustedMaghribTime {
                    adjustedTimes[maghribIndex] = PrayerTime(prayer: .maghrib, time: astronomicalTime)
                    logger.info("Applied astronomical Ja'fari Maghrib calculation (\(maghribAngle)° below horizon)")
                } else {
                    // Fallback to fixed delay if astronomical calculation fails
                    let delayInSeconds = madhab.maghribDelayMinutes * 60
                    let adjustedMaghribTime = adjustedTimes[maghribIndex].time.addingTimeInterval(delayInSeconds)
                    adjustedTimes[maghribIndex] = PrayerTime(prayer: .maghrib, time: adjustedMaghribTime)
                    logger.warning("Astronomical Maghrib calculation failed, using fixed delay fallback")
                }
            } else {
                // Use fixed delay method (15 minutes)
                let delayInSeconds = madhab.maghribDelayMinutes * 60
                let adjustedMaghribTime = adjustedTimes[maghribIndex].time.addingTimeInterval(delayInSeconds)
                adjustedTimes[maghribIndex] = PrayerTime(prayer: .maghrib, time: adjustedMaghribTime)
                logger.info("Applied fixed Ja'fari Maghrib delay (\(madhab.maghribDelayMinutes) minutes)")
            }
        }

        return adjustedTimes
    }

    /// Calculate astronomical Maghrib time when sun is at specified angle below horizon
    private func calculateAstronomicalMaghrib(for sunsetTime: Date, angle: Double) async throws -> Date {
        // Get current location
        let location = try await locationService.requestLocation()

        let coordinates = Coordinates(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: sunsetTime)

        // Create custom calculation parameters for the specified angle
        var params = Adhan.CalculationMethod.other.params
        params.fajrAngle = 18.0
        params.ishaAngle = angle
        params.madhab = Adhan.Madhab.shafi // Use Shafi as base

        // Calculate prayer times with custom Isha angle (representing our Maghrib angle)
        guard let customPrayerTimes = Adhan.PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: params) else {
            throw AppError.serviceUnavailable("Astronomical Maghrib calculation")
        }

        // Return the Isha time as our astronomical Maghrib time
        return customPrayerTimes.isha
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
        case .jafariLeva:
            return .other // Custom Ja'fari implementation
        case .jafariTehran:
            return .other // Custom Ja'fari implementation
        case .fcnaCanada:
            return .other // Custom FCNA implementation
        }
    }

    /// Returns custom calculation parameters for methods not directly supported by Adhan library
    func customParameters() -> CalculationParameters? {
        switch self {
        case .jafariLeva:
            var params = Adhan.CalculationMethod.other.params
            params.fajrAngle = 16.0
            params.ishaAngle = 14.0
            return params
        case .jafariTehran:
            var params = Adhan.CalculationMethod.other.params
            params.fajrAngle = 17.7
            params.ishaAngle = 14.0
            return params
        case .fcnaCanada:
            var params = Adhan.CalculationMethod.other.params
            params.fajrAngle = 13.0
            params.ishaAngle = 13.0
            return params
        default:
            return nil
        }
    }
}

extension Madhab {
    func adhanMadhab() -> Adhan.Madhab {
        switch self {
        case .hanafi:
            return .hanafi
        case .shafi:
            return .shafi
        case .jafari:
            return .shafi  // Adhan library doesn't have Ja'fari, use Shafi as closest approximation
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
