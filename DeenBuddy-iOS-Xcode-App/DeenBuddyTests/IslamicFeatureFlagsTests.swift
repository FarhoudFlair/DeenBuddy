import XCTest
@testable import DeenAssistCore

/// Test suite for Islamic Feature Flags system
final class IslamicFeatureFlagsTests: XCTestCase {
    
    var featureFlags: IslamicFeatureFlags!
    
    override func setUp() {
        super.setUp()
        // Use a fresh instance for each test
        featureFlags = IslamicFeatureFlags.shared
        // Reset all flags to default values
        featureFlags.resetAll()
    }
    
    override func tearDown() {
        // Clean up after each test
        featureFlags.resetAll()
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testFeatureFlagDefaults() {
        // Test that all features start with their default values
        for feature in IslamicFeature.allCases {
            let isEnabled = featureFlags.isEnabled(feature)
            XCTAssertEqual(isEnabled, feature.defaultValue, 
                          "Feature \(feature.rawValue) should default to \(feature.defaultValue)")
        }
    }
    
    func testEnableFeature() {
        // Test enabling a feature
        featureFlags.enable(.enhancedPrayerTracking)
        XCTAssertTrue(featureFlags.isEnabled(.enhancedPrayerTracking))
        
        // Test that other features remain unchanged
        XCTAssertFalse(featureFlags.isEnabled(.digitalTasbih))
    }
    
    func testDisableFeature() {
        // First enable a feature
        featureFlags.enable(.digitalTasbih)
        XCTAssertTrue(featureFlags.isEnabled(.digitalTasbih))
        
        // Then disable it
        featureFlags.disable(.digitalTasbih)
        XCTAssertFalse(featureFlags.isEnabled(.digitalTasbih))
    }
    
    func testResetFeature() {
        // Enable a feature that defaults to false
        featureFlags.enable(.islamicCalendar)
        XCTAssertTrue(featureFlags.isEnabled(.islamicCalendar))
        
        // Reset to default
        featureFlags.reset(.islamicCalendar)
        XCTAssertEqual(featureFlags.isEnabled(.islamicCalendar), 
                      IslamicFeature.islamicCalendar.defaultValue)
    }
    
    // MARK: - Batch Operations Tests
    
    func testEnableMultipleFeatures() {
        let features: [IslamicFeature] = [.enhancedPrayerTracking, .digitalTasbih, .islamicCalendar]
        
        featureFlags.enableFeatures(features)
        
        for feature in features {
            XCTAssertTrue(featureFlags.isEnabled(feature), 
                         "Feature \(feature.rawValue) should be enabled")
        }
    }
    
    func testDisableMultipleFeatures() {
        let features: [IslamicFeature] = [.enhancedPrayerTracking, .digitalTasbih, .islamicCalendar]
        
        // First enable them
        featureFlags.enableFeatures(features)
        
        // Then disable them
        featureFlags.disableFeatures(features)
        
        for feature in features {
            XCTAssertFalse(featureFlags.isEnabled(feature), 
                          "Feature \(feature.rawValue) should be disabled")
        }
    }
    
    func testResetAll() {
        // Enable some features
        featureFlags.enable(.enhancedPrayerTracking)
        featureFlags.enable(.digitalTasbih)
        featureFlags.enable(.islamicCalendar)
        
        // Reset all
        featureFlags.resetAll()
        
        // Check all features are back to defaults
        for feature in IslamicFeature.allCases {
            XCTAssertEqual(featureFlags.isEnabled(feature), feature.defaultValue,
                          "Feature \(feature.rawValue) should be reset to default")
        }
    }
    
    // MARK: - Phase Operations Tests
    
    func testEnablePhase() {
        featureFlags.enablePhase(.phase1)
        
        let phase1Features = featureFlags.getFeaturesForPhase(.phase1)
        for feature in phase1Features {
            XCTAssertTrue(featureFlags.isEnabled(feature),
                         "Phase 1 feature \(feature.rawValue) should be enabled")
        }
        
        // Check that phase 2 features remain unchanged
        let phase2Features = featureFlags.getFeaturesForPhase(.phase2)
        for feature in phase2Features {
            XCTAssertEqual(featureFlags.isEnabled(feature), feature.defaultValue,
                          "Phase 2 feature \(feature.rawValue) should remain at default")
        }
    }
    
    func testDisablePhase() {
        // First enable phase 1
        featureFlags.enablePhase(.phase1)
        
        // Then disable it
        featureFlags.disablePhase(.phase1)
        
        let phase1Features = featureFlags.getFeaturesForPhase(.phase1)
        for feature in phase1Features {
            XCTAssertFalse(featureFlags.isEnabled(feature),
                          "Phase 1 feature \(feature.rawValue) should be disabled")
        }
    }
    
    // MARK: - Risk Level Tests
    
    func testGetFeaturesWithRiskLevel() {
        let lowRiskFeatures = featureFlags.getFeaturesWithRiskLevel(.low)
        let highRiskFeatures = featureFlags.getFeaturesWithRiskLevel(.high)
        
        XCTAssertFalse(lowRiskFeatures.isEmpty, "Should have some low risk features")
        XCTAssertFalse(highRiskFeatures.isEmpty, "Should have some high risk features")
        
        // Check that features are correctly categorized
        for feature in lowRiskFeatures {
            XCTAssertEqual(feature.riskLevel, .low)
        }
        
        for feature in highRiskFeatures {
            XCTAssertEqual(feature.riskLevel, .high)
        }
    }
    
    func testSafeRollout() {
        featureFlags.safeRollout()
        
        let lowRiskFeatures = featureFlags.getFeaturesWithRiskLevel(.low)
        for feature in lowRiskFeatures {
            XCTAssertTrue(featureFlags.isEnabled(feature),
                         "Low risk feature \(feature.rawValue) should be enabled in safe rollout")
        }
        
        let highRiskFeatures = featureFlags.getFeaturesWithRiskLevel(.high)
        for feature in highRiskFeatures {
            XCTAssertFalse(featureFlags.isEnabled(feature),
                          "High risk feature \(feature.rawValue) should remain disabled in safe rollout")
        }
    }
    
    func testEmergencyRollback() {
        // Enable some features first
        featureFlags.enable(.enhancedPrayerTracking)
        featureFlags.enable(.digitalTasbih)
        featureFlags.enable(.islamicCalendar)
        
        // Perform emergency rollback
        featureFlags.emergencyRollback()
        
        // Check that all features are disabled
        for feature in IslamicFeature.allCases {
            XCTAssertFalse(featureFlags.isEnabled(feature),
                          "Feature \(feature.rawValue) should be disabled after emergency rollback")
        }
    }
    
    // MARK: - Convenience Helper Tests
    
    func testFeatureFlagHelper() {
        // Test the convenience helper
        XCTAssertFalse(FeatureFlag.enhancedPrayerTracking)
        
        FeatureFlag.enable(.enhancedPrayerTracking)
        XCTAssertTrue(FeatureFlag.enhancedPrayerTracking)
        
        FeatureFlag.disable(.enhancedPrayerTracking)
        XCTAssertFalse(FeatureFlag.enhancedPrayerTracking)
    }
    
    func testFeatureFlagHelperProperties() {
        // Test all convenience properties
        XCTAssertEqual(FeatureFlag.digitalTasbih, 
                      FeatureFlag.isEnabled(.digitalTasbih))
        XCTAssertEqual(FeatureFlag.islamicCalendar, 
                      FeatureFlag.isEnabled(.islamicCalendar))
        XCTAssertEqual(FeatureFlag.hadithCollection, 
                      FeatureFlag.isEnabled(.hadithCollection))
        XCTAssertEqual(FeatureFlag.mosqueFinder, 
                      FeatureFlag.isEnabled(.mosqueFinder))
        XCTAssertEqual(FeatureFlag.prayerJournal, 
                      FeatureFlag.isEnabled(.prayerJournal))
    }
    
    // MARK: - Persistence Tests
    
    func testFeaturePersistence() {
        // Enable a feature
        featureFlags.enable(.enhancedPrayerTracking)
        XCTAssertTrue(featureFlags.isEnabled(.enhancedPrayerTracking))
        
        // Check that it's stored in UserDefaults
        let userDefaults = UserDefaults.standard
        let key = "islamic_feature_enhanced_prayer_tracking"
        XCTAssertTrue(userDefaults.bool(forKey: key))
        
        // Disable the feature
        featureFlags.disable(.enhancedPrayerTracking)
        XCTAssertFalse(featureFlags.isEnabled(.enhancedPrayerTracking))
        XCTAssertFalse(userDefaults.bool(forKey: key))
    }
    
    // MARK: - Performance Tests
    
    func testFeatureFlagPerformance() {
        // Test that feature flag checks are fast
        measure {
            for _ in 0..<10000 {
                _ = featureFlags.isEnabled(.enhancedPrayerTracking)
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testFeatureProperties() {
        // Test that all features have required properties
        for feature in IslamicFeature.allCases {
            XCTAssertFalse(feature.displayName.isEmpty, 
                          "Feature \(feature.rawValue) should have a display name")
            XCTAssertFalse(feature.description.isEmpty, 
                          "Feature \(feature.rawValue) should have a description")
            XCTAssertNotNil(feature.phase, 
                           "Feature \(feature.rawValue) should have a phase")
            XCTAssertNotNil(feature.riskLevel, 
                           "Feature \(feature.rawValue) should have a risk level")
        }
    }
    
    func testGetFeatureStatus() {
        // Enable some features
        featureFlags.enable(.enhancedPrayerTracking)
        featureFlags.enable(.digitalTasbih)
        
        let status = featureFlags.getFeatureStatus()
        
        XCTAssertEqual(status["enhanced_prayer_tracking"], true)
        XCTAssertEqual(status["digital_tasbih"], true)
        XCTAssertEqual(status["islamic_calendar"], false)
    }
    
    func testGetEnabledFeatures() {
        // Initially, only features with default = true should be enabled
        let initiallyEnabled = featureFlags.getEnabledFeatures()
        let expectedEnabled = IslamicFeature.allCases.filter { $0.defaultValue }
        
        XCTAssertEqual(Set(initiallyEnabled), Set(expectedEnabled))
        
        // Enable a feature and test again
        featureFlags.enable(.enhancedPrayerTracking)
        let nowEnabled = featureFlags.getEnabledFeatures()
        
        XCTAssertTrue(nowEnabled.contains(.enhancedPrayerTracking))
    }
}

// MARK: - Integration Tests

extension IslamicFeatureFlagsTests {
    
    func testIntegrationWithMainApp() {
        // Test that the feature flag system works with the main app initialization
        DeenAssistCore.initialize()
        
        // Check that shared instance is accessible
        let sharedInstance = IslamicFeatureFlags.shared
        XCTAssertNotNil(sharedInstance)
        
        // Test that convenience methods work
        XCTAssertFalse(FeatureFlag.enhancedPrayerTracking)
        FeatureFlag.enable(.enhancedPrayerTracking)
        XCTAssertTrue(FeatureFlag.enhancedPrayerTracking)
    }
}