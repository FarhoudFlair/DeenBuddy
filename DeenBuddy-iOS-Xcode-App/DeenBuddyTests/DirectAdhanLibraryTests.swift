import XCTest
import Adhan
@testable import DeenBuddy

class DirectAdhanLibraryTests: XCTestCase {
    
    func testTehranVsLevaDirectAdhanComparison() {
        // Test coordinates (Tehran, Iran)
        let coordinates = Coordinates(latitude: 35.6892, longitude: 51.3890)
        let dateComponents = DateComponents(year: 2024, month: 1, day: 15)
        
        // Create Tehran parameters (17.7° Fajr angle) using correct Adhan API
        var tehranParams = Adhan.CalculationMethod.other.params
        tehranParams.fajrAngle = 17.7
        tehranParams.ishaAngle = 14.0
        tehranParams.madhab = .shafi
        
        // Create Leva parameters (16.0° Fajr angle) using correct Adhan API
        var levaParams = Adhan.CalculationMethod.other.params
        levaParams.fajrAngle = 16.0
        levaParams.ishaAngle = 14.0
        levaParams.madhab = .shafi
        
        // Calculate prayer times directly with Adhan library
        guard let tehranPrayerTimes = Adhan.PrayerTimes(
            coordinates: coordinates,
            date: dateComponents,
            calculationParameters: tehranParams
        ) else {
            XCTFail("Failed to calculate Tehran prayer times")
            return
        }
        
        guard let levaPrayerTimes = Adhan.PrayerTimes(
            coordinates: coordinates,
            date: dateComponents,
            calculationParameters: levaParams
        ) else {
            XCTFail("Failed to calculate Leva prayer times")
            return
        }
        
        // Debug logging
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        
        print("🔍 DIRECT ADHAN LIBRARY TEST RESULTS:")
        print("📍 Location: Tehran, Iran (test coordinates)")
        print("📅 Date: \(dateComponents)")
        print("")
        print("🏢 TEHRAN METHOD (17.7° Fajr):")
        print("   🌅 Fajr: \(formatter.string(from: tehranPrayerTimes.fajr))")
        print("   🌄 Sunrise: \(formatter.string(from: tehranPrayerTimes.sunrise))")
        print("   🌞 Dhuhr: \(formatter.string(from: tehranPrayerTimes.dhuhr))")
        print("   🌅 Asr: \(formatter.string(from: tehranPrayerTimes.asr))")
        print("   🌅 Maghrib: \(formatter.string(from: tehranPrayerTimes.maghrib))")
        print("   🌙 Isha: \(formatter.string(from: tehranPrayerTimes.isha))")
        print("")
        print("🏛️ LEVA METHOD (16.0° Fajr):")
        print("   🌅 Fajr: \(formatter.string(from: levaPrayerTimes.fajr))")
        print("   🌄 Sunrise: \(formatter.string(from: levaPrayerTimes.sunrise))")
        print("   🌞 Dhuhr: \(formatter.string(from: levaPrayerTimes.dhuhr))")
        print("   🌅 Asr: \(formatter.string(from: levaPrayerTimes.asr))")
        print("   🌅 Maghrib: \(formatter.string(from: levaPrayerTimes.maghrib))")
        print("   🌙 Isha: \(formatter.string(from: levaPrayerTimes.isha))")
        print("")
        
        // Calculate time differences
        let fajrDifferenceSeconds = tehranPrayerTimes.fajr.timeIntervalSince(levaPrayerTimes.fajr)
        let fajrDifferenceMinutes = fajrDifferenceSeconds / 60.0
        
        print("⏱️ TIME DIFFERENCES:")
        print("   🌅 Fajr difference: \(String(format: "%.1f", fajrDifferenceMinutes)) minutes")
        print("   🎯 Expected: Tehran Fajr should be LATER (positive difference)")
        print("   📐 Angle difference: 17.7° - 16.0° = 1.7°")
        
        // Verify that the methods produce different results
        if tehranPrayerTimes.fajr == levaPrayerTimes.fajr {
            print("❌ CRITICAL ISSUE: Tehran and Leva methods produce IDENTICAL Fajr times!")
            print("   🔍 This confirms the bug - different parameters are being ignored")
            print("   📐 Tehran params: fajrAngle=17.7°, ishaAngle=14.0°")
            print("   📐 Leva params: fajrAngle=16.0°, ishaAngle=14.0°")
            print("   🚨 Adhan library may be sharing parameter state or ignoring custom values")
        }
        
        XCTAssertNotEqual(
            tehranPrayerTimes.fajr,
            levaPrayerTimes.fajr,
            "🚨 CRITICAL: Tehran and Leva methods should produce DIFFERENT Fajr times!"
        )
        
        // Tehran method (higher Fajr angle) should produce LATER Fajr time
        XCTAssertGreaterThan(
            tehranPrayerTimes.fajr,
            levaPrayerTimes.fajr,
            "🚨 CRITICAL: Tehran method (17.7°) should produce LATER Fajr than Leva method (16.0°)"
        )
        
        // Expect reasonable difference (typically 5-15 minutes for 1.7° difference)
        XCTAssertGreaterThan(
            fajrDifferenceMinutes,
            2.0,
            "Fajr time difference should be at least 2 minutes for 1.7° angle difference"
        )
        
        XCTAssertLessThan(
            fajrDifferenceMinutes,
            20.0,
            "Fajr time difference should be less than 20 minutes for 1.7° angle difference"
        )
        
        print("✅ Direct Adhan library test completed successfully")
    }
    
    func testParameterObjectIsolation() {
        // Verify that parameter objects are truly independent
        var params1 = Adhan.CalculationMethod.other.params
        params1.fajrAngle = 17.7
        params1.ishaAngle = 14.0
        
        var params2 = Adhan.CalculationMethod.other.params
        params2.fajrAngle = 16.0
        params2.ishaAngle = 14.0
        
        // Modify one parameter
        params1.madhab = .hanafi
        params2.madhab = .shafi
        
        // Verify they remain independent
        XCTAssertEqual(params1.fajrAngle, 17.7)
        XCTAssertEqual(params2.fajrAngle, 16.0)
        XCTAssertEqual(params1.madhab, .hanafi)
        XCTAssertEqual(params2.madhab, .shafi)
        
        print("✅ Parameter object isolation test passed")
    }
}