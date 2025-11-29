# Islamic Calendar & Future Prayer Times - Frontend Implementation Tasks

**CRITICAL NOTICE**: This UI serves the Muslim community for religious practice. Visual accuracy, correct disclaimer display, and accessibility are paramount. Any UI bugs that hide disclaimers or show incorrect times could harm users' religious practice.

**PREREQUISITES**: Backend implementation MUST be complete before starting frontend work. Verify all backend services are functional and tested.

---

## Pre-Implementation Checklist

- [ ] Backend implementation is complete and all tests pass
- [ ] Review design specification document thoroughly
- [ ] Understand EXACT disclaimer copy requirements (no creative variations)
- [ ] Align with backend models/services:
  - `FuturePrayerTimeResult.precision` (exact vs window) and `disclaimerLevel` drive UI formatting/banners
  - Call `prayerTimeService.getFuturePrayerTimes(for:location:)` or range variant; handle `lookaheadLimitExceeded/dateRangeTooLarge`
  - Ramadan/Eid estimates come from `IslamicCalendarService` (`isDateInRamadan`, `estimateRamadanDates`, `estimateEidAlFitr`, `estimateEidAlAdha`, `getEventConfidence`)
- [ ] Verify PremiumDesignTokens, Colors, Typography, and Animations exist
- [ ] Run `byterover-retrieve-knowledge` for "SwiftUI components", "DeenBuddy design system"
- [ ] Confirm mock services are functional for UI development

---

## Phase 1: Core UI Components (14 hours)

### Task 1.1: Disclaimer Banner Component (3 hours)

**File**: `DeenBuddy/Frameworks/DeenAssistUI/Components/DisclaimerBanner.swift` (NEW)

**EXACT DISCLAIMER COPY** (non-negotiable):
- **Standard (0-12m)**: "Calculated times. Subject to DST changes and official mosque schedules."
- **Medium-term (12-60m)**: "Long-range estimate. DST rules and local authorities may differ. Verify closer to date."
- **High-latitude**: "High-latitude adjustment in use. Times are approximations. Check your local mosque."
- **Ramadan/Eid**: "Estimated by astronomical calculation (planning only). Actual dates set by your local Islamic authority."

**Implementation**:

```swift
import SwiftUI

/// Disclaimer banner for future prayer time calculations
/// CRITICAL: Copy must be EXACT as specified - no creative variations
public struct DisclaimerBanner: View {
    let type: DisclaimerType
    @Binding var isDismissed: Bool

    @Environment(\.currentTheme) private var currentTheme
    @Environment(\.colorScheme) private var colorScheme

    private var themeColors: ThemeAwareColorPalette {
        ThemeAwareColorPalette(theme: currentTheme)
    }

    public init(type: DisclaimerType, isDismissed: Binding<Bool>) {
        self.type = type
        self._isDismissed = isDismissed
    }

    public var body: some View {
        if !isDismissed {
            HStack(alignment: .top, spacing: 12) {
                // Icon
                Image(systemName: type.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(type.iconColor(colorScheme: colorScheme))
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                // Text content
                VStack(alignment: .leading, spacing: 8) {
                    Text(type.title)
                        .font(Typography.titleMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(type.textColor(colorScheme: colorScheme))

                    Text(type.message)
                        .font(Typography.bodyMedium)
                        .foregroundColor(type.textColor(colorScheme: colorScheme).opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Dismiss button (session only - ALWAYS visible in production for non-today dates)
                Button {
                    withAnimation(AppAnimations.standard) {
                        isDismissed = true
                        HapticFeedback.light()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(type.textColor(colorScheme: colorScheme).opacity(0.6))
                }
                .accessibilityLabel("Dismiss disclaimer")
                .accessibilityHint("Hides this disclaimer for the current session")
            }
            .padding(PremiumDesignTokens.spacing16)
            .background(
                RoundedRectangle(cornerRadius: PremiumDesignTokens.cornerRadius12)
                    .fill(type.backgroundColor(colorScheme: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PremiumDesignTokens.cornerRadius12)
                    .strokeBorder(type.borderColor(colorScheme: colorScheme), lineWidth: 1)
            )
            .premiumShadow(.level1)
            .padding(.horizontal, PremiumDesignTokens.spacing16)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Important notice: \(type.accessibilityMessage)")
            .accessibilityAddTraits(.isStaticText)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

/// Disclaimer types with EXACT copy requirements
public enum DisclaimerType {
    case standard
    case mediumTerm
    case highLatitude
    case ramadanEid

    var title: String {
        switch self {
        case .standard:
            return "Calculated Times"
        case .mediumTerm:
            return "Long-Range Estimate"
        case .highLatitude:
            return "High-Latitude Approximation"
        case .ramadanEid:
            return "Astronomical Estimate"
        }
    }

    /// EXACT COPY REQUIRED - DO NOT MODIFY
    var message: String {
        switch self {
        case .standard:
            return "Calculated times. Subject to DST changes and official mosque schedules."
        case .mediumTerm:
            return "Long-range estimate. DST rules and local authorities may differ. Verify closer to date."
        case .highLatitude:
            return "High-latitude adjustment in use. Times are approximations. Check your local mosque."
        case .ramadanEid:
            return "Estimated by astronomical calculation (planning only). Actual dates set by your local Islamic authority."
        }
    }

    var accessibilityMessage: String {
        message
    }

    var icon: String {
        switch self {
        case .standard:
            return "info.circle.fill"
        case .mediumTerm:
            return "exclamationmark.triangle.fill"
        case .highLatitude:
            return "location.fill"
        case .ramadanEid:
            return "moon.stars.fill"
        }
    }

    func backgroundColor(colorScheme: ColorScheme) -> Color {
        switch self {
        case .standard:
            return colorScheme == .dark
                ? Color.yellow.opacity(0.15)
                : Color(red: 1.0, green: 0.95, blue: 0.8) // #FFF8E1
        case .mediumTerm:
            return colorScheme == .dark
                ? Color.orange.opacity(0.2)
                : Color(red: 1.0, green: 0.88, blue: 0.7) // #FFE0B2
        case .highLatitude:
            return colorScheme == .dark
                ? Color.red.opacity(0.2)
                : Color(red: 1.0, green: 0.85, blue: 0.75) // #FFCCBC
        case .ramadanEid:
            return colorScheme == .dark
                ? Color.purple.opacity(0.2)
                : Color(red: 0.93, green: 0.84, blue: 0.96) // Light purple
        }
    }

    func borderColor(colorScheme: ColorScheme) -> Color {
        switch self {
        case .standard:
            return colorScheme == .dark ? Color.yellow.opacity(0.4) : Color.yellow.opacity(0.3)
        case .mediumTerm:
            return colorScheme == .dark ? Color.orange.opacity(0.5) : Color.orange.opacity(0.4)
        case .highLatitude:
            return colorScheme == .dark ? Color.red.opacity(0.5) : Color.red.opacity(0.4)
        case .ramadanEid:
            return colorScheme == .dark ? Color.purple.opacity(0.5) : Color.purple.opacity(0.4)
        }
    }

    func textColor(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white : Color.black
    }

    func iconColor(colorScheme: ColorScheme) -> Color {
        switch self {
        case .standard:
            return colorScheme == .dark ? Color.yellow : Color.orange
        case .mediumTerm:
            return Color.orange
        case .highLatitude:
            return Color.red
        case .ramadanEid:
            return colorScheme == .dark ? Color.purple : Color(red: 0.6, green: 0.1, blue: 0.7)
        }
    }
}
```

