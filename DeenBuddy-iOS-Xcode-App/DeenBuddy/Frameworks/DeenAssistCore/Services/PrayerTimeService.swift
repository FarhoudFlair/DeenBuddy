import Foundation
import CoreLocation
import Combine
import Adhan

/// Real implementation of PrayerTimeServiceProtocol using AdhanSwift
public class PrayerTimeService: PrayerTimeServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var todaysPrayerTimes: [PrayerTime] = []
    @Published public var nextPrayer: PrayerTime? = nil
    @Published public var timeUntilNextPrayer: TimeInterval? = nil
    @Published public var calculationMethod: CalculationMethod = .muslimWorldLeague
    @Published public var madhab: Madhab = .shafi
    @Published public var isLoading: Bool = false
    @Published public var error: Error? = nil
    
    // MARK: - Private Properties

    private let locationService: any LocationServiceProtocol
    private let errorHandler: ErrorHandler
    private let retryMechanism: RetryMechanism
    private let networkMonitor: NetworkMonitor
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Cache Keys
    
    private enum CacheKeys {
        static let calculationMethod = "DeenAssist.CalculationMethod"
        static let madhab = "DeenAssist.Madhab"
        static let cachedPrayerTimes = "DeenAssist.CachedPrayerTimes"
        static let cacheDate = "DeenAssist.CacheDate"
    }
    
    // MARK: - Initialization
    
    public init(locationService: any LocationServiceProtocol, errorHandler: ErrorHandler, retryMechanism: RetryMechanism, networkMonitor: NetworkMonitor) {
        self.locationService = locationService
        self.errorHandler = errorHandler
        self.retryMechanism = retryMechanism
        self.networkMonitor = networkMonitor
        loadSettings()
        setupLocationObserver()
        startTimer()
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

            // Use Adhan.CalculationMethod and its params property
            let adhanMethod = Adhan.CalculationMethod(rawValue: calculationMethod.rawValue) ?? .muslimWorldLeague
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
        do {
            // Check for cached data first if offline
            if await !networkMonitor.isConnected {
                if let cachedTimes = loadCachedPrayerTimes() {
                    todaysPrayerTimes = cachedTimes
                    updateNextPrayer()
                    return
                }
            }

            // Fix: Remove .clLocation property access - use currentLocation directly
            guard let location = locationService.currentLocation else {
                let locationError = AppError.locationUnavailable
                error = locationError
                await errorHandler.handleError(locationError)
                return
            }

            let prayerTimes = try await calculatePrayerTimes(for: location, date: Date())
            todaysPrayerTimes = prayerTimes
            updateNextPrayer()
        } catch {
            let appError = convertToAppError(error)
            self.error = appError
            await errorHandler.handleError(appError)
        }
    }
    
    public func refreshTodaysPrayerTimes() async {
        await refreshPrayerTimes()
    }
    
    public func getCurrentLocation() async throws -> CLLocation {
        // Fix: Remove .clLocation property access - use currentLocation directly
        guard let location = locationService.currentLocation else {
            throw AppError.locationUnavailable
        }
        return location
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
    
    private func loadSettings() {
        if let methodRawValue = userDefaults.string(forKey: CacheKeys.calculationMethod),
           let method = CalculationMethod(rawValue: methodRawValue) {
            calculationMethod = method
        }
        
        if let madhabRawValue = userDefaults.string(forKey: CacheKeys.madhab),
           let madhab = Madhab(rawValue: madhabRawValue) {
            self.madhab = madhab
        }
        
        if let cachedTimes = loadCachedPrayerTimes() {
            todaysPrayerTimes = cachedTimes
            updateNextPrayer()
        }
    }
    
    private func saveSettings() {
        userDefaults.set(calculationMethod.rawValue, forKey: CacheKeys.calculationMethod)
        userDefaults.set(madhab.rawValue, forKey: CacheKeys.madhab)
    }
    
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
        
        if let data = try? JSONEncoder().encode(prayerTimes) {
            userDefaults.set(data, forKey: "\(CacheKeys.cachedPrayerTimes)_\(dateKey)")
            userDefaults.set(dateKey, forKey: CacheKeys.cacheDate)
        }
    }
    
    private func loadCachedPrayerTimes() -> [PrayerTime]? {
        let today = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = dateFormatter.string(from: today)

        if let data = userDefaults.data(forKey: "\(CacheKeys.cachedPrayerTimes)_\(todayKey)"),
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
