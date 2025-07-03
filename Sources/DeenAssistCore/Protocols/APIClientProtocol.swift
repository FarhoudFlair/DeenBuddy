import Foundation
import Combine

// MARK: - API Client Protocol

public protocol APIClientProtocol: ObservableObject {
    /// Network reachability status
    var isNetworkAvailable: Bool { get }
    
    /// Publisher for network status changes
    var networkStatusPublisher: AnyPublisher<Bool, Never> { get }
    
    /// Get prayer times for a specific date and location
    func getPrayerTimes(
        for date: Date,
        location: LocationCoordinate,
        calculationMethod: CalculationMethod,
        madhab: Madhab
    ) async throws -> PrayerTimes
    
    /// Get qibla direction for a location
    func getQiblaDirection(for location: LocationCoordinate) async throws -> QiblaDirection
    
    /// Check API health and connectivity
    func checkAPIHealth() async throws -> Bool
    
    /// Get current API rate limit status
    func getRateLimitStatus() -> APIRateLimitStatus
}

// MARK: - Rate Limiting

public struct APIRateLimitStatus {
    public let requestsRemaining: Int
    public let resetTime: Date
    public let isLimited: Bool
    
    public init(requestsRemaining: Int, resetTime: Date, isLimited: Bool) {
        self.requestsRemaining = requestsRemaining
        self.resetTime = resetTime
        self.isLimited = isLimited
    }
    
    public var timeUntilReset: TimeInterval {
        return resetTime.timeIntervalSinceNow
    }
}

// MARK: - API Configuration

public struct APIConfiguration {
    public let baseURL: String
    public let timeout: TimeInterval
    public let maxRetries: Int
    public let rateLimitPerMinute: Int
    
    public init(
        baseURL: String = "https://api.aladhan.com/v1",
        timeout: TimeInterval = 30,
        maxRetries: Int = 3,
        rateLimitPerMinute: Int = 90
    ) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.rateLimitPerMinute = rateLimitPerMinute
    }
    
    public static let `default` = APIConfiguration()
}

// MARK: - Request Types

public enum APIEndpoint {
    case timings(latitude: Double, longitude: Double, method: Int, school: Int)
    case qibla(latitude: Double, longitude: Double)
    case methods
    
    public var path: String {
        switch self {
        case .timings:
            return "/timings"
        case .qibla:
            return "/qibla"
        case .methods:
            return "/methods"
        }
    }
    
    public var queryItems: [URLQueryItem] {
        switch self {
        case .timings(let lat, let lon, let method, let school):
            return [
                URLQueryItem(name: "latitude", value: String(lat)),
                URLQueryItem(name: "longitude", value: String(lon)),
                URLQueryItem(name: "method", value: String(method)),
                URLQueryItem(name: "school", value: String(school))
            ]
        case .qibla(let lat, let lon):
            return [
                URLQueryItem(name: "latitude", value: String(lat)),
                URLQueryItem(name: "longitude", value: String(lon))
            ]
        case .methods:
            return []
        }
    }
}

// MARK: - Cache Protocol

public protocol APICacheProtocol {
    /// Cache prayer times for a specific date and location
    func cachePrayerTimes(_ prayerTimes: PrayerTimes, for date: Date, location: LocationCoordinate)
    
    /// Get cached prayer times for a specific date and location
    func getCachedPrayerTimes(for date: Date, location: LocationCoordinate) -> PrayerTimes?
    
    /// Cache qibla direction for a location
    func cacheQiblaDirection(_ direction: QiblaDirection, for location: LocationCoordinate)
    
    /// Get cached qibla direction for a location
    func getCachedQiblaDirection(for location: LocationCoordinate) -> QiblaDirection?
    
    /// Clear expired cache entries
    func clearExpiredCache()
    
    /// Clear all cache
    func clearAllCache()
    
    /// Get cache size in bytes
    func getCacheSize() -> Int64
}

// MARK: - Default Implementation Helpers

public extension APIClientProtocol {
    /// Check if we should use cached data based on network status
    var shouldUseCachedData: Bool {
        return !isNetworkAvailable
    }
    
    /// Check if API is rate limited
    var isRateLimited: Bool {
        return getRateLimitStatus().isLimited
    }
    
    /// Time until rate limit resets
    var timeUntilRateLimitReset: TimeInterval {
        return getRateLimitStatus().timeUntilReset
    }
}
