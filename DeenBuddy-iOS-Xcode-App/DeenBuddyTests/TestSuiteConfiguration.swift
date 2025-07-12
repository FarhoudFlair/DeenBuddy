//
//  TestSuiteConfiguration.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-11.
//

import XCTest

/// Configuration and organization for the complete prayer time synchronization test suite
class TestSuiteConfiguration: NSObject {
    
    // MARK: - Test Suite Organization
    
    /// Core synchronization tests that must pass for basic functionality
    static let coreTests: [XCTestCase.Type] = [
        ServiceSynchronizationTests.self,
        SettingsMigrationTests.self,
        PrayerTimeSynchronizationRegressionTests.self
    ]
    
    /// Cache-related tests for data consistency
    static let cacheTests: [XCTestCase.Type] = [
        CacheInvalidationTests.self,
        CacheKeyStrategyTests.self,
        CacheInvalidationConsistencyTests.self
    ]
    
    /// Integration tests for end-to-end functionality
    static let integrationTests: [XCTestCase.Type] = [
        PrayerTimeSynchronizationIntegrationTests.self,
        BackgroundServiceSynchronizationTests.self
    ]
    
    /// Performance tests to ensure no regressions
    static let performanceTests: [XCTestCase.Type] = [
        CachePerformanceTests.self
    ]
    
    /// Validation tests for real-world scenarios
    static let validationTests: [XCTestCase.Type] = [
        PrayerTimeValidationTests.self
    ]
    
    /// All test classes in execution order
    static let allTests: [XCTestCase.Type] = 
        coreTests + cacheTests + integrationTests + performanceTests + validationTests
    
    // MARK: - Test Configuration
    
    /// Test environment configuration
    struct TestEnvironment {
        static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        static let isRunningUITests = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        static let isRunningPerformanceTests = ProcessInfo.processInfo.arguments.contains("-performance-testing")
        static let testTimeout: TimeInterval = 30.0
        static let performanceTestTimeout: TimeInterval = 60.0
    }
    
    /// Test data configuration
    struct TestData {
        static let testLocations = [
            (name: "New York", lat: 40.7128, lon: -74.0060),
            (name: "Mecca", lat: 21.4225, lon: 39.8262),
            (name: "London", lat: 51.5074, lon: -0.1278),
            (name: "Jakarta", lat: -6.2088, lon: 106.8456),
            (name: "Cairo", lat: 30.0444, lon: 31.2357)
        ]
        
        static let testDates = [
            "2024-06-21", // Summer solstice
            "2024-12-21", // Winter solstice
            "2024-03-20", // Spring equinox
            "2024-09-22"  // Fall equinox
        ]
        
        static let calculationMethods = CalculationMethod.allCases
        static let madhabs = Madhab.allCases
    }
    
    // MARK: - Test Execution Helpers
    
    /// Run core tests that must pass for basic functionality
    static func runCoreTests() -> Bool {
        return runTestSuite(coreTests, name: "Core Synchronization Tests")
    }
    
    /// Run all cache-related tests
    static func runCacheTests() -> Bool {
        return runTestSuite(cacheTests, name: "Cache Tests")
    }
    
    /// Run integration tests
    static func runIntegrationTests() -> Bool {
        return runTestSuite(integrationTests, name: "Integration Tests")
    }
    
    /// Run performance tests
    static func runPerformanceTests() -> Bool {
        return runTestSuite(performanceTests, name: "Performance Tests")
    }
    
    /// Run validation tests
    static func runValidationTests() -> Bool {
        return runTestSuite(validationTests, name: "Validation Tests")
    }
    
    /// Run complete test suite
    static func runCompleteTestSuite() -> Bool {
        print("🧪 Starting Complete Prayer Time Synchronization Test Suite")
        print("=" * 60)
        
        var allPassed = true
        
        // Run test suites in order
        let testSuites = [
            ("Core Tests", coreTests),
            ("Cache Tests", cacheTests),
            ("Integration Tests", integrationTests),
            ("Performance Tests", performanceTests),
            ("Validation Tests", validationTests)
        ]
        
        for (suiteName, testClasses) in testSuites {
            let passed = runTestSuite(testClasses, name: suiteName)
            allPassed = allPassed && passed
            
            if !passed {
                print("❌ \(suiteName) FAILED - Stopping execution")
                break
            }
        }
        
        print("=" * 60)
        if allPassed {
            print("✅ ALL TESTS PASSED - Prayer Time Synchronization Fix Validated")
        } else {
            print("❌ SOME TESTS FAILED - Prayer Time Synchronization Fix Needs Attention")
        }
        
        return allPassed
    }
    
