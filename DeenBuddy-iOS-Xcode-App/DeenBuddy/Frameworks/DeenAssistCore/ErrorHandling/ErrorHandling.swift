import Foundation
import Combine

// MARK: - Error Handling Protocols

/// Protocol for errors that can be presented to users
public protocol UserPresentableError: LocalizedError {
    var title: String { get }
    var message: String { get }
    var actionTitle: String? { get }
    var isRetryable: Bool { get }
    var severity: ErrorSeverity { get }
}

/// Protocol for errors that can be automatically retried
public protocol RetryableError: Error {
    var maxRetryAttempts: Int { get }
    var retryDelay: TimeInterval { get }
    var shouldRetry: Bool { get }
}

/// Protocol for services that can handle errors
public protocol ErrorHandling {
    func handleError(_ error: Error)
    func presentError(_ error: UserPresentableError)
    func retryOperation<T>(_ operation: @escaping () async throws -> T) async throws -> T
}

// MARK: - Error Severity

public enum ErrorSeverity: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    public var displayName: String {
        return rawValue.capitalized
    }
    
    public var shouldReportToCrashlytics: Bool {
        switch self {
        case .low: return false
        case .medium: return true
        case .high: return true
        case .critical: return true
        }
    }
}

// MARK: - Standard App Errors

public enum AppError: UserPresentableError, RetryableError {
    case networkUnavailable
    case networkTimeout
    case serverError(Int)
    case dataCorrupted
    case locationUnavailable
    case locationPermissionDenied
    case notificationPermissionDenied
    case configurationMissing
    case serviceUnavailable(String)
    case unknownError(Error)
    
    // MARK: UserPresentableError
    
    public var title: String {
        switch self {
        case .networkUnavailable:
            return "No Internet Connection"
        case .networkTimeout:
            return "Connection Timeout"
        case .serverError:
            return "Server Error"
        case .dataCorrupted:
            return "Data Error"
        case .locationUnavailable:
            return "Location Unavailable"
        case .locationPermissionDenied:
            return "Location Permission Required"
        case .notificationPermissionDenied:
            return "Notification Permission Required"
        case .configurationMissing:
            return "Configuration Error"
        case .serviceUnavailable:
            return "Service Unavailable"
        case .unknownError:
            return "Unexpected Error"
        }
    }
    
    public var message: String {
        switch self {
        case .networkUnavailable:
            return "Please check your internet connection and try again."
        case .networkTimeout:
            return "The request took too long to complete. Please try again."
        case .serverError(let code):
            return "Server returned error code \(code). Please try again later."
        case .dataCorrupted:
            return "The data appears to be corrupted. Please refresh and try again."
        case .locationUnavailable:
            return "Unable to determine your location. Please ensure location services are enabled."
        case .locationPermissionDenied:
            return "Location access is required for prayer times and Qibla direction. Please enable location permissions in Settings."
        case .notificationPermissionDenied:
            return "Notification access is required for prayer reminders. Please enable notifications in Settings."
        case .configurationMissing:
            return "App configuration is missing. Please restart the app or contact support."
        case .serviceUnavailable(let service):
            return "\(service) is currently unavailable. Please try again later."
        case .unknownError(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    public var actionTitle: String? {
        switch self {
        case .networkUnavailable, .networkTimeout, .serverError, .dataCorrupted, .serviceUnavailable:
            return "Retry"
        case .locationPermissionDenied, .notificationPermissionDenied:
            return "Open Settings"
        case .locationUnavailable, .configurationMissing, .unknownError:
            return "OK"
        }
    }
    
    public var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .networkTimeout, .serverError, .dataCorrupted, .serviceUnavailable:
            return true
        case .locationUnavailable, .locationPermissionDenied, .notificationPermissionDenied, .configurationMissing, .unknownError:
            return false
        }
    }
    
    public var severity: ErrorSeverity {
        switch self {
        case .networkUnavailable, .networkTimeout:
            return .medium
        case .serverError, .dataCorrupted, .serviceUnavailable:
            return .high
        case .locationUnavailable, .locationPermissionDenied, .notificationPermissionDenied:
            return .medium
        case .configurationMissing, .unknownError:
            return .critical
        }
    }
    
    // MARK: RetryableError
    
    public var maxRetryAttempts: Int {
        switch self {
        case .networkUnavailable, .networkTimeout:
            return 3
        case .serverError:
            return 2
        case .dataCorrupted, .serviceUnavailable:
            return 1
        default:
            return 0
        }
    }
    
    public var retryDelay: TimeInterval {
        switch self {
        case .networkUnavailable, .networkTimeout:
            return 2.0
        case .serverError:
            return 5.0
        case .dataCorrupted, .serviceUnavailable:
            return 1.0
        default:
            return 0.0
        }
    }
    
    public var shouldRetry: Bool {
        return isRetryable && maxRetryAttempts > 0
    }
    
    // MARK: LocalizedError
    
    public var errorDescription: String? {
        return message
    }
}

// MARK: - Error Handler

@MainActor
public class ErrorHandler: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var currentError: UserPresentableError?
    @Published public var isShowingError = false
    
