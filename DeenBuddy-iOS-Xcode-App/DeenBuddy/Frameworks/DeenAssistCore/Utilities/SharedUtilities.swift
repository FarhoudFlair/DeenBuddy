import Foundation
import CoreLocation
import UIKit
import os.log

/// Shared utilities used across multiple services to reduce code duplication
public final class SharedUtilities {
    
    // MARK: - Date Formatting
    
    /// Shared date formatters to avoid creating new instances
    public static let sharedDateFormatters = DateFormatters()
    
    public struct DateFormatters {
        public let iso8601: ISO8601DateFormatter
        public let shortTime: DateFormatter
        public let longTime: DateFormatter
        public let shortDate: DateFormatter
        public let longDate: DateFormatter
        public let hijriDate: DateFormatter
        public let cacheKey: DateFormatter
        
        init() {
            iso8601 = ISO8601DateFormatter()
            
            shortTime = DateFormatter()
            shortTime.timeStyle = .short
            
            longTime = DateFormatter()
            longTime.timeStyle = .long
            
            shortDate = DateFormatter()
            shortDate.dateStyle = .short
            
            longDate = DateFormatter()
            longDate.dateStyle = .long
            
            hijriDate = DateFormatter()
            hijriDate.calendar = Calendar(identifier: .islamicCivil)
            hijriDate.dateStyle = .medium
            
            cacheKey = DateFormatter()
            cacheKey.dateFormat = "yyyy-MM-dd"
        }
    }
    
    // MARK: - Location Utilities
    