**Validation**:
- [ ] Component compiles without errors
- [ ] All 4 disclaimer variants display correctly
- [ ] Exact copy is used (character-for-character match)
- [ ] VoiceOver reads full disclaimer text
- [ ] Dynamic Type scales text appropriately
- [ ] Colors match design spec in both light and dark mode
- [ ] Animations are smooth and respect Reduce Motion
- [ ] Dismiss functionality works (session-only)

---

### Task 1.2: Islamic Date Picker Component (4 hours)

**File**: `DeenBuddy/Frameworks/DeenAssistUI/Components/IslamicDatePicker.swift` (NEW)

**Implementation** (based on design spec lines 341-639):

```swift
import SwiftUI

/// Islamic dual calendar date picker (Gregorian + Hijri)
public struct IslamicDatePicker: View {
    @Binding var selectedDate: Date
    let availableDateRange: ClosedRange<Date>
    let islamicEvents: [Date: IslamicEvent]

    @State private var displayedMonth: Date
    @State private var showMonthPicker = false

    @Environment(\.currentTheme) private var currentTheme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.calendar) private var calendar

    private var themeColors: ThemeAwareColorPalette {
        ThemeAwareColorPalette(theme: currentTheme)
    }

    private let hijriCalendar = Calendar(identifier: .islamicUmmAlQura)

    public init(
        selectedDate: Binding<Date>,
        availableDateRange: ClosedRange<Date>,
        islamicEvents: [Date: IslamicEvent] = [:]
    ) {
        self._selectedDate = selectedDate
        self.availableDateRange = availableDateRange
        self.islamicEvents = islamicEvents
        self._displayedMonth = State(initialValue: selectedDate.wrappedValue)
    }

    public var body: some View {
        VStack(spacing: PremiumDesignTokens.spacing16) {
            // Header with month/year and navigation
            headerView

            // Calendar grid
            calendarGridView
        }
        .padding(PremiumDesignTokens.spacing16)
        .background(
            RoundedRectangle(cornerRadius: PremiumDesignTokens.cornerRadius16)
                .fill(ColorPalette.surfacePrimary)
        )
        .premiumShadow(.level1)
        .sheet(isPresented: $showMonthPicker) {
            monthYearPickerView
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            // Previous month button
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(themeColors.primary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Previous month")

            Spacer()

            // Month/Year display (tappable for picker)
            Button {
                showMonthPicker = true
                HapticFeedback.light()
            } label: {
                VStack(spacing: 4) {
                    Text(gregorianMonthYear)
                        .font(Typography.titleLarge)
                        .fontWeight(.semibold)
                        .foregroundColor(ColorPalette.textPrimary)

                    Text(hijriMonthYear)
                        .font(Typography.bodyMedium)
                        .foregroundColor(ColorPalette.textSecondary)
                }
            }
            .accessibilityLabel("Current month: \(gregorianMonthYear) which is \(hijriMonthYear)")
            .accessibilityHint("Tap to select a different month")

            Spacer()

            // Next month button
            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(themeColors.primary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Next month")
        }
    }

    // MARK: - Calendar Grid

    private var calendarGridView: some View {
        let days = daysInMonth()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return VStack(spacing: 8) {
            // Weekday labels
            HStack(spacing: 0) {
                ForEach(calendar.veryShortWeekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(Typography.labelSmall)
                        .foregroundColor(ColorPalette.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(days.indices, id: \.self) { index in
                    if let date = days[index] {
                        dateCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
        }
    }

    private func dateCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let isDisabled = !availableDateRange.contains(date)
        let event = islamicEvents[date]

        return Button {
            if !isDisabled {
                selectedDate = date
                HapticFeedback.selection()
            }
        } label: {
            VStack(spacing: 2) {
                // Gregorian date number
                Text("\(calendar.component(.day, from: date))")
                    .font(Typography.titleMedium)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundColor(
                        isDisabled ? ColorPalette.textTertiary.opacity(0.3) :
                        isSelected ? Color.white :
                        isToday ? themeColors.primary :
                        ColorPalette.textPrimary
                    )

                // Event indicator dot
                if let event = event {
                    Circle()
                        .fill(event.color(colorScheme: colorScheme))
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeColors.primary)
                    } else if isToday {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(themeColors.primary, lineWidth: 2)
                    }
                }
            )
        }
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityLabel(for: date, event: event))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityHint(isDisabled ? "Date not available" : "Double tap to select")
    }

    // MARK: - Month/Year Picker

    private var monthYearPickerView: some View {
        NavigationView {
            VStack {
                Text("Month/Year Picker")
                    .font(Typography.headlineSmall)
                // TODO: Implement month/year picker UI
            }
            .navigationTitle("Select Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showMonthPicker = false
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private var gregorianMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var hijriMonthYear: String {
        let formatter = DateFormatter()
        formatter.calendar = hijriCalendar
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private func changeMonth(by offset: Int) {
        guard let newMonth = calendar.date(
            byAdding: .month,
            value: offset,
            to: displayedMonth
        ) else { return }

        withAnimation(AppAnimations.standard) {
            displayedMonth = newMonth
        }
        HapticFeedback.selection()
    }

    private func daysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let monthFirstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday else {
            return []
        }

        let daysInMonth = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 0
        let paddingDays = monthFirstWeekday - calendar.firstWeekday
        let totalDays = paddingDays + daysInMonth

        var days: [Date?] = Array(repeating: nil, count: paddingDays)

        for day in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: monthInterval.start) {
                days.append(date)
            }
        }

        // Fill remaining cells to complete the grid
        let remainingCells = (7 - (totalDays % 7)) % 7
        days.append(contentsOf: Array(repeating: nil, count: remainingCells))

        return days
    }

    private func accessibilityLabel(for date: Date, event: IslamicEvent?) -> String {
        let gregorianFormatter = DateFormatter()
        gregorianFormatter.dateStyle = .long

        let hijriFormatter = DateFormatter()
        hijriFormatter.calendar = hijriCalendar
        hijriFormatter.dateStyle = .long

        var label = "\(gregorianFormatter.string(from: date)), "
        label += "which is \(hijriFormatter.string(from: date))"

        if let event = event {
            label += ", \(event.name)"
        }

        return label
    }
}

/// Islamic event model
public struct IslamicEvent: Identifiable, Hashable {
    public let id = UUID()
    public let name: String
    public let type: EventType
    public let confidence: ConfidenceLevel

    public enum EventType {
        case ramadan
        case eid
        case other
    }

    public enum ConfidenceLevel {
        case high
        case medium
        case low
    }

    public init(name: String, type: EventType, confidence: ConfidenceLevel) {
        self.name = name
        self.type = type
        self.confidence = confidence
    }

    func color(colorScheme: ColorScheme) -> Color {
        switch type {
        case .ramadan:
            return colorScheme == .dark ? Color(red: 0.61, green: 0.30, blue: 0.80) : Color(red: 0.42, green: 0.11, blue: 0.60)
        case .eid:
            return colorScheme == .dark ? Color(red: 1.0, green: 0.84, blue: 0.31) : Color(red: 1.0, green: 0.70, blue: 0.0)
        case .other:
            return colorScheme == .dark ? Color.teal : Color.blue
        }
    }
}
```

