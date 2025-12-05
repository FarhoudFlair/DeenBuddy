<!-- 01df18d3-263a-4578-af31-b4f0ac3c36f0 2765d0af-c3e6-452d-b91a-e6627b225c3d -->
# Islamic Calendar & Future Prayer Times - Implementation Plan

## Overview

This plan implements a new screen accessible via the HomeScreen Quick Action that allows users to:

- Select future dates up to 5 years out
- View calculated prayer times for those dates
- See Islamic calendar events (Ramadan, Eid estimates)
- Understand calculation limitations through mandatory disclaimers

**Critical Requirement:** All disclaimers must use EXACT approved copy - no creative variations. Religious accuracy is non-negotiable.

---

## Phase 1: Backend Foundation (Data Layer)

### 1.1 Core Models

**File:** `DeenBuddy/Frameworks/DeenAssistCore/Models/FuturePrayerTimeModels.swift` (NEW)

Create the following models:

- `FuturePrayerTimeRequest` - Input for future prayer time calculations
- `FuturePrayerTimeResult` - Output with prayer times, hijri date, isRamadan flag, disclaimerLevel, isHighLatitude
- `DisclaimerLevel` enum (today, shortTerm 0-12m, mediumTerm 12-60m, longTerm >60m)
- `IslamicEventEstimate` with `EventConfidence` (high/medium/low)
- `PrecisionLevel` enum (exact, window, timeOfDay)

### 1.2 Extend PrayerTimeServiceProtocol

**File:** `DeenBuddy/Frameworks/DeenAssistProtocols/PrayerTimeServiceProtocol.swift` (EXTEND)

Add new protocol methods:

```swift
func getFuturePrayerTimes(for date: Date, location: CLLocation?) async throws -> FuturePrayerTimeResult
func getFuturePrayerTimes(from startDate: Date, to endDate: Date, location: CLLocation?) async throws -> [FuturePrayerTimeResult]
func validateLookaheadDate(_ date: Date) throws -> DisclaimerLevel
func isHighLatitudeLocation(_ location: CLLocation) -> Bool
```

### 1.3 Implement Future Prayer Time Logic

**File:** `DeenBuddy/Frameworks/DeenAssistCore/Services/PrayerTimeService.swift` (EXTEND)

Implementation requirements:

- Use existing `calculatePrayerTimes(for:date:)` with future dates
- Always recalculate using current iOS TZDB rules (no custom DST logic)
- Detect Ramadan via existing `IslamicCalendarService.isRamadan()` 
- Apply +30m Isha offset for Umm Al Qura/Qatar during Ramadan (Hijri month 9)
- High-latitude detection (>55° or <-55° latitude)
- Cache results with 7-day TTL using existing `IslamicCacheManager`

### 1.4 Extend IslamicCalendarService

**File:** `DeenBuddy/Frameworks/DeenAssistCore/Services/IslamicCalendarService.swift` (EXTEND)

Add methods for future event estimation:

```swift
func estimateRamadanDates(for hijriYear: Int) async -> DateInterval?
func estimateEidAlFitr(for hijriYear: Int) async -> Date?
func estimateEidAlAdha(for hijriYear: Int) async -> Date?
func getEventConfidence(for date: Date) -> EventConfidence
func isDateInRamadan(_ date: Date) async -> Bool
```

### 1.5 Add Feature Flag Settings

**File:** `DeenBuddy/Frameworks/DeenAssistCore/Services/SettingsService.swift` (EXTEND)

Add new settings properties:

- `maxLookaheadMonths: Int` (default: 60)
- `useRamadanIshaOffset: Bool` (default: true)
- `showLongRangePrecision: Bool` (default: false)

---

## Phase 2: UI Components (~14 hours)

### 2.1 Disclaimer Banner Component (3 hours)

**File:** `DeenBuddy/Frameworks/DeenAssistUI/Components/DisclaimerBanner.swift` (NEW)

**EXACT COPY REQUIREMENTS (NO VARIATIONS):**

- **Standard (0-12m):** "Calculated times. Subject to DST changes and official mosque schedules."
- **Medium-term (12-60m):** "Long-range estimate. DST rules and local authorities may differ. Verify closer to date."
- **High-latitude:** "High-latitude adjustment in use. Times are approximations. Check your local mosque."
- **Ramadan/Eid:** "Estimated by astronomical calculation (planning only). Actual dates set by your local Islamic authority."

