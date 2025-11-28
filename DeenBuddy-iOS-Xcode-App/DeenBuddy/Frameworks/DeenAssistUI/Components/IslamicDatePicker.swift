import SwiftUI

/// Islamic date picker with dual calendar display (Gregorian + Hijri)
/// Shows event indicators for Ramadan/Eid dates and supports swipe navigation
public struct IslamicDatePicker: View {

    // MARK: - Properties

    @Binding var selectedDate: Date
    let islamicEvents: [IslamicEventEstimate]
    let maxLookaheadDate: Date

    @State private var displayedMonth: Date
    @State private var dragOffset: CGFloat = 0

    @Environment(\.currentTheme) private var currentTheme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.calendar) private var gregorianCalendar

    private var islamicCalendar: Calendar {
        Calendar(identifier: .islamicUmmAlQura)
    }

    // MARK: - Initialization

    public init(
        selectedDate: Binding<Date>,
        islamicEvents: [IslamicEventEstimate],
        maxLookaheadDate: Date
    ) {
        self._selectedDate = selectedDate
        self.islamicEvents = islamicEvents
        self.maxLookaheadDate = maxLookaheadDate

        // Initialize displayed month to selected date's month
        _displayedMonth = State(initialValue: selectedDate.wrappedValue)
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: PremiumDesignTokens.spacing16) {
            // Month navigation header
            monthNavigationHeader

            // Weekday headers
            weekdayHeaders

            // Calendar grid
            calendarGrid

            // Hijri date display for selected date
            hijriDateDisplay
        }
        .gesture(swipeGesture)
    }

    // MARK: - Month Navigation Header

    private var monthNavigationHeader: some View {
        HStack {
            // Previous month button
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(themeColors.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonAccessibility(label: "Previous month")

            Spacer()

            // Current month/year display
            VStack(spacing: 4) {
                Text(monthYearText)
                    .font(Typography.titleLarge)
                    .foregroundColor(themeColors.textPrimary)

                // Hijri month/year
                Text(hijriMonthYearText)
                    .font(Typography.bodySmall)
                    .foregroundColor(themeColors.textSecondary)
            }

            Spacer()

            // Next month button
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(themeColors.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonAccessibility(label: "Next month")
        }
        .padding(.horizontal, PremiumDesignTokens.spacing8)
    }

    // MARK: - Weekday Headers

    private var weekdayHeaders: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(Typography.labelSmall)
                    .foregroundColor(themeColors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, PremiumDesignTokens.spacing8)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: PremiumDesignTokens.spacing8) {
            ForEach(daysInMonth, id: \.self) { date in
                if let date = date {
                    dateCell(for: date)
                } else {
                    // Empty cell for padding
                    Color.clear
                        .frame(height: 44)
                }
            }
        }
        .padding(.horizontal, PremiumDesignTokens.spacing8)
    }

    // MARK: - Date Cell

    private func dateCell(for date: Date) -> some View {
        let isSelected = gregorianCalendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = gregorianCalendar.isDateInToday(date)
        let isSelectable = isDateSelectable(date)
        let hasEvents = hasEventsOn(date)
        let events = eventsOn(date)

        return VStack(spacing: 4) {
            // Day number
            Text("\(gregorianCalendar.component(.day, from: date))")
                .font(Typography.titleSmall)
                .foregroundColor(textColor(for: date, isSelected: isSelected, isToday: isToday, isSelectable: isSelectable))
                .frame(width: 36, height: 36)
                .background(backgroundColor(for: date, isSelected: isSelected, isToday: isToday))
                .cornerRadius(18)

            // Event indicators (dots)
            if hasEvents {
                HStack(spacing: 2) {
                    ForEach(events.prefix(3), id: \.id) { event in
                        Circle()
                            .fill(eventColor(for: event))
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            } else {
                Spacer()
                    .frame(height: 4)
            }
        }
        .opacity(isSelectable ? 1.0 : 0.3)
        .disabled(!isSelectable)
        .onTapGesture {
            if isSelectable {
                withAnimation(AppAnimations.quick) {
                    selectedDate = date
                }
                HapticFeedback.selection()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: date, hasEvents: hasEvents, events: events))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isSelectable ? "Double tap to select" : "Date unavailable")
    }

    // MARK: - Hijri Date Display

    private var hijriDateDisplay: some View {
        let hijriDate = HijriDate(from: selectedDate)

        return VStack(spacing: PremiumDesignTokens.spacing8) {
            Divider()

            HStack {
                Image(systemName: "moon.stars")
                    .foregroundColor(themeColors.textSecondary)

                Text(hijriDate.formatted)
                    .font(Typography.bodyMedium)
                    .foregroundColor(themeColors.textPrimary)

                Spacer()

                Text(hijriDate.arabicFormatted)
                    .font(Typography.bodyMedium)
                    .foregroundColor(themeColors.textSecondary)
            }
            .padding(.horizontal, PremiumDesignTokens.spacing12)
        }
        .padding(.top, PremiumDesignTokens.spacing8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Selected date: \(gregorianDateText(selectedDate)), Islamic calendar: \(hijriDate.formatted)")
    }

    // MARK: - Swipe Gesture

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation.width
            }
            .onEnded { value in
                let threshold: CGFloat = 50
                if value.translation.width < -threshold {
                    // Swipe left → next month
                    nextMonth()
                } else if value.translation.width > threshold {
                    // Swipe right → previous month
                    previousMonth()
                }
                dragOffset = 0
            }
    }

    // MARK: - Helpers

    private var themeColors: ThemeAwareColorPalette {
        ThemeAwareColorPalette(theme: currentTheme)
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.veryShortWeekdaySymbols
    }

    private var monthYearText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var hijriMonthYearText: String {
        let hijriDate = HijriDate(from: displayedMonth)
        return "\(hijriDate.month.displayName) \(hijriDate.year)"
    }

    private var daysInMonth: [Date?] {
        guard let monthInterval = gregorianCalendar.dateInterval(of: .month, for: displayedMonth),
              let monthFirstWeekday = gregorianCalendar.dateComponents([.weekday], from: monthInterval.start).weekday else {
            return []
        }

        let firstWeekday = gregorianCalendar.firstWeekday
        let paddingDays = (monthFirstWeekday - firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: paddingDays)

        guard let range = gregorianCalendar.range(of: .day, in: .month, for: displayedMonth) else {
            // Fallback to an empty month when the calendar cannot resolve the range
            return []
        }

        for day in range {
            if let date = gregorianCalendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) {
                days.append(date)
            }
        }

        // Pad to complete weeks (7 days per row)
        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    private func isDateSelectable(_ date: Date) -> Bool {
        date <= maxLookaheadDate
    }

    private func hasEventsOn(_ date: Date) -> Bool {
        islamicEvents.contains { event in
            gregorianCalendar.isDate(event.estimatedDate, inSameDayAs: date)
        }
    }

    private func eventsOn(_ date: Date) -> [IslamicEventEstimate] {
        islamicEvents.filter { event in
            gregorianCalendar.isDate(event.estimatedDate, inSameDayAs: date)
        }
    }

    private func eventColor(for event: IslamicEventEstimate) -> Color {
        // Ramadan → Purple, Eid → Gold, Other → Green
        if event.event.name.lowercased().contains("ramadan") {
            return Color.purple
        } else if event.event.name.lowercased().contains("eid") {
            return Color(hex: "FFD700")  // Gold
        } else {
            return themeColors.primary
        }
    }

    private func textColor(for date: Date, isSelected: Bool, isToday: Bool, isSelectable: Bool) -> Color {
        if isSelected {
            return Color.white
        } else if isToday {
            return themeColors.primary
        } else if !isSelectable {
            return themeColors.textTertiary
        } else {
            return themeColors.textPrimary
        }
    }

    private func backgroundColor(for date: Date, isSelected: Bool, isToday: Bool) -> Color {
        if isSelected {
            return themeColors.primary
        } else if isToday {
            return themeColors.primary.opacity(0.1)
        } else {
            return Color.clear
        }
    }

    private func gregorianDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func accessibilityLabel(for date: Date, hasEvents: Bool, events: [IslamicEventEstimate]) -> String {
        let gregorianText = gregorianDateText(date)
        let hijriDate = HijriDate(from: date)
        let hijriText = hijriDate.formatted

        var label = "\(gregorianText), \(hijriText)"

        if hasEvents {
            let eventNames = events.map { $0.event.name }.joined(separator: ", ")
            label += ". Events: \(eventNames)"
        }

        return label
    }

    private func nextMonth() {
        guard let newMonth = gregorianCalendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
        withAnimation(AppAnimations.standard) {
            displayedMonth = newMonth
        }
        HapticFeedback.light()
    }

    private func previousMonth() {
        guard let newMonth = gregorianCalendar.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
        withAnimation(AppAnimations.standard) {
            displayedMonth = newMonth
        }
        HapticFeedback.light()
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

// Previews removed due to Swift 6 inline @State restrictions.
