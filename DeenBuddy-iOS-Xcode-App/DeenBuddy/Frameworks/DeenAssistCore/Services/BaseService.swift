import Foundation
import Combine
import UIKit
import os.log

/// Base service class that provides common functionality for all DeenBuddy services
/// Reduces code duplication and ensures consistent behavior across services
@MainActor
open class BaseService: ObservableObject {
    
    // MARK: - Common Properties
    
    /// Loading state
    @Published public var isLoading: Bool = false
    
    /// Error state
    @Published public var error: Error? = nil
    
    /// Last successful operation timestamp
    @Published public var lastSuccessfulOperation: Date?
    
    /// Service health status
    @Published public var isHealthy: Bool = true
    
    // MARK: - Internal Properties
    
    /// Service name for logging and debugging
    internal let serviceName: String
    
    /// Logger instance
    internal let logger: Logger
    
    /// Combine cancellables storage
    internal var cancellables = Set<AnyCancellable>()
    
    /// Unified cache manager
    internal let cacheManager: UnifiedCacheManager
    
    /// Timer manager for battery-aware operations
    internal let timerManager: BatteryAwareTimerManager
    
    /// Current operation tasks for cleanup
    internal var currentTasks: [String: Task<Void, Never>] = [:]
    
    // MARK: - Configuration
    
    /// Service configuration
    public struct ServiceConfiguration {
        public let enableLogging: Bool
        public let enableRetry: Bool
        public let defaultTimeout: TimeInterval
        public let maxConcurrentOperations: Int
        public let cacheEnabled: Bool
        
        public init(
            enableLogging: Bool = true,
            enableRetry: Bool = true,
            defaultTimeout: TimeInterval = 30.0,
            maxConcurrentOperations: Int = 5,
            cacheEnabled: Bool = true
        ) {
            self.enableLogging = enableLogging
            self.enableRetry = enableRetry
            self.defaultTimeout = defaultTimeout
            self.maxConcurrentOperations = maxConcurrentOperations
            self.cacheEnabled = cacheEnabled
        }
    }
    
    internal let configuration: ServiceConfiguration
    
    // MARK: - Initialization
    
    /// Initialize base service
    /// - Parameters:
    ///   - serviceName: Name of the service for logging
    ///   - configuration: Service configuration
    public init(
        serviceName: String,
        configuration: ServiceConfiguration = ServiceConfiguration()
    ) {
        self.serviceName = serviceName
        self.configuration = configuration
        self.logger = Logger(subsystem: "com.deenbuddy.app", category: serviceName)
        self.cacheManager = UnifiedCacheManager.shared
        self.timerManager = BatteryAwareTimerManager.shared
        
        setupHealthMonitoring()
        
        if configuration.enableLogging {
            logger.info("✅ \(self.serviceName) initialized successfully")
        }
    }
    
    deinit {
        // Cleanup synchronously without await
        MainActor.assumeIsolated {
            syncCleanup()
        }
        
        if configuration.enableLogging {
            logger.info("🧹 \(self.serviceName) deinitialized")
        }
    }
    
    // MARK: - Public Methods
    
    /// Start the service
    open func start() {
        logger.info("🚀 Starting \(self.serviceName)")
        isHealthy = true
        lastSuccessfulOperation = Date()
    }
    
    /// Stop the service
    open func stop() {
        logger.info("🛑 Stopping \(self.serviceName)")
        cleanup()
    }
    
    /// Perform health check
    open func healthCheck() -> Bool {
        return isHealthy && !isLoading
    }
    
    /// Get service status
    public func getStatus() -> ServiceStatus {
        return ServiceStatus(
            serviceName: serviceName,
            isHealthy: isHealthy,
            isLoading: isLoading,
            lastError: error,
            lastSuccessfulOperation: lastSuccessfulOperation,
            activeTasks: currentTasks.count
        )
    }
    
    // MARK: - Internal Methods
    
