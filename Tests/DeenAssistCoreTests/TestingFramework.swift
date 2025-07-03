import XCTest
import Combine
import CoreLocation
@testable import DeenAssistCore
@testable import DeenAssistProtocols

/// Comprehensive testing framework for DeenAssist
public class DeenAssistTestFramework {
    
    // MARK: - Test Utilities
    
    /// Create test dependency container
    public static func createTestContainer() -> DependencyContainer {
        return DependencyContainer.createForTesting(
            locationService: MockLocationService(),
            apiClient: MockAPIClient(),
            notificationService: MockNotificationService(),
            prayerTimeService: MockPrayerTimeService(),
            settingsService: MockSettingsService()
        )
    }
    
    /// Create test configuration
    public static func createTestConfiguration() -> AppConfiguration {
        return AppConfiguration(
            environment: .testing,
            supabase: SupabaseConfiguration(
                url: "https://test.supabase.co",
                anonKey: "test-key"
            ),
            api: APIConfiguration(
                baseURL: "https://api.test.com",
                timeout: 5,
                maxRetries: 1,
                rateLimitPerMinute: 1000
            ),
            features: FeatureFlags(
                enableAnalytics: false,
                enableCrashReporting: false,
                enableBetaFeatures: true,
                enableOfflineMode: true
            ),
            logging: LoggingConfiguration(
                level: .debug,
                enableFileLogging: false,
                enableRemoteLogging: false
            )
        )
    }
    
    /// Wait for async operation with timeout
    public static func waitForAsync<T>(
        timeout: TimeInterval = 5.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TestError.timeout
            }
            
            guard let result = try await group.next() else {
                throw TestError.timeout
            }
            
            group.cancelAll()
            return result
        }
    }
    
    /// Assert that async operation throws specific error
    public static func assertThrowsAsync<T>(
        _ operation: @escaping () async throws -> T,
        expectedError: Error,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            _ = try await operation()
            XCTFail("Expected operation to throw error", file: file, line: line)
        } catch {
            XCTAssertEqual(
                String(describing: error),
                String(describing: expectedError),
                "Expected different error",
                file: file,
                line: line
            )
        }
    }
    
    /// Create test location
    public static func createTestLocation(
        latitude: Double = 37.7749,
        longitude: Double = -122.4194
    ) -> LocationInfo {
        return LocationInfo(
            coordinate: LocationCoordinate(latitude: latitude, longitude: longitude),
            address: "Test Address",
            city: "Test City",
            country: "Test Country",
            timestamp: Date()
        )
    }
    
    /// Create test prayer times
    public static func createTestPrayerTimes(for date: Date = Date()) -> [PrayerTime] {
        let calendar = Calendar.current
        let baseDate = calendar.startOfDay(for: date)
        
        return [
            PrayerTime(prayer: .fajr, time: calendar.date(byAdding: .hour, value: 5, to: baseDate)!),
            PrayerTime(prayer: .dhuhr, time: calendar.date(byAdding: .hour, value: 12, to: baseDate)!),
            PrayerTime(prayer: .asr, time: calendar.date(byAdding: .hour, value: 15, to: baseDate)!),
            PrayerTime(prayer: .maghrib, time: calendar.date(byAdding: .hour, value: 18, to: baseDate)!),
            PrayerTime(prayer: .isha, time: calendar.date(byAdding: .hour, value: 20, to: baseDate)!)
        ]
    }
}

// MARK: - Test Error

public enum TestError: Error, LocalizedError {
    case timeout
    case invalidTestData
    case mockServiceError
    
    public var errorDescription: String? {
        switch self {
        case .timeout:
            return "Test operation timed out"
        case .invalidTestData:
            return "Invalid test data provided"
        case .mockServiceError:
            return "Mock service error"
        }
    }
}

// MARK: - Performance Testing

public class PerformanceTestSuite {
    