    // MARK: - Private Helpers
    
    private static func runTestSuite(_ testClasses: [XCTestCase.Type], name: String) -> Bool {
        print("\n🔍 Running \(name)...")
        print("-" * 40)
        
        var allPassed = true
        
        for testClass in testClasses {
            let testSuite = XCTestSuite(forTestCaseClass: testClass)
            let testRun = XCTestSuiteRun(test: testSuite)
            
            testSuite.run(testRun)
            
            let passed = testRun.testCaseCount == testRun.executionCount && testRun.failureCount == 0
            let status = passed ? "✅" : "❌"
            
            print("\(status) \(testClass) - \(testRun.executionCount) tests, \(testRun.failureCount) failures")
            
            if !passed {
                allPassed = false
            }
        }
        
        let suiteStatus = allPassed ? "✅ PASSED" : "❌ FAILED"
        print("\n\(name): \(suiteStatus)")
        
        return allPassed
    }
}

// MARK: - Test Utilities

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

/// Test execution configuration for CI/CD
struct ContinuousIntegrationConfig {
    
    /// Tests that must pass for CI to succeed
    static let criticalTests: [XCTestCase.Type] = [
        ServiceSynchronizationTests.self,
        PrayerTimeSynchronizationRegressionTests.self,
        CacheInvalidationTests.self
    ]
    
    /// Tests that can be skipped in fast CI builds
    static let optionalTests: [XCTestCase.Type] = [
        CachePerformanceTests.self,
        PrayerTimeValidationTests.self
    ]
    
    /// Run tests appropriate for CI environment
    static func runCITests() -> Bool {
        print("🚀 Running CI Test Suite for Prayer Time Synchronization")
        
        if TestSuiteConfiguration.TestEnvironment.isRunningPerformanceTests {
            return TestSuiteConfiguration.runCompleteTestSuite()
        } else {
            return TestSuiteConfiguration.runTestSuite(criticalTests, name: "Critical CI Tests")
        }
    }
}

/// Test reporting utilities
struct TestReporting {
    
    /// Generate test report summary
    static func generateTestReport() -> String {
        var report = """
        # Prayer Time Synchronization Test Report
        
        ## Test Suite Coverage
        
        ### Core Synchronization Tests
        - ServiceSynchronizationTests: Settings service and prayer time service synchronization
        - SettingsMigrationTests: Migration from legacy UserDefaults keys
        - PrayerTimeSynchronizationRegressionTests: Regression prevention for critical bugs
        
        ### Cache System Tests
        - CacheInvalidationTests: Cache invalidation when settings change
        - CacheKeyStrategyTests: Method and madhab-specific cache keys
        - CacheInvalidationConsistencyTests: Cross-system cache consistency
        
        ### Integration Tests
        - PrayerTimeSynchronizationIntegrationTests: End-to-end functionality
        - BackgroundServiceSynchronizationTests: Background service synchronization
        
        ### Performance Tests
        - CachePerformanceTests: Cache operation performance validation
        
        ### Validation Tests
        - PrayerTimeValidationTests: Real-world prayer time accuracy
        
        ## Test Environment
        - Test Locations: \(TestSuiteConfiguration.TestData.testLocations.count) locations
        - Test Dates: \(TestSuiteConfiguration.TestData.testDates.count) dates
        - Calculation Methods: \(TestSuiteConfiguration.TestData.calculationMethods.count) methods
        - Madhabs: \(TestSuiteConfiguration.TestData.madhabs.count) madhabs
        
        ## Critical Bug Prevention
        This test suite specifically prevents:
        1. Duplicate UserDefaults keys between services
        2. Settings changes not triggering prayer time recalculation
        3. Cache invalidation failures
        4. Background service synchronization issues
        5. Performance regressions
        6. Data consistency problems
        
        """
        
        return report
    }
    
    /// Log test execution summary
    static func logTestSummary(passed: Bool, duration: TimeInterval) {
        let status = passed ? "✅ PASSED" : "❌ FAILED"
        let formattedDuration = String(format: "%.2f", duration)
        
        print("""
        
        📊 TEST EXECUTION SUMMARY
        Status: \(status)
        Duration: \(formattedDuration) seconds
        Test Classes: \(TestSuiteConfiguration.allTests.count)
        
        """)
    }
}
