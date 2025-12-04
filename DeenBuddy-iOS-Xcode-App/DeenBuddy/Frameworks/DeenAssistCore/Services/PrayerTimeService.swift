import Foundation
import CoreLocation
import Combine
import Adhan
import ActivityKit
import WidgetKit
import UIKit


/// Real implementation of PrayerTimeServiceProtocol using AdhanSwift
public class PrayerTimeService: PrayerTimeServiceProtocol, ObservableObject {
    
    // MARK: - Logger
    
    private let logger = AppLogger.prayerTimes
    
    // MARK: - Published Properties
    
    @Published public var todaysPrayerTimes: [PrayerTime] = []
    
    public var todaysPrayerTimesPublisher: AnyPublisher<[PrayerTime], Never> {
        $todaysPrayerTimes.eraseToAnyPublisher()
    }
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

    internal let locationService: any LocationServiceProtocol
    internal let settingsService: any SettingsServiceProtocol
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
    
    // MARK: - Performance & Debouncing
    private var widgetUpdateTask: Task<Void, Never>?
    private let widgetUpdateDebounceInterval: TimeInterval = 1.0 // 1 second debounce
    private let locationAccuracyThreshold: CLLocationAccuracy = 100.0
    
    // Request coordinator for managing duplicate requests
    private let requestCoordinator = PrayerTimeRequestCoordinator()
    
    // Performance monitoring
    private var lastPerformanceCheck = Date()
    private var functionCallCount: [String: Int] = [:]
    private let performanceCheckInterval: TimeInterval = 10.0 // Check every 10 seconds
    
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

