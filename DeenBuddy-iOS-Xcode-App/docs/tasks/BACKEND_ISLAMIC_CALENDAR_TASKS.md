# Islamic Calendar & Future Prayer Times - Backend Implementation Tasks

**CRITICAL NOTICE**: This feature serves the Muslim community. Islamic accuracy is paramount. Any calculation errors or misleading disclaimers could harm users' religious practice. Proceed with extreme care and validate all Islamic logic thoroughly.

---

## Non-Negotiable Islamic Safety Rails (apply everywhere)

- Exact-minute display: only for today and up to 12 months ahead; beyond that either require the `showLongRangePrecision` flag or degrade to windows (e.g., ±15m) per PrecisionLevel.
- Lookahead hard stops: enforce `maxLookaheadMonths` (default 60). Reject calculations past the limit with a clear error.
- Timezone/DST: always recalc with current iOS TZDB at display time; never cache offsets; no custom DST logic.
- Ramadan/Eid: always labeled “Estimated…local authority may differ”; never imply official/fatwa dates.
- High latitude (>55°): flag and show the high-latitude warning; consider windowed times by default.
- Umm Al Qura/Qatar Isha: 90m default; +30m in Hijri month 9 when `useRamadanIshaOffset` is on; offer user override.

---

## Pre-Implementation Checklist

- [ ] Review all 4 planning documents thoroughly
- [ ] Understand fiqh compliance requirements (disclaimers, lookahead rules, Ramadan adjustments)
- [ ] Set up knowledge retrieval: Run `byterover-retrieve-knowledge` for "prayer times", "Islamic calendar", "DST handling"
- [ ] Verify Adhan Swift v1.4.0 is integrated and functional

---

## Phase 1: Core Data Models (4 hours)

### Task 1.1: Create FuturePrayerTimeModels.swift

**File**: `DeenBuddy/Frameworks/DeenAssistCore/Models/FuturePrayerTimeModels.swift` (NEW)

**Requirements**:
```swift
import Foundation
import CoreLocation

// MARK: - Request Model
public struct FuturePrayerTimeRequest {
    public let location: CLLocation
    public let date: Date
    public let calculationMethod: CalculationMethod
    public let madhab: Madhab
    public let useCurrentTimezone: Bool // ALWAYS true - recalculate with current iOS TZDB

    public init(location: CLLocation, date: Date, calculationMethod: CalculationMethod, madhab: Madhab, useCurrentTimezone: Bool = true) {
        self.location = location
        self.date = date
        self.calculationMethod = calculationMethod
        self.madhab = madhab
        self.useCurrentTimezone = useCurrentTimezone
    }
}

// MARK: - Result Model
public struct FuturePrayerTimeResult {
    public let date: Date
    public let prayerTimes: [PrayerTime]
    public let hijriDate: HijriDate
    public let isRamadan: Bool
    public let disclaimerLevel: DisclaimerLevel
    public let calculationTimezone: TimeZone
    public let isHighLatitude: Bool
    public let precision: PrecisionLevel

    public init(date: Date, prayerTimes: [PrayerTime], hijriDate: HijriDate, isRamadan: Bool, disclaimerLevel: DisclaimerLevel, calculationTimezone: TimeZone, isHighLatitude: Bool, precision: PrecisionLevel) {
        self.date = date
        self.prayerTimes = prayerTimes
        self.hijriDate = hijriDate
        self.isRamadan = isRamadan
        self.disclaimerLevel = disclaimerLevel
        self.calculationTimezone = calculationTimezone
        self.isHighLatitude = isHighLatitude
        self.precision = precision
    }
}

// MARK: - Disclaimer Level
public enum DisclaimerLevel {
    case today              // No banner
    case shortTerm          // 0-12 months
    case mediumTerm         // 12-60 months
    case longTerm           // >60 months (discourage or omit)

    public var requiresBanner: Bool {
        self != .today
    }

    /// EXACT COPY REQUIRED - NO CREATIVE VARIATIONS
    public var bannerMessage: String {
        switch self {
        case .today:
            return ""
        case .shortTerm:
            return "Calculated times. Subject to DST changes and official mosque schedules."
        case .mediumTerm:
            return "Long-range estimate. DST rules and local authorities may differ. Verify closer to date."
        case .longTerm:
            return "Long-range estimate not recommended. Use for planning only with extreme caution."
        }
    }
}

// MARK: - Islamic Event Estimate
public struct IslamicEventEstimate: Identifiable, Hashable {
    public let id = UUID()
    public let event: IslamicEvent
    public let estimatedDate: Date
    public let hijriDate: HijriDate
    public let confidenceLevel: EventConfidence

    /// EXACT COPY REQUIRED
    public var disclaimer: String {
        "Estimated by astronomical calculation (planning only). Actual dates set by your local Islamic authority."
    }

    public init(event: IslamicEvent, estimatedDate: Date, hijriDate: HijriDate, confidenceLevel: EventConfidence) {
        self.event = event
        self.estimatedDate = estimatedDate
        self.hijriDate = hijriDate
        self.confidenceLevel = confidenceLevel
    }
}

public enum IslamicEvent {
    case ramadanStart
    case ramadanEnd
    case eidAlFitr
    case eidAlAdha
    case other(name: String)
}

public enum EventConfidence {
    case high       // <12 months
    case medium     // 12-60 months
    case low        // >60 months

    public var displayText: String {
        switch self {
        case .high: return "High confidence"
        case .medium: return "Medium confidence"
        case .low: return "Low confidence"
        }
    }
}

// MARK: - Precision Level
public enum PrecisionLevel {
    case exact                          // Show HH:mm
    case window(minutes: Int)           // Show ±15 min window
    case timeOfDay                      // Show "Early Morning", "Noon", etc.

    public func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()

        switch self {
        case .exact:
            formatter.timeStyle = .short
            return formatter.string(from: date)

        case .window(let minutes):
            formatter.timeStyle = .short
            let calendar = Calendar.current
            guard let startTime = calendar.date(byAdding: .minute, value: -minutes/2, to: date),
                  let endTime = calendar.date(byAdding: .minute, value: minutes/2, to: date) else {
                return formatter.string(from: date)
            }
            return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"

        case .timeOfDay:
            let hour = Calendar.current.component(.hour, from: date)
            switch hour {
            case 0..<6: return "Early Morning"
            case 6..<12: return "Morning"
            case 12..<13: return "Noon"
            case 13..<17: return "Afternoon"
            case 17..<20: return "Evening"
            default: return "Night"
            }
        }
    }
}
```