    /// Calculate distance between two coordinates
    /// - Parameters:
    ///   - from: Starting coordinate
    ///   - to: Ending coordinate
    /// - Returns: Distance in kilometers
    public static func calculateDistance(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation) / 1000.0 // Convert to km
    }
    
    /// Check if coordinate is valid
    /// - Parameter coordinate: Coordinate to validate
    /// - Returns: True if valid
    public static func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return CLLocationCoordinate2DIsValid(coordinate) &&
               coordinate.latitude >= -90 && coordinate.latitude <= 90 &&
               coordinate.longitude >= -180 && coordinate.longitude <= 180
    }
    
    /// Create location-based cache key
    /// - Parameters:
    ///   - location: Location for key
    ///   - precision: Precision for rounding (default: 0.01 for ~1km)
    /// - Returns: Cache key string
    public static func createLocationCacheKey(
        for location: CLLocationCoordinate2D,
        precision: Double = 0.01
    ) -> String {
        let lat = (location.latitude / precision).rounded() * precision
        let lon = (location.longitude / precision).rounded() * precision
        return String(format: "%.2f,%.2f", lat, lon)
    }
    
    // MARK: - String Utilities
    
    /// Generate deterministic hash for cache keys
    /// - Parameter input: Input string
    /// - Returns: Hash string
    public static func generateCacheKey(_ input: String) -> String {
        return String(input.hashValue)
    }
    
    /// Safe string truncation
    /// - Parameters:
    ///   - string: String to truncate
    ///   - length: Maximum length
    /// - Returns: Truncated string
    public static func truncateString(_ string: String, to length: Int) -> String {
        if string.count <= length {
            return string
        }
        return String(string.prefix(length)) + "..."
    }
    
    /// Remove diacritics from Arabic text for search
    /// - Parameter text: Arabic text
    /// - Returns: Text without diacritics
    public static func removeDiacritics(from text: String) -> String {
        return text.folding(options: .diacriticInsensitive, locale: .current)
    }

    /// Normalize Arabic text for search by removing diacritics and standardizing characters
    /// - Parameter text: Arabic text to normalize
    /// - Returns: Normalized text suitable for search matching
    public static func normalizeArabicForSearch(_ text: String) -> String {
        var normalized = text

        // Remove all diacritics by filtering out combining marks
        normalized = String(normalized.unicodeScalars.filter { scalar in
            let category = scalar.properties.generalCategory
            return category != .nonspacingMark && category != .enclosingMark && category != .spacingMark
        })

        // Normalize different Alif variants to standard Alif
        normalized = normalized.replacingOccurrences(of: "ٱ", with: "ا") // Alif Wasla → Alif
        normalized = normalized.replacingOccurrences(of: "أ", with: "ا") // Alif with Hamza above → Alif
        normalized = normalized.replacingOccurrences(of: "إ", with: "ا") // Alif with Hamza below → Alif
        normalized = normalized.replacingOccurrences(of: "آ", with: "ا") // Alif with Madda → Alif

        // Normalize different Yaa variants
        normalized = normalized.replacingOccurrences(of: "ى", with: "ي") // Alif Maksura → Yaa
        normalized = normalized.replacingOccurrences(of: "ئ", with: "ي") // Yaa with Hamza → Yaa

        // Normalize different Haa variants
        normalized = normalized.replacingOccurrences(of: "ة", with: "ه") // Taa Marbouta → Haa

        // Normalize different Waw variants
        normalized = normalized.replacingOccurrences(of: "ؤ", with: "و") // Waw with Hamza → Waw

        // Remove extra whitespace and convert to lowercase
        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized = normalized.lowercased()

        return normalized
    }

    /// Check if text contains Arabic search term with proper normalization
    /// - Parameters:
    ///   - text: Text to search in
    ///   - searchTerm: Term to search for
    /// - Returns: True if normalized text contains normalized search term
    public static func arabicTextContains(_ text: String, searchTerm: String) -> Bool {
        let normalizedText = normalizeArabicForSearch(text)
        let normalizedSearchTerm = normalizeArabicForSearch(searchTerm)
        return normalizedText.contains(normalizedSearchTerm)
    }
    
    // MARK: - Data Conversion
    
    /// Convert object to JSON data
    /// - Parameter object: Object to convert
    /// - Returns: JSON data or nil
    public static func toJSONData<T: Codable>(_ object: T) -> Data? {
        return try? JSONEncoder().encode(object)
    }
    
    /// Convert JSON data to object
    /// - Parameters:
    ///   - data: JSON data
    ///   - type: Object type
    /// - Returns: Decoded object or nil
    public static func fromJSONData<T: Codable>(_ data: Data, type: T.Type) -> T? {
        return try? JSONDecoder().decode(type, from: data)
    }
    
    /// Calculate data size in bytes
    /// - Parameter data: Data to measure
    /// - Returns: Size in bytes
    public static func calculateDataSize<T: Codable>(_ data: T) -> Int {
        return toJSONData(data)?.count ?? 0
    }
    
    // MARK: - Error Handling
    
    /// Create standardized error message
    /// - Parameters:
    ///   - error: Original error
    ///   - context: Additional context
    /// - Returns: Formatted error message
    public static func formatErrorMessage(_ error: Error, context: String? = nil) -> String {
        var message = error.localizedDescription
        
        if let context = context {
            message = "\(context): \(message)"
        }
        
        return message
    }
    
    /// Check if error is network-related
    /// - Parameter error: Error to check
    /// - Returns: True if network error
    public static func isNetworkError(_ error: Error) -> Bool {
        if let nsError = error as NSError? {
            return nsError.domain == NSURLErrorDomain ||
                   nsError.code == NSURLErrorNotConnectedToInternet ||
                   nsError.code == NSURLErrorTimedOut
        }
        return false
    }
    
    // MARK: - Device Information
    
    /// Get device model identifier
    /// - Returns: Device model string
    public static func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
    }
    
    /// Get app version
    /// - Returns: App version string
    public static func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    /// Get app build number
    /// - Returns: Build number string
    public static func getBuildNumber() -> String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    /// Check if running on simulator
    /// - Returns: True if simulator
    public static func isSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Performance Utilities
    
    /// Measure execution time of operation
    /// - Parameters:
    ///   - operation: Operation to measure
    ///   - label: Label for logging
    /// - Returns: Result of operation
    public static func measureExecutionTime<T>(
        _ operation: () throws -> T,
        label: String = "Operation"
    ) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        let logger = Logger(subsystem: "com.deenbuddy.app", category: "Performance")
        logger.info("⏱️ \(label) took \(String(format: "%.2f", timeElapsed * 1000))ms")
        
        return result
    }
    
    /// Async version of execution time measurement
    /// - Parameters:
    ///   - operation: Async operation to measure
    ///   - label: Label for logging
    /// - Returns: Result of operation
    public static func measureExecutionTime<T>(
        _ operation: () async throws -> T,
        label: String = "Operation"
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        let logger = Logger(subsystem: "com.deenbuddy.app", category: "Performance")
        logger.info("⏱️ \(label) took \(String(format: "%.2f", timeElapsed * 1000))ms")
        
        return result
    }
    
    // MARK: - Islamic Utilities
    
    /// Convert Gregorian date to Hijri
    /// - Parameter date: Gregorian date
    /// - Returns: Hijri date components
    public static func convertToHijri(_ date: Date) -> DateComponents {
        let hijriCalendar = Calendar(identifier: .islamicCivil)
        return hijriCalendar.dateComponents([.year, .month, .day], from: date)
    }
    
    /// Convert Hijri date to Gregorian
    /// - Parameter hijriComponents: Hijri date components
    /// - Returns: Gregorian date or nil
    public static func convertToGregorian(_ hijriComponents: DateComponents) -> Date? {
        let hijriCalendar = Calendar(identifier: .islamicCivil)
        return hijriCalendar.date(from: hijriComponents)
    }
    
    /// Format Arabic text for RTL display
    /// - Parameter text: Arabic text
    /// - Returns: Formatted text
    public static func formatArabicText(_ text: String) -> String {
        // Add RTL mark if needed
        return "\u{200F}" + text
    }
    
    /// Check if text contains Arabic characters
    /// - Parameter text: Text to check
    /// - Returns: True if contains Arabic
    public static func containsArabic(_ text: String) -> Bool {
        return text.rangeOfCharacter(from: CharacterSet(charactersIn: "\u{0600}"..."\u{06FF}")) != nil
    }
    
    // MARK: - Async Utilities
    
    /// Create async sequence from timer
    /// - Parameter interval: Timer interval
    /// - Returns: Async sequence
    public static func createTimerSequence(interval: TimeInterval) -> AsyncStream<Date> {
        return AsyncStream { continuation in
            let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                continuation.yield(Date())
            }
            
            continuation.onTermination = { _ in
                timer.invalidate()
            }
        }
    }
    
    /// Debounce async operation
    /// - Parameters:
    ///   - operation: Operation to debounce
    ///   - delay: Delay in seconds
    /// - Returns: Debounced operation
    public static func debounce<T>(
        _ operation: @escaping () async throws -> T,
        delay: TimeInterval
    ) -> () async throws -> T {
        var task: Task<T, Error>?
        
        return {
            task?.cancel()
            task = Task {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await operation()
            }
            return try await task!.value
        }
    }
    
    // MARK: - Validation Utilities
    
    /// Validate email format
    /// - Parameter email: Email string
    /// - Returns: True if valid
    public static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    /// Validate phone number format
    /// - Parameter phone: Phone number string
    /// - Returns: True if valid
    public static func isValidPhone(_ phone: String) -> Bool {
        let phoneRegex = #"^\+?[\d\s\-\(\)]{10,}$"#
        return NSPredicate(format: "SELF MATCHES %@", phoneRegex).evaluate(with: phone)
    }
    
    /// Validate URL format
    /// - Parameter urlString: URL string
    /// - Returns: True if valid
    public static func isValidURL(_ urlString: String) -> Bool {
        return URL(string: urlString) != nil
    }
}

// MARK: - Extensions

extension SharedUtilities {
    /// Common retry delays for network operations
    public static let retryDelays: [TimeInterval] = [0.5, 1.0, 2.0, 4.0, 8.0]
    
    /// Default timeout intervals
    public static let defaultTimeouts = TimeoutConfiguration()
    
    public struct TimeoutConfiguration {
        public let short: TimeInterval = 5.0
        public let medium: TimeInterval = 30.0
        public let long: TimeInterval = 60.0
        public let extended: TimeInterval = 120.0
    }
}

// MARK: - Thread Safety Utilities

extension SharedUtilities {
    /// Execute operation on main thread
    /// - Parameter operation: Operation to execute
    public static func executeOnMainThread(_ operation: @escaping () -> Void) {
        if Thread.isMainThread {
            operation()
        } else {
            DispatchQueue.main.async {
                operation()
            }
        }
    }
    
    /// Execute operation on background thread
    /// - Parameters:
    ///   - qos: Quality of service
    ///   - operation: Operation to execute
    public static func executeOnBackground(
        qos: DispatchQoS.QoSClass = .utility,
        _ operation: @escaping () -> Void
    ) {
        DispatchQueue.global(qos: qos).async {
            operation()
        }
    }
}