    /// Test prayer time calculation performance
    public static func testPrayerTimeCalculationPerformance() {
        let location = DeenAssistTestFramework.createTestLocation()
        let clLocation = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let service = PrayerTimeService(locationService: MockLocationService())
        
        measure {
            let expectation = XCTestExpectation(description: "Prayer time calculation")
            
            Task {
                do {
                    _ = try await service.calculatePrayerTimes(
                        for: clLocation,
                        date: Date()
                    )
                    expectation.fulfill()
                } catch {
                    XCTFail("Prayer time calculation failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            // Wait for async operation to complete
            let result = XCTWaiter.wait(for: [expectation], timeout: 10.0)
            XCTAssertEqual(result, .completed, "Prayer time calculation should complete within timeout")
        }
    }
    
    /// Test Qibla direction calculation performance
    public static func testQiblaCalculationPerformance() {
        let location = DeenAssistTestFramework.createTestLocation()
        
        measure {
            _ = QiblaDirection.calculate(from: location.coordinate)
        }
    }
    
    /// Test memory usage during operations
    public static func testMemoryUsage() {
        let memoryManager = MemoryManager.shared
        let initialMemory = memoryManager.currentMemoryUsage.usedMemory
        
        // Perform memory-intensive operations
        var data: [Data] = []
        for _ in 0..<1000 {
            data.append(Data(count: 1024)) // 1KB each
        }
        
        let finalMemory = memoryManager.currentMemoryUsage.usedMemory
        let memoryIncrease = finalMemory - initialMemory
        
        // Should not increase by more than 10MB
        XCTAssertLessThan(memoryIncrease, 10 * 1024 * 1024, "Memory usage increased too much")
        
        // Clean up
        data.removeAll()
    }
    
    private static func measure(_ block: () -> Void) {
        let startTime = CFAbsoluteTimeGetCurrent()
        block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("⏱️ Performance test completed in \(timeElapsed) seconds")
    }
}

// MARK: - Integration Testing

public class IntegrationTestSuite {
    
    /// Test complete prayer time flow
    public static func testCompletePrayerTimeFlow() async throws {
        let container = DeenAssistTestFramework.createTestContainer()
        let location = DeenAssistTestFramework.createTestLocation()
        let clLocation = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        
        // Mock location service to return test location
        if let mockLocationService = container.locationService as? MockLocationService {
            mockLocationService.mockLocation = location
        }
        
        // Test prayer time calculation
        let prayerTimes = try await container.prayerTimeService.calculatePrayerTimes(
            for: clLocation,
            date: Date()
        )
        
        XCTAssertEqual(prayerTimes.count, 5, "Should return 5 prayer times")
        XCTAssertTrue(prayerTimes.allSatisfy { $0.time > Date().addingTimeInterval(-86400) }, "All prayer times should be recent")
    }
    
    /// Test error handling flow
    public static func testErrorHandlingFlow() async {
        let errorHandler = ErrorHandler.shared
        let testError = AppError.networkUnavailable
        
        // Test error handling
        errorHandler.handleError(testError)
        
        XCTAssertTrue(errorHandler.isShowingError, "Should show error")
        XCTAssertEqual(errorHandler.currentError?.title, testError.title, "Should show correct error")
        
        // Test error dismissal
        errorHandler.dismissError()
        
        XCTAssertFalse(errorHandler.isShowingError, "Should dismiss error")
        XCTAssertNil(errorHandler.currentError, "Should clear current error")
    }
    
    /// Test offline functionality
    public static func testOfflineFunctionality() async {
        let networkMonitor = NetworkMonitor.shared
        let offlineManager = OfflineManager.shared
        
        // Simulate offline state
        offlineManager.enableOfflineMode()
        
        XCTAssertTrue(offlineManager.isOfflineMode, "Should be in offline mode")
        XCTAssertTrue(offlineManager.isAvailableOffline(.prayerTimes), "Prayer times should be available offline")
        XCTAssertTrue(offlineManager.isAvailableOffline(.qiblaDirection), "Qibla direction should be available offline")
    }
}

// MARK: - Accessibility Testing

public class AccessibilityTestSuite {
    
    /// Test VoiceOver compatibility
    public static func testVoiceOverCompatibility() {
        let accessibilityService = AccessibilityService.shared
        
        // Test accessibility labels
        let prayerLabel = AccessibilityHelpers.prayerTimeLabel(prayer: .fajr, time: Date())
        XCTAssertFalse(prayerLabel.isEmpty, "Prayer time label should not be empty")
        XCTAssertTrue(prayerLabel.contains("Fajr"), "Prayer label should contain prayer name")
        
        // Test Qibla accessibility
        let qiblaLabel = AccessibilityHelpers.qiblaDirectionLabel(direction: 45.0, distance: 1000.0)
        XCTAssertFalse(qiblaLabel.isEmpty, "Qibla label should not be empty")
        XCTAssertTrue(qiblaLabel.contains("direction"), "Qibla label should contain direction info")
    }
    
    /// Test dynamic type support
    public static func testDynamicTypeSupport() {
        let accessibilityService = AccessibilityService.shared
        
        // Test font size multipliers
        XCTAssertGreaterThan(accessibilityService.fontSizeMultiplier, 0, "Font size multiplier should be positive")
        XCTAssertLessThan(accessibilityService.fontSizeMultiplier, 5, "Font size multiplier should be reasonable")
    }
    
    /// Test reduce motion support
    public static func testReduceMotionSupport() {
        let accessibilityService = AccessibilityService.shared
        
        // Test animation duration adjustment
        let normalDuration = 0.3
        let adjustedDuration = accessibilityService.getAnimationDuration(normalDuration)
        
        if accessibilityService.isReduceMotionEnabled {
            XCTAssertEqual(adjustedDuration, 0.0, "Should disable animations when reduce motion is enabled")
        } else {
            XCTAssertEqual(adjustedDuration, normalDuration, "Should use normal duration when reduce motion is disabled")
        }
    }
}

// MARK: - Localization Testing

public class LocalizationTestSuite {
    
    /// Test language switching
    public static func testLanguageSwitching() {
        let localizationService = LocalizationService.shared
        let originalLanguage = localizationService.currentLanguage
        
        // Test switching to Arabic
        localizationService.setLanguage(.arabic)
        XCTAssertEqual(localizationService.currentLanguage, .arabic, "Should switch to Arabic")
        XCTAssertTrue(localizationService.isRTLLanguage, "Arabic should be RTL")
        
        // Test switching back
        localizationService.setLanguage(originalLanguage)
        XCTAssertEqual(localizationService.currentLanguage, originalLanguage, "Should switch back to original language")
    }
    
    /// Test RTL layout support
    public static func testRTLLayoutSupport() {
        let localizationService = LocalizationService.shared
        
        // Test RTL languages
        localizationService.setLanguage(.arabic)
        XCTAssertTrue(localizationService.isRTLLanguage, "Arabic should be RTL")
        
        localizationService.setLanguage(.urdu)
        XCTAssertTrue(localizationService.isRTLLanguage, "Urdu should be RTL")
        
        // Test LTR languages
        localizationService.setLanguage(.english)
        XCTAssertFalse(localizationService.isRTLLanguage, "English should be LTR")
    }
    
    /// Test date and number formatting
    public static func testDateAndNumberFormatting() {
        let localizationService = LocalizationService.shared
        let testDate = Date()
        let testNumber = NSNumber(value: 1234.56)
        
        // Test English formatting
        localizationService.setLanguage(.english)
        let englishDate = localizationService.formatDate(testDate)
        let englishNumber = localizationService.formatNumber(testNumber)
        
        XCTAssertFalse(englishDate.isEmpty, "English date should not be empty")
        XCTAssertFalse(englishNumber.isEmpty, "English number should not be empty")
        
        // Test Arabic formatting
        localizationService.setLanguage(.arabic)
        let arabicDate = localizationService.formatDate(testDate)
        let arabicNumber = localizationService.formatNumber(testNumber)
        
        XCTAssertFalse(arabicDate.isEmpty, "Arabic date should not be empty")
        XCTAssertFalse(arabicNumber.isEmpty, "Arabic number should not be empty")
    }
}