**Validation**:
- [ ] All models compile without errors
- [ ] Disclaimer messages are EXACT as specified (no variations)
- [ ] All properties are public for cross-module access
- [ ] Documentation comments explain Islamic significance

---

## Phase 2: Service Protocol Extension (3 hours)

### Task 2.1: Extend PrayerTimeServiceProtocol

**File**: `DeenBuddy/Frameworks/DeenAssistProtocols/PrayerTimeServiceProtocol.swift` (EXTEND)

**Add these methods**:
```swift
/// Calculate prayer times for a future date using current iOS TZDB rules
/// - Parameters:
///   - date: Future date to calculate for
///   - location: Optional location (uses current location if nil)
/// - Returns: Future prayer time result with Islamic metadata
/// - Throws: PrayerTimeError if calculation fails or date exceeds lookahead limit
func getFuturePrayerTimes(for date: Date, location: CLLocation?) async throws -> FuturePrayerTimeResult

/// Calculate prayer times for a date range (max 90 days)
/// - Parameters:
///   - startDate: Start of date range
///   - endDate: End of date range
///   - location: Optional location (uses current location if nil)
/// - Returns: Array of future prayer time results
/// - Throws: PrayerTimeError if range exceeds 90 days or calculation fails
func getFuturePrayerTimes(from startDate: Date, to endDate: Date, location: CLLocation?) async throws -> [FuturePrayerTimeResult]

/// Validate lookahead date is within acceptable limits
/// - Parameter date: Date to validate
/// - Returns: Appropriate disclaimer level for the date
/// - Throws: PrayerTimeError.lookaheadLimitExceeded if date is too far in future
func validateLookaheadDate(_ date: Date) throws -> DisclaimerLevel

/// Check if location is at high latitude requiring special handling
/// - Parameter location: Location to check
/// - Returns: True if latitude > 55° or < -55°
func isHighLatitudeLocation(_ location: CLLocation) -> Bool
```

**Validation**:
- [ ] Protocol extension compiles
- [ ] All existing protocol implementations still compile
- [ ] Documentation comments explain Islamic considerations
- [ ] Methods are async where appropriate

---

## Phase 3: Service Implementation (8 hours)

### Task 3.1: Implement Future Prayer Time Methods

**File**: `DeenBuddy/Frameworks/DeenAssistCore/Services/PrayerTimeService.swift` (EXTEND)

**Implementation Requirements**:

#### 3.1.1: Implement `getFuturePrayerTimes(for:location:)`

```swift
public func getFuturePrayerTimes(for date: Date, location: CLLocation?) async throws -> FuturePrayerTimeResult {
    // 1. Validate date is within lookahead limit
    let disclaimerLevel = try validateLookaheadDate(date)

    // 2. Get location (use provided or fetch current)
    let targetLocation = try await resolveLocation(location)

    // 3. Check if high latitude
    let isHighLat = isHighLatitudeLocation(targetLocation)

    // 4. Calculate prayer times using existing method
    // CRITICAL: Always use current iOS TZDB rules (no custom DST logic)
    let prayerTimes = try await calculatePrayerTimes(for: targetLocation, date: date)

    // 5. Get Hijri date
    let hijriDate = getHijriDate(for: date)

    // 6. Check if date is in Ramadan
    let isRamadan = try await islamicCalendarService.isDateInRamadan(date)

    // 7. Apply Ramadan Isha offset if applicable
    var adjustedPrayerTimes = prayerTimes
    if isRamadan && shouldApplyRamadanIshaOffset() {
        adjustedPrayerTimes = applyRamadanIshaOffset(to: prayerTimes, for: date, location: targetLocation)
    }

    // 8. Get current timezone
    let timezone = TimeZone.current

    // 9. Choose precision (exact for <=12 months unless user opted in to long-range precision)
    let precision: PrecisionLevel
    switch disclaimerLevel {
    case .today, .shortTerm:
        precision = .exact
    case .mediumTerm:
        precision = settingsService.showLongRangePrecision ? .exact : .window(minutes: 30)
    case .longTerm:
        precision = .window(minutes: 30)
    }

    // 10. Build result
    return FuturePrayerTimeResult(
        date: date,
        prayerTimes: adjustedPrayerTimes,
        hijriDate: hijriDate,
        isRamadan: isRamadan,
        disclaimerLevel: disclaimerLevel,
        calculationTimezone: timezone,
        isHighLatitude: isHighLat,
        precision: precision
    )
}

// MARK: - Helper Methods

private func resolveLocation(_ location: CLLocation?) async throws -> CLLocation {
    if let location = location {
        return location
    }

    guard let currentLocation = try await locationService.getCurrentLocation() else {
        throw PrayerTimeError.locationUnavailable
    }

    return currentLocation
}

private func shouldApplyRamadanIshaOffset() -> Bool {
    // Check user setting AND calculation method
    guard settingsService.useRamadanIshaOffset else {
        return false
    }

    let method = settingsService.calculationMethod
    return method == .ummAlQura || method == .qatar
}

private func applyRamadanIshaOffset(to prayerTimes: [PrayerTime], for date: Date, location: CLLocation) -> [PrayerTime] {
    // For Umm Al Qura and Qatar methods:
    // Default Isha: 90 minutes after Maghrib
    // Ramadan Isha: 90 + 30 = 120 minutes after Maghrib

    guard let ishaIndex = prayerTimes.firstIndex(where: { $0.name == .isha }) else {
        return prayerTimes
    }

    var adjustedTimes = prayerTimes
    let originalIsha = prayerTimes[ishaIndex]

    // Add 30 minutes to existing Isha time
    guard let adjustedIshaDate = Calendar.current.date(byAdding: .minute, value: 30, to: originalIsha.time) else {
        return prayerTimes
    }

    adjustedTimes[ishaIndex] = PrayerTime(
        name: .isha,
        time: adjustedIshaDate,
        isRamadanAdjusted: true
    )

    return adjustedTimes
}
```

