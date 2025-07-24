import XCTest
import Adhan
@testable import DeenBuddy

class DirectAdhanLibraryTests: XCTestCase {
    
    func testTehranVsLevaDirectAdhanComparison() {
        // Test coordinates (Tehran, Iran)
        let coordinates = Coordinates(latitude: 35.6892, longitude: 51.3890)
        let dateComponents = DateComponents(year: 2024, month: 1, day: 15)
        
        // Create Tehran parameters (17.7° Fajr angle) using ULTIMATE approach (different base methods)
        var tehranParams = Adhan.CalculationMethod.karachi.params  // Different base for independence
        tehranParams.method = .other
        tehranParams.fajrAngle = 17.7
        tehranParams.ishaAngle = 14.0
        tehranParams.madhab = .shafi
        
        // Create Leva parameters (16.0° Fajr angle) using ULTIMATE approach (different base methods)
        var levaParams = Adhan.CalculationMethod.egyptian.params  // Different base for independence
        levaParams.method = .other
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
        print("   🎯 Expected: Tehran Fajr should be EARLIER (negative difference - higher angle)")
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
        
        // Tehran method (higher Fajr angle) should produce EARLIER Fajr time
        XCTAssertLessThan(
            tehranPrayerTimes.fajr,
            levaPrayerTimes.fajr,
            "✅ CORRECT: Tehran method (17.7°) should produce EARLIER Fajr than Leva method (16.0°) - higher angle = earlier time"
        )
        
        // Expect reasonable difference (typically 5-15 minutes for 1.7° difference, negative because Tehran is earlier)
        XCTAssertLessThan(
            fajrDifferenceMinutes,
            -2.0,
            "Fajr time difference should be at least 2 minutes earlier for 1.7° angle difference"
        )
        
        XCTAssertGreaterThan(
            fajrDifferenceMinutes,
            -20.0,
            "Fajr time difference should be less than 20 minutes earlier for 1.7° angle difference"
        )
        
        print("✅ Direct Adhan library test completed successfully")
    }
    
    func testParameterObjectIsolation() {
        // Verify that parameter objects are truly independent using ULTIMATE approach (different base methods)
        var params1 = Adhan.CalculationMethod.karachi.params  // Different base for independence
        params1.method = .other
        params1.fajrAngle = 17.7
        params1.ishaAngle = 14.0
        params1.madhab = .hanafi
        
        var params2 = Adhan.CalculationMethod.egyptian.params  // Different base for independence
        params2.method = .other
        params2.fajrAngle = 16.0
        params2.ishaAngle = 14.0
        params2.madhab = .shafi
        
        // Verify they are independent
        XCTAssertEqual(params1.fajrAngle, 17.7)
        XCTAssertEqual(params2.fajrAngle, 16.0)
        XCTAssertEqual(params1.madhab, .hanafi)
        XCTAssertEqual(params2.madhab, .shafi)
        
        print("✅ Parameter object isolation test passed")
        
        print("✅ Parameter object isolation test passed")
    }
}