**Validation**:
- [ ] Component compiles without errors
- [ ] Dual calendar displays correctly (Gregorian + Hijri)
- [ ] Month navigation works (swipe left/right)
- [ ] Date selection triggers haptic feedback
- [ ] Islamic events show color-coded dots
- [ ] Dates beyond lookahead limit are disabled
- [ ] VoiceOver announces both calendar dates
- [ ] Dynamic Type scales appropriately
- [ ] Touch targets are minimum 44x44pt
- [ ] Precision formatting matches backend `precision` (exact/window/timeOfDay)
- [ ] Timezone text shown from `calculationTimezone`
- [ ] Ramadan badge visible when `isRamadan`

---

### Backend Integration Checklist (add to any screen using future times)

- [ ] Calls `prayerTimeService.getFuturePrayerTimes(for:location:)` (or range) and handles `lookaheadLimitExceeded` / `dateRangeTooLarge` with user-facing messaging.
- [ ] Uses `result.precision` to format times; do not hardcode precision decisions in UI.
- [ ] Shows banners based on `result.disclaimerLevel` and `result.isHighLatitude`; applies Ramadan/Eid disclaimer when showing event estimates.
- [ ] Displays timezone from `result.calculationTimezone.identifier`.
- [ ] Honors settings toggles: `showLongRangePrecision`, `useRamadanIshaOffset` (surface note in settings UI), `maxLookaheadMonths` (disable out-of-range dates).

### Task 1.3: Future Prayer Times List Component (4 hours)

**File**: `DeenBuddy/Frameworks/DeenAssistUI/Components/FuturePrayerTimesList.swift` (NEW)

**Implementation** (based on design spec lines 854-978):

**Backend contract alignment**:
- Input should come from `FuturePrayerTimeResult` returned by `prayerTimeService.getFuturePrayerTimes(for:location:)`.
- Respect `result.precision`:
  - `.exact` -> standard HH:mm (respect `timeFormat`)
  - `.window(minutes:)` -> render as provided window range (±minutes/2). Do not invent your own; use helper on `PrecisionLevel` if exposed or replicate formatting: start-end with `DateFormatter.timeStyle = .short`.
  - `.timeOfDay` -> coarse labels (“Early Morning”, “Morning”, “Noon”, “Afternoon”, “Evening”, “Night”).
- Show Ramadan badge if `result.isRamadan` is true (Isha badge for +30m when applicable).
- Show timezone text from `result.calculationTimezone.identifier`.

```swift
import SwiftUI

/// Prayer times list for a specific date
public struct FuturePrayerTimesList: View {
    let prayerTimes: [PrayerTimeEntry]
    let isRamadan: Bool

    @Environment(\.currentTheme) private var currentTheme

    private var themeColors: ThemeAwareColorPalette {
        ThemeAwareColorPalette(theme: currentTheme)
    }

    public init(prayerTimes: [PrayerTimeEntry], isRamadan: Bool = false) {
        self.prayerTimes = prayerTimes
        self.isRamadan = isRamadan
    }

    public var body: some View {
        VStack(spacing: PremiumDesignTokens.spacing12) {
            ForEach(prayerTimes) { prayer in
                prayerRow(for: prayer)
            }
        }
        .padding(PremiumDesignTokens.spacing16)
        .background(
            RoundedRectangle(cornerRadius: PremiumDesignTokens.cornerRadius16)
                .fill(ColorPalette.surfacePrimary)
        )
        .premiumShadow(.level1)
        .padding(.horizontal, PremiumDesignTokens.spacing16)
    }

    private func prayerRow(for prayer: PrayerTimeEntry) -> some View {
        HStack(spacing: PremiumDesignTokens.spacing16) {
            // Prayer icon
            Image(systemName: prayer.iconName)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(themeColors.primary)
                .frame(width: 24, height: 24)

            // Prayer name
            Text(prayer.name)
                .font(Typography.titleMedium)
                .fontWeight(.medium)
                .foregroundColor(ColorPalette.textPrimary)

            Spacer()

            // Ramadan Isha indicator
            if isRamadan && prayer.name == "Isha" {
                Text("+30m")
                    .font(Typography.labelSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.purple.opacity(0.15))
                    )
                    .accessibilityLabel("Ramadan adjustment: plus 30 minutes")
            }

            // Prayer time
            Text(prayer.timeString)
                .font(Typography.prayerTime)
                .fontWeight(.bold)
                .foregroundColor(themeColors.accent)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(prayer.name) prayer at \(prayer.timeString)\(isRamadan && prayer.name == "Isha" ? ", plus 30 minutes for Ramadan" : "")")
        .accessibilityAddTraits(.isStaticText)
    }
}

/// Prayer time entry model
public struct PrayerTimeEntry: Identifiable {
    public let id = UUID()
    public let name: String
    public let time: Date
    public let timeWindow: (start: Date, end: Date)?

    public init(name: String, time: Date, timeWindow: (start: Date, end: Date)? = nil) {
        self.name = name
        self.time = time
        self.timeWindow = timeWindow
    }

    var iconName: String {
        switch name.lowercased() {
        case "fajr":
            return "sunrise.fill"
        case "dhuhr":
            return "sun.max.fill"
        case "asr":
            return "sun.haze.fill"
        case "maghrib":
            return "sunset.fill"
        case "isha":
            return "moon.fill"
        default:
            return "clock.fill"
        }
    }

    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        if let window = timeWindow {
            return "\(formatter.string(from: window.start)) - \(formatter.string(from: window.end))"
        } else {
            return formatter.string(from: time)
        }
    }
}
```

**Validation**:
- [ ] Component compiles without errors
- [ ] All 5 prayers display with correct icons
- [ ] Ramadan Isha +30m badge shows when applicable
- [ ] Prayer times use Typography.prayerTime (monospaced)
- [ ] VoiceOver reads prayer names and times correctly
- [ ] Time window format works (for long-range precision)
- [ ] Colors match design spec
- [ ] Minimum touch targets maintained

---

### Task 1.4: Islamic Event Card Component (3 hours)

**File**: `DeenBuddy/Frameworks/DeenAssistUI/Components/IslamicEventCard.swift` (NEW)

**Implementation** (based on design spec lines 676-849):