    /// Execute operation with common patterns (loading, error handling, retry)
    /// - Parameters:
    ///   - operation: The operation to execute
    ///   - operationName: Name for logging and task tracking
    ///   - enableRetry: Whether to enable retry mechanism
    /// - Returns: Result of the operation
    internal func executeOperation<T>(
        _ operation: @escaping () async throws -> T,
        operationName: String,
        enableRetry: Bool = true
    ) async throws -> T {
        
        guard currentTasks.count < configuration.maxConcurrentOperations else {
            throw ServiceError.tooManyOperations
        }
        
        let taskId = "\(operationName)-\(UUID().uuidString.prefix(8))"
        
        // Start operation
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        // Create task for cleanup tracking
        let task = Task {
            defer {
                Task { @MainActor in
                    self.currentTasks.removeValue(forKey: taskId)
                    self.isLoading = self.currentTasks.isEmpty ? false : self.isLoading
                }
            }
        }
        
        currentTasks[taskId] = task
        
        do {
            let result: T
            
            if enableRetry && configuration.enableRetry {
                // Simplified retry mechanism - retry once on failure
                result = try await performWithSimpleRetry(operation: operation)
            } else {
                result = try await operation()
            }
            
            // Success
            await MainActor.run {
                self.lastSuccessfulOperation = Date()
                self.isHealthy = true
                self.error = nil
            }
            
            if configuration.enableLogging {
                logger.info("✅ \(operationName) completed successfully")
            }
            
            return result
            
        } catch {
            // Error handling
            let serviceError = convertToServiceError(error)
            
            await MainActor.run {
                self.error = serviceError
                self.isHealthy = false
            }
            
            if configuration.enableLogging {
                logger.error("❌ \(operationName) failed: \(error.localizedDescription)")
            }
            
            throw serviceError
        }
    }
    
