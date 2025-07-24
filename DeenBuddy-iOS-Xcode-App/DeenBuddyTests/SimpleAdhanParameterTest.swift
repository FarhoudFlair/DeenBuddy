import XCTest
import Adhan
@testable import DeenBuddy

class SimpleAdhanParameterTest: XCTestCase {
    
    func testAdhanParameterSharedStateIssue() {
        print("🔬 INVESTIGATING ADHAN LIBRARY PARAMETER SHARING")
        
        // Test coordinates
        let coordinates = Coordinates(latitude: 35.6892, longitude: 51.3890)
        let dateComponents = DateComponents(year: 2024, month: 1, day: 15)
        
        // Method 1: Create first params using FIXED approach (independent object creation)
        var params1 = Adhan.CalculationMethod.muslimWorldLeague.params
        params1.method = .other
        params1.fajrAngle = 17.7
        params1.ishaAngle = 14.0
        params1.madhab = .shafi
        
        print("📐 PARAMS1 (Tehran): fajrAngle=\(params1.fajrAngle)°, ishaAngle=\(params1.ishaAngle)°")
        
        // Method 2: Create second params using FIXED approach (independent object creation)
        var params2 = Adhan.CalculationMethod.muslimWorldLeague.params
        params2.method = .other
        params2.fajrAngle = 16.0
        params2.ishaAngle = 14.0
        params2.madhab = .shafi
        
        print("📐 PARAMS2 (Leva): fajrAngle=\(params2.fajrAngle)°, ishaAngle=\(params2.ishaAngle)°")
        
        // CRITICAL TEST: Check if modifying params2 affects params1
        print("🔍 CHECKING FOR SHARED STATE...")
        print("   Before calculation - PARAMS1: fajrAngle=\(params1.fajrAngle)°")
        print("   Before calculation - PARAMS2: fajrAngle=\(params2.fajrAngle)°")
        
        // Calculate with params1 first
        guard let prayerTimes1 = Adhan.PrayerTimes(
            coordinates: coordinates,
            date: dateComponents,
            calculationParameters: params1
        ) else {
            XCTFail("Failed to calculate prayer times with params1")
            return
        }
        
        // Check if params1 was modified by the calculation
        print("   After params1 calculation - PARAMS1: fajrAngle=\(params1.fajrAngle)°")
        print("   After params1 calculation - PARAMS2: fajrAngle=\(params2.fajrAngle)°")
        
        // Calculate with params2
        guard let prayerTimes2 = Adhan.PrayerTimes(
            coordinates: coordinates,
            date: dateComponents,
            calculationParameters: params2
        ) else {
            XCTFail("Failed to calculate prayer times with params2")
            return
        }
        
        // Final state check
        print("   After both calculations - PARAMS1: fajrAngle=\(params1.fajrAngle)°")
        print("   After both calculations - PARAMS2: fajrAngle=\(params2.fajrAngle)°")
        
        // Format and compare results
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        
        print("")
        print("⏰ RESULTS:")
        print("   📅 Params1 (17.7°) Fajr: \(formatter.string(from: prayerTimes1.fajr))")
        print("   📅 Params2 (16.0°) Fajr: \(formatter.string(from: prayerTimes2.fajr))")
        
        if prayerTimes1.fajr == prayerTimes2.fajr {
            print("❌ CONFIRMED BUG: Different parameters produce IDENTICAL results!")
            print("   🔍 This proves the Adhan library has shared state or ignores custom parameters")
        } else {
            print("✅ Parameters working correctly: Different results produced")
        }
        
        // Verify the issue exists
        XCTAssertNotEqual(prayerTimes1.fajr, prayerTimes2.fajr, 
                         "Different Fajr angles should produce different prayer times")
    }
}