#### 3.1.2: Implement `getFuturePrayerTimes(from:to:location:)`

```swift
public func getFuturePrayerTimes(from startDate: Date, to endDate: Date, location: CLLocation?) async throws -> [FuturePrayerTimeResult] {
    // Validate date range (max 90 days)
    let calendar = Calendar.current
    guard let daysDiff = calendar.dateComponents([.day], from: startDate, to: endDate).day,
          daysDiff <= 90 else {
        throw PrayerTimeError.dateRangeTooLarge
    }

    // Use request coordinator to prevent duplicate calculations
    var results: [FuturePrayerTimeResult] = []
    var currentDate = startDate

    while currentDate <= endDate {
        // Check cache first
        let cacheKey = generateCacheKey(for: currentDate, location: location)

        if let cachedResult = cache.get(key: cacheKey) as? FuturePrayerTimeResult {
            results.append(cachedResult)
        } else {
            // Calculate and cache
            let result = try await getFuturePrayerTimes(for: currentDate, location: location)
            cache.set(key: cacheKey, value: result, ttl: 7 * 24 * 60 * 60) // 7 day TTL
            results.append(result)
        }

        // Move to next day
        guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
            break
        }
        currentDate = nextDate
    }

    return results
}
```

#### 3.1.3: Implement `validateLookaheadDate(_:)`

```swift
public func validateLookaheadDate(_ date: Date) throws -> DisclaimerLevel {
    let calendar = Calendar.current
    let today = Date()

    // Check if today
    if calendar.isDate(date, inSameDayAs: today) {
        return .today
    }

    // Calculate months difference
    guard let monthsDiff = calendar.dateComponents([.month], from: today, to: date).month else {
        throw PrayerTimeError.invalidDate
    }

    // Get max lookahead from settings
    let maxLookahead = settingsService.maxLookaheadMonths

    // Validate within limit
    guard monthsDiff <= maxLookahead else {
        throw PrayerTimeError.lookaheadLimitExceeded(requested: monthsDiff, maximum: maxLookahead)
    }

    // Return appropriate disclaimer level
    switch monthsDiff {
    case 0...12:
        return .shortTerm
    case 13...60:
        return .mediumTerm
    default:
        return .longTerm
    }
}
```

#### 3.1.4: Implement `isHighLatitudeLocation(_:)`

```swift
public func isHighLatitudeLocation(_ location: CLLocation) -> Bool {
    let latitude = abs(location.coordinate.latitude)
    return latitude > 55.0
}
```

**Validation Checklist**:
- [ ] All methods compile and integrate with existing service
- [ ] DST handling uses iOS TZDB only (no custom logic)
- [ ] Ramadan Isha offset applies correctly for Umm Al Qura/Qatar methods
- [ ] High-latitude detection is accurate (>55° or <-55°)
- [ ] Caching uses 7-day TTL via IslamicCacheManager
- [ ] Precision selection follows policy (<=12 months exact; medium/long term windowed unless explicitly enabled)
- [ ] Error handling is comprehensive and user-friendly

---

## Phase 4: Islamic Calendar Service Extension (4 hours)

### Task 4.1: Add Future Event Estimation Methods

**File**: `DeenBuddy/Frameworks/DeenAssistCore/Services/IslamicCalendarService.swift` (EXTEND)

**Add these methods**:

```swift
/// Estimate Ramadan dates for a future Hijri year
/// - Parameter hijriYear: Hijri year (e.g., 1446)
/// - Returns: Date interval for Ramadan (±1 day uncertainty for >1 year)
public func estimateRamadanDates(for hijriYear: Int) async -> DateInterval? {
    // Use astronomical calculations to estimate 1st of Ramadan
    let hijriCalendar = Calendar(identifier: .islamicUmmAlQura)

    var components = DateComponents()
    components.year = hijriYear
    components.month = 9  // Ramadan is 9th month
    components.day = 1

    guard let ramadanStart = hijriCalendar.date(from: components),
          let ramadanEnd = hijriCalendar.date(byAdding: .day, value: 29, to: ramadanStart) else {
        return nil
    }

    return DateInterval(start: ramadanStart, end: ramadanEnd)
}

/// Estimate Eid al-Fitr date for a future Hijri year
/// - Parameter hijriYear: Hijri year
/// - Returns: Estimated Eid date (planning only)
public func estimateEidAlFitr(for hijriYear: Int) async -> Date? {
    let hijriCalendar = Calendar(identifier: .islamicUmmAlQura)

    var components = DateComponents()
    components.year = hijriYear
    components.month = 10  // Shawwal (month after Ramadan)
    components.day = 1      // Eid is 1st of Shawwal

    return hijriCalendar.date(from: components)
}

/// Estimate Eid al-Adha date for a future Hijri year
/// - Parameter hijriYear: Hijri year
/// - Returns: Estimated Eid date (planning only)
public func estimateEidAlAdha(for hijriYear: Int) async -> Date? {
    let hijriCalendar = Calendar(identifier: .islamicUmmAlQura)

    var components = DateComponents()
    components.year = hijriYear
    components.month = 12  // Dhul Hijjah
    components.day = 10     // Eid is 10th of Dhul Hijjah

    return hijriCalendar.date(from: components)
}

/// Get confidence level for an Islamic event based on how far in future
/// - Parameter date: Event date
/// - Returns: Confidence level (high/medium/low)
public func getEventConfidence(for date: Date) -> EventConfidence {
    let calendar = Calendar.current
    let today = Date()

    guard let monthsDiff = calendar.dateComponents([.month], from: today, to: date).month else {
        return .low
    }

    switch monthsDiff {
    case 0...12:
        return .high
    case 13...60:
        return .medium
    default:
        return .low
    }
}

/// Check if a date falls within Ramadan
/// - Parameter date: Date to check
/// - Returns: True if date is in Ramadan
public func isDateInRamadan(_ date: Date) async -> Bool {
    let hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
    let hijriMonth = hijriCalendar.component(.month, from: date)
    return hijriMonth == 9  // Ramadan is 9th month
}
```

**Validation**:
- [ ] All methods compile and integrate correctly
- [ ] Hijri calendar calculations use Islamic Umm Al Qura calendar
- [ ] Confidence levels are appropriate for time ranges
- [ ] ±1 day uncertainty is documented for >1 year estimates

---

## Phase 5: Settings Service Extension (2 hours)

### Task 5.1: Add Feature Flag Settings

**File**: `DeenBuddy/Frameworks/DeenAssistCore/Services/SettingsService.swift` (EXTEND)

**Add these properties**:

```swift
// MARK: - Future Prayer Times Settings

/// Maximum lookahead in months (default: 60 months / 5 years)
public var maxLookaheadMonths: Int {
    get {
        userDefaults.integer(forKey: UnifiedSettingsKeys.maxLookaheadMonths) != 0
            ? userDefaults.integer(forKey: UnifiedSettingsKeys.maxLookaheadMonths)
            : 60
    }
    set {
        userDefaults.set(newValue, forKey: UnifiedSettingsKeys.maxLookaheadMonths)
    }
}

/// Use Ramadan Isha offset (+30m for Umm Al Qura/Qatar methods)
public var useRamadanIshaOffset: Bool {
    get {
        userDefaults.bool(forKey: UnifiedSettingsKeys.useRamadanIshaOffset) != false
            ? userDefaults.bool(forKey: UnifiedSettingsKeys.useRamadanIshaOffset)
            : true  // Default: ON
    }
    set {
        userDefaults.set(newValue, forKey: UnifiedSettingsKeys.useRamadanIshaOffset)
    }
}

/// Show long-range precision (exact times beyond 12 months)
public var showLongRangePrecision: Bool {
    get {
        userDefaults.bool(forKey: UnifiedSettingsKeys.showLongRangePrecision)
    }
    set {
        userDefaults.set(newValue, forKey: UnifiedSettingsKeys.showLongRangePrecision)
    }
}
```

**Add to UnifiedSettingsKeys**:

```swift
// File: DeenBuddy/Frameworks/DeenAssistCore/Constants/UnifiedSettingsKeys.swift

extension UnifiedSettingsKeys {
    static let maxLookaheadMonths = "maxLookaheadMonths"
    static let useRamadanIshaOffset = "useRamadanIshaOffset"
    static let showLongRangePrecision = "showLongRangePrecision"
}
```

**Validation**:
- [ ] Settings persist correctly in UserDefaults
- [ ] Default values are appropriate for Islamic accuracy
- [ ] Settings changes invalidate cached prayer times

---

## Phase 6: Mock Service Implementation (3 hours)

### Task 6.1: Extend MockPrayerTimeService

**File**: `DeenBuddy/Frameworks/DeenAssistUI/Mocks/MockPrayerTimeService.swift` (EXTEND)

**Add mock implementations**:

```swift
// MARK: - Future Prayer Times Mock Implementation

public func getFuturePrayerTimes(for date: Date, location: CLLocation?) async throws -> FuturePrayerTimeResult {
    // Check if we should simulate an error
    if shouldSimulateError {
        throw PrayerTimeError.calculationFailed
    }

    // Generate mock prayer times
    let prayerTimes = generateMockPrayerTimes(for: date)

    // Check if Ramadan (mock: March 2025)
    let calendar = Calendar.current
    let isRamadan = calendar.component(.month, from: date) == 3 &&
                    calendar.component(.year, from: date) == 2025

    // Get disclaimer level
    let disclaimerLevel = try validateLookaheadDate(date)

    // Check high latitude
    let isHighLat = location.map { isHighLatitudeLocation($0) } ?? false

    // Get Hijri date
    let hijriDate = HijriDate(day: 15, month: 9, year: 1446, monthName: "Ramadan")

    return FuturePrayerTimeResult(
        date: date,
        prayerTimes: prayerTimes,
        hijriDate: hijriDate,
        isRamadan: isRamadan,
        disclaimerLevel: disclaimerLevel,
        calculationTimezone: TimeZone.current,
        isHighLatitude: isHighLat,
        precision: .exact
    )
}

public func getFuturePrayerTimes(from startDate: Date, to endDate: Date, location: CLLocation?) async throws -> [FuturePrayerTimeResult] {
    var results: [FuturePrayerTimeResult] = []
    var currentDate = startDate
    let calendar = Calendar.current

    while currentDate <= endDate {
        let result = try await getFuturePrayerTimes(for: currentDate, location: location)
        results.append(result)

        guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
            break
        }
        currentDate = nextDate
    }

    return results
}

public func validateLookaheadDate(_ date: Date) throws -> DisclaimerLevel {
    let calendar = Calendar.current
    let today = Date()

    if calendar.isDate(date, inSameDayAs: today) {
        return .today
    }

    guard let monthsDiff = calendar.dateComponents([.month], from: today, to: date).month else {
        throw PrayerTimeError.invalidDate
    }

    guard monthsDiff <= 60 else {
        throw PrayerTimeError.lookaheadLimitExceeded(requested: monthsDiff, maximum: 60)
    }

    switch monthsDiff {
    case 0...12:
        return .shortTerm
    case 13...60:
        return .mediumTerm
    default:
        return .longTerm
    }
}

public func isHighLatitudeLocation(_ location: CLLocation) -> Bool {
    return abs(location.coordinate.latitude) > 55.0
}

// MARK: - Mock Data Generation

private func generateMockPrayerTimes(for date: Date) -> [PrayerTime] {
    let calendar = Calendar.current

    // Base times (will vary by season/location in real implementation)
    return [
        PrayerTime(name: .fajr, time: calendar.date(bySettingHour: 5, minute: 30, second: 0, of: date)!),
        PrayerTime(name: .dhuhr, time: calendar.date(bySettingHour: 12, minute: 15, second: 0, of: date)!),
        PrayerTime(name: .asr, time: calendar.date(bySettingHour: 15, minute: 45, second: 0, of: date)!),
        PrayerTime(name: .maghrib, time: calendar.date(bySettingHour: 18, minute: 30, second: 0, of: date)!),
        PrayerTime(name: .isha, time: calendar.date(bySettingHour: 20, minute: 0, second: 0, of: date)!)
    ]
}

// MARK: - Mock Configuration

public var shouldSimulateError = false
public var shouldSimulateHighLatitude = false
public var shouldSimulateRamadan = false
```

**Validation**:
- [ ] Mock service compiles and conforms to protocol
- [ ] Test data covers various scenarios (normal, Ramadan, high-latitude, DST transitions)
- [ ] Configurable mock behavior for different test cases

---

## Phase 7: Unit Testing (12 hours)

### Task 7.1: Create FuturePrayerTimesTests.swift

**File**: `DeenBuddyTests/FuturePrayerTimesTests.swift` (NEW)

**Test Coverage Requirements**:

```swift
import XCTest
@testable import DeenAssistCore

final class FuturePrayerTimesTests: XCTestCase {
    var sut: PrayerTimeService!
    var mockLocationService: MockLocationService!
    var mockIslamicCalendarService: MockIslamicCalendarService!
    var mockSettingsService: MockSettingsService!

    override func setUp() {
        super.setUp()
        mockLocationService = MockLocationService()
        mockIslamicCalendarService = MockIslamicCalendarService()
        mockSettingsService = MockSettingsService()

        sut = PrayerTimeService(
            locationService: mockLocationService,
            islamicCalendarService: mockIslamicCalendarService,
            settingsService: mockSettingsService
        )
    }

    // MARK: - Future Prayer Time Calculation Tests

    func testFuturePrayerTimes_6MonthsOut_NYC() async throws {
        // Given
        let nyc = CLLocation(latitude: 40.7128, longitude: -74.0060)
        let futureDate = Calendar.current.date(byAdding: .month, value: 6, to: Date())!

        // When
        let result = try await sut.getFuturePrayerTimes(for: futureDate, location: nyc)

        // Then
        XCTAssertEqual(result.prayerTimes.count, 5)
        XCTAssertEqual(result.disclaimerLevel, .shortTerm)
        XCTAssertFalse(result.isHighLatitude)
        XCTAssertEqual(result.calculationTimezone, TimeZone.current)
    }

    func testFuturePrayerTimes_2YearsOut_Riyadh() async throws {
        // Given
        let riyadh = CLLocation(latitude: 24.7136, longitude: 46.6753)
        let futureDate = Calendar.current.date(byAdding: .year, value: 2, to: Date())!

        // When
        let result = try await sut.getFuturePrayerTimes(for: futureDate, location: riyadh)

        // Then
        XCTAssertEqual(result.disclaimerLevel, .mediumTerm)
        XCTAssertFalse(result.isHighLatitude)
    }

    func testFuturePrayerTimes_5YearsOut_ThrowsOrWarns() async throws {
        // Given
        let location = CLLocation(latitude: 40.7128, longitude: -74.0060)
        let futureDate = Calendar.current.date(byAdding: .year, value: 5, to: Date())!
        mockSettingsService.maxLookaheadMonths = 60

        // When
        let result = try await sut.getFuturePrayerTimes(for: futureDate, location: location)

        // Then
        XCTAssertEqual(result.disclaimerLevel, .longTerm)
    }

    // MARK: - DST Boundary Tests

    func testDSTTransition_SpringForward_2025() async throws {
        // Given: March 9, 2025 (day before DST) vs March 11, 2025 (day after DST)
        let nyc = CLLocation(latitude: 40.7128, longitude: -74.0060)
        let beforeDST = DateComponents(calendar: .current, year: 2025, month: 3, day: 9).date!
        let afterDST = DateComponents(calendar: .current, year: 2025, month: 3, day: 11).date!

        // When
        let resultBefore = try await sut.getFuturePrayerTimes(for: beforeDST, location: nyc)
        let resultAfter = try await sut.getFuturePrayerTimes(for: afterDST, location: nyc)

        // Then: Should see ~1 hour difference due to DST
        let fajrBefore = resultBefore.prayerTimes.first { $0.name == .fajr }!
        let fajrAfter = resultAfter.prayerTimes.first { $0.name == .fajr }!

        // DST should affect the times (exact difference may vary by calculation method)
        XCTAssertNotEqual(fajrBefore.time, fajrAfter.time)
    }

    func testDSTTransition_FallBack_2025() async throws {
        // Given: November 2, 2025 (day before DST) vs November 3, 2025 (day after DST)
        let nyc = CLLocation(latitude: 40.7128, longitude: -74.0060)
        let beforeDST = DateComponents(calendar: .current, year: 2025, month: 11, day: 1).date!
        let afterDST = DateComponents(calendar: .current, year: 2025, month: 11, day: 3).date!

        // When
        let resultBefore = try await sut.getFuturePrayerTimes(for: beforeDST, location: nyc)
        let resultAfter = try await sut.getFuturePrayerTimes(for: afterDST, location: nyc)

        // Then
        XCTAssertNotEqual(resultBefore.prayerTimes.first?.time, resultAfter.prayerTimes.first?.time)
    }

    // MARK: - Ramadan Isha Offset Tests

    func testRamadanIshaOffset_UmmAlQura_Applied() async throws {
        // Given: Date in Ramadan 2025 (March)
        let ramadanDate = DateComponents(calendar: .current, year: 2025, month: 3, day: 15).date!
        let location = CLLocation(latitude: 24.7136, longitude: 46.6753) // Riyadh

        mockSettingsService.calculationMethod = .ummAlQura
        mockSettingsService.useRamadanIshaOffset = true
        mockIslamicCalendarService.mockIsRamadan = true

        // When
        let result = try await sut.getFuturePrayerTimes(for: ramadanDate, location: location)

        // Then
        XCTAssertTrue(result.isRamadan)
        let ishaTime = result.prayerTimes.first { $0.name == .isha }!
        XCTAssertTrue(ishaTime.isRamadanAdjusted ?? false)
    }

    func testRamadanIshaOffset_Qatar_Applied() async throws {
        // Similar test for Qatar method
        let ramadanDate = DateComponents(calendar: .current, year: 2025, month: 3, day: 15).date!
        let location = CLLocation(latitude: 25.2854, longitude: 51.5310) // Doha

        mockSettingsService.calculationMethod = .qatar
        mockSettingsService.useRamadanIshaOffset = true
        mockIslamicCalendarService.mockIsRamadan = true

        // When
        let result = try await sut.getFuturePrayerTimes(for: ramadanDate, location: location)

        // Then
        XCTAssertTrue(result.isRamadan)
    }

    func testRamadanIshaOffset_ToggleOff_NotApplied() async throws {
        // Given
        let ramadanDate = DateComponents(calendar: .current, year: 2025, month: 3, day: 15).date!
        let location = CLLocation(latitude: 24.7136, longitude: 46.6753)

        mockSettingsService.calculationMethod = .ummAlQura
        mockSettingsService.useRamadanIshaOffset = false  // User disabled
        mockIslamicCalendarService.mockIsRamadan = true

        // When
        let result = try await sut.getFuturePrayerTimes(for: ramadanDate, location: location)

        // Then
        let ishaTime = result.prayerTimes.first { $0.name == .isha }!
        XCTAssertFalse(ishaTime.isRamadanAdjusted ?? false)
    }

    // MARK: - High-Latitude Tests

    func testHighLatitude_Oslo_FlagSet() async throws {
        // Given: Oslo, Norway (59.9°N)
        let oslo = CLLocation(latitude: 59.9139, longitude: 10.7522)
        let futureDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())!

        // When
        let result = try await sut.getFuturePrayerTimes(for: futureDate, location: oslo)

        // Then
        XCTAssertTrue(result.isHighLatitude)
    }

    func testHighLatitude_Tromso_FlagSet() async throws {
        // Given: Tromsø, Norway (69.6°N) - extreme latitude
        let tromso = CLLocation(latitude: 69.6492, longitude: 18.9553)
        let futureDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())!

        // When
        let result = try await sut.getFuturePrayerTimes(for: futureDate, location: tromso)

        // Then
        XCTAssertTrue(result.isHighLatitude)
    }

    func testNormalLatitude_Sydney_FlagNotSet() async throws {
        // Given: Sydney, Australia (-33.8°S)
        let sydney = CLLocation(latitude: -33.8688, longitude: 151.2093)
        let futureDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())!

        // When
        let result = try await sut.getFuturePrayerTimes(for: futureDate, location: sydney)

        // Then
        XCTAssertFalse(result.isHighLatitude)
    }

    // MARK: - Madhab Impact Tests

    func testMadhab_Hanafi_AsrTiming() async throws {
        // Given
        let location = CLLocation(latitude: 40.7128, longitude: -74.0060)
        let futureDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())!

        mockSettingsService.madhab = .hanafi

        // When
        let result = try await sut.getFuturePrayerTimes(for: futureDate, location: location)

        // Then: Hanafi Asr should be later than Shafi (2x shadow vs 1x shadow)
        let asrTime = result.prayerTimes.first { $0.name == .asr }!
        XCTAssertNotNil(asrTime)
    }

    func testMadhab_Shafi_AsrTiming() async throws {
        // Similar test for Shafi madhab
        let location = CLLocation(latitude: 40.7128, longitude: -74.0060)
        let futureDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())!

        mockSettingsService.madhab = .shafi

        // When
        let result = try await sut.getFuturePrayerTimes(for: futureDate, location: location)

        // Then
        let asrTime = result.prayerTimes.first { $0.name == .asr }!
        XCTAssertNotNil(asrTime)
    }

    // MARK: - Disclaimer Level Tests

    func testDisclaimerLevel_Today() throws {
        // Given
        let today = Date()

        // When
        let level = try sut.validateLookaheadDate(today)

        // Then
        XCTAssertEqual(level, .today)
        XCTAssertFalse(level.requiresBanner)
    }

    func testDisclaimerLevel_6Months() throws {
        // Given
        let futureDate = Calendar.current.date(byAdding: .month, value: 6, to: Date())!

        // When
        let level = try sut.validateLookaheadDate(futureDate)

        // Then
        XCTAssertEqual(level, .shortTerm)
        XCTAssertTrue(level.requiresBanner)
        XCTAssertEqual(level.bannerMessage, "Calculated times. Subject to DST changes and official mosque schedules.")
    }

    func testDisclaimerLevel_2Years() throws {
        // Given
        let futureDate = Calendar.current.date(byAdding: .year, value: 2, to: Date())!

        // When
        let level = try sut.validateLookaheadDate(futureDate)

        // Then
        XCTAssertEqual(level, .mediumTerm)
        XCTAssertTrue(level.requiresBanner)
    }

    func testPrecisionPolicy_LongRange_UsesWindowWhenDisabled() async throws {
        // Given
        let futureDate = Calendar.current.date(byAdding: .year, value: 2, to: Date())!
        mockSettingsService.showLongRangePrecision = false

        // When
        let result = try await sut.getFuturePrayerTimes(for: futureDate, location: nil)

        // Then
        switch result.precision {
        case .window:
            XCTAssertTrue(true)
        default:
            XCTFail("Expected windowed precision for medium-term when long-range precision is disabled")
        }
    }

    func testDisclaimerLevel_ExceedsLimit_Throws() {
        // Given
        let futureDate = Calendar.current.date(byAdding: .year, value: 10, to: Date())!
        mockSettingsService.maxLookaheadMonths = 60

        // When/Then
        XCTAssertThrowsError(try sut.validateLookaheadDate(futureDate)) { error in
            guard case PrayerTimeError.lookaheadLimitExceeded = error else {
                XCTFail("Expected lookaheadLimitExceeded error")
                return
            }
        }
    }

    // MARK: - Batch Calculation Tests

    func testBatchCalculation_90Days_Success() async throws {
        // Given
        let location = CLLocation(latitude: 40.7128, longitude: -74.0060)
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 90, to: startDate)!

        // When
        let results = try await sut.getFuturePrayerTimes(from: startDate, to: endDate, location: location)

        // Then
        XCTAssertEqual(results.count, 91) // Inclusive of start and end
    }

    func testBatchCalculation_ExceedsLimit_Throws() async {
        // Given
        let location = CLLocation(latitude: 40.7128, longitude: -74.0060)
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 100, to: startDate)!

        // When/Then
        await XCTAssertThrowsError(try await sut.getFuturePrayerTimes(from: startDate, to: endDate, location: location))
    }
}
```