    // MARK: - Private Properties
    
    private let crashReporter: CrashReporter
    private var retryAttempts: [String: Int] = [:]
    
    public init(crashReporter: CrashReporter) {
        self.crashReporter = crashReporter
    }
    
    // MARK: - Public Methods
    
    /// Handle any error and determine appropriate action
    public func handleError(_ error: Error) {
        let appError = convertToAppError(error)
        
        // Log error for debugging
        print("🚨 Error handled: \(appError)")
        
        // Report to crash reporting if severe enough
        if appError.severity.shouldReportToCrashlytics {
            crashReporter.recordError(appError)
        }
        
        // Present to user if it's user-presentable
        if let presentableError = error as? UserPresentableError {
            presentError(presentableError)
        } else {
            presentError(appError)
        }
    }
    
    /// Present error to user
    public func presentError(_ error: UserPresentableError) {
        currentError = error
        isShowingError = true
    }
    
    /// Dismiss current error
    public func dismissError() {
        currentError = nil
        isShowingError = false
    }
    
    /// Retry an operation with automatic retry logic
    public func retryOperation<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T,
        errorKey: String = UUID().uuidString
    ) async throws -> T {
        let maxAttempts = 3
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                let result = try await operation()
                // Reset retry count on success
                retryAttempts[errorKey] = 0
                return result
            } catch {
                lastError = error
                
                // Check if error is retryable
                if let retryableError = error as? RetryableError,
                   retryableError.shouldRetry,
                   attempt < maxAttempts {
                    
                    print("🔄 Retrying operation (attempt \(attempt)/\(maxAttempts))")
                    
                    // Wait before retrying
                    try await Task.sleep(nanoseconds: UInt64(retryableError.retryDelay * 1_000_000_000))
                    continue
                } else {
                    // Not retryable or max attempts reached
                    break
                }
            }
        }
        
        // All retries failed, throw the last error
        throw lastError ?? AppError.unknownError(NSError(domain: "RetryFailed", code: -1))
    }
    
    // MARK: - Private Methods
    
    private func convertToAppError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        // Convert common errors to AppError
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkUnavailable
            case .timedOut:
                return .networkTimeout
            default:
                return .unknownError(error)
            }
        }
        
        return .unknownError(error)
    }
}

// MARK: - Crash Reporter

public class CrashReporter {
    
    private let userDefaults = UserDefaults.standard
    private let crashLogKey = "DeenAssist.CrashLogs"
    
    public init() {}
    
    /// Record an error for crash reporting
    public func recordError(_ error: Error) {
        let crashLog = CrashLog(
            error: error,
            timestamp: Date(),
            severity: (error as? UserPresentableError)?.severity ?? .medium
        )
        
        saveCrashLog(crashLog)
        
        // In a real implementation, this would send to Firebase Crashlytics
        print("📊 Crash reported: \(crashLog)")
    }
    
    /// Record a custom event
    public func recordEvent(_ event: String, parameters: [String: Any] = [:]) {
        print("📊 Event recorded: \(event) with parameters: \(parameters)")
        // In a real implementation, this would send to analytics service
    }
    
    /// Get stored crash logs
    public func getCrashLogs() -> [CrashLog] {
        guard let data = userDefaults.data(forKey: crashLogKey),
              let logs = try? JSONDecoder().decode([CrashLog].self, from: data) else {
            return []
        }
        return logs
    }
    
    /// Clear crash logs
    public func clearCrashLogs() {
        userDefaults.removeObject(forKey: crashLogKey)
    }
    
    private func saveCrashLog(_ log: CrashLog) {
        var logs = getCrashLogs()
        logs.append(log)
        
        // Keep only last 50 logs
        if logs.count > 50 {
            logs = Array(logs.suffix(50))
        }
        
        if let data = try? JSONEncoder().encode(logs) {
            userDefaults.set(data, forKey: crashLogKey)
        }
    }
}

// MARK: - Crash Log

public struct CrashLog: Codable {
    public let id: String
    public let errorDescription: String
    public let timestamp: Date
    public let severity: ErrorSeverity
    
    public init(error: Error, timestamp: Date, severity: ErrorSeverity) {
        self.id = UUID().uuidString
        self.errorDescription = error.localizedDescription
        self.timestamp = timestamp
        self.severity = severity
    }
}
