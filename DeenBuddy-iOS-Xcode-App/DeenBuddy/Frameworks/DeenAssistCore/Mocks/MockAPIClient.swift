import Foundation
import Combine

// MARK: - Mock API Client

public class MockAPIClient: APIClientProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isNetworkAvailable: Bool = true
    
    // MARK: - Publishers
    
    private let networkStatusSubject = PassthroughSubject<Bool, Never>()
    
    public var networkStatusPublisher: AnyPublisher<Bool, Never> {
        networkStatusSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Mock Configuration
    
    public var mockDelay: TimeInterval = 1.0
    public var shouldFailRequests: Bool = false
    public var mockError: APIError = .networkError(URLError(.notConnectedToInternet))
    public var rateLimitStatus = APIRateLimitStatus(requestsRemaining: 90, resetTime: Date().addingTimeInterval(3600), isLimited: false)
    
    // MARK: - Mock Data Storage
    
    private var mockPrayerTimesCache: [String: PrayerTimes] = [:]
    private var mockQiblaDirectionCache: [String: QiblaDirection] = [:]
    
    // MARK: - Initialization
    
    public init() {
        setupDefaultMockData()
    }
    
    // MARK: - Protocol Implementation
    
    public func getPrayerTimes(
        for date: Date,
        location: LocationCoordinate,
        calculationMethod: CalculationMethod,
        madhab: Madhab
    ) async throws -> PrayerTimes {
        await simulateNetworkDelay()
        
        if shouldFailRequests {
            throw mockError
        }
        
        if !isNetworkAvailable {
            throw APIError.networkError(URLError(.notConnectedToInternet))
        }
        
        // Simulate rate limiting
        if rateLimitStatus.isLimited {
            throw APIError.rateLimitExceeded
        }
        
        // Generate or return cached mock prayer times
        let cacheKey = prayerTimesCacheKey(date: date, location: location, method: calculationMethod, madhab: madhab)

        if let cached = mockPrayerTimesCache[cacheKey] {
            return cached
        }
        
        let prayerTimes = generateMockPrayerTimes(
            for: date,
            location: location,
            calculationMethod: calculationMethod,
            madhab: madhab
        )
        
        mockPrayerTimesCache[cacheKey] = prayerTimes
        updateRateLimit()
        
        return prayerTimes
    }
    
    public func getQiblaDirection(for location: LocationCoordinate) async throws -> QiblaDirection {
        await simulateNetworkDelay()
        
        if shouldFailRequests {
            throw mockError
        }
        
        if !isNetworkAvailable {
            throw APIError.networkError(URLError(.notConnectedToInternet))
        }
        
        if rateLimitStatus.isLimited {
            throw APIError.rateLimitExceeded
        }
        
        let cacheKey = qiblaCacheKey(location: location)
        
        if let cached = mockQiblaDirectionCache[cacheKey] {
            return cached
        }
        
        let qiblaDirection = KaabaLocation.calculateDirection(from: location)
        mockQiblaDirectionCache[cacheKey] = qiblaDirection
        updateRateLimit()
        
        return qiblaDirection
    }
    
    public func checkAPIHealth() async throws -> Bool {
        await simulateNetworkDelay()
        
        if shouldFailRequests {
            throw mockError
        }
        
        return isNetworkAvailable
    }
    
    public func getRateLimitStatus() -> APIRateLimitStatus {
        return rateLimitStatus
    }

    public func clearPrayerTimeCache() {
        mockPrayerTimesCache.removeAll()
        print("🗑️ MockAPIClient: Cleared prayer time cache")
    }

    public func clearPrayerTimeCache(for calculationMethod: CalculationMethod, madhab: Madhab) {
        let methodKey = calculationMethod.rawValue
        let madhabKey = madhab.rawValue
        
        let keysToRemove = mockPrayerTimesCache.keys.filter { key in
            key.hasSuffix("_\(methodKey)_\(madhabKey)")
        }
        
        for key in keysToRemove {
            mockPrayerTimesCache.removeValue(forKey: key)
        }
        
        print("🗑️ MockAPIClient: Cleared prayer time cache for \(methodKey)/\(madhabKey)")
    }
    
    // MARK: - Mock Configuration Methods
    
    public func setNetworkAvailable(_ available: Bool) {
        isNetworkAvailable = available
        networkStatusSubject.send(available)
    }
    
    public func simulateNetworkError(_ error: APIError) {
        shouldFailRequests = true
        mockError = error
    }
    
    public func clearNetworkError() {
        shouldFailRequests = false
    }
    
    public func setRateLimited(_ limited: Bool) {
        if limited {
            rateLimitStatus = APIRateLimitStatus(
                requestsRemaining: 0,
                resetTime: Date().addingTimeInterval(3600),
                isLimited: true
            )
        } else {
            rateLimitStatus = APIRateLimitStatus(
                requestsRemaining: 90,
                resetTime: Date().addingTimeInterval(3600),
                isLimited: false
            )
        }
    }
    
    public func addMockPrayerTimes(_ prayerTimes: PrayerTimes) {
        let cacheKey = prayerTimesCacheKey(
            date: prayerTimes.date,
            location: prayerTimes.location,
            method: CalculationMethod(rawValue: prayerTimes.calculationMethod) ?? .muslimWorldLeague,
            madhab: .shafi // Default madhab for mock data
        )
        mockPrayerTimesCache[cacheKey] = prayerTimes
    }
    
    public func addMockQiblaDirection(_ direction: QiblaDirection) {
        let cacheKey = qiblaCacheKey(location: direction.location)
        mockQiblaDirectionCache[cacheKey] = direction
    }
    
    public func clearMockCache() {
        mockPrayerTimesCache.removeAll()
        mockQiblaDirectionCache.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func simulateNetworkDelay() async {
        try? await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
    }
    
    private func updateRateLimit() {
        let remaining = max(0, rateLimitStatus.requestsRemaining - 1)
        rateLimitStatus = APIRateLimitStatus(
            requestsRemaining: remaining,
            resetTime: rateLimitStatus.resetTime,
            isLimited: remaining == 0
        )
    }
    
    private func prayerTimesCacheKey(date: Date, location: LocationCoordinate, method: CalculationMethod, madhab: Madhab) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: date))_\(location.latitude)_\(location.longitude)_\(method.rawValue)_\(madhab.rawValue)"
    }
    
    private func qiblaCacheKey(location: LocationCoordinate) -> String {
        return "\(location.latitude)_\(location.longitude)"
    }
    
    private func setupDefaultMockData() {
        // Add some default mock data for common locations
        let newYork = LocationCoordinate(latitude: 40.7128, longitude: -74.0060)
        let london = LocationCoordinate(latitude: 51.5074, longitude: -0.1278)
        let dubai = LocationCoordinate(latitude: 25.2048, longitude: 55.2708)
        
        let today = Date()
        
        // Add mock prayer times for today
        for location in [newYork, london, dubai] {
            let prayerTimes = generateMockPrayerTimes(
                for: today,
                location: location,
                calculationMethod: .muslimWorldLeague,
                madhab: .shafi
            )
            addMockPrayerTimes(prayerTimes)
            
            let qiblaDirection = KaabaLocation.calculateDirection(from: location)
            addMockQiblaDirection(qiblaDirection)
        }
    }
    
    private func generateMockPrayerTimes(
        for date: Date,
        location: LocationCoordinate,
        calculationMethod: CalculationMethod,
        madhab: Madhab
    ) -> PrayerTimes {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)

        // Generate different prayer times based on calculation method
        // This simulates how different methods produce different times
        let fajrMinute: Int
        let ishaMinute: Int

        switch calculationMethod {
        case .muslimWorldLeague:
            fajrMinute = 30  // 5:30 AM for Muslim World League
            ishaMinute = 45  // 7:45 PM
        case .egyptian:
            fajrMinute = 15  // 5:15 AM for Egyptian method
            ishaMinute = 30  // 7:30 PM
        case .karachi:
            fajrMinute = 45  // 5:45 AM for Karachi method
            ishaMinute = 0   // 8:00 PM
        case .northAmerica:
            fajrMinute = 20  // 5:20 AM for North America method
            ishaMinute = 15  // 7:15 PM
        case .jafariLeva:
            fajrMinute = 10  // 5:10 AM for Ja'fari Leva method
            ishaMinute = 50  // 7:50 PM
        case .ummAlQura:
            fajrMinute = 25  // 5:25 AM for Umm Al-Qura method
            ishaMinute = 35  // 7:35 PM
        case .dubai:
            fajrMinute = 35  // 5:35 AM for Dubai method
            ishaMinute = 25  // 7:25 PM
        case .moonsightingCommittee:
            fajrMinute = 40  // 5:40 AM for Moonsighting Committee method
            ishaMinute = 20  // 7:20 PM
        case .kuwait:
            fajrMinute = 5   // 5:05 AM for Kuwait method
            ishaMinute = 55  // 7:55 PM
        case .qatar:
            fajrMinute = 50  // 5:50 AM for Qatar method
            ishaMinute = 10  // 7:10 PM
        case .singapore:
            fajrMinute = 55  // 5:55 AM for Singapore method
            ishaMinute = 5   // 7:05 PM
        case .jafariTehran:
            fajrMinute = 0   // 5:00 AM for Ja'fari Tehran method
            ishaMinute = 40  // 7:40 PM
        case .fcnaCanada:
            fajrMinute = 12  // 5:12 AM for FCNA Canada method
            ishaMinute = 48  // 7:48 PM
        }

        let fajr = calendar.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: 5,  // All methods use 5 AM base hour
            minute: fajrMinute
        )) ?? date

        let dhuhr = calendar.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: 12,
            minute: 30
        )) ?? date

        let asr = calendar.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: 15,
            minute: madhab == .hanafi ? 45 : 30
        )) ?? date

        let maghrib = calendar.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: 18,
            minute: 15
        )) ?? date

        let isha = calendar.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: 19,
            minute: ishaMinute
        )) ?? date

        return PrayerTimes(
            date: date,
            fajr: fajr,
            dhuhr: dhuhr,
            asr: asr,
            maghrib: maghrib,
            isha: isha,
            calculationMethod: calculationMethod.rawValue,
            location: location
        )
    }
}