**Additional Test Files**:

#### Task 7.2: Create IslamicCalendarServiceTests.swift

Test Ramadan estimation, Eid estimation, confidence levels

#### Task 7.3: Create SettingsMigrationTests.swift (EXTEND)

Test new settings persist and migrate correctly

**Validation Checklist**:
- [ ] All unit tests pass
- [ ] Test coverage >80% for new code
- [ ] Islamic accuracy validated against known correct prayer times
- [ ] DST transitions handled correctly
- [ ] Ramadan Isha offset applies correctly
- [ ] High-latitude detection works for Oslo, Tromsø, Sydney test cases
- [ ] Madhab differences reflected in Asr times

---

## Phase 8: Integration Testing (2 hours)

### Task 8.1: Create BackendIntegrationTests.swift

**File**: `DeenBuddyTests/BackendIntegrationTests.swift` (NEW)

**Test end-to-end flows**:
- Service initialization and dependency resolution
- Future prayer time calculation with all services integrated
- Cache invalidation when settings change
- Error propagation through service layers

**Validation**:
- [ ] All services integrate correctly
- [ ] Dependency injection resolves services properly
- [ ] Cache invalidation works when settings change
- [ ] Error handling cascades appropriately

---

## Phase 9: Documentation & Knowledge Storage (2 hours)

