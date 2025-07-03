import Foundation
import Combine

/// Service for handling automatic retry logic
@MainActor
public class RetryMechanism: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var activeRetries: [String: RetryOperation] = [:]
    @Published public var retryStatistics: RetryStatistics = RetryStatistics()
    
    // MARK: - Private Properties
    
    private let networkMonitor = NetworkMonitor.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Singleton
    
    public static let shared = RetryMechanism()
    
    private init() {
        setupNetworkObserver()
    }
    
    // MARK: - Public Methods
    
    /// Execute an operation with automatic retry logic
    public func executeWithRetry<T>(
        operation: @escaping () async throws -> T,
        retryPolicy: RetryPolicy = .default,
        operationId: String = UUID().uuidString
    ) async throws -> T {
        
        let retryOperation = RetryOperation(
            id: operationId,
            policy: retryPolicy,
            startTime: Date()
        )
        
        activeRetries[operationId] = retryOperation
        defer { activeRetries.removeValue(forKey: operationId) }
        
        var lastError: Error?
        
        for attempt in 1...retryPolicy.maxAttempts {
            do {
                let result = try await operation()
                
                // Update statistics on success
                retryStatistics.recordSuccess(attempts: attempt)
                
                // Log success
                if attempt > 1 {
                    print("✅ Operation succeeded on attempt \(attempt)/\(retryPolicy.maxAttempts)")
                }
                
                return result
                
            } catch {
                lastError = error
                
                // Update retry operation
                retryOperation.attempts = attempt
                retryOperation.lastError = error
                
                // Check if we should retry
                if attempt < retryPolicy.maxAttempts && shouldRetry(error: error, policy: retryPolicy) {
                    
                    let delay = calculateDelay(attempt: attempt, policy: retryPolicy, error: error)
                    
                    print("🔄 Retrying operation (attempt \(attempt)/\(retryPolicy.maxAttempts)) after \(delay)s delay")
                    
                    // Wait before retrying
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    
                    // Check if network is available for network-related errors
                    if isNetworkError(error) && !networkMonitor.isConnected {
                        print("⏳ Waiting for network connection...")
                        let connected = await networkMonitor.waitForConnection(timeout: retryPolicy.networkWaitTimeout)
                        if !connected {
                            print("❌ Network connection timeout")
                            break
                        }
                    }
                    
                    continue
                } else {
                    // No more retries or error is not retryable
                    break
                }
            }
        }
        
        // All retries failed
        retryStatistics.recordFailure(attempts: retryOperation.attempts)
        
        if let lastError = lastError {
            throw lastError
        } else {
            throw RetryError.maxAttemptsExceeded
        }
    }
    
    /// Execute operation with exponential backoff
    public func executeWithExponentialBackoff<T>(
        operation: @escaping () async throws -> T,
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        operationId: String = UUID().uuidString
    ) async throws -> T {
        
        let policy = RetryPolicy(
            maxAttempts: maxAttempts,
            baseDelay: baseDelay,
            maxDelay: maxDelay,
            backoffStrategy: .exponential,
            retryableErrors: [.networkError, .serverError, .timeout]
        )
        
        return try await executeWithRetry(
            operation: operation,
            retryPolicy: policy,
            operationId: operationId
        )
    }
    
    /// Cancel a specific retry operation
    public func cancelRetry(operationId: String) {
        activeRetries.removeValue(forKey: operationId)
        print("❌ Retry operation cancelled: \(operationId)")
    }
    
    /// Cancel all active retries
    public func cancelAllRetries() {
        activeRetries.removeAll()
        print("❌ All retry operations cancelled")
    }
    
    /// Get retry statistics
    public func getStatistics() -> RetryStatistics {
        return retryStatistics
    }
    
    /// Reset retry statistics
    public func resetStatistics() {
        retryStatistics = RetryStatistics()
    }
    
    // MARK: - Private Methods
    
    private func shouldRetry(error: Error, policy: RetryPolicy) -> Bool {
        let errorType = classifyError(error)
        return policy.retryableErrors.contains(errorType)
    }
    
    private func calculateDelay(attempt: Int, policy: RetryPolicy, error: Error) -> TimeInterval {
        switch policy.backoffStrategy {
        case .fixed:
            return policy.baseDelay
            
        case .linear:
            return policy.baseDelay * TimeInterval(attempt)
            
        case .exponential:
            let delay = policy.baseDelay * pow(2.0, TimeInterval(attempt - 1))
            return min(delay, policy.maxDelay)
            
        case .exponentialWithJitter:
            let exponentialDelay = policy.baseDelay * pow(2.0, TimeInterval(attempt - 1))
            let jitter = TimeInterval.random(in: 0...1) * exponentialDelay * 0.1
            let delay = exponentialDelay + jitter
            return min(delay, policy.maxDelay)
        }
    }
    
    private func classifyError(_ error: Error) -> RetryableErrorType {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError
            case .timedOut:
                return .timeout
            case .cannotFindHost, .cannotConnectToHost:
                return .serverError
            default:
                return .unknown
            }
        }
        
        if let appError = error as? AppError {
            switch appError {
            case .networkUnavailable, .networkTimeout:
                return .networkError
            case .serverError:
                return .serverError
            case .serviceUnavailable:
                return .serverError
            default:
                return .unknown
            }
        }
        
        return .unknown
    }
    
    private func isNetworkError(_ error: Error) -> Bool {
        return classifyError(error) == .networkError
    }
    
    private func setupNetworkObserver() {
        networkMonitor.$isConnected
            .sink { [weak self] isConnected in
                if isConnected {
                    print("🌐 Network reconnected - retries may resume")
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Retry Policy

public struct RetryPolicy {
    public let maxAttempts: Int
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let backoffStrategy: BackoffStrategy
    public let retryableErrors: [RetryableErrorType]
    public let networkWaitTimeout: TimeInterval
    
    public init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        backoffStrategy: BackoffStrategy = .exponential,
        retryableErrors: [RetryableErrorType] = [.networkError, .serverError, .timeout],
        networkWaitTimeout: TimeInterval = 30.0
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.backoffStrategy = backoffStrategy
        self.retryableErrors = retryableErrors
        self.networkWaitTimeout = networkWaitTimeout
    }
    
    public static let `default` = RetryPolicy()
    
    public static let aggressive = RetryPolicy(
        maxAttempts: 5,
        baseDelay: 0.5,
        maxDelay: 60.0,
        backoffStrategy: .exponentialWithJitter
    )
    
    public static let conservative = RetryPolicy(
        maxAttempts: 2,
        baseDelay: 2.0,
        maxDelay: 10.0,
        backoffStrategy: .fixed
    )
    
    public static let networkOnly = RetryPolicy(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 15.0,
        backoffStrategy: .exponential,
        retryableErrors: [.networkError]
    )
}

// MARK: - Backoff Strategy

public enum BackoffStrategy {
    case fixed
    case linear
    case exponential
    case exponentialWithJitter
}

// MARK: - Retryable Error Type

public enum RetryableErrorType {
    case networkError
    case serverError
    case timeout
    case unknown
}

// MARK: - Retry Operation

public class RetryOperation: ObservableObject {
    public let id: String
    public let policy: RetryPolicy
    public let startTime: Date
    
    @Published public var attempts: Int = 0
    @Published public var lastError: Error?
    
    public init(id: String, policy: RetryPolicy, startTime: Date) {
        self.id = id
        self.policy = policy
        self.startTime = startTime
    }
    
    public var duration: TimeInterval {
        return Date().timeIntervalSince(startTime)
    }
    
    public var isActive: Bool {
        return attempts < policy.maxAttempts
    }
}

// MARK: - Retry Statistics

public struct RetryStatistics {
    public var totalOperations: Int = 0
    public var successfulOperations: Int = 0
    public var failedOperations: Int = 0
    public var totalRetries: Int = 0
    public var averageAttemptsToSuccess: Double = 0.0
    
    public mutating func recordSuccess(attempts: Int) {
        totalOperations += 1
        successfulOperations += 1
        totalRetries += (attempts - 1)
        
        // Update average
        let totalAttempts = successfulOperations + totalRetries
        averageAttemptsToSuccess = Double(totalAttempts) / Double(successfulOperations)
    }
    
    public mutating func recordFailure(attempts: Int) {
        totalOperations += 1
        failedOperations += 1
        totalRetries += attempts
    }
    
    public var successRate: Double {
        guard totalOperations > 0 else { return 0.0 }
        return Double(successfulOperations) / Double(totalOperations)
    }
    
    public var retryRate: Double {
        guard totalOperations > 0 else { return 0.0 }
        return Double(totalRetries) / Double(totalOperations)
    }
}

// MARK: - Retry Error

public enum RetryError: LocalizedError {
    case maxAttemptsExceeded
    case operationCancelled
    case networkTimeout
    
    public var errorDescription: String? {
        switch self {
        case .maxAttemptsExceeded:
            return "Maximum retry attempts exceeded"
        case .operationCancelled:
            return "Retry operation was cancelled"
        case .networkTimeout:
            return "Network connection timeout during retry"
        }
    }
}
