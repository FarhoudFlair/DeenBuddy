import Foundation

// MARK: - AlAdhan API Response Models

public struct AlAdhanTimingsResponse: Codable {
    public let code: Int
    public let status: String
    public let data: AlAdhanTimingsData
    
    public init(code: Int, status: String, data: AlAdhanTimingsData) {
        self.code = code
        self.status = status
        self.data = data
    }
}

public struct AlAdhanTimingsData: Codable {
    public let timings: AlAdhanTimings
    public let date: AlAdhanDate
    public let meta: AlAdhanMeta
    
    public init(timings: AlAdhanTimings, date: AlAdhanDate, meta: AlAdhanMeta) {
        self.timings = timings
        self.date = date
        self.meta = meta
    }
}

public struct AlAdhanTimings: Codable {
    public let fajr: String
    public let sunrise: String
    public let dhuhr: String
    public let asr: String
    public let sunset: String
    public let maghrib: String
    public let isha: String
    public let imsak: String
    public let midnight: String
    
    public init(
        fajr: String,
        sunrise: String,
        dhuhr: String,
        asr: String,
        sunset: String,
        maghrib: String,
        isha: String,
        imsak: String,
        midnight: String
    ) {
        self.fajr = fajr
        self.sunrise = sunrise
        self.dhuhr = dhuhr
        self.asr = asr
        self.sunset = sunset
        self.maghrib = maghrib
        self.isha = isha
        self.imsak = imsak
        self.midnight = midnight
    }
    
    enum CodingKeys: String, CodingKey {
        case fajr = "Fajr"
        case sunrise = "Sunrise"
        case dhuhr = "Dhuhr"
        case asr = "Asr"
        case sunset = "Sunset"
        case maghrib = "Maghrib"
        case isha = "Isha"
        case imsak = "Imsak"
        case midnight = "Midnight"
    }
}

public struct AlAdhanDate: Codable {
    public let readable: String
    public let timestamp: String
    public let hijri: AlAdhanHijriDate
    public let gregorian: AlAdhanGregorianDate
    
    public init(readable: String, timestamp: String, hijri: AlAdhanHijriDate, gregorian: AlAdhanGregorianDate) {
        self.readable = readable
        self.timestamp = timestamp
        self.hijri = hijri
        self.gregorian = gregorian
    }
}

public struct AlAdhanHijriDate: Codable {
    public let date: String
    public let format: String
    public let day: String
    public let weekday: AlAdhanWeekday
    public let month: AlAdhanMonth
    public let year: String
    
    public init(date: String, format: String, day: String, weekday: AlAdhanWeekday, month: AlAdhanMonth, year: String) {
        self.date = date
        self.format = format
        self.day = day
        self.weekday = weekday
        self.month = month
        self.year = year
    }
}

public struct AlAdhanGregorianDate: Codable {
    public let date: String
    public let format: String
    public let day: String
    public let weekday: AlAdhanWeekday
    public let month: AlAdhanMonth
    public let year: String
    
    public init(date: String, format: String, day: String, weekday: AlAdhanWeekday, month: AlAdhanMonth, year: String) {
        self.date = date
        self.format = format
        self.day = day
        self.weekday = weekday
        self.month = month
        self.year = year
    }
}

public struct AlAdhanWeekday: Codable {
    public let en: String
    public let ar: String?
    
    public init(en: String, ar: String? = nil) {
        self.en = en
        self.ar = ar
    }
}

public struct AlAdhanMonth: Codable {
    public let number: Int
    public let en: String
    public let ar: String?
    
    public init(number: Int, en: String, ar: String? = nil) {
        self.number = number
        self.en = en
        self.ar = ar
    }
}

public struct AlAdhanMeta: Codable {
    public let latitude: Double
    public let longitude: Double
    public let timezone: String
    public let method: AlAdhanMethod
    public let latitudeAdjustmentMethod: String
    public let midnightMode: String
    public let school: String
    public let offset: [String: Int]
    
    public init(
        latitude: Double,
        longitude: Double,
        timezone: String,
        method: AlAdhanMethod,
        latitudeAdjustmentMethod: String,
        midnightMode: String,
        school: String,
        offset: [String: Int]
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.timezone = timezone
        self.method = method
        self.latitudeAdjustmentMethod = latitudeAdjustmentMethod
        self.midnightMode = midnightMode
        self.school = school
        self.offset = offset
    }
}

public struct AlAdhanMethod: Codable {
    public let id: Int
    public let name: String
    public let params: AlAdhanMethodParams
    
    public init(id: Int, name: String, params: AlAdhanMethodParams) {
        self.id = id
        self.name = name
        self.params = params
    }
}

public struct AlAdhanMethodParams: Codable {
    public let fajr: Double
    public let isha: Double
    
    public init(fajr: Double, isha: Double) {
        self.fajr = fajr
        self.isha = isha
    }
    
    enum CodingKeys: String, CodingKey {
        case fajr = "Fajr"
        case isha = "Isha"
    }
}

// MARK: - Qibla API Response

public struct AlAdhanQiblaResponse: Codable {
    public let code: Int
    public let status: String
    public let data: AlAdhanQiblaData
    
    public init(code: Int, status: String, data: AlAdhanQiblaData) {
        self.code = code
        self.status = status
        self.data = data
    }
}

public struct AlAdhanQiblaData: Codable {
    public let latitude: Double
    public let longitude: Double
    public let direction: Double
    
    public init(latitude: Double, longitude: Double, direction: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.direction = direction
    }
}

// MARK: - API Error Models

public enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(Error)
    case serverError(Int, String?)
    case rateLimitExceeded
    case invalidResponse
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .noData:
            return "No data received from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Unknown error")"
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please try again later."
        case .invalidResponse:
            return "Invalid response from server"
        case .timeout:
            return "Request timed out. Please check your connection."
        }
    }
}
