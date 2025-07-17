import Foundation
import CoreLocation
import Combine

/// Example service demonstrating the benefits of BaseService and SharedUtilities
/// This shows how code duplication is reduced compared to the original service implementations
@MainActor
public class ExampleRefactoredService: BaseService {
    
    // MARK: - Published Properties
    
    @Published public var data: [String] = []
    @Published public var location: CLLocation?
    
    // MARK: - Initialization
    
    public init() {
        super.init(
            serviceName: "ExampleRefactoredService",
            configuration: BaseService.ServiceConfiguration(
                enableLogging: true,
                enableRetry: true,
                defaultTimeout: 30.0,
                maxConcurrentOperations: 3,
                cacheEnabled: true
            )
        )
        
        setupPeriodicDataRefresh()
        start()
    }
    
    // MARK: - Public Methods
    
    /// Load data with proper error handling and caching
    public func loadData() async {
        do {
            try await SharedUtilities.measureExecutionTime({
                try await self.executeOperation({
                // Check cache first
                if let cachedData = self.retrieveFromCache([String].self, key: "data", type: .temporaryData) {
                    await MainActor.run {
                        self.data = cachedData
                    }
                    return
                }
                
                // Simulate network operation
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                let newData = ["Item 1", "Item 2", "Item 3"]
                
                // Store in cache
                self.storeInCache(newData, key: "data", type: .temporaryData, expiry: 300) // 5 minutes
                
                await MainActor.run {
                    self.data = newData
                }
            }, operationName: "loadData")
            }, label: "ExampleService.loadData")
        } catch {
            logger.error("Failed to load data: \(error.localizedDescription)")
        }
    }
    
    /// Get location with validation and caching
    public func getCurrentLocation() async throws -> CLLocation {
        return try await executeOperation({
            // Check cache first using UnifiedCacheManager convenience method
            if let cachedLocation = self.cacheManager.retrieveLocation(forKey: "current") {
                return cachedLocation
            }
            
            // Simulate location retrieval
            let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // San Francisco
            
            guard SharedUtilities.isValidCoordinate(coordinate) else {
                throw ServiceError.configurationError("Invalid coordinate")
            }
            
            let newLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            // Store in cache using UnifiedCacheManager convenience method
            self.cacheManager.storeLocation(newLocation, forKey: "current")
            
            await MainActor.run {
                self.location = newLocation
            }
            
            return newLocation
        }, operationName: "getCurrentLocation")
    }
    
    /// Format data for display using SharedUtilities
    public func getFormattedData() -> String {
        let timestamp = SharedUtilities.sharedDateFormatters.shortTime.string(from: Date())
        let itemCount = data.count
        
        if let location = location {
            let locationKey = SharedUtilities.createLocationCacheKey(for: location.coordinate)
            return "Data (\(itemCount) items) at \(timestamp) from location \(locationKey)"
        } else {
            return "Data (\(itemCount) items) at \(timestamp)"
        }
    }
    
    /// Validate input using SharedUtilities
    public func validateAndProcessInput(_ input: String) -> Bool {
        // Trim whitespace
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if empty
        guard !trimmed.isEmpty else { return false }
        
        // Check for Arabic content if needed
        if SharedUtilities.containsArabic(trimmed) {
            // Format for RTL display
            let formatted = SharedUtilities.formatArabicText(trimmed)
            logger.info("Processed Arabic text: \(formatted)")
        }
        
        return true
    }
    
    // MARK: - Private Methods
    
    /// Setup periodic data refresh using BaseService utilities
    private func setupPeriodicDataRefresh() {
        schedulePeriodicOperation({
            await self.loadDataSafely()
        }, timerType: .backgroundRefresh, operationName: "periodicDataRefresh")
    }
    
    /// Safe data loading operation
    private func loadDataSafely() async {
        safeAsyncOperation({
            await self.loadData()
        }, operationName: "safeDataLoad")
    }
}

// MARK: - Comparison with Original Pattern

/*
 BEFORE (Original Service Pattern):
 
 public class OriginalService: ObservableObject {
     @Published var isLoading: Bool = false
     @Published var error: Error? = nil
     @Published var data: [String] = []
     
     private var cancellables = Set<AnyCancellable>()
     private var timer: Timer?
     private let userDefaults = UserDefaults.standard
     
     func loadData() async {
         isLoading = true
         error = nil
         
         do {
             // Duplicate error handling code
             let result = try await performOperation()
             data = result
             error = nil
         } catch {
             self.error = error
             // Duplicate error logging
         }
         
         isLoading = false
     }
     
     private func performOperation() async throws -> [String] {
         // Duplicate timeout handling
         // Duplicate retry logic
         // Duplicate caching logic
         // etc.
     }
     
     deinit {
         timer?.invalidate()
         // Manual cleanup
     }
 }
 
 AFTER (BaseService Pattern):
 
 public class RefactoredService: BaseService {
     @Published var data: [String] = []
     
     func loadData() async {
         await executeOperation({
             // Focus on business logic only
             let result = await performOperation()
             await MainActor.run {
                 self.data = result
             }
         }, operationName: "loadData")
     }
 }
 
 BENEFITS:
 1. ✅ Automatic loading state management
 2. ✅ Consistent error handling and logging
 3. ✅ Built-in retry mechanism
 4. ✅ Automatic resource cleanup
 5. ✅ Battery-aware timer management
 6. ✅ Unified caching system
 7. ✅ Shared utility functions
 8. ✅ Consistent service health monitoring
 9. ✅ Reduced boilerplate code by ~60%
 10. ✅ Better testability through protocol injection
 */