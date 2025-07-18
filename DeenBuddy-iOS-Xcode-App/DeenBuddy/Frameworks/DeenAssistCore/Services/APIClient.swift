import Foundation
import Network
import Combine

// MARK: - API Client Implementation

public class APIClient: APIClientProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isNetworkAvailable: Bool = true
    
    // MARK: - Publishers
    
    private let networkStatusSubject = PassthroughSubject<Bool, Never>()
    
    public var networkStatusPublisher: AnyPublisher<Bool, Never> {
        networkStatusSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    
    private let configuration: APIConfiguration
    private let urlSession: URLSession
    private let networkMonitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private let cache: APICacheProtocol
    private var rateLimitTracker: RateLimitTracker
    
    // MARK: - Initialization
    
    public init(
        configuration: APIConfiguration = .default,
        cache: APICacheProtocol? = nil
    ) {
        self.configuration = configuration
        self.cache = cache ?? APICache()
        self.rateLimitTracker = RateLimitTracker(limitPerMinute: configuration.rateLimitPerMinute)
        
        // Configure URL session
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 2
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.urlSession = URLSession(configuration: sessionConfig)
        
        // Setup network monitoring
        self.networkMonitor = NWPathMonitor()
        setupNetworkMonitoring()
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - Protocol Implementation
    
    public func getPrayerTimes(
        for date: Date,
        location: LocationCoordinate,
        calculationMethod: CalculationMethod,
        madhab: Madhab
    ) async throws -> PrayerTimes {
        // Check cache first with method-specific key
        if let cached = cache.getCachedPrayerTimes(for: date, location: location, calculationMethod: calculationMethod, madhab: madhab) {
            return cached
        }
        
        // Check network availability
        guard isNetworkAvailable else {
            throw APIError.networkError(URLError(.notConnectedToInternet))
        }
        
        // Check rate limiting
        try await rateLimitTracker.checkRateLimit()
        
        // Build request
        let methodId = calculationMethodId(for: calculationMethod)
        let schoolId = madhabSchoolId(for: madhab)
        
        let endpoint = APIEndpoint.timings(
            latitude: location.latitude,
            longitude: location.longitude,
            method: methodId,
            school: schoolId
        )
        
        let request = try buildRequest(for: endpoint, date: date)
        
        // Execute request with retry logic
        let response: AlAdhanTimingsResponse = try await executeRequest(request)
        
        // Convert to PrayerTimes
        let prayerTimes = try convertToPrayerTimes(
            response: response,
            date: date,
            location: location,
            calculationMethod: calculationMethod
        )
        
        // Cache the result with method-specific key
        cache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: calculationMethod, madhab: madhab)
        
        return prayerTimes
    }
    
    public func getQiblaDirection(for location: LocationCoordinate) async throws -> QiblaDirection {
        // Check cache first
        if let cached = cache.getCachedQiblaDirection(for: location) {
            return cached
        }
        
        // Check network availability
        guard isNetworkAvailable else {
            // Use local calculation as fallback
            return KaabaLocation.calculateDirection(from: location)
        }
        
        // Check rate limiting
        try await rateLimitTracker.checkRateLimit()
        
        // Build request
        let endpoint = APIEndpoint.qibla(latitude: location.latitude, longitude: location.longitude)
        let request = try buildRequest(for: endpoint)
        
        // Execute request with retry logic
        let response: AlAdhanQiblaResponse = try await executeRequest(request)
        
        // Convert to QiblaDirection
        let qiblaDirection = QiblaDirection(
            direction: response.data.direction,
            distance: KaabaLocation.calculateDirection(from: location).distance,
            location: location
        )
        
        // Cache the result
        cache.cacheQiblaDirection(qiblaDirection, for: location)
        
        return qiblaDirection
    }
    
    public func checkAPIHealth() async throws -> Bool {
        guard isNetworkAvailable else {
            return false
        }
        
        let endpoint = APIEndpoint.methods
        let request = try buildRequest(for: endpoint)
        
        do {
            let (_, response) = try await urlSession.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            
            return false
        } catch {
            return false
        }
    }
    
    public func getRateLimitStatus() -> APIRateLimitStatus {
        return rateLimitTracker.getCurrentStatus()
    }

    public func clearPrayerTimeCache() {
        cache.clearPrayerTimeCache()
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let isAvailable = path.status == .satisfied
                self?.isNetworkAvailable = isAvailable
                self?.networkStatusSubject.send(isAvailable)
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    private func buildRequest(for endpoint: APIEndpoint, date: Date? = nil) throws -> URLRequest {
        guard var urlComponents = URLComponents(string: configuration.baseURL + endpoint.path) else {
            throw APIError.invalidURL
        }
        
        var queryItems = endpoint.queryItems
        
        // Add date parameter if provided
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd-MM-yyyy"
            queryItems.append(URLQueryItem(name: "date", value: formatter.string(from: date)))
        }
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("DeenAssist/1.0", forHTTPHeaderField: "User-Agent")
        
        return request
    }
    
    private func executeRequest<T: Codable>(_ request: URLRequest) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...configuration.maxRetries {
            do {
                let (data, response) = try await urlSession.data(for: request)
                
                // Check HTTP response
                if let httpResponse = response as? HTTPURLResponse {
                    try validateHTTPResponse(httpResponse)
                }
                
                // Update rate limit tracker
                rateLimitTracker.recordRequest()
                
                // Decode response
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                return try decoder.decode(T.self, from: data)
                
            } catch let error as APIError {
                lastError = error
                
                // Don't retry for certain errors
                switch error {
                case .rateLimitExceeded:
                    throw error
                case .serverError(let code, _) where code >= 400 && code < 500:
                    throw error
                default:
                    if attempt == configuration.maxRetries {
                        throw error
                    }
                }
                
            } catch {
                lastError = APIError.networkError(error)
                
                if attempt == configuration.maxRetries {
                    throw APIError.networkError(error)
                }
            }
            
            // Wait before retry
            if attempt < configuration.maxRetries {
                let delay = TimeInterval(attempt * 2) // Exponential backoff
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw lastError ?? APIError.networkError(URLError(.unknown))
    }
    
    private func validateHTTPResponse(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 429:
            throw APIError.rateLimitExceeded
        case 400...499:
            throw APIError.serverError(response.statusCode, HTTPURLResponse.localizedString(forStatusCode: response.statusCode))
        case 500...599:
            throw APIError.serverError(response.statusCode, HTTPURLResponse.localizedString(forStatusCode: response.statusCode))
        default:
            throw APIError.invalidResponse
        }
    }
    
    private func convertToPrayerTimes(
        response: AlAdhanTimingsResponse,
        date: Date,
        location: LocationCoordinate,
        calculationMethod: CalculationMethod
    ) throws -> PrayerTimes {
        let timings = response.data.timings
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        dateFormatter.timeZone = TimeZone.current
        
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        
        guard let fajrTime = parseTime(timings.fajr, dateComponents: dateComponents, formatter: dateFormatter),
              let dhuhrTime = parseTime(timings.dhuhr, dateComponents: dateComponents, formatter: dateFormatter),
              let asrTime = parseTime(timings.asr, dateComponents: dateComponents, formatter: dateFormatter),
              let maghribTime = parseTime(timings.maghrib, dateComponents: dateComponents, formatter: dateFormatter),
              let ishaTime = parseTime(timings.isha, dateComponents: dateComponents, formatter: dateFormatter) else {
            throw APIError.decodingError(NSError(domain: "TimeParsingError", code: 0))
        }
        
        return PrayerTimes(
            date: date,
            fajr: fajrTime,
            dhuhr: dhuhrTime,
            asr: asrTime,
            maghrib: maghribTime,
            isha: ishaTime,
            calculationMethod: calculationMethod.rawValue,
            location: location
        )
    }
    
    private func parseTime(_ timeString: String, dateComponents: DateComponents, formatter: DateFormatter) -> Date? {
        guard let time = formatter.date(from: timeString) else { return nil }
        
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: time)
        
        return Calendar.current.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: timeComponents.hour,
            minute: timeComponents.minute
        ))
    }
    
    private func calculationMethodId(for method: CalculationMethod) -> Int {
        switch method {
        case .muslimWorldLeague: return 3
        case .egyptian: return 5
        case .karachi: return 1
        case .ummAlQura: return 4
        case .dubai: return 8
        case .moonsightingCommittee: return 7
        case .northAmerica: return 2
        case .kuwait: return 9
        case .qatar: return 10
        case .singapore: return 11
        }
    }

    private func madhabSchoolId(for madhab: Madhab) -> Int {
        switch madhab {
        case .hanafi: return 1  // Hanafi school
        case .shafi: return 0   // Shafi'i school (default, includes Maliki/Hanbali)
        case .jafari: return 0  // Use Shafi'i as closest approximation for API
        }
    }
}

// MARK: - Rate Limit Tracker

private class RateLimitTracker: @unchecked Sendable {
    private let limitPerMinute: Int
    private var requestTimes: [Date] = []
    private let queue = DispatchQueue(label: "RateLimitTracker", attributes: .concurrent)

    init(limitPerMinute: Int) {
        self.limitPerMinute = limitPerMinute
    }

    func checkRateLimit() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(flags: .barrier) {
                self.cleanOldRequests()

                if self.requestTimes.count >= self.limitPerMinute {
                    continuation.resume(throwing: APIError.rateLimitExceeded)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func recordRequest() {
        queue.async(flags: .barrier) {
            self.requestTimes.append(Date())
            self.cleanOldRequests()
        }
    }

    func getCurrentStatus() -> APIRateLimitStatus {
        return queue.sync {
            cleanOldRequests()
            let remaining = max(0, limitPerMinute - requestTimes.count)
            let resetTime = requestTimes.first?.addingTimeInterval(60) ?? Date()

            return APIRateLimitStatus(
                requestsRemaining: remaining,
                resetTime: resetTime,
                isLimited: remaining == 0
            )
        }
    }

    private func cleanOldRequests() {
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        requestTimes.removeAll { $0 < oneMinuteAgo }
    }
}
