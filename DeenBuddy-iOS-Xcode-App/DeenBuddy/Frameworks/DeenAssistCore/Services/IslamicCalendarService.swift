import Foundation
import Combine

/// Real implementation of IslamicCalendarServiceProtocol
@MainActor
public class IslamicCalendarService: IslamicCalendarServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var currentHijriDate: HijriDate = HijriDate(from: Date())
    @Published public var todayInfo: IslamicCalendarDay = IslamicCalendarDay(gregorianDate: Date(), hijriDate: HijriDate(from: Date()))
    @Published public var upcomingEvents: [IslamicEvent] = []
    @Published public var allEvents: [IslamicEvent] = []
    @Published public var statistics: IslamicCalendarStatistics = IslamicCalendarStatistics()
    @Published public var isLoading: Bool = false
    @Published public var error: Error? = nil
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    private var calculationMethod: IslamicCalendarMethod = .civil
    private var eventNotificationsEnabled: Bool = true
    private var defaultReminderTime: TimeInterval = 86400 // 24 hours
    
    // MARK: - UserDefaults Keys
    
    private enum CacheKeys {
        static let events = "islamic_calendar_events"
        static let customEvents = "islamic_calendar_custom_events"
        static let reminders = "islamic_calendar_reminders"
        static let settings = "islamic_calendar_settings"
        static let statistics = "islamic_calendar_statistics"
        static let calculationMethod = "islamic_calendar_method"
    }
    
    // MARK: - Initialization
    
    public init() {
        setupDefaultEvents()
        loadCachedData()
        setupObservers()
        updateTodayInfo()
    }
    
    // MARK: - Setup Methods
    
    private func setupDefaultEvents() {
        let defaultEvents = [
            // Major Islamic Events
            IslamicEvent(
                name: "Islamic New Year",
                arabicName: "رأس السنة الهجرية",
                description: "The beginning of the Islamic lunar year",
                hijriDate: HijriDate(day: 1, month: .muharram, year: 1445),
                category: .religious,
                significance: .major,
                observances: ["Reflection on the Hijra", "Prayers for the new year"],
                source: "Islamic Tradition"
            ),
            IslamicEvent(
                name: "Day of Ashura",
                arabicName: "يوم عاشوراء",
                description: "The 10th day of Muharram, a day of fasting and remembrance",
                hijriDate: HijriDate(day: 10, month: .muharram, year: 1445),
                category: .religious,
                significance: .major,
                observances: ["Fasting", "Charity", "Remembrance of martyrs"],
                source: "Hadith"
            ),
            IslamicEvent(
                name: "Mawlid an-Nabi",
                arabicName: "المولد النبوي",
                description: "Birthday of Prophet Muhammad (peace be upon him)",
                hijriDate: HijriDate(day: 12, month: .rabiAlAwwal, year: 1445),
                category: .religious,
                significance: .major,
                observances: ["Recitation of Quran", "Sending blessings on the Prophet", "Charity"],
                source: "Islamic Tradition"
            ),
            IslamicEvent(
                name: "Isra and Mi'raj",
                arabicName: "الإسراء والمعراج",
                description: "The Night Journey and Ascension of Prophet Muhammad",
                hijriDate: HijriDate(day: 27, month: .rajab, year: 1445),
                category: .religious,
                significance: .major,
                observances: ["Night prayers", "Recitation of Quran", "Reflection"],
                source: "Quran and Hadith"
            ),
            IslamicEvent(
                name: "Laylat al-Bara'at",
                arabicName: "ليلة البراءة",
                description: "The Night of Forgiveness",
                hijriDate: HijriDate(day: 15, month: .shaban, year: 1445),
                category: .religious,
                significance: .moderate,
                observances: ["Night prayers", "Seeking forgiveness", "Charity"],
                source: "Hadith"
            ),
            IslamicEvent(
                name: "First Day of Ramadan",
                arabicName: "أول رمضان",
                description: "Beginning of the holy month of fasting",
                hijriDate: HijriDate(day: 1, month: .ramadan, year: 1445),
                category: .religious,
                significance: .major,
                observances: ["Fasting begins", "Increased prayers", "Charity"],
                source: "Quran"
            ),
            IslamicEvent(
                name: "Laylat al-Qadr",
                arabicName: "ليلة القدر",
                description: "The Night of Power",
                hijriDate: HijriDate(day: 27, month: .ramadan, year: 1445),
                category: .religious,
                significance: .major,
                observances: ["Night prayers", "Recitation of Quran", "Seeking Laylat al-Qadr"],
                source: "Quran"
            ),
            IslamicEvent(
                name: "Eid al-Fitr",
                arabicName: "عيد الفطر",
                description: "Festival of Breaking the Fast",
                hijriDate: HijriDate(day: 1, month: .shawwal, year: 1445),
                category: .religious,
                significance: .major,
                observances: ["Eid prayers", "Charity (Zakat al-Fitr)", "Celebration", "Family gatherings"],
                source: "Hadith"
            ),
            IslamicEvent(
                name: "Day of Arafah",
                arabicName: "يوم عرفة",
                description: "The most important day of Hajj pilgrimage",
                hijriDate: HijriDate(day: 9, month: .dhulHijjah, year: 1445),
                category: .religious,
                significance: .major,
                observances: ["Fasting (for non-pilgrims)", "Prayers", "Remembrance of Allah"],
                source: "Hadith"
            ),
            IslamicEvent(
                name: "Eid al-Adha",
                arabicName: "عيد الأضحى",
                description: "Festival of Sacrifice",
                hijriDate: HijriDate(day: 10, month: .dhulHijjah, year: 1445),
                category: .religious,
                significance: .major,
                observances: ["Eid prayers", "Animal sacrifice", "Charity", "Family gatherings"],
                source: "Quran and Hadith"
            )
        ]
        
        allEvents = defaultEvents
    }
    
    private func setupObservers() {
        // Update today's info daily
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTodayInfo()
            }
        }
        
        // Update current Hijri date
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentHijriDate = HijriDate(from: Date())
            }
        }
    }
    
    private func loadCachedData() {
        // Load custom events
        if let data = userDefaults.data(forKey: CacheKeys.customEvents),
           let customEvents = try? JSONDecoder().decode([IslamicEvent].self, from: data) {
            allEvents.append(contentsOf: customEvents)
        }
        
        // Load calculation method
        if let methodString = userDefaults.string(forKey: CacheKeys.calculationMethod),
           let method = IslamicCalendarMethod(rawValue: methodString) {
            calculationMethod = method
        }
        
        // Load statistics
        if let data = userDefaults.data(forKey: CacheKeys.statistics),
           let stats = try? JSONDecoder().decode(IslamicCalendarStatistics.self, from: data) {
            statistics = stats
        }
        
        updateUpcomingEvents()
    }
    
    private func updateTodayInfo() {
        let today = Date()
        let hijriDate = HijriDate(from: today)
        let todayEvents = allEvents.filter { event in
            let eventDate = event.gregorianDate(for: hijriDate.year)
            return Calendar.current.isDate(eventDate, inSameDayAs: today)
        }
        
        todayInfo = IslamicCalendarDay(
            gregorianDate: today,
            hijriDate: hijriDate,
            events: todayEvents,
            moonPhase: calculateMoonPhase(for: today),
            isHolyDay: !todayEvents.isEmpty || hijriDate.month.isHolyMonth,
            specialObservances: todayEvents.flatMap { $0.observances }
        )
    }
    
    private func updateUpcomingEvents() {
        let today = Date()
        let calendar = Calendar.current
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: today) ?? today
        
        upcomingEvents = allEvents.compactMap { event in
            let eventDate = event.gregorianDate(for: currentHijriDate.year)
            if eventDate > today && eventDate <= nextMonth {
                return event
            }
            return nil
        }.sorted { event1, event2 in
            let date1 = event1.gregorianDate(for: currentHijriDate.year)
            let date2 = event2.gregorianDate(for: currentHijriDate.year)
            return date1 < date2
        }
    }
    
    // MARK: - Date Conversion
    
    public func convertToHijri(_ gregorianDate: Date) async -> HijriDate {
        return HijriDate(from: gregorianDate)
    }
    
    public func convertToGregorian(_ hijriDate: HijriDate) async -> Date {
        return hijriDate.toGregorianDate()
    }
    
    public func getCurrentHijriDate() async -> HijriDate {
        return HijriDate(from: Date())
    }
    
    public func isDate(_ gregorianDate: Date, equalToHijri hijriDate: HijriDate) async -> Bool {
        let convertedHijri = HijriDate(from: gregorianDate)
        return convertedHijri == hijriDate
    }
    
    // MARK: - Calendar Information
    
    public func getCalendarInfo(for date: Date) async -> IslamicCalendarDay {
        let hijriDate = HijriDate(from: date)
        let dayEvents = allEvents.filter { event in
            let eventDate = event.gregorianDate(for: hijriDate.year)
            return Calendar.current.isDate(eventDate, inSameDayAs: date)
        }
        
        return IslamicCalendarDay(
            gregorianDate: date,
            hijriDate: hijriDate,
            events: dayEvents,
            moonPhase: calculateMoonPhase(for: date),
            isHolyDay: !dayEvents.isEmpty || hijriDate.month.isHolyMonth,
            specialObservances: dayEvents.flatMap { $0.observances }
        )
    }
    
    public func getCalendarInfo(for period: DateInterval) async -> [IslamicCalendarDay] {
        var calendarDays: [IslamicCalendarDay] = []
        let calendar = Calendar.current
        var currentDate = period.start
        
        while currentDate <= period.end {
            let dayInfo = await getCalendarInfo(for: currentDate)
            calendarDays.append(dayInfo)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? period.end
        }
        
        return calendarDays
    }
    
    public func getMonthInfo(month: HijriMonth, year: Int) async -> [IslamicCalendarDay] {
        // Create date range for the Hijri month
        let startHijri = HijriDate(day: 1, month: month, year: year)
        let endHijri = HijriDate(day: 29, month: month, year: year) // Minimum month length
        
        let startGregorian = startHijri.toGregorianDate()
        let endGregorian = endHijri.toGregorianDate()
        
        let period = DateInterval(start: startGregorian, end: endGregorian)
        return await getCalendarInfo(for: period)
    }
    
    public func isHolyDay(_ date: Date) async -> Bool {
        let calendarInfo = await getCalendarInfo(for: date)
        return calendarInfo.isHolyDay
    }
    
    public func getMoonPhase(for date: Date) async -> MoonPhase? {
        return calculateMoonPhase(for: date)
    }
    
    // MARK: - Event Management
    
    public func getAllEvents() async -> [IslamicEvent] {
        return allEvents
    }
    
    public func getEvents(for date: Date) async -> [IslamicEvent] {
        let hijriDate = HijriDate(from: date)
        return allEvents.filter { event in
            let eventDate = event.gregorianDate(for: hijriDate.year)
            return Calendar.current.isDate(eventDate, inSameDayAs: date)
        }
    }
    
    public func getEvents(for period: DateInterval) async -> [IslamicEvent] {
        let currentYear = currentHijriDate.year
        return allEvents.filter { event in
            let eventDate = event.gregorianDate(for: currentYear)
            return period.contains(eventDate)
        }
    }
    
    public func getEvents(by category: EventCategory) async -> [IslamicEvent] {
        return allEvents.filter { $0.category == category }
    }
    
    public func getEvents(by significance: EventSignificance) async -> [IslamicEvent] {
        return allEvents.filter { $0.significance == significance }
    }
    
    public func getUpcomingEvents(limit: Int = 10) async -> [IslamicEvent] {
        updateUpcomingEvents()
        return Array(upcomingEvents.prefix(limit))
    }
    
    public func searchEvents(_ query: String) async -> [IslamicEvent] {
        let lowercaseQuery = query.lowercased()
        return allEvents.filter { event in
            event.name.lowercased().contains(lowercaseQuery) ||
            event.description.lowercased().contains(lowercaseQuery) ||
            event.arabicName?.lowercased().contains(lowercaseQuery) == true
        }
    }
    
    public func addCustomEvent(_ event: IslamicEvent) async {
        var customEvent = event
        customEvent = IslamicEvent(
            id: event.id,
            name: event.name,
            arabicName: event.arabicName,
            description: event.description,
            hijriDate: event.hijriDate,
            category: event.category,
            significance: event.significance,
            observances: event.observances,
            isRecurring: event.isRecurring,
            duration: event.duration,
            source: event.source,
            isUserAdded: true
        )
        
        allEvents.append(customEvent)
        updateUpcomingEvents()
        
        do {
            try saveCachedData()
        } catch {
            self.error = error
        }
    }
    
    public func updateEvent(_ event: IslamicEvent) async {
        if let index = allEvents.firstIndex(where: { $0.id == event.id }) {
            allEvents[index] = event
            updateUpcomingEvents()
            
            do {
                try saveCachedData()
            } catch {
                self.error = error
            }
        }
    }
    
    public func deleteEvent(_ eventId: UUID) async {
        allEvents.removeAll { $0.id == eventId && $0.isUserAdded }
        updateUpcomingEvents()
        
        do {
            try saveCachedData()
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func calculateMoonPhase(for date: Date) -> MoonPhase? {
        // Simplified moon phase calculation
        // In a real implementation, you would use astronomical calculations
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let phase = (dayOfYear % 29) // Approximate lunar cycle
        
        switch phase {
        case 0...3: return .newMoon
        case 4...6: return .waxingCrescent
        case 7...10: return .firstQuarter
        case 11...13: return .waxingGibbous
        case 14...16: return .fullMoon
        case 17...20: return .waningGibbous
        case 21...24: return .lastQuarter
        case 25...28: return .waningCrescent
        default: return .newMoon
        }
    }
    
    private func saveCachedData() throws {
        // Save custom events only
        let customEvents = allEvents.filter { $0.isUserAdded }
        let customEventsData = try JSONEncoder().encode(customEvents)
        userDefaults.set(customEventsData, forKey: CacheKeys.customEvents)

        // Save calculation method
        userDefaults.set(calculationMethod.rawValue, forKey: CacheKeys.calculationMethod)

        // Save statistics
        let statisticsData = try JSONEncoder().encode(statistics)
        userDefaults.set(statisticsData, forKey: CacheKeys.statistics)
    }

    // MARK: - Holy Months & Special Periods

    public func isRamadan() async -> Bool {
        return currentHijriDate.month == .ramadan
    }

    public func isHolyMonth() async -> Bool {
        return currentHijriDate.month.isHolyMonth
    }

    public func getDaysRemainingInMonth() async -> Int {
        let calendar = Calendar(identifier: .islamicCivil)
        let currentDate = Date()
        let range = calendar.range(of: .day, in: .month, for: currentDate)
        let daysInMonth = range?.count ?? 30
        return daysInMonth - currentHijriDate.day
    }

    public func getCurrentHolyMonthInfo() async -> HolyMonthInfo? {
        guard currentHijriDate.month.isHolyMonth else { return nil }

        let monthEvents = allEvents.filter { $0.hijriDate.month == currentHijriDate.month }
        let daysRemaining = await getDaysRemainingInMonth()

        let significance: String
        switch currentHijriDate.month {
        case .muharram:
            significance = "The first month of the Islamic year, containing the Day of Ashura"
        case .rajab:
            significance = "One of the four sacred months, month of Isra and Mi'raj"
        case .dhulQadah:
            significance = "One of the four sacred months, preparation for Hajj"
        case .dhulHijjah:
            significance = "The month of Hajj pilgrimage and Eid al-Adha"
        default:
            significance = "A blessed month in the Islamic calendar"
        }

        return HolyMonthInfo(
            month: currentHijriDate.month,
            year: currentHijriDate.year,
            significance: significance,
            observances: monthEvents.flatMap { $0.observances },
            specialDays: monthEvents,
            daysRemaining: daysRemaining
        )
    }

    public func getRamadanPeriod(for hijriYear: Int) async -> DateInterval? {
        let ramadanStart = HijriDate(day: 1, month: .ramadan, year: hijriYear)
        let ramadanEnd = HijriDate(day: 29, month: .ramadan, year: hijriYear) // Minimum length

        let startDate = ramadanStart.toGregorianDate()
        let endDate = ramadanEnd.toGregorianDate()

        return DateInterval(start: startDate, end: endDate)
    }

    public func getHajjPeriod(for hijriYear: Int) async -> DateInterval? {
        let hajjStart = HijriDate(day: 8, month: .dhulHijjah, year: hijriYear)
        let hajjEnd = HijriDate(day: 13, month: .dhulHijjah, year: hijriYear)

        let startDate = hajjStart.toGregorianDate()
        let endDate = hajjEnd.toGregorianDate()

        return DateInterval(start: startDate, end: endDate)
    }

    // MARK: - Notifications & Reminders

    public func setEventReminder(_ event: IslamicEvent, reminderTime: TimeInterval) async {
        let reminder = EventReminder(
            event: event,
            reminderTime: reminderTime
        )

        var reminders = loadReminders()
        reminders.append(reminder)

        do {
            let data = try JSONEncoder().encode(reminders)
            userDefaults.set(data, forKey: CacheKeys.reminders)
        } catch {
            self.error = error
        }
    }

    public func getActiveReminders() async -> [EventReminder] {
        return loadReminders().filter { $0.isActive }
    }

    public func cancelEventReminder(_ reminderId: UUID) async {
        var reminders = loadReminders()
        reminders.removeAll { $0.id == reminderId }

        do {
            let data = try JSONEncoder().encode(reminders)
            userDefaults.set(data, forKey: CacheKeys.reminders)
        } catch {
            self.error = error
        }
    }

    // MARK: - Statistics & Analytics

    public func getStatistics() async -> IslamicCalendarStatistics {
        let totalEvents = allEvents.count
        let majorEventsThisYear = allEvents.filter {
            $0.significance == .major && $0.hijriDate.year == currentHijriDate.year
        }.count
        let personalEvents = allEvents.filter { $0.isUserAdded }.count
        let upcoming = Array(upcomingEvents.prefix(5))

        return IslamicCalendarStatistics(
            totalEventsTracked: totalEvents,
            majorEventsThisYear: majorEventsThisYear,
            holyMonthsObserved: 4, // Four holy months
            personalEventsAdded: personalEvents,
            mostActiveMonth: await getMostActiveMonth(),
            upcomingEvents: upcoming,
            recentlyObserved: []
        )
    }

    public func getEventsObservedThisYear() async -> [IslamicEvent] {
        return allEvents.filter { $0.hijriDate.year == currentHijriDate.year }
    }

    public func getMostActiveMonth() async -> HijriMonth? {
        let monthCounts = Dictionary(grouping: allEvents, by: { $0.hijriDate.month })
            .mapValues { $0.count }

        return monthCounts.max(by: { $0.value < $1.value })?.key
    }

    public func getEventFrequencyByCategory() async -> [EventCategory: Int] {
        return Dictionary(grouping: allEvents, by: { $0.category })
            .mapValues { $0.count }
    }

    // MARK: - Import & Export

    public func exportCalendarData(for period: DateInterval) async -> String {
        let periodEvents = await getEvents(for: period)

        let exportData: [String: Any] = [
            "events": periodEvents.map { event in
                [
                    "id": event.id.uuidString,
                    "name": event.name,
                    "arabicName": event.arabicName,
                    "description": event.description,
                    "hijriDate": [
                        "day": event.hijriDate.day,
                        "month": event.hijriDate.month.rawValue,
                        "year": event.hijriDate.year
                    ],
                    "category": event.category.rawValue,
                    "significance": event.significance.rawValue,
                    "observances": event.observances,
                    "isRecurring": event.isRecurring,
                    "duration": event.duration,
                    "source": event.source,
                    "isUserAdded": event.isUserAdded
                ]
            },
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "period": [
                "start": ISO8601DateFormatter().string(from: period.start),
                "end": ISO8601DateFormatter().string(from: period.end)
            ]
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"Failed to export calendar data\"}"
        }
    }

    public func importEvents(from jsonData: String) async throws {
        guard let data = jsonData.data(using: .utf8) else {
            throw NSError(domain: "IslamicCalendarService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON data"])
        }

        let eventArray = try JSONDecoder().decode([IslamicEvent].self, from: data)

        for event in eventArray {
            await addCustomEvent(event)
        }
    }

    public func exportAsICalendar(_ events: [IslamicEvent]) async -> String {
        var icalendar = "BEGIN:VCALENDAR\r\n"
        icalendar += "VERSION:2.0\r\n"
        icalendar += "PRODID:-//DeenBuddy//Islamic Calendar//EN\r\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")

        for event in events {
            let eventDate = event.gregorianDate(for: currentHijriDate.year)

            icalendar += "BEGIN:VEVENT\r\n"
            icalendar += "UID:\(event.id.uuidString)\r\n"
            icalendar += "DTSTART:\(dateFormatter.string(from: eventDate))\r\n"
            icalendar += "SUMMARY:\(event.name)\r\n"
            icalendar += "DESCRIPTION:\(event.description)\r\n"
            icalendar += "CATEGORIES:\(event.category.displayName)\r\n"
            icalendar += "END:VEVENT\r\n"
        }

        icalendar += "END:VCALENDAR\r\n"
        return icalendar
    }

    // MARK: - Settings & Preferences

    public func setCalculationMethod(_ method: IslamicCalendarMethod) async {
        calculationMethod = method

        do {
            try saveCachedData()
        } catch {
            self.error = error
        }
    }

    public func setEventNotifications(_ enabled: Bool) async {
        eventNotificationsEnabled = enabled

        do {
            try saveCachedData()
        } catch {
            self.error = error
        }
    }

    public func setDefaultReminderTime(_ time: TimeInterval) async {
        defaultReminderTime = time

        do {
            try saveCachedData()
        } catch {
            self.error = error
        }
    }

    // MARK: - Cache Management

    public func refreshCalendarData() async {
        updateTodayInfo()
        updateUpcomingEvents()
        statistics = await getStatistics()
    }

    public func clearCache() async {
        userDefaults.removeObject(forKey: CacheKeys.customEvents)
        userDefaults.removeObject(forKey: CacheKeys.reminders)
        userDefaults.removeObject(forKey: CacheKeys.settings)
        userDefaults.removeObject(forKey: CacheKeys.statistics)

        // Reset to defaults
        setupDefaultEvents()
        statistics = IslamicCalendarStatistics()
        updateTodayInfo()
        updateUpcomingEvents()
    }

    public func updateFromExternalSources() async {
        // In a real implementation, this would fetch updated event data from external sources
        await refreshCalendarData()
    }

    // MARK: - Private Helper Methods

    private func loadReminders() -> [EventReminder] {
        guard let data = userDefaults.data(forKey: CacheKeys.reminders),
              let reminders = try? JSONDecoder().decode([EventReminder].self, from: data) else {
            return []
        }
        return reminders
    }
}