**Visual Specifications (from design spec):**

- Variants: shortTerm (yellow `#FFF8E1`), mediumTerm (orange `#FFE0B2`), highLatitude (red `#FFCCBC`), ramadanEid (purple/gold gradient)
- Icons: `info.circle.fill`, `exclamationmark.triangle.fill`, `location.fill`, `moon.stars.fill`
- Full-width with 16pt padding, 12pt corner radius
- Session-dismissible with "Don't show again" (but always visible for non-today dates in production)
- Animation: Slide in from top (0.3s ease-out), fade out on dismiss (0.2s)

**Accessibility:**

- `accessibilityLabel`: "Important notice: [full disclaimer text]"
- `accessibilityAddTraits(.isStaticText)`

### 2.2 Islamic Date Picker Component

**File:** `DeenBuddy/Frameworks/DeenAssistUI/Components/IslamicDatePicker.swift` (NEW)

Features:

- Dual calendar display (Gregorian + Hijri using existing `HijriDate`)
- Event indicators (dots for Ramadan/Eid)
- Swipe navigation for months
- Disabled state for dates beyond lookahead limit
- VoiceOver support with both date formats

### 2.3 Future Prayer Times List Component

**File:** `DeenBuddy/Frameworks/DeenAssistUI/Components/FuturePrayerTimesList.swift` (NEW)

Features:

- Display 5 daily prayers with times (reuse existing prayer icons from HomeScreen)
- Ramadan Isha "+30m" badge indicator
- Precision-based display (exact HH:mm vs window "6:15-6:45 AM")
- Use existing `PremiumDesignTokens` for styling

### 2.4 Islamic Event Card Component

**File:** `DeenBuddy/Frameworks/DeenAssistUI/Components/IslamicEventCard.swift` (NEW)

Features:

- Event name, icon (moon.stars.fill for Ramadan, star.fill for Eid)
- Confidence indicator (green/yellow/orange capsule)
- "(Planning only)" label for Ramadan/Eid
- Gradient backgrounds matching event type

### 2.5 Calculation Info Footer Component

**File:** `DeenBuddy/Frameworks/DeenAssistUI/Components/CalculationInfoFooter.swift` (NEW)

Required content:

- Calculation method (read-only, from SettingsService)
- Madhab (read-only, from SettingsService)
- Timezone (device timezone)
- **REQUIRED:** "Defer to local authority for official prayer times."
- **Conditional (Ramadan + Umm Al Qura/Qatar):** "Isha in Ramadan: 90m + 30m; errs to later for safety."
- Link to Settings screen

---

## Phase 3: Main Screen & ViewModel

### 3.1 Islamic Calendar Screen

**File:** `DeenBuddy/Frameworks/DeenAssistUI/Screens/IslamicCalendarScreen.swift` (NEW)

Screen structure (top to bottom):

1. Navigation bar with "Islamic Calendar" title and "Today" button
2. DisclaimerBanner (if not today)
3. High-latitude warning banner (if applicable)
4. IslamicDatePicker
5. IslamicEventCard (if events on selected date)
6. FuturePrayerTimesList
7. CalculationInfoFooter

### 3.2 ViewModel

**File:** `DeenBuddy/ViewModels/IslamicCalendarViewModel.swift` (NEW)

```swift
@MainActor
class IslamicCalendarViewModel: ObservableObject {
    @Published var selectedDate: Date
    @Published var prayerTimeResult: FuturePrayerTimeResult?
    @Published var islamicEvents: [IslamicEventEstimate]
    @Published var isLoading: Bool
    @Published var error: AppError?
    @Published var disclaimerLevel: DisclaimerLevel
    @Published var showHighLatitudeWarning: Bool
    @Published var isDisclaimerDismissed: Bool
    
    // Injected services (via init)
    private let prayerTimeService: any PrayerTimeServiceProtocol
    private let islamicCalendarService: any IslamicCalendarServiceProtocol
    private let locationService: any LocationServiceProtocol
    private let settingsService: any SettingsServiceProtocol
}
```

---

## Phase 4: Navigation Integration

### 4.1 Add Navigation State to AppCoordinator

**File:** `DeenBuddy/Frameworks/DeenAssistUI/Navigation/AppCoordinator.swift` (EXTEND)