### Task 9.1: Document Islamic Logic

**Add comprehensive documentation**:

```swift
/// ISLAMIC ACCURACY NOTES:
///
/// DST Handling:
/// - CRITICAL: Always use iOS TZDB rules (TimeZone.current)
/// - Never implement custom DST logic - delegate to iOS
/// - Political DST changes invalidate future calculations (covered by disclaimers)
///
/// Ramadan Isha Offset:
/// - Umm Al Qura method: Default 90m, Ramadan 120m (90m + 30m)
/// - Qatar method: Same as Umm Al Qura
/// - Rationale: Conservative approach, errs to later time for safety
/// - User can disable via settings if following different authority
///
/// High-Latitude Handling:
/// - Detect: latitude > 55° or < -55°
/// - Adhan Swift uses fallback methods (1/7 night, middle of night, angle-based)
/// - Always show warning banner for high-latitude locations
/// - Consider limiting lookahead to 12 months for extreme latitudes
///
/// Disclaimer Requirements (EXACT COPY):
/// - Short-term: "Calculated times. Subject to DST changes and official mosque schedules."
/// - Medium-term: "Long-range estimate. DST rules and local authorities may differ. Verify closer to date."
/// - High-latitude: "High-latitude adjustment in use. Times are approximations. Check your local mosque."
/// - Ramadan/Eid: "Estimated by astronomical calculation (planning only). Actual dates set by your local Islamic authority."
```

### Task 9.2: Store Knowledge in Byterover

Run after implementation complete:

```bash
# Store critical knowledge
byterover-store-knowledge "Future prayer time calculations use iOS TZDB rules exclusively. No custom DST logic. Ramadan Isha offset adds 30 minutes to Umm Al Qura/Qatar methods during Hijri month 9. High-latitude detection >55° triggers warning banner. Disclaimer copy is EXACT and non-negotiable for fiqh compliance."
```

**Validation**:
- [ ] Code documentation is comprehensive
- [ ] Islamic accuracy considerations are documented
- [ ] Knowledge stored in Byterover for future reference
- [ ] CLAUDE.md updated with feature overview

---

## Completion Criteria

### Backend is DONE when:

**Functional Requirements**:
- [ ] All data models compile and are production-ready
- [ ] Service protocol extensions are complete
- [ ] PrayerTimeService implements all future prayer methods
- [ ] IslamicCalendarService implements event estimation
- [ ] SettingsService has all feature flag settings
- [ ] Mock services fully implement new protocols

**Quality Requirements**:
- [ ] All unit tests pass (>80% coverage)
- [ ] Integration tests pass
- [ ] No compilation errors or warnings
- [ ] SwiftLint passes (if configured)
- [ ] No force unwraps or unsafe code

**Islamic Accuracy Requirements** (CRITICAL):
- [ ] Prayer time calculations validated against known accurate sources
- [ ] DST transitions handled correctly (Spring/Fall)
- [ ] Ramadan Isha offset applies correctly for Umm Al Qura/Qatar
- [ ] High-latitude detection works (Oslo, Tromsø, Sydney test cases)
- [ ] Madhab differences reflected in Asr times (Hanafi vs Shafi)
- [ ] Disclaimer messages use EXACT approved copy (no variations)
- [ ] All Islamic logic documented and explained

**Documentation Requirements**:
- [ ] Code comments explain Islamic significance
- [ ] Fiqh compliance requirements documented
- [ ] Edge cases and limitations documented
- [ ] Knowledge stored in Byterover

---

## Handoff to Frontend Team

**After backend completion**:

1. **Verify all protocols are implemented**:
   - `PrayerTimeServiceProtocol` extended
   - `IslamicCalendarServiceProtocol` extended
   - Mock services fully functional

2. **Confirm test coverage**:
   - Share test results and coverage report
   - Document any edge cases found during testing

3. **Provide integration guide**:
   - How to resolve services via DependencyContainer
   - How to call future prayer time methods
   - How to handle errors and loading states

4. **Islamic accuracy validation**:
   - Share test data and expected results
   - Provide calculation method/madhab combinations tested
   - Document any known limitations or edge cases

**Frontend team can now proceed with UI implementation using fully functional backend services.**

---

## Emergency Contacts

**If you encounter blocking issues**:
- Adhan Swift library documentation: https://github.com/batoulapps/adhan-swift
- Islamic calendar calculations: Umm Al Qura system documentation
- DST/Timezone issues: iOS TimeZone class documentation
- Fiqh questions: Consult Islamic authority or defer to local mosque

**Remember**: Religious accuracy is non-negotiable. When in doubt, show stronger disclaimers and defer to local Islamic authority.