```swift
import SwiftUI

/// Islamic event card with confidence indicator
public struct IslamicEventCard: View {
    let event: IslamicEvent

    @Environment(\.colorScheme) private var colorScheme

    public init(event: IslamicEvent) {
        self.event = event
    }

    public var body: some View {
        HStack(spacing: PremiumDesignTokens.spacing12) {
            // Event icon
            Image(systemName: eventIcon)
                .font(.system(size: 32))
                .foregroundColor(eventIconColor)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(eventIconColor.opacity(0.15))
                )

            // Event details
            VStack(alignment: .leading, spacing: 6) {
                Text(event.name)
                    .font(Typography.titleLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(eventTextColor)

                HStack(spacing: 6) {
                    confidenceIndicator

                    Text(event.type == .ramadan || event.type == .eid ? "(Planning only)" : "")
                        .font(Typography.labelSmall)
                        .foregroundColor(eventTextColor.opacity(0.7))
                }
            }

            Spacer()
        }
        .padding(PremiumDesignTokens.spacing12)
        .background(eventBackground)
        .clipShape(RoundedRectangle(cornerRadius: PremiumDesignTokens.cornerRadius16))
        .premiumShadow(.level1)
        .padding(.horizontal, PremiumDesignTokens.spacing16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var eventIcon: String {
        switch event.type {
        case .ramadan:
            return "moon.stars.fill"
        case .eid:
            return "star.fill"
        case .other:
            return "calendar"
        }
    }

    private var eventIconColor: Color {
        switch event.type {
        case .ramadan:
            return colorScheme == .dark ? Color(red: 0.61, green: 0.30, blue: 0.80) : Color(red: 0.42, green: 0.11, blue: 0.60)
        case .eid:
            return colorScheme == .dark ? Color(red: 1.0, green: 0.84, blue: 0.31) : Color(red: 1.0, green: 0.70, blue: 0.0)
        case .other:
            return colorScheme == .dark ? Color.teal : Color.blue
        }
    }

    private var eventTextColor: Color {
        colorScheme == .dark ? Color.white : Color.black
    }

    private var eventBackground: some ShapeStyle {
        switch event.type {
        case .ramadan:
            return AnyShapeStyle(LinearGradient(
                colors: [
                    (colorScheme == .dark ? Color(red: 0.42, green: 0.11, blue: 0.60) : Color(red: 0.61, green: 0.15, blue: 0.69)).opacity(0.2),
                    (colorScheme == .dark ? Color(red: 0.61, green: 0.30, blue: 0.80) : Color(red: 0.74, green: 0.30, blue: 0.80)).opacity(0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        case .eid:
            return AnyShapeStyle(LinearGradient(
                colors: [
                    (colorScheme == .dark ? Color(red: 1.0, green: 0.70, blue: 0.0) : Color(red: 1.0, green: 0.70, blue: 0.0)).opacity(0.2),
                    (colorScheme == .dark ? Color(red: 1.0, green: 0.84, blue: 0.31) : Color(red: 1.0, green: 0.84, blue: 0.50)).opacity(0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        case .other:
            return AnyShapeStyle(Color.blue.opacity(0.1))
        }
    }

    private var confidenceIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)

            Text(confidenceText)
                .font(Typography.labelSmall)
                .fontWeight(.medium)
                .foregroundColor(confidenceColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(confidenceColor.opacity(0.15))
        )
    }

    private var confidenceColor: Color {
        switch event.confidence {
        case .high:
            return Color.green
        case .medium:
            return Color.orange
        case .low:
            return Color.red
        }
    }

    private var confidenceText: String {
        switch event.confidence {
        case .high:
            return "High confidence"
        case .medium:
            return "Medium confidence"
        case .low:
            return "Low confidence"
        }
    }

    private var accessibilityLabel: String {
        var label = "\(event.name). "
        label += "\(confidenceText). "
        if event.type == .ramadan || event.type == .eid {
            label += "Planning only. "
        }
        return label
    }
}
```

**Validation**:
- [ ] Component compiles without errors
- [ ] Event types display with correct icons and colors
- [ ] Confidence indicators show (green/yellow/red)
- [ ] "(Planning only)" label shows for Ramadan/Eid
- [ ] Gradient backgrounds match design spec
- [ ] VoiceOver reads event details correctly
- [ ] Dark mode colors are appropriate

---

### Task 1.5: Calculation Info Footer Component (3 hours)

**File**: `DeenBuddy/Frameworks/DeenAssistUI/Components/CalculationInfoFooter.swift` (NEW)

**Implementation** (based on design spec lines 982-1093):

```swift
import SwiftUI

/// Footer showing calculation info and disclaimers
public struct CalculationInfoFooter: View {
    let calculationMethod: String
    let madhab: String
    let timezone: String
    let isRamadan: Bool
    let isUmmAlQuraOrQatar: Bool
    let onSettingsTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    public init(
        calculationMethod: String,
        madhab: String,
        timezone: String,
        isRamadan: Bool = false,
        isUmmAlQuraOrQatar: Bool = false,
        onSettingsTap: @escaping () -> Void
    ) {
        self.calculationMethod = calculationMethod
        self.madhab = madhab
        self.timezone = timezone
        self.isRamadan = isRamadan
        self.isUmmAlQuraOrQatar = isUmmAlQuraOrQatar
        self.onSettingsTap = onSettingsTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PremiumDesignTokens.spacing12) {
            // Calculation details
            VStack(alignment: .leading, spacing: 6) {
                infoRow(label: "Calculation Method", value: calculationMethod)
                infoRow(label: "Madhab", value: madhab)
                infoRow(label: "Timezone", value: timezone)
            }

            Divider()
                .background(ColorPalette.border)

            // REQUIRED: Authority disclaimer (EXACT COPY)
            Text("Defer to local authority for official prayer times.")
                .font(Typography.labelMedium)
                .foregroundColor(ColorPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // Ramadan Umm Al Qura footnote (conditional, EXACT COPY)
            if isRamadan && isUmmAlQuraOrQatar {
                Text("Isha in Ramadan: 90m + 30m; errs to later for safety.")
                    .font(Typography.caption)
                    .italic()
                    .foregroundColor(ColorPalette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Settings link
            Button {
                onSettingsTap()
                HapticFeedback.light()
            } label: {
                HStack(spacing: 6) {
                    Text("Change method/madhab in Settings")
                        .font(Typography.labelMedium)
                        .foregroundColor(Color.accentGold)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.accentGold)
                }
            }
            .accessibilityLabel("Change calculation method or madhab")
            .accessibilityHint("Opens app settings")
        }
        .padding(PremiumDesignTokens.spacing12)
        .background(
            colorScheme == .dark
                ? Color.white.opacity(0.05)
                : Color.black.opacity(0.03)
        )
        .clipShape(RoundedRectangle(cornerRadius: PremiumDesignTokens.cornerRadius12))
        .padding(.horizontal, PremiumDesignTokens.spacing16)
        .accessibilityElement(children: .contain)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Typography.labelMedium)
                .foregroundColor(ColorPalette.textTertiary)

            Spacer()

            Text(value)
                .font(Typography.labelMedium)
                .fontWeight(.medium)
                .foregroundColor(ColorPalette.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
```

**Validation**:
- [ ] Component compiles without errors
- [ ] "Defer to local authority" message uses EXACT copy
- [ ] Ramadan footnote uses EXACT copy ("90m + 30m; errs to later")
- [ ] Ramadan footnote shows ONLY when both conditions met (isRamadan AND isUmmAlQuraOrQatar)
- [ ] Settings link navigates correctly
- [ ] VoiceOver reads all information
- [ ] Footer is visible on ALL future date views (fiqh requirement)

---