    /// Safe async operation wrapper
    /// - Parameters:
    ///   - operation: The operation to execute
    ///   - operationName: Name for logging
    internal func safeAsyncOperation(
        _ operation: @escaping () async -> Void,
        operationName: String
    ) {
        Task {
            do {
                try await executeOperation({
                    await operation()
                }, operationName: operationName, enableRetry: false)
            } catch {
                logger.error("🔥 Safe async operation '\(operationName)' failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Schedule periodic operation
    /// - Parameters:
    ///   - operation: The operation to execute
    ///   - timerType: Timer type for battery awareness
    ///   - operationName: Name for logging
    internal func schedulePeriodicOperation(
        _ operation: @escaping () async -> Void,
        timerType: BatteryAwareTimerManager.TimerType,
        operationName: String
    ) {
        let timerId = "\(serviceName)-\(operationName)"
        
        timerManager.scheduleTimer(id: timerId, type: timerType) { [weak self] in
            self?.safeAsyncOperation(operation, operationName: operationName)
        }
    }
    
    /// Cancel periodic operation
    /// - Parameter operationName: Name of the operation to cancel
    internal func cancelPeriodicOperation(_ operationName: String) {
        let timerId = "\(serviceName)-\(operationName)"
        timerManager.cancelTimer(id: timerId)
    }
    
    /// Store data in cache with service-specific key
    /// - Parameters:
    ///   - data: Data to cache
    ///   - key: Cache key
    ///   - type: Cache type
    ///   - expiry: Custom expiry time
    internal func storeInCache<T: Codable>(
        _ data: T,
        key: String,
        type: UnifiedCacheManager.CacheType,
        expiry: TimeInterval? = nil
    ) {
        guard configuration.cacheEnabled else { return }
        
        let serviceKey = "\(serviceName)_\(key)"
        cacheManager.store(data, forKey: serviceKey, type: type, expiry: expiry)
    }
    
    /// Retrieve data from cache with service-specific key
    /// - Parameters:
    ///   - dataType: Type of data to retrieve
    ///   - key: Cache key
    ///   - type: Cache type
    /// - Returns: Cached data or nil
    internal func retrieveFromCache<T: Codable>(
        _ dataType: T.Type,
        key: String,
        type: UnifiedCacheManager.CacheType
    ) -> T? {
        guard configuration.cacheEnabled else { return nil }
        
        let serviceKey = "\(serviceName)_\(key)"
        return cacheManager.retrieve(dataType, forKey: serviceKey, cacheType: type)
    }
    
    /// Clear service-specific cache
    /// - Parameter type: Cache type to clear
    internal func clearServiceCache(type: UnifiedCacheManager.CacheType) {
        // Clear cache entries that start with service name
        // Implementation would filter by service name prefix
        let servicePrefix = "\(serviceName)_"
        cacheManager.clearCacheWithPrefix(servicePrefix, type: type)
    }
    
    /// Convert error to service-specific error
    /// - Parameter error: Original error
    /// - Returns: Service error
    internal func convertToServiceError(_ error: Error) -> ServiceError {
        if let serviceError = error as? ServiceError {
            return serviceError
        }
        
        // Map common errors to service errors
        if error is CancellationError {
            return ServiceError.operationCancelled
        }
        
        return ServiceError.unknownError(error)
    }
    
    // MARK: - Private Methods
    
    private func setupHealthMonitoring() {
        // Monitor for memory pressure
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleMemoryPressure()
            }
            .store(in: &cancellables)
    }
    
    private func handleMemoryPressure() {
        logger.warning("⚠️ Memory pressure detected in \(self.serviceName)")
        
        // Cancel non-essential operations
        let nonEssentialTasks = currentTasks.filter { $0.key.contains("background") || $0.key.contains("cache") }
        for (taskId, task) in nonEssentialTasks {
            task.cancel()
            currentTasks.removeValue(forKey: taskId)
        }
        
        // Clear temporary cache
        cacheManager.clearCache(for: .temporaryData)
    }
    
    private func cleanup() {
        // Cancel all tasks
        for (_, task) in currentTasks {
            task.cancel()
        }
        currentTasks.removeAll()
        
        // Cancel timers
        timerManager.cancelAllTimers()
        
        // Clear subscriptions
        cancellables.removeAll()
        
        logger.info("🧹 \(self.serviceName) cleanup completed")
    }
    
    /// Synchronous cleanup for deinit
    private func syncCleanup() {
        // Cancel all tasks synchronously
        for (_, task) in currentTasks {
            task.cancel()
        }
        currentTasks.removeAll()
        
        // Clear subscriptions
        cancellables.removeAll()
    }
    
    /// Simple retry mechanism
    private func performWithSimpleRetry<T>(
        operation: @escaping () async throws -> T,
        maxRetries: Int = 2
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    // Wait before retry
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 500_000_000)) // 0.5s, 1s
                }
            }
        }
        
        throw lastError ?? ServiceError.unknownError(NSError(domain: "BaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Retry failed"]))
    }
}

// MARK: - Supporting Types

/// Service status information
public struct ServiceStatus {
    public let serviceName: String
    public let isHealthy: Bool
    public let isLoading: Bool
    public let lastError: Error?
    public let lastSuccessfulOperation: Date?
    public let activeTasks: Int
    
    public var statusDescription: String {
        if isHealthy {
            return "✅ Healthy"
        } else if let error = lastError {
            return "❌ Error: \(error.localizedDescription)"
        } else {
            return "⚠️ Unhealthy"
        }
    }
}

/// Service-specific errors
public enum ServiceError: LocalizedError {
    case operationCancelled
    case tooManyOperations
    case configurationError(String)
    case unknownError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .operationCancelled:
            return "Operation was cancelled"
        case .tooManyOperations:
            return "Too many concurrent operations"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .unknownError(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - UnifiedCacheManager Extension

extension UnifiedCacheManager {
    /// Clear cache entries with a specific prefix
    /// - Parameters:
    ///   - prefix: Prefix to match
    ///   - type: Cache type
    internal func clearCacheWithPrefix(_ prefix: String, type: CacheType) {
        // Implementation would clear entries starting with the prefix
        // For now, this is a placeholder method
    }
}