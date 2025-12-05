//
//  DeenBuddyTests.swift
//  DeenBuddyTests
//
//  Created by Farhoud Talebi on 2025-07-03.
//

import Testing
@testable import DeenBuddy

struct DeenBuddyTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    /// Ensures Prayer enum maintains consistency with Islamic prayer names
    @Test func prayerEnumConsistency() {
        // Verify all five Islamic prayers are represented
        let expectedRawValues = ["fajr", "dhuhr", "asr", "maghrib", "isha"]
        let actualRawValues = Prayer.allCases.map { $0.rawValue }

        #expect(actualRawValues == expectedRawValues, "Prayer enum raw values must match Islamic prayer names")

        // Verify each case can be initialized from its raw value (for widget compatibility)
        for rawValue in expectedRawValues {
            let prayer = Prayer(widgetRawValue: rawValue)
            #expect(prayer != nil, "Prayer enum must be initializable from '\(rawValue)'")
            #expect(prayer!.rawValue == rawValue, "Prayer enum round-trip consistency failed for '\(rawValue)'")
        }

        // Verify all Prayer cases are distinct and properly ordered
        #expect(Prayer.allCases.count == 5, "Prayer enum must have exactly 5 cases")
        #expect(Prayer.allCases == Prayer.chronologicalOrder, "Prayer cases must be in chronological order")
    }

}