## Phase 2: Main Screen Implementation (14 hours)

### Task 2.1: Islamic Calendar Screen (8 hours)

**File**: `DeenBuddy/Frameworks/DeenAssistUI/Screens/IslamicCalendarScreen.swift` (NEW)

**Screen Structure** (based on design spec lines 1099-1267):

```swift
import SwiftUI

/// Islamic Calendar screen - Main view
public struct IslamicCalendarScreen: View {
    @StateObject private var viewModel: IslamicCalendarViewModel

    @Environment(\.currentTheme) private var currentTheme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private var themeColors: ThemeAwareColorPalette {
        ThemeAwareColorPalette(theme: currentTheme)
    }

    public init(viewModel: IslamicCalendarViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: PremiumDesignTokens.spacing24) {
                    // Disclaimer banner (conditional - NOT shown for today)
                    if viewModel.shouldShowDisclaimer {
                        DisclaimerBanner(
                            type: viewModel.disclaimerType,
                            isDismissed: $viewModel.isDisclaimerDismissed
                        )
                    }

                    // High-latitude warning (conditional)
                    if viewModel.showHighLatitudeWarning {
                        DisclaimerBanner(
                            type: .highLatitude,
                            isDismissed: $viewModel.isHighLatitudeWarningDismissed
                        )
                    }

                    // Islamic Date Picker
                    IslamicDatePicker(
                        selectedDate: $viewModel.selectedDate,
                        availableDateRange: viewModel.availableDateRange,
                        islamicEvents: viewModel.islamicEventsDict
                    )

                    // Islamic Events Card (conditional)
                    if let event = viewModel.selectedDateEvent {
                        IslamicEventCard(event: event)
                    }

                    // Prayer Times List
                    if viewModel.isLoadingPrayerTimes {
                        loadingView
                    } else if let error = viewModel.prayerTimesError {
                        errorView(error: error)
                    } else if let prayerTimes = viewModel.displayPrayerTimes {
                        FuturePrayerTimesList(
                            prayerTimes: prayerTimes,
                            isRamadan: viewModel.isSelectedDateRamadan
                        )
                    }

                    // Calculation Info Footer (REQUIRED FOR ALL FUTURE DATES)
                    CalculationInfoFooter(
                        calculationMethod: viewModel.calculationMethod,
                        madhab: viewModel.madhab,
                        timezone: viewModel.timezone,
                        isRamadan: viewModel.isSelectedDateRamadan,
                        isUmmAlQuraOrQatar: viewModel.isUmmAlQuraOrQatar,
                        onSettingsTap: viewModel.openSettings
                    )

                    // Bottom spacing for safe area
                    Color.clear
                        .frame(height: PremiumDesignTokens.spacing16)
                }
                .padding(.top, PremiumDesignTokens.spacing16)
            }
            .background(ColorPalette.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Islamic Calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(themeColors.primary)
                    }
                    .accessibilityLabel("Back")
                    .accessibilityHint("Returns to home screen")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.goToToday()
                    } label: {
                        Text("Today")
                            .font(Typography.labelLarge)
                            .foregroundColor(themeColors.primary)
                    }
                    .accessibilityLabel("Go to today")
                    .accessibilityHint("Selects today's date")
                }
            }
        }
        .onAppear {
            viewModel.fetchPrayerTimesForSelectedDate()
        }
        .onChange(of: viewModel.selectedDate) { _ in
            viewModel.fetchPrayerTimesForSelectedDate()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: PremiumDesignTokens.spacing16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(themeColors.primary)

            Text("Loading prayer times...")
                .font(Typography.bodyMedium)
                .foregroundColor(ColorPalette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PremiumDesignTokens.spacing48)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading prayer times")
    }

    // MARK: - Error View

    private func errorView(error: String) -> some View {
        VStack(spacing: PremiumDesignTokens.spacing16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(Color.red)

            Text("Unable to calculate prayer times")
                .font(Typography.titleLarge)
                .fontWeight(.semibold)
                .foregroundColor(ColorPalette.textPrimary)

            Text(error)
                .font(Typography.bodyMedium)
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                viewModel.retryFetchPrayerTimes()
            } label: {
                Text("Retry")
                    .font(Typography.buttonText)
                    .foregroundColor(.white)
                    .padding(.horizontal, PremiumDesignTokens.spacing24)
                    .padding(.vertical, PremiumDesignTokens.spacing12)
                    .background(
                        RoundedRectangle(cornerRadius: PremiumDesignTokens.cornerRadius20)
                            .fill(themeColors.primary)
                    )
            }
            .accessibilityLabel("Retry loading prayer times")
        }
        .padding(PremiumDesignTokens.spacing24)
        .background(
            RoundedRectangle(cornerRadius: PremiumDesignTokens.cornerRadius16)
                .fill(Color.red.opacity(0.1))
        )
        .padding(.horizontal, PremiumDesignTokens.spacing16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(error). Double tap retry button to try again.")
    }
}
```

**Validation**:
- [ ] Screen compiles without errors
- [ ] All components display in correct order (top to bottom)
- [ ] Disclaimer banner shows for all non-today dates
- [ ] High-latitude warning shows when applicable
- [ ] Footer is ALWAYS visible (fiqh requirement)
- [ ] Loading and error states display correctly
- [ ] Navigation bar has back button and "Today" button
- [ ] ScrollView works smoothly
- [ ] Safe areas respected (notch/home indicator)

---

### Task 2.2: View Model Implementation (6 hours)

**File**: `DeenBuddy/ViewModels/IslamicCalendarViewModel.swift` (NEW)

**Implementation**:

```swift
import Foundation
import SwiftUI
import CoreLocation
import Combine

@MainActor
public class IslamicCalendarViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public var selectedDate: Date = Date()
    @Published public var isDisclaimerDismissed = false
    @Published public var isHighLatitudeWarningDismissed = false
    @Published public var isLoadingPrayerTimes = false
    @Published public var prayerTimesError: String?
    @Published public var prayerTimeResult: FuturePrayerTimeResult?
    @Published public var islamicEvents: [IslamicEventEstimate] = []

    // MARK: - Services (Injected)

    private let prayerTimeService: any PrayerTimeServiceProtocol
    private let islamicCalendarService: any IslamicCalendarServiceProtocol
    private let locationService: any LocationServiceProtocol
    private let settingsService: any SettingsServiceProtocol

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init(
        prayerTimeService: any PrayerTimeServiceProtocol,
        islamicCalendarService: any IslamicCalendarServiceProtocol,
        locationService: any LocationServiceProtocol,
        settingsService: any SettingsServiceProtocol
    ) {
        self.prayerTimeService = prayerTimeService
        self.islamicCalendarService = islamicCalendarService
        self.locationService = locationService
        self.settingsService = settingsService
    }

    // MARK: - Computed Properties

    public var availableDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let startDate = Date()
        let maxMonths = settingsService.maxLookaheadMonths
        let endDate = calendar.date(byAdding: .month, value: maxMonths, to: startDate) ?? startDate
        return startDate...endDate
    }

    public var islamicEventsDict: [Date: IslamicEvent] {
        var dict: [Date: IslamicEvent] = [:]
        for event in islamicEvents {
            let eventUI = IslamicEvent(
                name: event.event.displayName,
                type: event.event.eventType,
                confidence: event.confidenceLevel
            )
            dict[event.estimatedDate] = eventUI
        }
        return dict
    }

    public var shouldShowDisclaimer: Bool {
        !Calendar.current.isDateInToday(selectedDate) && !isDisclaimerDismissed
    }

    public var disclaimerType: DisclaimerType {
        guard let result = prayerTimeResult else {
            return .standard
        }

        // Prioritize Ramadan/Eid disclaimer
        if result.isRamadan || selectedDateEvent?.event.isRamadanOrEid == true {
            return .ramadanEid
        }

        // Then high-latitude
        if result.isHighLatitude {
            return .highLatitude
        }

        // Then disclaimer level
        switch result.disclaimerLevel {
        case .today:
            return .standard
        case .shortTerm:
            return .standard
        case .mediumTerm:
            return .mediumTerm
        case .longTerm:
            return .mediumTerm // Use medium-term for long-term (or implement separate .longTerm type)
        }
    }

    public var showHighLatitudeWarning: Bool {
        guard let result = prayerTimeResult else {
            return false
        }
        return result.isHighLatitude && !isHighLatitudeWarningDismissed
    }

    public var selectedDateEvent: IslamicEvent? {
        islamicEventsDict[selectedDate]
    }

    public var isSelectedDateRamadan: Bool {
        prayerTimeResult?.isRamadan ?? false
    }

    public var displayPrayerTimes: [PrayerTimeEntry]? {
        guard let result = prayerTimeResult else {
            return nil
        }

        return result.prayerTimes.map { prayer in
            PrayerTimeEntry(name: prayer.name.displayName, time: prayer.time)
        }
    }

    public var calculationMethod: String {
        settingsService.calculationMethod.displayName
    }

    public var madhab: String {
        settingsService.madhab.displayName
    }

    public var timezone: String {
        let tz = TimeZone.current
        return "\(tz.identifier) (\(tz.abbreviation() ?? ""))"
    }

    public var isUmmAlQuraOrQatar: Bool {
        let method = settingsService.calculationMethod
        return method == .ummAlQura || method == .qatar
    }

    // MARK: - Public Methods

    public func fetchPrayerTimesForSelectedDate() {
        Task {
            isLoadingPrayerTimes = true
            prayerTimesError = nil

            do {
                // Fetch prayer times
                let location = try await locationService.getCurrentLocation()
                let result = try await prayerTimeService.getFuturePrayerTimes(
                    for: selectedDate,
                    location: location
                )
                prayerTimeResult = result

                // Fetch Islamic events
                await fetchIslamicEventsForSelectedDate()

                isLoadingPrayerTimes = false
            } catch {
                prayerTimesError = error.localizedDescription
                isLoadingPrayerTimes = false
            }
        }
    }

    public func retryFetchPrayerTimes() {
        fetchPrayerTimesForSelectedDate()
    }

    public func goToToday() {
        selectedDate = Date()
        fetchPrayerTimesForSelectedDate()
    }

    public func openSettings() {
        // Navigate to settings (implement via coordinator)
        // For now, this is a placeholder
    }

    // MARK: - Private Methods

    private func fetchIslamicEventsForSelectedDate() async {
        let calendar = Calendar(identifier: .islamicUmmAlQura)
        let hijriYear = calendar.component(.year, from: selectedDate)
        let hijriMonth = calendar.component(.month, from: selectedDate)

        var events: [IslamicEventEstimate] = []

        // Check if Ramadan
        if hijriMonth == 9 {
            let confidence = islamicCalendarService.getEventConfidence(for: selectedDate)
            let hijriDate = getHijriDate(for: selectedDate)

            events.append(IslamicEventEstimate(
                event: .ramadanStart,
                estimatedDate: selectedDate,
                hijriDate: hijriDate,
                confidenceLevel: confidence
            ))
        }

        // Check for Eid al-Fitr (1st of Shawwal)
        if hijriMonth == 10, calendar.component(.day, from: selectedDate) == 1 {
            let confidence = islamicCalendarService.getEventConfidence(for: selectedDate)
            let hijriDate = getHijriDate(for: selectedDate)

            events.append(IslamicEventEstimate(
                event: .eidAlFitr,
                estimatedDate: selectedDate,
                hijriDate: hijriDate,
                confidenceLevel: confidence
            ))
        }

        // Check for Eid al-Adha (10th of Dhul Hijjah)
        if hijriMonth == 12, calendar.component(.day, from: selectedDate) == 10 {
            let confidence = islamicCalendarService.getEventConfidence(for: selectedDate)
            let hijriDate = getHijriDate(for: selectedDate)

            events.append(IslamicEventEstimate(
                event: .eidAlAdha,
                estimatedDate: selectedDate,
                hijriDate: hijriDate,
                confidenceLevel: confidence
            ))
        }

        islamicEvents = events
    }

    private func getHijriDate(for date: Date) -> HijriDate {
        let calendar = Calendar(identifier: .islamicUmmAlQura)
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "MMMM"
        let monthName = formatter.string(from: date)

        return HijriDate(day: day, month: month, year: year, monthName: monthName)
    }
}

// MARK: - Extensions for Display

extension IslamicEvent {
    var isRamadanOrEid: Bool {
        switch self {
        case .ramadanStart, .eidAlFitr, .eidAlAdha:
            return true
        case .other:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .ramadanStart:
            return "1st Day of Ramadan"
        case .ramadanEnd:
            return "Last Day of Ramadan"
        case .eidAlFitr:
            return "Eid al-Fitr"
        case .eidAlAdha:
            return "Eid al-Adha"
        case .other(let name):
            return name
        }
    }

    var eventType: IslamicEvent.EventType {
        switch self {
        case .ramadanStart, .ramadanEnd:
            return .ramadan
        case .eidAlFitr, .eidAlAdha:
            return .eid
        case .other:
            return .other
        }
    }
}

extension PrayerName {
    var displayName: String {
        switch self {
        case .fajr: return "Fajr"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        }
    }
}

extension CalculationMethod {
    var displayName: String {
        // Implement based on your CalculationMethod enum
        // For now, returning placeholder
        return "Muslim World League"
    }
}

extension Madhab {
    var displayName: String {
        switch self {
        case .hanafi: return "Hanafi"
        case .shafi: return "Shafi"
        // Add other madhabs
        default: return "Shafi"
        }
    }
}
```

**Validation**:
- [ ] ViewModel compiles without errors
- [ ] All services injected correctly via initializer
- [ ] Published properties trigger UI updates
- [ ] Prayer times fetch on date selection
- [ ] Islamic events fetch and display correctly
- [ ] Error handling captures and displays errors
- [ ] Loading states work correctly
- [ ] Disclaimer logic is correct (today=hidden, future=shown)

---

## Phase 3: Navigation & Settings Integration (5 hours)

### Task 3.1: Navigation Integration (2 hours)

**File**: `DeenBuddy/Frameworks/DeenAssistUI/Navigation/AppCoordinator.swift` (EXTEND)

**Add navigation state and methods**:

```swift
// MARK: - Islamic Calendar Navigation

@Published public var showingIslamicCalendar = false

public func showIslamicCalendar() {
    showingIslamicCalendar = true
}

public func dismissIslamicCalendar() {
    showingIslamicCalendar = false
}
```

**Add sheet presentation** in `SimpleTabView` or `MainAppView`:

```swift
.sheet(isPresented: $coordinator.showingIslamicCalendar) {
    IslamicCalendarScreen(viewModel: createIslamicCalendarViewModel())
}

private func createIslamicCalendarViewModel() -> IslamicCalendarViewModel {
    guard let container = dependencyContainer else {
        fatalError("Dependency container not initialized")
    }

    return IslamicCalendarViewModel(
        prayerTimeService: container.prayerTimeService,
        islamicCalendarService: container.islamicCalendarService,
        locationService: container.locationService,
        settingsService: container.settingsService
    )
}
```

**Wire HomeScreen Quick Action**:

```swift
// In HomeScreen.swift
onCalendarTapped: {
    coordinator.showIslamicCalendar()
}
```

**Validation**:
- [ ] Navigation compiles without errors
- [ ] Quick Action button navigates to Islamic Calendar screen
- [ ] Back button dismisses screen correctly
- [ ] Sheet presentation works
- [ ] Dependency injection resolves services correctly

---

### Task 3.2: Settings Integration (3 hours)

**File**: `DeenBuddy/Views/Settings/NotificationSettingsView.swift` OR create new `FuturePrayerTimesSettingsView.swift`

**Add new settings section**:

```swift
Section(header: Text("Future Prayer Times")) {
    // Max lookahead months slider
    VStack(alignment: .leading, spacing: 8) {
        Text("Max Lookahead")
            .font(Typography.bodyMedium)

        Slider(
            value: Binding(
                get: { Double(settingsService.maxLookaheadMonths) },
                set: { settingsService.maxLookaheadMonths = Int($0) }
            ),
            in: 12...60,
            step: 6
        )

        Text("\(settingsService.maxLookaheadMonths) months")
            .font(Typography.labelSmall)
            .foregroundColor(ColorPalette.textTertiary)
    }

    // Ramadan Isha offset toggle
    Toggle("Ramadan Isha Offset (+30m)", isOn: $settingsService.useRamadanIshaOffset)
        .font(Typography.bodyMedium)

    Text("Add 30 minutes to Isha during Ramadan for Umm Al Qura and Qatar methods. Errs to later for safety.")
        .font(Typography.caption)
        .foregroundColor(ColorPalette.textTertiary)

    // Long-range precision toggle
    Toggle("Show Long-Range Exact Times", isOn: $settingsService.showLongRangePrecision)
        .font(Typography.bodyMedium)

    Text("Show exact times beyond 1 year (with strong disclaimers). If disabled, shows time windows.")
        .font(Typography.caption)
        .foregroundColor(ColorPalette.textTertiary)
}
```

**Validation**:
- [ ] Settings section compiles and displays
- [ ] Slider changes max lookahead months
- [ ] Toggles work correctly
- [ ] Settings persist in UserDefaults
- [ ] Help text is clear and accurate
- [ ] Settings changes invalidate cached prayer times

---

## Phase 4: Testing (11 hours)

### Task 4.1: UI/Snapshot Tests (6 hours)

**File**: `DeenBuddyUITests/IslamicCalendarScreenTests.swift` (NEW)

**Test cases**:

```swift
import XCTest

class IslamicCalendarScreenUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testDisclaimerBanner_Today_NotShown() {
        // Navigate to Islamic Calendar
        app.buttons["Islamic Calendar"].tap()

        // Verify no banner shown for today
        XCTAssertFalse(app.staticTexts["Calculated Times"].exists)
    }

    func testDisclaimerBanner_6MonthsFuture_StandardShown() {
        // Navigate to Islamic Calendar
        app.buttons["Islamic Calendar"].tap()

        // Select date 6 months in future
        // (Implementation depends on date picker UI)

        // Verify standard disclaimer shown
        XCTAssertTrue(app.staticTexts["Calculated Times"].exists)
        XCTAssertTrue(app.staticTexts["Calculated times. Subject to DST changes and official mosque schedules."].exists)
    }

    func testDisclaimerBanner_2YearsFuture_MediumTermShown() {
        // Similar test for 2 years future
        // Verify medium-term disclaimer
    }

    func testDatePicker_DisplaysCorrectly() {
        app.buttons["Islamic Calendar"].tap()

        // Verify dual calendar display
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'which is'")).count > 0)
    }

    func testPrayerTimes_Display5Prayers() {
        app.buttons["Islamic Calendar"].tap()

        // Verify 5 prayers displayed
        XCTAssertTrue(app.staticTexts["Fajr"].exists)
        XCTAssertTrue(app.staticTexts["Dhuhr"].exists)
        XCTAssertTrue(app.staticTexts["Asr"].exists)
        XCTAssertTrue(app.staticTexts["Maghrib"].exists)
        XCTAssertTrue(app.staticTexts["Isha"].exists)
    }

    func testRamadanIndicator_ShownDuringRamadan() {
        // Navigate to Ramadan date
        app.buttons["Islamic Calendar"].tap()

        // Select Ramadan date (March 2025)
        // (Implementation depends on date picker)

        // Verify Ramadan indicator and Isha +30m badge
        XCTAssertTrue(app.staticTexts["1st Day of Ramadan"].exists)
        XCTAssertTrue(app.staticTexts["+30m"].exists)
    }

    func testCalculationInfoFooter_AlwaysVisible() {
        app.buttons["Islamic Calendar"].tap()

        // Verify footer is visible
        XCTAssertTrue(app.staticTexts["Defer to local authority for official prayer times."].exists)
    }

    func testVoiceOver_ReadsDisclaimers() {
        // Enable VoiceOver
        // Navigate to future date
        // Verify VoiceOver reads full disclaimer
    }

    func testDynamicType_ScalesText() {
        // Change Dynamic Type setting
        // Verify text scales appropriately
    }
}
```

**Validation**:
- [ ] All UI tests pass
- [ ] Disclaimer banners display correctly
- [ ] Date picker works correctly
- [ ] Prayer times display correctly
- [ ] Ramadan indicators show when applicable
- [ ] Footer is always visible
- [ ] VoiceOver tests pass
- [ ] Dynamic Type tests pass

---

### Task 4.2: Integration Tests (6 hours)

**File**: `DeenBuddyTests/IslamicCalendarIntegrationTests.swift` (NEW)

**Test full user flows**:

```swift
import XCTest
@testable import DeenAssistCore
@testable import DeenAssistUI

@MainActor
class IslamicCalendarIntegrationTests: XCTestCase {
    var viewModel: IslamicCalendarViewModel!
    var mockPrayerTimeService: MockPrayerTimeService!
    var mockIslamicCalendarService: MockIslamicCalendarService!
    var mockLocationService: MockLocationService!
    var mockSettingsService: MockSettingsService!

    override func setUp() async throws {
        try await super.setUp()

        mockPrayerTimeService = MockPrayerTimeService()
        mockIslamicCalendarService = MockIslamicCalendarService()
        mockLocationService = MockLocationService()
        mockSettingsService = MockSettingsService()

        viewModel = IslamicCalendarViewModel(
            prayerTimeService: mockPrayerTimeService,
            islamicCalendarService: mockIslamicCalendarService,
            locationService: mockLocationService,
            settingsService: mockSettingsService
        )
    }

    func testFullUserFlow_SelectFutureDate() async throws {
        // Given: Navigate to Islamic Calendar
        let futureDate = Calendar.current.date(byAdding: .month, value: 6, to: Date())!
        mockLocationService.mockLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)

        // When: Select future date
        viewModel.selectedDate = futureDate
        viewModel.fetchPrayerTimesForSelectedDate()

        // Wait for async operations
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Then: Verify results
        XCTAssertNotNil(viewModel.prayerTimeResult)
        XCTAssertEqual(viewModel.prayerTimeResult?.disclaimerLevel, .shortTerm)
        XCTAssertTrue(viewModel.shouldShowDisclaimer)
        XCTAssertNotNil(viewModel.displayPrayerTimes)
        XCTAssertEqual(viewModel.displayPrayerTimes?.count, 5)
    }

    func testRamadanFlow_IshaOffsetApplied() async throws {
        // Given: Ramadan date
        let ramadanDate = DateComponents(calendar: .current, year: 2025, month: 3, day: 15).date!
        mockSettingsService.calculationMethod = .ummAlQura
        mockSettingsService.useRamadanIshaOffset = true
        mockIslamicCalendarService.mockIsRamadan = true

        // When: Fetch prayer times
        viewModel.selectedDate = ramadanDate
        viewModel.fetchPrayerTimesForSelectedDate()

        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Then: Verify Ramadan indicator and Isha offset
        XCTAssertTrue(viewModel.isSelectedDateRamadan)
        XCTAssertTrue(viewModel.prayerTimeResult?.isRamadan ?? false)
    }

    func testSettingsChange_RecalculatesPrayerTimes() async throws {
        // Given: Initial prayer times calculated
        let futureDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
        viewModel.selectedDate = futureDate
        viewModel.fetchPrayerTimesForSelectedDate()

        try await Task.sleep(nanoseconds: 500_000_000)

        let initialTimes = viewModel.displayPrayerTimes

        // When: Change madhab setting
        mockSettingsService.madhab = .hanafi
        viewModel.fetchPrayerTimesForSelectedDate()

        try await Task.sleep(nanoseconds: 500_000_000)

        // Then: Verify times recalculated
        let newTimes = viewModel.displayPrayerTimes
        XCTAssertNotEqual(initialTimes, newTimes) // Asr time should change
    }
}
```

**Validation**:
- [ ] All integration tests pass
- [ ] Full user flows work correctly
- [ ] Ramadan flow works
- [ ] Settings changes trigger recalculation
- [ ] Error handling works
- [ ] Quick Action integration works

---

## Completion Criteria

### Frontend is DONE when:

**Functional Requirements**:
- [ ] All UI components compile and render correctly
- [ ] Islamic Calendar screen displays all required sections
- [ ] Navigation works from HomeScreen Quick Action
- [ ] Settings integration is functional
- [ ] Date selection triggers prayer time calculations
- [ ] Islamic events display correctly
- [ ] Loading and error states work

**Quality Requirements**:
- [ ] All UI tests pass
- [ ] All integration tests pass
- [ ] No compilation errors or warnings
- [ ] SwiftLint passes (if configured)
- [ ] No force unwraps or unsafe code in UI layer

**Fiqh Compliance Requirements** (CRITICAL):
- [ ] Disclaimer banners show for ALL non-today dates
- [ ] Disclaimer messages use EXACT approved copy (character-for-character match)
- [ ] "Defer to local authority" footer is ALWAYS visible
- [ ] Ramadan/Eid labeled as "(Planning only)"
- [ ] High-latitude warning shows for >55° latitude
- [ ] Umm Al Qura Ramadan footnote shows when both conditions met
- [ ] No exact times beyond 5 years (or strong warning)

**Accessibility Requirements**:
- [ ] VoiceOver reads all elements correctly
- [ ] VoiceOver reads full disclaimer text
- [ ] Dynamic Type scales text appropriately (test -3 to +7 sizes)
- [ ] High Contrast mode increases border thickness
- [ ] Reduce Motion disables animations
- [ ] All interactive elements have 44x44pt minimum touch targets
- [ ] No color-only information (icons + text)

**Design Specification Compliance**:
- [ ] Colors match design spec (light and dark mode)
- [ ] Typography matches design spec (SF Pro fonts)
- [ ] Spacing follows 8pt grid system
- [ ] Corner radius matches spec (12pt banners, 16pt cards)
- [ ] Shadows use PremiumDesignTokens (.level1)
- [ ] Animations are smooth and respect Reduce Motion

**Performance Requirements**:
- [ ] Date selection responds within 500ms
- [ ] Prayer time display updates within 1 second
- [ ] Screen loads within 1 second
- [ ] Scrolling is smooth (no frame drops)
- [ ] No memory leaks

---

## Handoff to QA Team

**After frontend completion**:

1. **Provide test build**:
   - Deploy to TestFlight for internal testing
   - Share build number and version

2. **Share test data**:
   - Known accurate prayer times for validation
   - Test locations (NYC, Riyadh, Oslo, Sydney)
   - Test dates (today, 6 months, 2 years, Ramadan)

3. **Islamic accuracy checklist**:
   - [ ] All disclaimers use exact approved copy
   - [ ] Ramadan/Eid labeled "planning only"
   - [ ] High-latitude warnings shown
   - [ ] Footer always visible
   - [ ] Isha +30m indicator shows during Ramadan (Umm Al Qura/Qatar)

4. **Accessibility validation**:
   - [ ] VoiceOver reads all content
   - [ ] Dynamic Type scaling works
   - [ ] High Contrast mode works
   - [ ] Reduce Motion works
   - [ ] Touch targets are adequate

5. **Performance testing**:
   - [ ] Test on iPhone SE (lowest spec device)
   - [ ] Test on iPhone 16 Pro (highest spec device)
   - [ ] Test on various iOS versions (15.0+)

**Remember**: Any mistake in disclaimer display or Islamic calculations could harm users' religious practice. Test thoroughly.

---

## Emergency Contacts

**If you encounter blocking issues**:
- SwiftUI layout issues: Apple SwiftUI documentation
- Accessibility issues: iOS Accessibility Programming Guide
- Design system issues: Check existing DeenBuddy components for patterns
- Islamic accuracy questions: Consult backend team or Islamic authority

**Remember**: This UI serves Muslims for religious practice. Accuracy and respectful presentation are paramount.

---

## Knowledge Storage

**After completion, store knowledge**:

```bash
byterover-store-knowledge "Islamic Calendar UI implemented with exact disclaimer copy requirements. DisclaimerBanner component uses EXACT messages specified in fiqh compliance docs. CalculationInfoFooter always shows 'Defer to local authority' message. Ramadan Isha +30m badge shows conditionally. High-latitude warning triggers for >55° latitude. All components follow PremiumDesignTokens design system. Full VoiceOver and Dynamic Type support implemented."
```
