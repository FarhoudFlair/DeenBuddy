//
//  CachePerformanceTests.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-11.
//

import XCTest
import Combine
import CoreLocation
@testable import DeenAssistCore

/// Performance tests for cache operations and prayer time synchronization
class CachePerformanceTests: XCTestCase {
    
    // MARK: - Properties
    
    private var settingsService: MockSettingsService!
    private var locationService: MockLocationService!
    private var apiClient: MockAPIClient!
    private var prayerTimeService: PrayerTimeService!
    private var apiCache: APICache!
    private var islamicCacheManager: IslamicCacheManager!
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Create mock services
        settingsService = MockSettingsService()
        locationService = MockLocationService()
        apiClient = MockAPIClient()
        
        // Create cache systems
        apiCache = APICache()
        islamicCacheManager = IslamicCacheManager()
        
        // Create prayer time service
        prayerTimeService = PrayerTimeService(
            locationService: locationService,
            settingsService: settingsService,
            apiClient: apiClient,
            errorHandler: ErrorHandler(crashReporter: CrashReporter()),
            retryMechanism: RetryMechanism(networkMonitor: NetworkMonitor.shared),
            networkMonitor: NetworkMonitor.shared
        )
        
        // Set up test location
        locationService.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
    }
    
    override func tearDown() {
        cancellables.removeAll()
        apiCache.clearAllCache()
        islamicCacheManager.clearAllCache()
        
        settingsService = nil
        locationService = nil
        apiClient = nil
        prayerTimeService = nil
        apiCache = nil
        islamicCacheManager = nil
        
        super.tearDown()
    }
    
    // MARK: - Cache Operation Performance Tests
    
    func testAPICachePerformance() {
        let iterations = 1000
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        
        measure {
            for i in 0..<iterations {
                let prayerTimes = createMockPrayerTimes(for: date.addingTimeInterval(TimeInterval(i * 86400)), location: location, method: "muslim_world_league")
                
                // Test caching performance
                apiCache.cachePrayerTimes(prayerTimes, for: date.addingTimeInterval(TimeInterval(i * 86400)), location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
                
                // Test retrieval performance
                _ = apiCache.getCachedPrayerTimes(for: date.addingTimeInterval(TimeInterval(i * 86400)), location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
            }
        }
    }
    
    func testIslamicCacheManagerPerformance() {
        let iterations = 1000
        let date = Date()
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        measure {
            for i in 0..<iterations {
                let schedule = createMockPrayerSchedule(for: date.addingTimeInterval(TimeInterval(i * 86400)))
                
                // Test caching performance
                islamicCacheManager.cachePrayerSchedule(schedule, for: date.addingTimeInterval(TimeInterval(i * 86400)), location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
                
                // Test retrieval performance
                _ = islamicCacheManager.getCachedPrayerSchedule(for: date.addingTimeInterval(TimeInterval(i * 86400)), location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
            }
        }
    }
    
    func testCacheInvalidationPerformance() {
        // Pre-populate cache with data
        let iterations = 100
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let clLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        for i in 0..<iterations {
            let prayerTimes = createMockPrayerTimes(for: date.addingTimeInterval(TimeInterval(i * 86400)), location: location, method: "muslim_world_league")
            let schedule = createMockPrayerSchedule(for: date.addingTimeInterval(TimeInterval(i * 86400)))
            
            apiCache.cachePrayerTimes(prayerTimes, for: date.addingTimeInterval(TimeInterval(i * 86400)), location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
            islamicCacheManager.cachePrayerSchedule(schedule, for: date.addingTimeInterval(TimeInterval(i * 86400)), location: clLocation, calculationMethod: .muslimWorldLeague, madhab: .shafi)
        }
        
        // Test cache invalidation performance
        measure {
            apiCache.clearPrayerTimeCache()
            islamicCacheManager.clearPrayerTimeCache()
        }
    }
    
    // MARK: - Settings Synchronization Performance Tests
    
    func testSettingsSynchronizationPerformance() {
        let iterations = 100
        let methods: [CalculationMethod] = [.muslimWorldLeague, .egyptian, .karachi, .ummAlQura]
        let madhabs: [Madhab] = [.shafi, .hanafi]
        
        measure {
            for i in 0..<iterations {
                let method = methods[i % methods.count]
                let madhab = madhabs[i % madhabs.count]
                
                settingsService.calculationMethod = method
                settingsService.madhab = madhab
            }
        }
    }
    
    func testRapidSettingsChangesPerformance() {
        let iterations = 500
        
        measure {
            for i in 0..<iterations {
                let method: CalculationMethod = i % 2 == 0 ? .egyptian : .muslimWorldLeague
                let madhab: Madhab = i % 2 == 0 ? .hanafi : .shafi
                
                settingsService.calculationMethod = method
                settingsService.madhab = madhab
            }
        }
    }
    
    // MARK: - Prayer Time Calculation Performance Tests
    
    func testPrayerTimeCalculationPerformance() async {
        let iterations = 50
        
        await measure {
            for i in 0..<iterations {
                let method: CalculationMethod = i % 2 == 0 ? .egyptian : .muslimWorldLeague
                settingsService.calculationMethod = method
                
                await prayerTimeService.refreshPrayerTimes()
            }
        }
    }
    
    func testConcurrentSettingsChangesPerformance() async {
        let iterations = 20
        
        await measure {
            await withTaskGroup(of: Void.self) { group in
                for i in 0..<iterations {
                    group.addTask {
                        let method: CalculationMethod = i % 2 == 0 ? .egyptian : .muslimWorldLeague
                        await MainActor.run {
                            self.settingsService.calculationMethod = method
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Memory Usage Tests
    
    func testMemoryUsageUnderLoad() {
        let iterations = 1000
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        
        // Measure memory usage during heavy cache operations
        measure(metrics: [XCTMemoryMetric()]) {
            for i in 0..<iterations {
                let prayerTimes = createMockPrayerTimes(for: date.addingTimeInterval(TimeInterval(i * 86400)), location: location, method: "muslim_world_league")
                
                apiCache.cachePrayerTimes(prayerTimes, for: date.addingTimeInterval(TimeInterval(i * 86400)), location: location, calculationMethod: .muslimWorldLeague, madhab: .shafi)
                
                // Periodically clear cache to prevent excessive memory usage
                if i % 100 == 0 {
                    apiCache.clearExpiredCache()
                }
            }
        }
    }
    
    func testCacheKeyGenerationPerformance() {
        let iterations = 10000
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        
        measure {
            for i in 0..<iterations {
                let method: CalculationMethod = i % 2 == 0 ? .egyptian : .muslimWorldLeague
                let madhab: Madhab = i % 2 == 0 ? .hanafi : .shafi
                
                // This tests the performance of cache key generation with method and madhab
                let prayerTimes = createMockPrayerTimes(for: date, location: location, method: method.rawValue)
                apiCache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: method, madhab: madhab)
            }
        }
    }
    
    // MARK: - Background Performance Tests
    
    func testBackgroundServicePerformance() {
        let iterations = 100
        
        let backgroundTaskManager = BackgroundTaskManager(
            prayerTimeService: prayerTimeService,
            notificationService: MockNotificationService(),
            locationService: locationService
        )
        
        measure {
            for i in 0..<iterations {
                let method: CalculationMethod = i % 2 == 0 ? .egyptian : .muslimWorldLeague
                settingsService.calculationMethod = method
                
                // Simulate background task execution
                backgroundTaskManager.registerBackgroundTasks()
            }
        }
    }
    
    // MARK: - Stress Tests
    
    func testStressTestRapidSettingsChanges() {
        let iterations = 1000
        let methods: [CalculationMethod] = [.muslimWorldLeague, .egyptian, .karachi, .ummAlQura]
        let madhabs: [Madhab] = [.shafi, .hanafi]
        
        // This test ensures the system can handle rapid settings changes without performance degradation
        measure {
            for i in 0..<iterations {
                let method = methods[i % methods.count]
                let madhab = madhabs[i % madhabs.count]
                
                settingsService.calculationMethod = method
                settingsService.madhab = madhab
                
                // Simulate some processing time
                Thread.sleep(forTimeInterval: 0.001) // 1ms
            }
        }
    }
    
    func testCacheConsistencyUnderLoad() {
        let iterations = 500
        let date = Date()
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        
        measure {
            for i in 0..<iterations {
                let method: CalculationMethod = i % 2 == 0 ? .egyptian : .muslimWorldLeague
                let madhab: Madhab = i % 2 == 0 ? .hanafi : .shafi
                
                let prayerTimes = createMockPrayerTimes(for: date, location: location, method: method.rawValue)
                
                // Cache with different method/madhab combinations
                apiCache.cachePrayerTimes(prayerTimes, for: date, location: location, calculationMethod: method, madhab: madhab)
                
                // Retrieve to ensure consistency
                let cached = apiCache.getCachedPrayerTimes(for: date, location: location, calculationMethod: method, madhab: madhab)
                XCTAssertNotNil(cached, "Cache should be consistent under load")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockPrayerTimes(for date: Date, location: LocationCoordinate, method: String) -> PrayerTimes {
        return PrayerTimes(
            date: date,
            location: location,
            fajr: date.addingTimeInterval(5 * 3600),
            sunrise: date.addingTimeInterval(6 * 3600),
            dhuhr: date.addingTimeInterval(12 * 3600),
            asr: date.addingTimeInterval(15 * 3600),
            maghrib: date.addingTimeInterval(18 * 3600),
            isha: date.addingTimeInterval(19 * 3600),
            calculationMethod: method,
            madhab: "shafi"
        )
    }
    
    private func createMockPrayerSchedule(for date: Date) -> PrayerSchedule {
        return PrayerSchedule(
            date: date,
            prayers: [
                Prayer(name: .fajr, time: date.addingTimeInterval(5 * 3600)),
                Prayer(name: .dhuhr, time: date.addingTimeInterval(12 * 3600)),
                Prayer(name: .asr, time: date.addingTimeInterval(15 * 3600)),
                Prayer(name: .maghrib, time: date.addingTimeInterval(18 * 3600)),
                Prayer(name: .isha, time: date.addingTimeInterval(19 * 3600))
            ]
        )
    }
}