        // Load any existing cached prayer times and update widget immediately
        if let cachedTimes = loadCachedPrayerTimes() {
            todaysPrayerTimes = cachedTimes
            updateNextPrayer()
            
            // Trigger widget update with cached data so widgets display immediately on app launch
            Task { @MainActor in
                await self.updateWidgetData()
            }
        }
    }
    
    deinit {
        // Cancel all tasks first
        updateNextPrayerTask?.cancel()
        updateNextPrayerTask = nil
        widgetUpdateTask?.cancel()
        widgetUpdateTask = nil

        // Cancel all Combine subscriptions
        cancellables.removeAll()

        // Cancel timer synchronously to avoid retain cycles
        // Note: This is safe because timerManager is designed to handle cross-actor calls
        timerManager.cancelTimerSync(id: "prayer-update")

        print("🧹 PrayerTimeService deinit completed")
    }
    
    // MARK: - Protocol Implementation
    
    public func calculatePrayerTimes(for location: CLLocation, date: Date) async throws -> [PrayerTime] {
        // Use request coordinator to prevent duplicate calculations
        return try await requestCoordinator.requestPrayerTimes(
            for: location,
            date: date,
            requestType: .general
        ) { location, date in
            // Delegate to retry mechanism for the actual calculation
            return try await self.retryMechanism.executeWithRetry(
                operation: {
                    return try await self.performPrayerTimeCalculation(for: location, date: date)
                },
                retryPolicy: .conservative,
                operationId: "calculatePrayerTimes-\(date.timeIntervalSince1970)"
            )
        }
    }

    private func performPrayerTimeCalculation(for location: CLLocation, date: Date) async throws -> [PrayerTime] {
        // Track function calls for performance monitoring
        trackFunctionCall("performPrayerTimeCalculation")
        isLoading = true
        error = nil

        defer {
            isLoading = false
        }

        // Validate calculation method and madhab compatibility
        if !calculationMethod.isCompatible(with: madhab) {
            logger.warning("⚠️ INCOMPATIBLE COMBINATION: \(calculationMethod.rawValue) method with \(madhab.rawValue) madhab")
            logger.warning("   Designed for: \(calculationMethod.preferredMadhab?.rawValue ?? "Any madhab")")
            logger.warning("   This may result in theologically incorrect prayer times")
        }

        do {
            let coordinates = Coordinates(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            
            // Create date components using proper timezone handling for the location
            // The Adhan library expects dateComponents to represent the date in the local timezone
            var calendar = Calendar(identifier: .gregorian)
            
            // For geographic locations, try to determine the appropriate timezone
            let timeZone: TimeZone
            if let locationTimeZone = await determineTimeZone(for: location) {
                timeZone = locationTimeZone
                logger.info("📍 Using determined timezone: \(timeZone.identifier) for location: \(location.coordinate)")
            } else {
                // Fallback to UTC to ensure consistent behavior
                timeZone = TimeZone(secondsFromGMT: 0)!
                logger.warning("⚠️ Using UTC timezone as fallback for location: \(location.coordinate)")
            }
            
            calendar.timeZone = timeZone
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
            
            logger.info("📅 Date components created: year=\(dateComponents.year ?? 0), month=\(dateComponents.month ?? 0), day=\(dateComponents.day ?? 0) in timezone \(timeZone.identifier)")

            // Convert app's CalculationMethod to Adhan.CalculationMethod
            let adhanMethod = calculationMethod.toAdhanMethod()
            var params: CalculationParameters

            // Use custom parameters for methods not directly supported by Adhan library
            if let customParams = calculationMethod.customParameters() {
                params = customParams
                logger.info("Using custom parameters for \(calculationMethod.rawValue)")
                
                // CRITICAL VALIDATION: Verify parameter object independence
                validateParameterIndependence(params: params, method: calculationMethod)
                
                // DEBUG: Log the actual custom parameter values
                logger.info("📐 CUSTOM PARAMETERS LOADED:")
                logger.info("   🌅 Fajr Angle: \(params.fajrAngle)°")
                logger.info("   🌙 Isha Angle: \(params.ishaAngle)°")
                logger.info("   🌅 Maghrib Angle: \(params.maghribAngle ?? 0.0)°")
                logger.info("   ⏰ Isha Interval: \(params.ishaInterval) minutes")
                logger.info("   📖 Method: \(params.method)")
                logger.info("   🔄 Initial Madhab: \(params.madhab)")
            } else {
                // ULTIMATE FIX: Create a *new copy* of the parameters to prevent shared state.
                // Adhan.CalculationMethod.params returns a reference to the same object, so we must copy it.
                params = adhanMethod.params.copy()
            }

            // CRITICAL: Always set madhab AFTER parameter initialization to ensure Asr calculation priority
            // This ensures Hanafi madhab (2x shadow) takes precedence over any default madhab settings
            let targetMadhab = madhab.adhanMadhab()
            params.madhab = targetMadhab
            
            // DEBUG: Log parameters AFTER madhab setting to detect any overrides
            logger.info("📐 PARAMETERS AFTER MADHAB OVERRIDE:")
            logger.info("   🌅 Fajr Angle: \(params.fajrAngle)° (should be \(calculationMethod == .jafariTehran ? "17.7" : calculationMethod == .jafariLeva ? "16.0" : "default"))")
            logger.info("   🌙 Isha Angle: \(params.ishaAngle)°")
            logger.info("   📖 Final Madhab: \(params.madhab)")
            logger.info("   🎯 Method Type: \(params.method)")
            
            // Enhanced debugging for Hanafi Asr calculation issue
            logger.info("🕌 PRAYER CALCULATION DEBUG:")
            logger.info("   📍 Location: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
            logger.info("   📅 Date: \(dateComponents)")
            logger.info("   🔧 Calculation Method: \(calculationMethod.rawValue)")
            logger.info("   📖 App Madhab: \(madhab.rawValue) -> Adhan Madhab: \(targetMadhab.rawValue)")
            logger.info("   🎯 Expected Hanafi Shadow Multiplier: \(madhab.asrShadowMultiplier)x")

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

            // Validate inputs before calling Adhan library
            try validateAdhanInputs(location: location, dateComponents: dateComponents, params: params)

            // DEBUG: Final parameter check just before Adhan library call
            logger.info("🎯 FINAL PARAMETERS BEFORE ADHAN LIBRARY:")
            logger.info("   🌅 Final Fajr Angle: \(params.fajrAngle)°")
            logger.info("   🌙 Final Isha Angle: \(params.ishaAngle)°")
            logger.info("   📖 Final Madhab: \(params.madhab)")
            logger.info("   🔧 Final Method: \(params.method)")
            logger.info("   📍 Coordinates: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
            logger.info("   📅 Date Components: \(dateComponents)")

            // Try primary Adhan calculation with enhanced error handling and parameter validation
            logger.info("🎯 Attempting primary Adhan calculation...")
            
            // Pre-validate critical parameters before calling Adhan library
            if params.ishaAngle <= 0 && params.ishaInterval <= 0 {
                logger.error("❌ Critical parameter issue detected before Adhan call: Isha angle=\(params.ishaAngle)°, interval=\(params.ishaInterval)")
                throw AppError.serviceUnavailable("Invalid Isha parameters detected")
            }
            
            var adhanPrayerTimes: Adhan.PrayerTimes?
            
            // Try primary calculation with defensive error handling
            do {
                adhanPrayerTimes = Adhan.PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: params)
                if adhanPrayerTimes != nil {
                    logger.info("✅ Primary Adhan calculation succeeded")
                } else {
                    logger.warning("⚠️ Primary Adhan calculation returned nil (possibly invalid parameter combination)")
                }
            } catch {
                logger.error("❌ Primary Adhan calculation threw error: \(error)")
                adhanPrayerTimes = nil
            }
            
            // If primary calculation failed, try fallback approaches
            if adhanPrayerTimes == nil {
                logger.warning("🔄 Primary calculation failed, attempting fallback strategies...")
                
                // Strategy 1: Try with slightly adjusted parameters
                if let adjustedTimes = try attemptParameterAdjustmentFallback(coordinates: coordinates, dateComponents: dateComponents, originalParams: params) {
                    logger.info("✅ Parameter adjustment fallback succeeded")
                    return adjustedTimes
                }
                
                // Strategy 2: Try fallback calculation with different method
                if let fallbackTimes = try attemptFallbackCalculation(coordinates: coordinates, dateComponents: dateComponents, originalMethod: calculationMethod, originalMadhab: madhab) {
                    logger.warning("✅ Using fallback calculation for \(calculationMethod.rawValue)/\(madhab.rawValue)")
                    return fallbackTimes
                }
                
                logger.error("❌ All calculation strategies failed")
                throw AppError.serviceUnavailable("Prayer time calculation failed for location \(location.coordinate) and date \(date)")
            }
            
            guard let finalPrayerTimes = adhanPrayerTimes else {
                logger.error("❌ Unexpected nil prayer times after successful check")
                throw AppError.serviceUnavailable("Prayer time calculation returned nil")
            }
            
            // Debug log the calculated Asr time for madhab analysis
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .medium
            logger.info("🕐 Calculated Asr time with \(params.madhab.rawValue) madhab: \(dateFormatter.string(from: finalPrayerTimes.asr))")

            var prayerTimes = [
                PrayerTime(prayer: .fajr, time: finalPrayerTimes.fajr),
                PrayerTime(prayer: .dhuhr, time: finalPrayerTimes.dhuhr),
                PrayerTime(prayer: .asr, time: finalPrayerTimes.asr),
                PrayerTime(prayer: .maghrib, time: finalPrayerTimes.maghrib),
                PrayerTime(prayer: .isha, time: finalPrayerTimes.isha)
            ]

            // Debug log to detect potential Hanafi Asr calculation issues
            if madhab == .hanafi, let asrTime = prayerTimes.first(where: { $0.prayer == .asr })?.time {
                logger.info("🔍 HANAFI ASR DEBUG: Calculated time \(dateFormatter.string(from: asrTime))")
                
                // Quick validation: Calculate Shafi for comparison in debug builds
                #if DEBUG
                var shafiParams = params
                shafiParams.madhab = .shafi
                do {
                    if let shafiPrayerTimes = Adhan.PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: shafiParams) {
                        let timeDifference = asrTime.timeIntervalSince(shafiPrayerTimes.asr)
                        logger.info("🔍 ASR DIFFERENCE DEBUG: Hanafi vs Shafi = \(Int(timeDifference)) seconds (\(Int(timeDifference/60)) minutes)")

                        // Flag potential calculation issues
                        if timeDifference > 2400 { // More than 40 minutes
                            logger.warning("⚠️ POTENTIAL HANAFI ASR CALCULATION ISSUE: Difference exceeds expected 40 minutes")
                            logger.warning("   Expected: 30-40 minutes, Actual: \(Int(timeDifference/60)) minutes")
                            logger.warning("   This may indicate an Adhan library integration issue")
                        }
                    } else {
                        logger.warning("⚠️ Could not calculate Shafi Asr for comparison")
                    }
                } catch {
                    logger.warning("⚠️ Error calculating Shafi Asr for comparison: \(error)")
                }
                #endif
            }

            // Apply post-calculation madhab adjustments (only if not already included in calculation method)
            prayerTimes = await applyPostCalculationAdjustments(to: prayerTimes, method: calculationMethod, madhab: madhab, location: location)

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
        // Track function calls for performance monitoring
        trackFunctionCall("refreshPrayerTimes")
        
        // Use request coordinator for debouncing instead of local implementation
        requestCoordinator.coordinateRefresh(requestType: .refresh) {
            await self.performPrayerTimesRefresh()
        }
    }
    
    /// Perform the actual prayer times refresh (separated for debouncing)
    @MainActor
    private func performPrayerTimesRefresh() async {
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

            // Check if location change is significant enough to trigger recalculation
            if !requestCoordinator.shouldRecalculateForLocation(validLocation) {
                logger.debug("📍 Location change not significant enough - using cached data if available")
                if !todaysPrayerTimes.isEmpty {
                    return
                }
            }

            let prayerTimes = try await requestCoordinator.requestPrayerTimes(
                for: validLocation,
                date: Date(),
                requestType: .refresh
            ) { location, date in
                return try await self.retryMechanism.executeWithRetry(
                    operation: {
                        return try await self.performPrayerTimeCalculation(for: location, date: date)
                    },
                    retryPolicy: .conservative,
                    operationId: "refreshPrayerTimes-\(date.timeIntervalSince1970)"
                )
            }
            
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

    public func getFuturePrayerTimes(for date: Date, location: CLLocation?) async throws -> FuturePrayerTimeResult {
        let disclaimerLevel = try validateLookaheadDate(date)
        let targetLocation = try await resolveLocation(location)
        let isHighLat = isHighLatitudeLocation(targetLocation)
        let prayerTimes = try await calculatePrayerTimes(for: targetLocation, date: date)
        let hijriDate = HijriDate(from: date)
        let isRamadan = await islamicCalendarService.isDateInRamadan(date)
        let timezone = await determineTimeZone(for: targetLocation) ?? TimeZone.current
        let precision = precisionLevel(for: disclaimerLevel)

        return FuturePrayerTimeResult(
            date: date,
            prayerTimes: prayerTimes,
            hijriDate: hijriDate,
            isRamadan: isRamadan,
            disclaimerLevel: disclaimerLevel,
            calculationTimezone: timezone,
            isHighLatitude: isHighLat,
            precision: precision
        )
    }

    public func getFuturePrayerTimes(from startDate: Date, to endDate: Date, location: CLLocation?) async throws -> [FuturePrayerTimeResult] {
        let calendar = Calendar.current
        guard let daysDiff = calendar.dateComponents([.day], from: startDate, to: endDate).day,
              daysDiff <= 90,
              daysDiff >= 0 else {
            throw PrayerTimeError.dateRangeTooLarge
        }

        var results: [FuturePrayerTimeResult] = []
        var currentDate = startDate

        while currentDate <= endDate {
            let result = try await getFuturePrayerTimes(for: currentDate, location: location)
            results.append(result)

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return results
    }

    public func validateLookaheadDate(_ date: Date) throws -> DisclaimerLevel {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)

        if target < today {
            throw PrayerTimeError.invalidDate
        }

        if calendar.isDate(target, inSameDayAs: today) {
            return .today
        }

        guard let monthsDiff = calendar.dateComponents([.month], from: today, to: target).month else {
            throw PrayerTimeError.invalidDate
        }

        if monthsDiff > settingsService.maxLookaheadMonths {
            throw PrayerTimeError.lookaheadLimitExceeded(requested: monthsDiff, maximum: settingsService.maxLookaheadMonths)
        }

        switch monthsDiff {
        case 0...12:
            return .shortTerm
        case 13...60:
            return .mediumTerm
        default:
            return .longTerm
        }
    }

    public func isHighLatitudeLocation(_ location: CLLocation) -> Bool {
        abs(location.coordinate.latitude) > 55.0
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
    
    /// Get tomorrow's prayer times with intelligent caching to avoid duplicate calculations
    /// This is optimized for widget updates to prevent duplicate tomorrow prayer time requests
    public func getTomorrowPrayerTimes(for location: CLLocation) async throws -> [PrayerTime] {
        return try await requestCoordinator.getTomorrowPrayerTimes(for: location) { location, date in
            return try await self.retryMechanism.executeWithRetry(
                operation: {
                    return try await self.performPrayerTimeCalculation(for: location, date: date)
                },
                retryPolicy: .conservative,
                operationId: "getTomorrowPrayerTimes-\(date.timeIntervalSince1970)"
            )
        }
    }
    
    /// Get request statistics for monitoring duplicate request prevention
    public func getRequestStatistics() -> RequestStatistics {
        return requestCoordinator.getRequestStatistics()
    }
    
    /// Reset request statistics (useful for testing)
    public func resetRequestStatistics() {
        requestCoordinator.resetStatistics()
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
                receiveValue: { [weak self] location in
                    guard let self = self else { return }
                    // Use coordinator's location-specific debouncing
                    self.requestCoordinator.coordinateRefresh(requestType: .locationChange) {
                        await self.refreshPrayerTimes()
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
                guard let self = self else { return }
                // Use coordinator's settings-specific debouncing (2 seconds for settings changes)
                self.requestCoordinator.coordinateRefresh(requestType: .settingsChange) {
                    await self.invalidateCacheAndRefresh()
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

        // With method and madhab-specific cache keys, we don't need to clear cache
        // when settings change, as each method/madhab combination has its own cache.
        // Old combinations keep their cache, new combinations start empty.
        
        // All cache systems (APICache, IslamicCacheManager, and UserDefaults) use
        // method-specific keys, so no cache clearing is needed on settings changes.
        
        logger.debug("Cache invalidation skipped - all cache systems use method-specific keys")
    }
    
    /// Cancel all pending async tasks
    private func cancelAllTasks() {
        updateNextPrayerTask?.cancel()
        updateNextPrayerTask = nil
        widgetUpdateTask?.cancel()
        widgetUpdateTask = nil
        
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
                        let tomorrowPrayers = try await self.getTomorrowPrayerTimes(for: location)
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
        
        // Only trigger if notifications and Live Activities are enabled (user preference)
        guard settingsService.notificationsEnabled && settingsService.liveActivitiesEnabled else { return }
        
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
            // Skip Live Activities in simulator - they don't work properly (compile-time check)
            #if targetEnvironment(simulator)
            logger.debug("Skipping Live Activity on iOS Simulator - not supported")
            return
            #endif
            
            // Additional runtime check for simulator (some builds might miss compile-time check)
            if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil {
                logger.debug("Skipping Live Activity - running on iOS Simulator")
                return
            }
            
            // Check user preference for Live Activities
            guard settingsService.liveActivitiesEnabled else {
                logger.debug("Live Activities disabled in user settings, skipping Dynamic Island")
                return
            }
            
            do {
                // Comprehensive Live Activity debugging
                let authInfo = ActivityAuthorizationInfo()
                let deviceModel = UIDevice.current.model
                let systemVersion = UIDevice.current.systemVersion
                
                logger.debug("🔍 Live Activity Debug - Device: \(deviceModel), iOS: \(systemVersion)")
                logger.debug("🔍 Live Activity Debug - Activities Enabled: \(authInfo.areActivitiesEnabled)")
                logger.debug("🔍 Live Activity Debug - User Setting: \(settingsService.liveActivitiesEnabled)")
                
                guard authInfo.areActivitiesEnabled else {
                    logger.debug("❌ Live Activities not enabled by system - check Settings > Face ID & Passcode > Live Activities")
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
                // Handle specific Live Activity errors gracefully without spamming logs
                if let activityError = error as? LiveActivityError {
                    switch activityError {
                    case .notAvailable, .permissionDenied:
                        // These are expected conditions, log at debug level only
                        logger.debug("Live Activities not available or permission denied")
                    default:
                        // Unexpected errors get more detailed logging
                        logger.warning("Live Activity failed: \(activityError.localizedDescription)")
                    }
                } else {
                    // Check for specific ActivityKit errors
                    let nsError = error as NSError
                    if nsError.domain == "com.apple.ActivityKit.ActivityInput" {
                        if nsError.code == 0 && nsError.userInfo["NSUnderlyingError"] != nil {
                            // SessionCore.PermissionsError Code=3 - Live Activities disabled in Lock Screen settings
                            logger.info("ℹ️ Live Activities permission required:")
                            logger.info("   Please enable: Settings > Face ID & Passcode > Allow Access When Locked > Live Activities")
                            logger.info("   This allows the Allah symbol to appear in the Dynamic Island")
                        } else {
                            logger.debug("Live Activity configuration issue: \(error.localizedDescription)")
                        }
                    } else if nsError.domain.contains("SessionCore.PermissionsError") {
                        if nsError.code == 3 {
                            logger.info("🔒 Live Activities need Lock Screen access:")
                            logger.info("   Settings > Face ID & Passcode > Allow Access When Locked > Live Activities = ON")
                        } else {
                            logger.debug("Live Activity permission issue: \(error.localizedDescription)")
                        }
                    } else {
                        // Genuine unexpected errors
                        logger.warning("Unexpected Live Activity error: \(error)")
                    }
                }
            }
        }
    }

    /// Update widget data when prayer times change (with debouncing to prevent performance issues)
    private func updateWidgetData() async {
        // Track function calls for performance monitoring
        trackFunctionCall("updateWidgetData")
        
        // Cancel any existing widget update task to implement debouncing
        widgetUpdateTask?.cancel()
        
        widgetUpdateTask = Task { @MainActor in
            // Wait for debounce interval to prevent rapid successive calls
            try? await Task.sleep(nanoseconds: UInt64(widgetUpdateDebounceInterval * 1_000_000_000))
            
            // Check if task was cancelled during sleep
            guard !Task.isCancelled else { return }
            
            // Proceed with widget update
            await performWidgetUpdate()
        }
    }
    
    /// Perform the actual widget update (separated for clarity and testability)
    @MainActor
    private func performWidgetUpdate() async {
        guard !todaysPrayerTimes.isEmpty else { 
            logger.debug("Skipping widget update - no prayer times available")
            return 
        }

        // Create widget data
        let locationDescription: String
        if let locationInfo = locationService.currentLocationInfo {
            let currentLocation = locationService.currentLocation
            if let city = locationInfo.city, !city.isEmpty {
                // If accuracy is poor (>threshold), prefix with "Near"
                if let currentLocation, currentLocation.horizontalAccuracy > locationAccuracyThreshold {
                    locationDescription = "Near \(city)"
                } else {
                    locationDescription = city
                }
            } else if let country = locationInfo.country, !country.isEmpty {
                locationDescription = country
            } else {
                locationDescription = "Current Location"
            }
        } else {
            locationDescription = "Current Location"
        }

        let widgetData = WidgetData(
            nextPrayer: nextPrayer,
            timeUntilNextPrayer: timeUntilNextPrayer,
            todaysPrayerTimes: todaysPrayerTimes,
            hijriDate: HijriDate(from: Date()),
            location: locationDescription,
            calculationMethod: calculationMethod,
            lastUpdated: Date()
        )

        // Save widget data using the shared manager
        WidgetDataManager.shared.saveWidgetData(widgetData)

        // Refresh widget timelines to show updated data (avoid potential loops)
        // Only refresh if we're not already in a widget refresh cycle
        Task {
            WidgetCenter.shared.reloadAllTimelines()
        }

        logger.debug("Widget data updated and timelines refreshed from PrayerTimeService")
    }
    
    /// Monitor function call frequency to detect potential performance issues
    private func trackFunctionCall(_ functionName: String) {
        let now = Date()
        
        // Increment call count
        functionCallCount[functionName, default: 0] += 1
        
        // Check if it's time for a performance check
        if now.timeIntervalSince(lastPerformanceCheck) >= performanceCheckInterval {
            checkPerformanceMetrics()
            lastPerformanceCheck = now
            functionCallCount.removeAll() // Reset counters
        }
    }
    
    /// Check for potential performance issues
    private func checkPerformanceMetrics() {
        for (functionName, callCount) in functionCallCount {
            let callsPerSecond = Double(callCount) / performanceCheckInterval
            
            // Alert if any function is called more than 5 times per second (potential issue)
            if callsPerSecond > 5.0 {
                logger.warning("⚠️ Performance Alert: \(functionName) called \(callCount) times in \(performanceCheckInterval) seconds (\(String(format: "%.1f", callsPerSecond)) calls/sec)")
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
        guard (calculationMethod == .ummAlQura || calculationMethod == .qatar),
              settingsService.useRamadanIshaOffset else {
            return
        }

        let isRamadan = await islamicCalendarService.isDateInRamadan(date)

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

        // Enhanced validation for Hanafi madhab (addressing the 69-minute issue)
        if madhab == .hanafi {
            if params.madhab != .hanafi {
                logger.error("🚨 CRITICAL PRIORITY VIOLATION: Hanafi madhab not applied - forcing correction")
                params.madhab = .hanafi
            }
            
            // Additional validation: Ensure no other parameters interfere with Hanafi Asr calculation
            logger.info("🔧 Hanafi madhab validation:")
            logger.info("   ✅ Madhab set to: \(params.madhab.rawValue)")
            logger.info("   🎯 Expected shadow multiplier: 2x (vs Shafi 1x)")
            logger.info("   🕐 Expected difference: 30-40 minutes later than Shafi")
            
            // Defensive programming: Force Hanafi madhab if any issues detected
            if params.madhab != .hanafi {
                logger.error("🔧 FORCE CORRECTION: Setting madhab to Hanafi to fix Asr calculation")
                params.madhab = .hanafi
            }
        }

        // Apply Ja'fari-specific Maghrib delay if using Ja'fari madhab
        if madhab == .jafari {
            // Ja'fari madhab requires a delay after sunset for Maghrib
            // This will be handled in post-calculation adjustments
            logger.info("Ja'fari madhab selected - Maghrib delay will be applied post-calculation")
        }

        // Enhanced logging for debugging madhab application
        logger.info("🎯 Final madhab validation:")
        logger.info("   📋 Requested: \(madhab.rawValue)")
        logger.info("   ✅ Applied: \(params.madhab.rawValue)")
        logger.info("   🔍 Status: \(params.madhab == targetMadhab ? "✅ CORRECT" : "❌ MISMATCH")")

        // Note: Twilight angles are determined by calculation method selection
        // Users can choose specific calculation methods for twilight angles
        // The madhab setting ONLY affects Asr prayer timing through shadow length calculation
    }

    /// Validate that calculation parameters are truly independent objects
    /// This prevents shared state issues that cause incorrect prayer time calculations
    private func validateParameterIndependence(params: CalculationParameters, method: CalculationMethod) {
        // Verify the parameters match the expected values for the method
        let expectedFajrAngle: Double
        let expectedIshaAngle: Double
        
        switch method {
        case .jafariTehran:
            expectedFajrAngle = 17.7
            expectedIshaAngle = 14.0
        case .jafariLeva:
            expectedFajrAngle = 16.0
            expectedIshaAngle = 14.0
        case .fcnaCanada:
            expectedFajrAngle = 13.0
            expectedIshaAngle = 13.0
        default:
            return // No validation needed for standard methods
        }
        
        // Check if parameters match expected values
        let fajrMatches = abs(params.fajrAngle - expectedFajrAngle) < 0.001
        let ishaMatches = abs(params.ishaAngle - expectedIshaAngle) < 0.001
        
        if !fajrMatches || !ishaMatches {
            logger.error("🚨 PARAMETER INDEPENDENCE VIOLATION DETECTED:")
            logger.error("   Method: \(method.rawValue)")
            logger.error("   Expected Fajr: \(expectedFajrAngle)°, Actual: \(params.fajrAngle)°")
            logger.error("   Expected Isha: \(expectedIshaAngle)°, Actual: \(params.ishaAngle)°")
            logger.error("   This indicates shared parameter state - prayer times will be incorrect!")
            
            // Note: CalculationParameters is a struct, so we can't check object identity
            // The independence is verified by checking the parameter values instead")
        } else {
            logger.info("✅ Parameter independence validated for \(method.rawValue)")
            logger.info("   Fajr: \(params.fajrAngle)°, Isha: \(params.ishaAngle)°")
        }
    }

    /// Validate that madhab has been correctly applied to calculation parameters
    /// This is critical for ensuring Hanafi Asr calculation priority is maintained
    private func validateMadhabApplication(params: CalculationParameters, expectedMadhab: Madhab) {
        let expectedAdhanMadhab = expectedMadhab.adhanMadhab()

        guard params.madhab == expectedAdhanMadhab else {
            logger.error("❌ MADHAB PRIORITY VIOLATION DETECTED:")
            logger.error("   Expected: \(expectedMadhab.rawValue) -> \(expectedAdhanMadhab.rawValue)")
            logger.error("   Actual: \(params.madhab.rawValue)")
            logger.error("   Impact: This will cause incorrect Asr prayer timing for \(expectedMadhab.displayName) users")
            logger.error("   Hanafi Issue: If this is Hanafi, it may cause the 69-minute vs 40-minute timing difference")

            // Create production-safe error for madhab validation failure
            let madhabError = AppError.configurationMissing

            // Set error state to notify users about potential timing inaccuracy
            Task { @MainActor in
                self.error = madhabError
                await self.errorHandler.handleError(madhabError)
            }

            logger.error("🚨 PRODUCTION SAFETY: Continuing execution despite madhab validation failure to prevent app crash")
            logger.error("📱 User notification: Error state set to inform about potential Asr timing inaccuracy")
            return
        }

        // Special validation for Hanafi madhab (most critical for the current issue)
        if expectedMadhab == .hanafi {
            logger.info("✅ HANAFI PRIORITY CONFIRMED:")
            logger.info("   🎯 Madhab: \(params.madhab.rawValue)")
            logger.info("   🔢 Shadow multiplier: 2x object height")
            logger.info("   ⏰ Expected timing: 30-40 minutes later than Shafi")
            logger.info("   🐛 Fix: Should resolve 69-minute timing difference issue")
        } else {
            logger.info("✅ Madhab priority confirmed: \(expectedMadhab.displayName) applied correctly (\(params.madhab.rawValue))")
        }
    }

    /// Determines if madhab-specific adjustments should be applied based on calculation method
    /// Prevents double-application of madhab parameters when calculation method already includes them
    private func shouldApplyMadhabAdjustments(method: CalculationMethod, madhab: Madhab) -> Bool {
        switch (method, madhab) {
        case (.jafariTehran, .jafari):
            // Tehran IOG already includes Ja'fari-specific twilight angles (17.7°/14°)
            return false
        case (.jafariLeva, .jafari):
            // Leva Institute already includes Ja'fari-specific twilight angles (16°/14°)
            return false
        case (.karachi, .hanafi):
            // University of Islamic Sciences Karachi designed specifically for Hanafi madhab
            return false
        default:
            // General calculation methods need madhab-specific adjustments applied
            return true
        }
    }

    /// Apply post-calculation adjustments for specific madhab requirements
    /// Updated to prevent double-application when calculation method already includes madhab parameters
    private func applyPostCalculationAdjustments(to prayerTimes: [PrayerTime], method: CalculationMethod, madhab: Madhab, location: CLLocation) async -> [PrayerTime] {
        // Track function calls for performance monitoring
        trackFunctionCall("applyPostCalculationAdjustments")
        // Skip adjustments if calculation method already handles madhab-specific requirements
        guard shouldApplyMadhabAdjustments(method: method, madhab: madhab) else {
            logger.info("✅ Skipping madhab adjustments - \(method.rawValue) already includes \(madhab.rawValue) calculations")
            return prayerTimes
        }
        
        logger.info("🔧 Applying madhab adjustments for \(madhab.rawValue) with \(method.rawValue) method")
        var adjustedTimes = prayerTimes

        // Apply Maghrib delay for Ja'fari madhab (only for general calculation methods)
        if madhab == .jafari, let maghribIndex = adjustedTimes.firstIndex(where: { $0.prayer == .maghrib }) {

            // Check if user prefers astronomical calculation
            let useAstronomical = await settingsService.useAstronomicalMaghrib

            if useAstronomical, let maghribAngle = madhab.maghribAngle {
                // Use astronomical calculation (4° below horizon)
                let adjustedMaghribTime = try? await calculateAstronomicalMaghrib(
                    for: adjustedTimes[maghribIndex].time,
                    angle: maghribAngle,
                    location: location
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
    private func calculateAstronomicalMaghrib(for sunsetTime: Date, angle: Double, location: CLLocation) async throws -> Date {
        // Location is now passed as parameter - no need to request it

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
    
    // MARK: - Input Validation and Fallback Methods
    
    /// Validates inputs before calling Adhan library to prevent null returns
    private func validateAdhanInputs(location: CLLocation, dateComponents: DateComponents, params: CalculationParameters) throws {
        // Validate coordinates
        guard location.coordinate.latitude >= -90 && location.coordinate.latitude <= 90 else {
            logger.error("❌ Invalid latitude: \(location.coordinate.latitude)")
            throw AppError.serviceUnavailable("Invalid latitude: \(location.coordinate.latitude)")
        }
        
        guard location.coordinate.longitude >= -180 && location.coordinate.longitude <= 180 else {
            logger.error("❌ Invalid longitude: \(location.coordinate.longitude)")
            throw AppError.serviceUnavailable("Invalid longitude: \(location.coordinate.longitude)")
        }
        
        // Validate date components
        guard let year = dateComponents.year, year >= 1900 && year <= 2100 else {
            logger.error("❌ Invalid year: \(dateComponents.year ?? -1)")
            throw AppError.serviceUnavailable("Invalid year: \(dateComponents.year ?? -1)")
        }
        
        guard let month = dateComponents.month, month >= 1 && month <= 12 else {
            logger.error("❌ Invalid month: \(dateComponents.month ?? -1)")
            throw AppError.serviceUnavailable("Invalid month: \(dateComponents.month ?? -1)")
        }
        
        guard let day = dateComponents.day, day >= 1 && day <= 31 else {
            logger.error("❌ Invalid day: \(dateComponents.day ?? -1)")
            throw AppError.serviceUnavailable("Invalid day: \(dateComponents.day ?? -1)")
        }
        
        // Validate calculation parameters with more permissive ranges
        // Some calculation methods may use angles outside the typical 10-25 range
        guard params.fajrAngle >= 0 && params.fajrAngle <= 30 else {
            logger.error("❌ Invalid Fajr angle: \(params.fajrAngle)")
            throw AppError.serviceUnavailable("Invalid Fajr angle: \(params.fajrAngle)")
        }
        
        // Check for Isha angle or interval - some methods use one or the other
        let hasValidIshaAngle = params.ishaAngle > 0 && params.ishaAngle <= 30
        let hasValidIshaInterval = params.ishaInterval > 0 && params.ishaInterval <= 300 // Up to 5 hours
        
        guard hasValidIshaAngle || hasValidIshaInterval else {
            logger.error("❌ Invalid Isha parameters: angle=\(params.ishaAngle)°, interval=\(params.ishaInterval) minutes")
            throw AppError.serviceUnavailable("Invalid Isha parameters: angle=\(params.ishaAngle)°, interval=\(params.ishaInterval) minutes")
        }
        
        // Additional validation for edge cases
        if params.ishaAngle <= 0 && params.ishaInterval <= 0 {
            logger.error("❌ Both Isha angle and interval are invalid: angle=\(params.ishaAngle)°, interval=\(params.ishaInterval) minutes")
            throw AppError.serviceUnavailable("Both Isha angle and interval are invalid")
        }
        
        logger.info("✅ Adhan input validation passed")
    }
    
    /// Attempts parameter adjustment fallback when primary calculation fails
    private func attemptParameterAdjustmentFallback(coordinates: Coordinates, dateComponents: DateComponents, originalParams: CalculationParameters) throws -> [PrayerTime]? {
        logger.info("🔧 Attempting parameter adjustment fallback...")
        
        // Strategy 1: If Isha angle is problematic, try using interval instead
        if originalParams.ishaAngle <= 0 || originalParams.ishaAngle > 25 {
            logger.info("🔧 Trying Isha interval fallback (angle was \(originalParams.ishaAngle)°)")
            var adjustedParams = originalParams
            adjustedParams.ishaAngle = 0 // Disable angle
            adjustedParams.ishaInterval = 90 // Use 90 minute interval
            
            if let adjustedPrayerTimes = Adhan.PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: adjustedParams) {
                logger.info("✅ Isha interval adjustment succeeded")
                return [
                    PrayerTime(prayer: .fajr, time: adjustedPrayerTimes.fajr),
                    PrayerTime(prayer: .dhuhr, time: adjustedPrayerTimes.dhuhr),
                    PrayerTime(prayer: .asr, time: adjustedPrayerTimes.asr),
                    PrayerTime(prayer: .maghrib, time: adjustedPrayerTimes.maghrib),
                    PrayerTime(prayer: .isha, time: adjustedPrayerTimes.isha)
                ]
            }
        }
        
        // Strategy 2: If using interval, try angle instead
        if originalParams.ishaInterval > 0 && originalParams.ishaAngle <= 0 {
            logger.info("🔧 Trying Isha angle fallback (interval was \(originalParams.ishaInterval) minutes)")
            var adjustedParams = originalParams
            adjustedParams.ishaInterval = 0 // Disable interval
            adjustedParams.ishaAngle = 17.0 // Use reasonable angle
            
            if let adjustedPrayerTimes = Adhan.PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: adjustedParams) {
                logger.info("✅ Isha angle adjustment succeeded")
                return [
                    PrayerTime(prayer: .fajr, time: adjustedPrayerTimes.fajr),
                    PrayerTime(prayer: .dhuhr, time: adjustedPrayerTimes.dhuhr),
                    PrayerTime(prayer: .asr, time: adjustedPrayerTimes.asr),
                    PrayerTime(prayer: .maghrib, time: adjustedPrayerTimes.maghrib),
                    PrayerTime(prayer: .isha, time: adjustedPrayerTimes.isha)
                ]
            }
        }
        
        // Strategy 3: Try with slightly adjusted angles
        let angleAdjustments: [Double] = [1.0, -1.0, 2.0, -2.0]
        for adjustment in angleAdjustments {
            logger.info("🔧 Trying angle adjustment: +\(adjustment)° to Fajr and Isha")
            var adjustedParams = originalParams
            adjustedParams.fajrAngle = max(10.0, min(25.0, originalParams.fajrAngle + adjustment))
            if adjustedParams.ishaAngle > 0 {
                adjustedParams.ishaAngle = max(10.0, min(25.0, originalParams.ishaAngle + adjustment))
            }
            
            if let adjustedPrayerTimes = Adhan.PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: adjustedParams) {
                logger.info("✅ Angle adjustment (\(adjustment)°) succeeded")
                return [
                    PrayerTime(prayer: .fajr, time: adjustedPrayerTimes.fajr),
                    PrayerTime(prayer: .dhuhr, time: adjustedPrayerTimes.dhuhr),
                    PrayerTime(prayer: .asr, time: adjustedPrayerTimes.asr),
                    PrayerTime(prayer: .maghrib, time: adjustedPrayerTimes.maghrib),
                    PrayerTime(prayer: .isha, time: adjustedPrayerTimes.isha)
                ]
            }
        }
        
        logger.warning("🔧 All parameter adjustment strategies failed")
        return nil
    }
    
    /// Attempts fallback calculation when primary Adhan calculation fails
    private func attemptFallbackCalculation(coordinates: Coordinates, dateComponents: DateComponents, originalMethod: CalculationMethod, originalMadhab: Madhab) throws -> [PrayerTime]? {
        logger.warning("🔄 Attempting fallback calculation for \(originalMethod.rawValue)/\(originalMadhab.rawValue)")
        
        // Try with Muslim World League as safe fallback
        let fallbackMethods: [Adhan.CalculationMethod] = [
            .muslimWorldLeague,
            .egyptian,
            .karachi,
            .northAmerica
        ]
        
        for fallbackMethod in fallbackMethods {
            logger.info("🔄 Trying fallback method: \(fallbackMethod)")
            
            var fallbackParams = fallbackMethod.params
            
            // Apply original madhab to fallback parameters
            switch originalMadhab {
            case .hanafi:
                fallbackParams.madhab = .hanafi
            case .shafi, .jafari:
                fallbackParams.madhab = .shafi
            }
            
            // Apply Ja'fari specific adjustments if needed
            if originalMadhab == .jafari {
                // Apply Ja'fari Maghrib delay manually after calculation
                fallbackParams.maghribAngle = 4.0  // Use astronomical angle for Ja'fari
            }
            
            if let fallbackPrayerTimes = Adhan.PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: fallbackParams) {
                logger.info("✅ Fallback calculation succeeded with \(fallbackMethod)")
                
                var prayerTimes = [
                    PrayerTime(prayer: .fajr, time: fallbackPrayerTimes.fajr),
                    PrayerTime(prayer: .dhuhr, time: fallbackPrayerTimes.dhuhr),
                    PrayerTime(prayer: .asr, time: fallbackPrayerTimes.asr),
                    PrayerTime(prayer: .maghrib, time: fallbackPrayerTimes.maghrib),
                    PrayerTime(prayer: .isha, time: fallbackPrayerTimes.isha)
                ]
                
                // Apply Ja'fari Maghrib delay manually
                if originalMadhab == .jafari {
                    for i in 0..<prayerTimes.count {
                        if prayerTimes[i].prayer == .maghrib {
                            prayerTimes[i] = PrayerTime(
                                prayer: .maghrib,
                                time: prayerTimes[i].time.addingTimeInterval(15 * 60) // Add 15 minutes
                            )
                            logger.info("✅ Applied Ja'fari Maghrib delay (+15 minutes)")
                            break
                        }
                    }
                }
                
                logger.warning("⚠️ Using fallback calculation - results may differ from expected \(originalMethod.rawValue) method")
                return prayerTimes
            }
        }
        
        logger.error("❌ All fallback calculation attempts failed")
        return nil
    }

    private func resolveLocation(_ location: CLLocation?) async throws -> CLLocation {
        if let location {
            return location
        }

        guard let currentLocation = locationService.currentLocation else {
            return try await locationService.requestLocation()
        }

        return currentLocation
    }

    private func precisionLevel(for disclaimerLevel: DisclaimerLevel) -> PrecisionLevel {
        switch disclaimerLevel {
        case .today, .shortTerm:
            return .exact
        case .mediumTerm:
            return settingsService.showLongRangePrecision ? .exact : .window(minutes: 30)
        case .longTerm:
            return .window(minutes: 30)
        }
    }
    
    // MARK: - Timezone Methods
    
    /// Determine appropriate timezone for a given location
    private func determineTimeZone(for location: CLLocation) async -> TimeZone? {
        // Use known timezone mappings for common locations
        let knownTimezones: [(latitude: Double, longitude: Double, timezone: String)] = [
            // Major Islamic cities and test locations
            (21.4225, 39.8262, "Asia/Riyadh"),      // Mecca
            (24.7136, 46.6753, "Asia/Riyadh"),      // Riyadh
            (40.7128, -74.0060, "America/New_York"), // New York
            (51.5074, -0.1278, "Europe/London"),     // London
            (-6.2088, 106.8456, "Asia/Jakarta"),     // Jakarta
            (33.6844, 73.0479, "Asia/Karachi"),      // Islamabad/Karachi
            (30.0444, 31.2357, "Africa/Cairo"),      // Cairo
            (25.2048, 55.2708, "Asia/Dubai"),        // Dubai
            (25.3548, 51.1839, "Asia/Qatar"),        // Doha
        ]
        
        // Find closest known timezone (within 1 degree tolerance)
        for knownLocation in knownTimezones {
            let latDiff = abs(location.coordinate.latitude - knownLocation.latitude)
            let lonDiff = abs(location.coordinate.longitude - knownLocation.longitude)
            
            if latDiff <= 1.0 && lonDiff <= 1.0 {
                logger.info("🌍 Found known timezone \(knownLocation.timezone) for location (\(location.coordinate.latitude), \(location.coordinate.longitude))")
                return TimeZone(identifier: knownLocation.timezone)
            }
        }
        
        // Fallback: Use basic timezone calculation based on longitude
        // Each 15 degrees of longitude represents 1 hour of time difference
        let hoursFromUTC = Int(round(location.coordinate.longitude / 15.0))
        let clampedHours = max(-12, min(12, hoursFromUTC)) // Clamp to valid timezone range
        let secondsFromGMT = clampedHours * 3600
        
        logger.info("🌍 Calculated timezone offset: GMT\(clampedHours >= 0 ? "+" : "")\(clampedHours) for longitude \(location.coordinate.longitude)")
        return TimeZone(secondsFromGMT: secondsFromGMT)
    }
}

// MARK: - Extensions

// ULTIMATE FIX: Extend CalculationParameters to add a `copy()` method to prevent shared state.
// This creates a new instance with the same values, ensuring calculations are independent.
extension CalculationParameters {
    /// Creates a fresh, mutable copy of the calculation parameters.
    func copy() -> CalculationParameters {
        // Start with a base parameter set (any will do, as we overwrite it).
        // This is a new instance, not a shared one.
        var newParams = Adhan.CalculationMethod.other.params

        // Manually copy all properties to the new instance.
        newParams.method = self.method
        newParams.fajrAngle = self.fajrAngle
        newParams.maghribAngle = self.maghribAngle
        newParams.ishaAngle = self.ishaAngle
        newParams.ishaInterval = self.ishaInterval
        newParams.madhab = self.madhab
        newParams.highLatitudeRule = self.highLatitudeRule
        newParams.rounding = self.rounding
        newParams.shafaq = self.shafaq

        // Also create a new instance of adjustments to avoid shared state.
        newParams.adjustments = PrayerAdjustments(
            fajr: self.adjustments.fajr,
            sunrise: self.adjustments.sunrise,
            dhuhr: self.adjustments.dhuhr,
            asr: self.adjustments.asr,
            maghrib: self.adjustments.maghrib,
            isha: self.adjustments.isha
        )

        return newParams
    }
}


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
    /// ULTIMATE FIX: Creates truly independent CalculationParameters objects by copying from different base methods
    func customParameters() -> CalculationParameters? {
        switch self {
        case .jafariLeva:
            // ULTIMATE FIX: Create completely independent parameter objects by copying from a different base method each time
            // This ensures no shared state by using different source methods
            var params = Adhan.CalculationMethod.egyptian.params  // Different base for independence
            params.method = .other
            params.fajrAngle = 16.0
            params.ishaAngle = 14.0
            // Note: Keep .shafi as default since Adhan library doesn't have native Ja'fari support
            // The user's Ja'fari madhab setting will be handled separately to avoid double-application
            params.madhab = .shafi  
            return params
        case .jafariTehran:
            // ULTIMATE FIX: Create completely independent parameter objects by copying from a different base method each time
            // This ensures no shared state by using different source methods
            var params = Adhan.CalculationMethod.karachi.params  // Different base for independence
            params.method = .other
            params.fajrAngle = 17.7
            params.ishaAngle = 14.0
            // Note: Keep .shafi as default since Adhan library doesn't have native Ja'fari support
            // The user's Ja'fari madhab setting will be handled separately to avoid double-application
            params.madhab = .shafi  
            return params
        case .fcnaCanada:
            // ULTIMATE FIX: Create completely independent parameter objects by copying from a different base method each time
            // This ensures no shared state by using different source methods
            var params = Adhan.CalculationMethod.northAmerica.params  // Different base for independence
            params.method = .other
            params.fajrAngle = 13.0
            params.ishaAngle = 13.0
            params.madhab = .shafi  // Will be overridden by madhab setting
            return params
        default:
            // Other calculation methods use Adhan library's built-in parameters
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
    case lookaheadLimitExceeded(requested: Int, maximum: Int)
    case dateRangeTooLarge
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
        case .lookaheadLimitExceeded(let requested, let maximum):
            return "Requested lookahead of \(requested) months exceeds maximum of \(maximum) months"
        case .dateRangeTooLarge:
            return "Date range exceeds the allowed limit"
        case .permissionDenied:
            return "Location permission denied"
        case .networkError:
            return "Network connection error"
        }
    }
}