Add:

```swift
@Published public var showingIslamicCalendar = false

public func showIslamicCalendar() {
    showingIslamicCalendar = true
}

public func dismissIslamicCalendar() {
    showingIslamicCalendar = false
}
```

### 4.2 Wire HomeScreen Quick Action

**File:** `DeenBuddy/Frameworks/DeenAssistUI/Navigation/AppCoordinator.swift` (EXTEND)

In `SimpleTabView` and `MainAppView`, update HomeScreen initialization:

```swift
onCalendarTapped: { coordinator.showIslamicCalendar() }
```

Add sheet presentation for Islamic Calendar screen.

### 4.3 Handle Deep Link (Optional)

Add case for "calendar" deep link in `handleDeepLink(_:)`.

---

## Phase 5: Testing

### 5.1 Unit Tests - Future Prayer Times

**File:** `DeenBuddyTests/FuturePrayerTimesTests.swift` (NEW)

Test cases:

- Future prayer calculation (6m, 2y, 5y out)
- DST boundary handling (Spring/Fall transitions)
- Ramadan Isha +30m offset (Umm Al Qura/Qatar methods)
- High-latitude detection (Oslo 60°N, Tromsø 69°N, Sydney -33°S)
- Long-range precision degradation rules
- Hanafi/Shafi/Ja'fari madhab impact
- Hijri month 9 (Ramadan) detection

### 5.2 Integration Tests

**File:** `DeenBuddyTests/IslamicCalendarIntegrationTests.swift` (NEW)

Test scenarios:

- Full user flow (navigate → select date → verify calculations)
- DST transition verification
- Ramadan flow (event shown, Isha +30m, toggle on/off)
- High-latitude flow (warning shown, fallback method used)
- Settings changes trigger recalculation

### 5.3 Update Mock Services

**File:** `DeenBuddy/Frameworks/DeenAssistUI/Mocks/MockPrayerTimeService.swift` (EXTEND)

Add mock implementations for new protocol methods with configurable test data.

---

## Fiqh Compliance Checklist (QA Gate)

**MUST PASS before release:**

- [ ] All non-today dates show disclaimer banner
- [ ] Banner messages use EXACT approved copy
- [ ] Ramadan/Eid labeled "(Planning only)"
- [ ] High-latitude warning for >55° latitude
- [ ] Umm Al Qura Ramadan footnote visible when applicable
- [ ] "Defer to local authority" footer on ALL future date views
- [ ] No exact times beyond 5 years (or strongest red warning)
- [ ] Calculation method, madhab, timezone displayed read-only

---

## Files Summary

**NEW Files (14):**

1. `DeenAssistCore/Models/FuturePrayerTimeModels.swift`
2. `DeenAssistUI/Components/DisclaimerBanner.swift`
3. `DeenAssistUI/Components/IslamicDatePicker.swift`
4. `DeenAssistUI/Components/FuturePrayerTimesList.swift`
5. `DeenAssistUI/Components/IslamicEventCard.swift`
6. `DeenAssistUI/Components/CalculationInfoFooter.swift`
7. `DeenAssistUI/Screens/IslamicCalendarScreen.swift`
8. `ViewModels/IslamicCalendarViewModel.swift`
9. `DeenBuddyTests/FuturePrayerTimesTests.swift`
10. `DeenBuddyTests/IslamicCalendarIntegrationTests.swift`

**EXTENDED Files (6):**

1. `DeenAssistProtocols/PrayerTimeServiceProtocol.swift`
2. `DeenAssistCore/Services/PrayerTimeService.swift`
3. `DeenAssistCore/Services/IslamicCalendarService.swift`
4. `DeenAssistCore/Services/SettingsService.swift`
5. `DeenAssistUI/Navigation/AppCoordinator.swift`
6. `DeenAssistUI/Mocks/MockPrayerTimeService.swift`

---

## Risk Mitigations

| Risk | Impact | Mitigation |

|------|--------|------------|

| DST political changes | High | Always recalculate with current TZDB; show disclaimer |

| Islamic calendar drift | High | Label as "estimates"; "(planning only)" required |

| High-latitude unreliability | Medium | Detect >55°; show warning; consider time windows |

| User reliance on long-range times | Medium | Avoid exact times >5y; red warning for >60m |