import Foundation
import Combine
import CoreLocation

// MARK: - Supporting Types

/// Prayer reminder entry for internal use
public struct PrayerReminderEntry: Codable, Identifiable {
    public let id: UUID
    public let prayer: Prayer
    public let offsetMinutes: Int
    public let isEnabled: Bool
    public let createdAt: Date

    public init(id: UUID = UUID(), prayer: Prayer, offsetMinutes: Int, isEnabled: Bool = true, createdAt: Date = Date()) {
        self.id = id
        self.prayer = prayer
        self.offsetMinutes = offsetMinutes
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }
}

/// Real implementation of PrayerTrackingServiceProtocol
@MainActor
public class PrayerTrackingService: ObservableObject, PrayerTrackingServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published public var currentStreak: Int = 0
    @Published public var todaysCompletedPrayers: Int = 0
    @Published public var todayCompletionRate: Double = 0.0
    @Published public var recentEntries: [PrayerEntry] = []
    @Published public var isTrackingLoading: Bool = false
    @Published public var trackingError: Error? = nil
    
    // MARK: - Private Properties
    
    private let prayerTimeService: any PrayerTimeServiceProtocol
    private let settingsService: any SettingsServiceProtocol
    private let locationService: any LocationServiceProtocol
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - UserDefaults Keys
    
    private enum CacheKeys {
        static let prayerEntries = "prayer_tracking_entries"
        static let prayerStreaks = "prayer_tracking_streaks"
        static let prayerGoals = "prayer_tracking_goals"
        static let prayerReminders = "prayer_tracking_reminders"
        static let prayerJournals = "prayer_tracking_journals"
        static let prayerBadges = "prayer_tracking_badges"
        static let lastCalculatedDate = "prayer_tracking_last_calculated"
    }
    
    // MARK: - Initialization
    
    public init(
        prayerTimeService: any PrayerTimeServiceProtocol,
        settingsService: any SettingsServiceProtocol,
        locationService: any LocationServiceProtocol
    ) {
        self.prayerTimeService = prayerTimeService
        self.settingsService = settingsService
        self.locationService = locationService
        
        setupObservers()
        loadCachedData()
        calculateTodayStats()
    }

    deinit {
        // Clean up notification observers
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup Methods
    
    private func setupObservers() {
        // Observe prayer time changes to update completion rates
        // Note: Using a timer-based approach instead of objectWillChange to avoid conformance issues
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.calculateTodayStats()
            }
        }

        // Setup notification observers for prayer tracking actions
        setupNotificationObservers()
    }

    private func setupNotificationObservers() {
        // Listen for prayer completion from notifications
        NotificationCenter.default.addObserver(
            forName: .prayerMarkedAsPrayed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let prayerString = userInfo["prayer"] as? String,
                  let prayer = Prayer(rawValue: prayerString),
                  let timestamp = userInfo["timestamp"] as? Date else {
                return
            }

            let source = userInfo["source"] as? String ?? "unknown"
            let action = userInfo["action"] as? String ?? "completed"

            print("📱 Received prayer completion from \(source): \(prayer.displayName) - \(action)")

            // Only log as completed if the action is "completed"
            if action == "completed" {
                Task { @MainActor in
                    await self?.logPrayerCompletion(prayer, at: timestamp)
                }
            }
        }

        // Listen for notification taps (for analytics)
        NotificationCenter.default.addObserver(
            forName: .notificationTapped,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let prayerString = userInfo["prayer"] as? String,
                  let prayer = Prayer(rawValue: prayerString) else {
                return
            }

            let source = userInfo["source"] as? String ?? "unknown"
            let action = userInfo["action"] as? String ?? "tapped"

            print("📊 Prayer notification interaction: \(prayer.displayName) - \(action) from \(source)")

            // Could add analytics tracking here
        }

        // Listen for notification dismissals (for analytics)
        NotificationCenter.default.addObserver(
            forName: .notificationDismissed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let prayerString = userInfo["prayer"] as? String,
                  let prayer = Prayer(rawValue: prayerString) else {
                return
            }

            let source = userInfo["source"] as? String ?? "unknown"
            let action = userInfo["action"] as? String ?? "dismissed"

            print("📊 Prayer notification dismissed: \(prayer.displayName) - \(action) from \(source)")

            // Could add analytics tracking here
        }
    }
    
    private func loadCachedData() {
        // Load recent entries
        if let data = userDefaults.data(forKey: CacheKeys.prayerEntries),
           let entries = try? JSONDecoder().decode([PrayerEntry].self, from: data) {
            // Keep only last 100 entries for performance
            recentEntries = Array(entries.suffix(100))
        }
        
        // Load and calculate current streak
        calculateCurrentStreak()
    }
    
    // MARK: - Prayer Completion Methods

    public func logPrayerCompletion(_ prayer: Prayer, at completedAt: Date = Date()) async {
        await markPrayerCompleted(prayer, at: completedAt)
    }

    public func logPrayerCompletion(
        _ prayer: Prayer,
        at completedAt: Date,
        location: String?,
        notes: String?,
        mood: PrayerMood?,
        method: PrayerMethod,
        duration: TimeInterval?,
        congregation: CongregationType,
        isQada: Bool,
        hadithRemembered: String?,
        gratitudeNote: String?,
        difficulty: PrayerDifficulty?,
        tags: [String]
    ) async {
        await markPrayerCompleted(
            prayer,
            at: completedAt,
            location: location,
            notes: notes,
            mood: mood,
            method: method,
            duration: duration,
            congregation: congregation,
            isQada: isQada
        )
    }

    public func markPrayerCompleted(
        _ prayer: Prayer,
        at date: Date = Date(),
        location: String? = nil,
        notes: String? = nil,
        mood: PrayerMood? = nil,
        method: PrayerMethod = .individual,
        duration: TimeInterval? = nil,
        congregation: CongregationType = .individual,
        isQada: Bool = false
    ) async {
        isTrackingLoading = true
        trackingError = nil
        
        do {
            let currentLocation = location ?? getCurrentLocationString()
            
            let entry = PrayerEntry(
                prayer: prayer,
                completedAt: date,
                location: currentLocation,
                notes: notes,
                mood: mood,
                method: method,
                duration: duration,
                congregation: congregation,
                isQada: isQada
            )
            
            // Add to recent entries
            recentEntries.append(entry)
            
            // Keep only last 100 entries
            if recentEntries.count > 100 {
                recentEntries = Array(recentEntries.suffix(100))
            }
            
            // Save to UserDefaults
            try saveEntriesToCache()
            
            // Update statistics
            calculateTodayStats()
            calculateCurrentStreak()
            
            // Check for achievements
            await checkForNewAchievements(entry: entry)
            
        } catch {
            trackingError = error
        }
        
        isTrackingLoading = false
    }
    
    public func markPrayerMissed(_ prayer: Prayer, date: Date = Date(), reason: String? = nil) async {
        // For now, we just recalculate stats
        // In the future, we might want to track missed prayers explicitly
        calculateTodayStats()
        calculateCurrentStreak()
    }
    
    public func undoLastPrayerEntry() async -> Bool {
        guard !recentEntries.isEmpty else { return false }
        
        isTrackingLoading = true
        
        do {
            recentEntries.removeLast()
            try saveEntriesToCache()
            
            calculateTodayStats()
            calculateCurrentStreak()
            
            isTrackingLoading = false
            return true
        } catch {
            trackingError = error
            isTrackingLoading = false
            return false
        }
    }

    public func removePrayerEntry(_ entryId: UUID) async {
        recentEntries.removeAll { $0.id == entryId }
        do {
            try saveEntriesToCache()
            calculateTodayStats()
            calculateCurrentStreak()
        } catch {
            trackingError = error
        }
    }

    public func updatePrayerEntry(_ entry: PrayerEntry) async {
        if let index = recentEntries.firstIndex(where: { $0.id == entry.id }) {
            recentEntries[index] = entry
            do {
                try saveEntriesToCache()
                calculateTodayStats()
                calculateCurrentStreak()
            } catch {
                trackingError = error
            }
        }
    }

    // MARK: - Statistics Methods
    
    public func getPrayerStatistics(for period: DateInterval) async -> PrayerStatistics {
        let entriesInPeriod = recentEntries.filter { entry in
            period.contains(entry.completedAt)
        }
        
        let totalPrayers = entriesInPeriod.count
        let uniqueDays = Set(entriesInPeriod.map { Calendar.current.startOfDay(for: $0.completedAt) }).count
        let averagePerDay = uniqueDays > 0 ? Double(totalPrayers) / Double(uniqueDays) : 0.0
        
        // Calculate prayer-specific statistics
        let prayerCounts = Dictionary(grouping: entriesInPeriod, by: { $0.prayer })
            .mapValues { $0.count }
        
        let mostCompleted = prayerCounts.max(by: { $0.value < $1.value })?.key
        
        // Calculate mood statistics
        let moodEntries = entriesInPeriod.compactMap { $0.mood }
        let averageMood = moodEntries.isEmpty ? nil : moodEntries.first // Simplified for now
        
        // Calculate duration statistics
        let durations = entriesInPeriod.compactMap { $0.duration }
        let totalDuration = durations.reduce(0, +)
        let averageDuration = durations.isEmpty ? 0 : totalDuration / Double(durations.count)
        
        return PrayerStatistics(
            totalPrayers: totalPrayers,
            completedPrayers: totalPrayers,
            currentStreak: currentStreak,
            longestStreak: calculateLongestStreak(),
            averagePerDay: averagePerDay,
            completionRate: calculateCompletionRate(for: period),
            mostCompletedPrayer: mostCompleted,
            averageMood: averageMood,
            totalDuration: totalDuration,
            averageDuration: averageDuration
        )
    }

    public func getCurrentStreak() async -> PrayerStreak {
        return PrayerStreak(
            current: currentStreak,
            longest: calculateLongestStreak(),
            startDate: recentEntries.first?.completedAt,
            endDate: recentEntries.last?.completedAt,
            isActive: currentStreak > 0
        )
    }

    public func getPrayerHistory(
        limit: Int = 100,
        prayer: Prayer? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async -> [PrayerEntry] {
        var filteredEntries = recentEntries

        if let prayer = prayer {
            filteredEntries = filteredEntries.filter { $0.prayer == prayer }
        }

        if let startDate = startDate {
            filteredEntries = filteredEntries.filter { $0.completedAt >= startDate }
        }

        if let endDate = endDate {
            filteredEntries = filteredEntries.filter { $0.completedAt <= endDate }
        }

        return Array(filteredEntries.suffix(limit))
    }

    public func getDailyProgress(for date: Date) async -> DailyPrayerProgress {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let dayEntries = recentEntries.filter { entry in
            entry.completedAt >= startOfDay && entry.completedAt < endOfDay
        }

        let completedPrayers = Set(dayEntries.map { $0.prayer })

        return DailyPrayerProgress(
            date: date,
            fajrCompleted: completedPrayers.contains(.fajr),
            dhuhrCompleted: completedPrayers.contains(.dhuhr),
            asrCompleted: completedPrayers.contains(.asr),
            maghribCompleted: completedPrayers.contains(.maghrib),
            ishaCompleted: completedPrayers.contains(.isha),
            entries: dayEntries
        )
    }

    public func getWeeklyProgress(for date: Date) async -> WeeklyPrayerProgress {
        let calendar = Calendar.current
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date)!

        var dailyProgress: [DailyPrayerProgress] = []
        var currentDate = weekInterval.start

        while currentDate < weekInterval.end {
            let progress = await getDailyProgress(for: currentDate)
            dailyProgress.append(progress)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return WeeklyPrayerProgress(
            startDate: weekInterval.start,
            endDate: weekInterval.end,
            dailyProgress: dailyProgress
        )
    }

    public func getMonthlyStatistics(for date: Date) async -> PrayerStatistics {
        let calendar = Calendar.current
        let monthInterval = calendar.dateInterval(of: .month, for: date)!
        return await getPrayerStatistics(for: monthInterval)
    }

    public func getPrayerStreak(for prayer: Prayer) async -> PrayerStreak? {
        let prayerEntries = recentEntries.filter { $0.prayer == prayer }
        guard !prayerEntries.isEmpty else { return nil }
        
        let currentStreak = calculateStreakForPrayer(prayer)
        let longestStreak = calculateLongestStreakForPrayer(prayer)
        
        return PrayerStreak(
            current: currentStreak,
            longest: longestStreak,
            startDate: calculateStreakStartDate(for: prayer),
            endDate: prayerEntries.last?.completedAt,
            isActive: currentStreak > 0
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func getCurrentLocationString() -> String? {
        guard let location = locationService.currentLocation else { return nil }
        // In a real implementation, you might want to reverse geocode this
        return "\(location.coordinate.latitude), \(location.coordinate.longitude)"
    }
    
    private func saveEntriesToCache() throws {
        let data = try JSONEncoder().encode(recentEntries)
        userDefaults.set(data, forKey: CacheKeys.prayerEntries)
    }
    
    private func calculateTodayStats() {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let todayEntries = recentEntries.filter { entry in
            entry.completedAt >= today && entry.completedAt < tomorrow
        }
        
        todaysCompletedPrayers = todayEntries.count
        
        // Calculate completion rate based on expected prayers (5 daily prayers)
        let expectedPrayers = 5
        todayCompletionRate = min(Double(todaysCompletedPrayers) / Double(expectedPrayers), 1.0)
    }
    
    private func calculateCurrentStreak() {
        currentStreak = calculateConsecutiveDaysWithPrayers()
    }
    
    private func calculateConsecutiveDaysWithPrayers() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        while true {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            let dayEntries = recentEntries.filter { entry in
                entry.completedAt >= currentDate && entry.completedAt < nextDay
            }
            
            if dayEntries.isEmpty {
                break
            }
            
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }
        
        return streak
    }
    
    private func calculateLongestStreak() -> Int {
        // Simplified implementation - in reality, you'd want to analyze all historical data
        return currentStreak // For now, return current streak
    }
    
    private func calculateCompletionRate(for period: DateInterval) -> Double {
        let entriesInPeriod = recentEntries.filter { period.contains($0.completedAt) }
        let days = Int(period.duration / (24 * 60 * 60))
        let expectedPrayers = days * 5 // 5 prayers per day
        
        return expectedPrayers > 0 ? Double(entriesInPeriod.count) / Double(expectedPrayers) : 0.0
    }
    
    private func calculateStreakForPrayer(_ prayer: Prayer) -> Int {
        // Simplified implementation
        return recentEntries.filter { $0.prayer == prayer }.count
    }
    
    private func calculateLongestStreakForPrayer(_ prayer: Prayer) -> Int {
        // Simplified implementation
        return calculateStreakForPrayer(prayer)
    }
    
    private func calculateStreakStartDate(for prayer: Prayer) -> Date? {
        return recentEntries.first { $0.prayer == prayer }?.completedAt
    }
    
    private func checkForNewAchievements(entry: PrayerEntry) async {
        // Achievement checking logic would go here
        // For now, this is a placeholder
    }

    // MARK: - Journal Methods

    public func addPrayerJournalEntry(_ entry: PrayerJournalEntry) async {
        // Save journal entry to UserDefaults
        var journals = loadJournalEntries()
        journals.append(entry)

        do {
            let data = try JSONEncoder().encode(journals)
            userDefaults.set(data, forKey: CacheKeys.prayerJournals)
        } catch {
            trackingError = error
        }
    }

    public func getPrayerJournalEntries(for period: DateInterval) async -> [PrayerJournalEntry] {
        let journals = loadJournalEntries()
        return journals.filter { period.contains($0.date) }
    }

    public func updatePrayerJournalEntry(_ entry: PrayerJournalEntry) async {
        var journals = loadJournalEntries()
        if let index = journals.firstIndex(where: { $0.id == entry.id }) {
            journals[index] = entry

            do {
                let data = try JSONEncoder().encode(journals)
                userDefaults.set(data, forKey: CacheKeys.prayerJournals)
            } catch {
                trackingError = error
            }
        }
    }

    public func deletePrayerJournalEntry(_ entryId: UUID) async {
        var journals = loadJournalEntries()
        journals.removeAll { $0.id == entryId.uuidString }

        do {
            let data = try JSONEncoder().encode(journals)
            userDefaults.set(data, forKey: CacheKeys.prayerJournals)
        } catch {
            trackingError = error
        }
    }

    // MARK: - Reminder Methods

    public func schedulePrayerReminder(for prayer: Prayer, offset: TimeInterval) async {
        // Create a basic reminder - in a real implementation, this would schedule notifications
        let reminder = PrayerReminderEntry(
            id: UUID(),
            prayer: prayer,
            offsetMinutes: Int(offset / 60),
            isEnabled: true,
            createdAt: Date()
        )

        var reminders = loadReminderEntries()
        reminders.removeAll { $0.prayer == prayer } // Remove existing
        reminders.append(reminder)

        do {
            let data = try JSONEncoder().encode(reminders)
            userDefaults.set(data, forKey: CacheKeys.prayerReminders)
        } catch {
            trackingError = error
        }
    }

    public func cancelPrayerReminder(for prayer: Prayer) async {
        await deletePrayerReminder(for: prayer)
    }

    public func updateReminderSettings(enabled: Bool, defaultOffset: TimeInterval) async {
        // Store reminder settings in UserDefaults
        userDefaults.set(enabled, forKey: "prayer_reminders_enabled")
        userDefaults.set(defaultOffset, forKey: "prayer_reminders_default_offset")
    }

    public func setPrayerReminder(_ reminder: PrayerReminderEntry) async {
        var reminders = loadReminderEntries()

        // Remove existing reminder for the same prayer if it exists
        reminders.removeAll { $0.prayer == reminder.prayer }
        reminders.append(reminder)

        do {
            let data = try JSONEncoder().encode(reminders)
            userDefaults.set(data, forKey: CacheKeys.prayerReminders)
        } catch {
            trackingError = error
        }
    }

    public func getPrayerReminders() async -> [PrayerReminderEntry] {
        return loadReminderEntries()
    }

    public func deletePrayerReminder(for prayer: Prayer) async {
        var reminders = loadReminders()
        reminders.removeAll { $0.prayer == prayer }

        do {
            let data = try JSONEncoder().encode(reminders)
            userDefaults.set(data, forKey: CacheKeys.prayerReminders)
        } catch {
            trackingError = error
        }
    }

    // MARK: - Goal Methods

    public func setPrayerGoal(_ goal: PrayerGoal, for period: DateInterval) async {
        var goals = loadGoals()

        // Remove existing goal for the same period if it exists
        goals.removeAll { $0.endDate == goal.endDate }
        goals.append(goal)

        do {
            let data = try JSONEncoder().encode(goals)
            userDefaults.set(data, forKey: CacheKeys.prayerGoals)
        } catch {
            trackingError = error
        }
    }

    public func getCurrentGoals() async -> [PrayerGoal] {
        let goals = loadGoals()
        let now = Date()
        return goals.filter { $0.endDate >= now }
    }

    public func getGoalProgress() async -> [PrayerGoalProgress] {
        let goals = await getCurrentGoals()
        var progressArray: [PrayerGoalProgress] = []

        for goal in goals {
            let progress = calculateGoalProgress(for: goal)
            progressArray.append(progress)
        }

        return progressArray
    }

    // MARK: - Export Methods

    public func exportPrayerData(for period: DateInterval) async -> String {
        let entries = recentEntries.filter { period.contains($0.completedAt) }

        var csv = "Date,Prayer,Location,Notes,Mood,Method,Duration,Congregation,IsQada\n"

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        for entry in entries {
            let row = [
                formatter.string(from: entry.completedAt),
                entry.prayer.rawValue,
                entry.location ?? "",
                entry.notes ?? "",
                entry.mood?.rawValue ?? "",
                entry.method.rawValue,
                entry.duration?.description ?? "",
                entry.congregation.rawValue,
                entry.isQada.description
            ].joined(separator: ",")

            csv += row + "\n"
        }

        return csv
    }

    public func exportPrayerStatistics(for period: DateInterval) async -> String {
        let stats = await getPrayerStatistics(for: period)

        let statsDict: [String: Any] = [
            "totalPrayers": stats.totalPrayers,
            "completedPrayers": stats.completedPrayers,
            "currentStreak": stats.currentStreak,
            "longestStreak": stats.longestStreak,
            "averagePerDay": stats.averagePerDay,
            "completionRate": stats.completionRate,
            "mostCompletedPrayer": stats.mostCompletedPrayer?.rawValue ?? "",
            "totalDuration": stats.totalDuration,
            "averageDuration": stats.averageDuration
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: statsDict, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"Failed to export statistics\"}"
        }
    }

    // MARK: - Insights Methods

    public func getPrayerInsights() async -> [PrayerInsight] {
        // Simplified implementation - return basic insights
        var insights: [PrayerInsight] = []

        if currentStreak > 7 {
            insights.append(PrayerInsight(
                title: "Great Streak!",
                description: "You've maintained a \(currentStreak)-day prayer streak. Keep it up!",
                type: .achievement,
                importance: .high
            ))
        }

        if todayCompletionRate < 0.6 {
            insights.append(PrayerInsight(
                title: "Prayer Reminder",
                description: "You've completed \(Int(todayCompletionRate * 100))% of today's prayers. Don't forget your remaining prayers!",
                type: .recommendation,
                importance: .medium,
                actionRequired: true
            ))
        }

        return insights
    }

    public func getPrayerPatterns() async -> PrayerPatternAnalysis {
        // Simplified implementation
        return PrayerPatternAnalysis(
            mostActiveDay: "Friday",
            mostActiveTime: "Morning",
            averageDelay: 0.0,
            consistencyScore: todayCompletionRate,
            trends: [],
            recommendations: ["Evening prayers", "Weekend consistency"]
        )
    }

    public func getPersonalizedTips() async -> [PrayerTip] {
        var tips: [PrayerTip] = []

        if currentStreak == 0 {
            tips.append(PrayerTip(
                title: "Start Small",
                description: "Begin with just one prayer a day and gradually build your habit.",
                category: .motivation
            ))
        }

        if todayCompletionRate > 0.8 {
            tips.append(PrayerTip(
                title: "Add Reflection",
                description: "Consider adding a brief reflection or gratitude note after each prayer.",
                category: .technique
            ))
        }

        return tips
    }

    // MARK: - Cache Methods

    public func clearTrackingCache() async {
        userDefaults.removeObject(forKey: CacheKeys.prayerEntries)
        userDefaults.removeObject(forKey: CacheKeys.prayerStreaks)
        userDefaults.removeObject(forKey: CacheKeys.prayerGoals)
        userDefaults.removeObject(forKey: CacheKeys.prayerReminders)
        userDefaults.removeObject(forKey: CacheKeys.prayerJournals)
        userDefaults.removeObject(forKey: CacheKeys.prayerBadges)

        // Reset published properties
        recentEntries = []
        currentStreak = 0
        todaysCompletedPrayers = 0
        todayCompletionRate = 0.0
    }

    public func refreshTrackingData() async {
        loadCachedData()
        calculateTodayStats()
        calculateCurrentStreak()
    }

    public func syncPrayerData() async throws {
        // Placeholder for remote sync functionality
        // In a real implementation, this would sync with a backend service
        throw NSError(domain: "PrayerTrackingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Remote sync not implemented"])
    }

    // MARK: - Private Helper Methods for Data Loading

    private func loadJournalEntries() -> [PrayerJournalEntry] {
        guard let data = userDefaults.data(forKey: CacheKeys.prayerJournals),
              let journals = try? JSONDecoder().decode([PrayerJournalEntry].self, from: data) else {
            return []
        }
        return journals
    }

    private func loadReminderEntries() -> [PrayerReminderEntry] {
        guard let data = userDefaults.data(forKey: CacheKeys.prayerReminders),
              let reminders = try? JSONDecoder().decode([PrayerReminderEntry].self, from: data) else {
            return []
        }
        return reminders
    }

    private func loadReminders() -> [PrayerReminderEntry] {
        return loadReminderEntries()
    }

    private func loadGoals() -> [PrayerGoal] {
        guard let data = userDefaults.data(forKey: CacheKeys.prayerGoals),
              let goals = try? JSONDecoder().decode([PrayerGoal].self, from: data) else {
            return []
        }
        return goals
    }

    private func calculateGoalProgress(for goal: PrayerGoal) -> PrayerGoalProgress {
        // Simplified implementation
        let completedCount = recentEntries.filter { entry in
            goal.prayers.contains(entry.prayer) && entry.completedAt >= goal.startDate
        }.count

        let progress = min(Double(completedCount) / goal.targetValue, 1.0)

        return PrayerGoalProgress(
            goal: goal,
            completedPrayers: completedCount,
            completedDays: 0 // Simplified for now
        )
    }
}
