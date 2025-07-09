import Foundation
import Combine

// MARK: - Prayer Journal Service

/// Service for tracking prayer completion and managing prayer journal
@MainActor
public class PrayerJournalService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var entries: [PrayerJournalEntry] = []
    @Published public var dailyStats: [DailyPrayerStats] = []
    @Published public var currentStreak: Int = 0
    @Published public var bestStreak: Int = 0
    @Published public var isLoading = false
    @Published public var error: Error?
    @Published public var goals: [PrayerGoal] = []
    @Published public var todayStats: DailyPrayerStats?
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    private let prayerTimeService: PrayerTimeService
    
    // MARK: - Cache Keys
    
    private enum CacheKeys {
        static let entries = "DeenAssist.PrayerJournal.Entries"
        static let dailyStats = "DeenAssist.PrayerJournal.DailyStats"
        static let goals = "DeenAssist.PrayerJournal.Goals"
        static let streaks = "DeenAssist.PrayerJournal.Streaks"
    }
    
    // MARK: - Initialization
    
    public init(prayerTimeService: PrayerTimeService) {
        self.prayerTimeService = prayerTimeService
        loadCachedData()
        updateTodayStats()
        calculateStreaks()
        setupDefaultGoals()
    }
    
    // MARK: - Public Methods
    
    /// Log completion of a prayer
    public func logPrayerCompletion(
        prayer: Prayer,
        completedAt: Date = Date(),
        location: String? = nil,
        notes: String? = nil,
        mood: PrayerMood? = nil,
        method: PrayerMethod = .individual,
        duration: TimeInterval? = nil,
        congregation: CongregationType = .individual,
        isQada: Bool = false,
        hadithRemembered: String? = nil,
        gratitudeNote: String? = nil,
        difficulty: PrayerDifficulty? = nil,
        tags: [String] = []
    ) {
        let prayerTime = getPrayerTime(for: prayer, on: completedAt)
        let isOnTime = isCompletedOnTime(completedAt: completedAt, prayerTime: prayerTime)
        
        let entry = PrayerJournalEntry(
            prayer: prayer,
            date: Calendar.current.startOfDay(for: completedAt),
            completedAt: completedAt,
            location: location,
            notes: notes,
            mood: mood,
            method: method,
            duration: duration,
            isOnTime: isOnTime,
            isQada: isQada,
            congregation: congregation,
            hadithRemembered: hadithRemembered,
            gratitudeNote: gratitudeNote,
            difficulty: difficulty,
            tags: tags
        )
        
        // Add entry
        entries.append(entry)
        entries.sort { $0.completedAt > $1.completedAt }
        
        // Update statistics
        updateDailyStats(for: completedAt)
        updateTodayStats()
        calculateStreaks()
        updateGoalProgress()
        
        // Save to cache
        saveData()
        
        print("Prayer logged: \(prayer.displayName) at \(completedAt)")
    }
    
    /// Remove a prayer entry
    public func removePrayerEntry(_ entry: PrayerJournalEntry) {
        entries.removeAll { $0.id == entry.id }
        
        // Update statistics
        updateDailyStats(for: entry.date)
        updateTodayStats()
        calculateStreaks()
        updateGoalProgress()
        
        saveData()
    }
    
    /// Update an existing prayer entry
    public func updatePrayerEntry(_ entry: PrayerJournalEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            
            // Update statistics
            updateDailyStats(for: entry.date)
            updateTodayStats()
            calculateStreaks()
            updateGoalProgress()
            
            saveData()
        }
    }
    
    /// Get entries for a specific date
    public func getEntries(for date: Date) -> [PrayerJournalEntry] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return entries.filter { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }
    }
    
    /// Get entries for a date range
    public func getEntries(from startDate: Date, to endDate: Date) -> [PrayerJournalEntry] {
        return entries.filter { entry in
            entry.date >= startDate && entry.date <= endDate
        }
    }
    
    /// Check if a specific prayer has been completed today
    public func isPrayerCompletedToday(_ prayer: Prayer) -> Bool {
        let today = Date()
        let todayEntries = getEntries(for: today)
        return todayEntries.contains { $0.prayer == prayer && !$0.isQada }
    }
    
    /// Get the next prayer that needs to be completed
    public func getNextPrayerToComplete() -> Prayer? {
        let today = Date()
        let todayEntries = getEntries(for: today)
        let completedPrayers = Set(todayEntries.filter { !$0.isQada }.map { $0.prayer })
        
        // Find the first prayer that hasn't been completed
        return Prayer.allCases.first { !completedPrayers.contains($0) }
    }
    
    /// Get completion percentage for today
    public func getTodayCompletionPercentage() -> Double {
        guard let todayStats = todayStats else { return 0.0 }
        return todayStats.completionPercentage
    }
    
    /// Get weekly statistics
    public func getWeeklyStats(for date: Date = Date()) -> WeeklyPrayerStats {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? date
        
        var dailyStatsForWeek: [DailyPrayerStats] = []
        var totalCompleted = 0
        var totalOnTime = 0
        var totalCongregation = 0
        var completeDays = 0
        var currentStreak = 0
        var bestStreak = 0
        
        for i in 0..<7 {
            if let dayDate = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                let dayStats = getDailyStats(for: dayDate)
                dailyStatsForWeek.append(dayStats)
                
                totalCompleted += dayStats.completedPrayers.count
                totalOnTime += dayStats.onTimePrayers
                totalCongregation += dayStats.congregationPrayers
                
                if dayStats.isCompleteDay {
                    completeDays += 1
                    currentStreak += 1
                    bestStreak = max(bestStreak, currentStreak)
                } else {
                    currentStreak = 0
                }
            }
        }
        
        return WeeklyPrayerStats(
            startDate: startOfWeek,
            endDate: endOfWeek,
            dailyStats: dailyStatsForWeek,
            totalPossiblePrayers: 35,
            totalCompletedPrayers: totalCompleted,
            totalOnTimePrayers: totalOnTime,
            totalCongregationPrayers: totalCongregation,
            currentStreak: self.currentStreak,
            bestStreak: bestStreak,
            completeDays: completeDays
        )
    }
    
    /// Add a new goal
    public func addGoal(_ goal: PrayerGoal) {
        goals.append(goal)
        saveData()
    }
    
    /// Update a goal
    public func updateGoal(_ goal: PrayerGoal) {
        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index] = goal
            saveData()
        }
    }
    
    /// Remove a goal
    public func removeGoal(_ goal: PrayerGoal) {
        goals.removeAll { $0.id == goal.id }
        saveData()
    }
    
    /// Get active goals
    public var activeGoals: [PrayerGoal] {
        return goals.filter { $0.isActive && !$0.isOverdue }
    }
    
    /// Get completed goals
    public var completedGoals: [PrayerGoal] {
        return goals.filter { $0.isCompleted }
    }
    
    // MARK: - Private Methods
    
    private func loadCachedData() {
        // Load entries
        if let data = userDefaults.data(forKey: CacheKeys.entries),
           let cachedEntries = try? JSONDecoder().decode([PrayerJournalEntry].self, from: data) {
            entries = cachedEntries
        }
        
        // Load daily stats
        if let data = userDefaults.data(forKey: CacheKeys.dailyStats),
           let cachedStats = try? JSONDecoder().decode([DailyPrayerStats].self, from: data) {
            dailyStats = cachedStats
        }
        
        // Load goals
        if let data = userDefaults.data(forKey: CacheKeys.goals),
           let cachedGoals = try? JSONDecoder().decode([PrayerGoal].self, from: data) {
            goals = cachedGoals
        }
        
        // Load streaks
        currentStreak = userDefaults.integer(forKey: CacheKeys.streaks + ".current")
        bestStreak = userDefaults.integer(forKey: CacheKeys.streaks + ".best")
    }
    
    private func saveData() {
        // Save entries
        if let data = try? JSONEncoder().encode(entries) {
            userDefaults.set(data, forKey: CacheKeys.entries)
        }
        
        // Save daily stats
        if let data = try? JSONEncoder().encode(dailyStats) {
            userDefaults.set(data, forKey: CacheKeys.dailyStats)
        }
        
        // Save goals
        if let data = try? JSONEncoder().encode(goals) {
            userDefaults.set(data, forKey: CacheKeys.goals)
        }
        
        // Save streaks
        userDefaults.set(currentStreak, forKey: CacheKeys.streaks + ".current")
        userDefaults.set(bestStreak, forKey: CacheKeys.streaks + ".best")
    }
    
    private func updateDailyStats(for date: Date) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let dayEntries = getEntries(for: startOfDay)
        
        let completedPrayers = Set(dayEntries.filter { !$0.isQada }.map { $0.prayer })
        let onTimePrayers = dayEntries.filter { $0.isOnTime && !$0.isQada }.count
        let congregationPrayers = dayEntries.filter { $0.isInCongregation && !$0.isQada }.count
        let qadaPrayers = dayEntries.filter { $0.isQada }.count
        
        let durations = dayEntries.compactMap { $0.duration }
        let averageDuration = durations.isEmpty ? nil : durations.reduce(0, +) / Double(durations.count)
        
        var moodDistribution: [PrayerMood: Int] = [:]
        for entry in dayEntries {
            if let mood = entry.mood {
                moodDistribution[mood, default: 0] += 1
            }
        }
        
        let stats = DailyPrayerStats(
            date: startOfDay,
            completedPrayers: completedPrayers,
            totalPrayers: 5,
            onTimePrayers: onTimePrayers,
            congregationPrayers: congregationPrayers,
            qadaPrayers: qadaPrayers,
            averageDuration: averageDuration,
            moodDistribution: moodDistribution
        )
        
        // Update or add stats
        if let index = dailyStats.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }) {
            dailyStats[index] = stats
        } else {
            dailyStats.append(stats)
            dailyStats.sort { $0.date > $1.date }
        }
    }
    
    private func updateTodayStats() {
        let today = Date()
        updateDailyStats(for: today)
        todayStats = getDailyStats(for: today)
    }
    
    private func getDailyStats(for date: Date) -> DailyPrayerStats {
        let startOfDay = Calendar.current.startOfDay(for: date)
        
        if let existingStats = dailyStats.first(where: { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }) {
            return existingStats
        } else {
            // Create empty stats for the day
            return DailyPrayerStats(date: startOfDay)
        }
    }
    
    private func calculateStreaks() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Calculate current streak (consecutive complete days)
        var currentStreakCount = 0
        var bestStreakCount = 0
        var tempStreakCount = 0
        
        // Sort daily stats by date (newest first)
        let sortedStats = dailyStats.sorted { $0.date > $1.date }
        
        for (index, stats) in sortedStats.enumerated() {
            if stats.isCompleteDay {
                tempStreakCount += 1
                bestStreakCount = max(bestStreakCount, tempStreakCount)
                
                // If this is today or consecutive from today, count towards current streak
                if index == 0 || (index > 0 && calendar.dateComponents([.day], from: stats.date, to: sortedStats[index - 1].date).day == 1) {
                    if currentStreakCount == index {
                        currentStreakCount += 1
                    }
                }
            } else {
                tempStreakCount = 0
                if index < currentStreakCount {
                    break
                }
            }
        }
        
        self.currentStreak = currentStreakCount
        self.bestStreak = max(bestStreakCount, self.bestStreak)
    }
    
    private func updateGoalProgress() {
        for (index, goal) in goals.enumerated() {
            if goal.isActive && !goal.isCompleted {
                let newValue = calculateGoalProgress(for: goal)
                let updatedGoal = PrayerGoal(
                    id: goal.id,
                    title: goal.title,
                    description: goal.description,
                    type: goal.type,
                    targetValue: goal.targetValue,
                    currentValue: newValue,
                    startDate: goal.startDate,
                    endDate: goal.endDate,
                    isActive: goal.isActive,
                    prayers: goal.prayers,
                    reward: goal.reward
                )
                goals[index] = updatedGoal
            }
        }
    }
    
    private func calculateGoalProgress(for goal: PrayerGoal) -> Double {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: goal.startDate)
        let endDate = calendar.startOfDay(for: goal.endDate)
        
        switch goal.type {
        case .dailyCompletion:
            let completeDays = dailyStats.filter { stats in
                stats.date >= startDate && stats.date <= endDate && stats.isCompleteDay
            }.count
            return Double(completeDays)
            
        case .weeklyCompletion:
            // Count complete weeks
            let weeks = calendar.dateComponents([.weekOfYear], from: startDate, to: endDate).weekOfYear ?? 0
            var completeWeeks = 0
            
            for week in 0..<weeks {
                if let weekStart = calendar.date(byAdding: .weekOfYear, value: week, to: startDate) {
                    let weekStats = getWeeklyStats(for: weekStart)
                    if weekStats.completeDaysPercentage == 1.0 {
                        completeWeeks += 1
                    }
                }
            }
            return Double(completeWeeks)
            
        case .onTimePercentage:
            let relevantEntries = entries.filter { entry in
                entry.date >= startDate && entry.date <= endDate && 
                goal.prayers.contains(entry.prayer) && !entry.isQada
            }
            let onTimeEntries = relevantEntries.filter { $0.isOnTime }
            guard !relevantEntries.isEmpty else { return 0.0 }
            return (Double(onTimeEntries.count) / Double(relevantEntries.count)) * 100
            
        case .congregationPercentage:
            let relevantEntries = entries.filter { entry in
                entry.date >= startDate && entry.date <= endDate && 
                goal.prayers.contains(entry.prayer) && !entry.isQada
            }
            let congregationEntries = relevantEntries.filter { $0.isInCongregation }
            guard !relevantEntries.isEmpty else { return 0.0 }
            return (Double(congregationEntries.count) / Double(relevantEntries.count)) * 100
            
        case .streak:
            return Double(currentStreak)
            
        case .totalPrayers:
            let relevantEntries = entries.filter { entry in
                entry.date >= startDate && entry.date <= endDate && 
                goal.prayers.contains(entry.prayer)
            }
            return Double(relevantEntries.count)
            
        case .consistency:
            let totalDays = calendar.dateComponents([.day], from: startDate, to: min(Date(), endDate)).day ?? 0
            let activeDays = dailyStats.filter { stats in
                stats.date >= startDate && stats.date <= endDate && stats.completedPrayers.count > 0
            }.count
            return Double(activeDays)
        }
    }
    
    private func setupDefaultGoals() {
        if goals.isEmpty {
            let calendar = Calendar.current
            let today = Date()
            let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: today) ?? today
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: today) ?? today
            
            let defaultGoals = [
                PrayerGoal(
                    title: "Complete 5 Days This Week",
                    description: "Complete all 5 daily prayers for 5 days this week",
                    type: .dailyCompletion,
                    targetValue: 5,
                    startDate: today,
                    endDate: nextWeek,
                    reward: "Spiritual strength and consistency"
                ),
                PrayerGoal(
                    title: "80% On-Time This Month",
                    description: "Pray 80% of your prayers on time this month",
                    type: .onTimePercentage,
                    targetValue: 80,
                    startDate: today,
                    endDate: nextMonth,
                    reward: "Better time management and discipline"
                ),
                PrayerGoal(
                    title: "7-Day Streak",
                    description: "Maintain a 7-day prayer completion streak",
                    type: .streak,
                    targetValue: 7,
                    startDate: today,
                    endDate: nextMonth,
                    reward: "Consistent spiritual practice"
                )
            ]
            
            goals = defaultGoals
            saveData()
        }
    }
    
    private func getPrayerTime(for prayer: Prayer, on date: Date) -> Date {
        // This would integrate with the PrayerTimeService to get actual prayer times
        // For now, return approximate times
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        switch prayer {
        case .fajr:
            return calendar.date(byAdding: .hour, value: 5, to: startOfDay) ?? date
        case .dhuhr:
            return calendar.date(byAdding: .hour, value: 12, to: startOfDay) ?? date
        case .asr:
            return calendar.date(byAdding: .hour, value: 15, to: startOfDay) ?? date
        case .maghrib:
            return calendar.date(byAdding: .hour, value: 18, to: startOfDay) ?? date
        case .isha:
            return calendar.date(byAdding: .hour, value: 20, to: startOfDay) ?? date
        }
    }
    
    private func isCompletedOnTime(completedAt: Date, prayerTime: Date) -> Bool {
        // Consider "on time" if completed within 30 minutes after prayer time
        let timeDifference = completedAt.timeIntervalSince(prayerTime)
        return timeDifference >= 0 && timeDifference <= 1800 // 30 minutes
    }
}

// MARK: - Extensions

extension Prayer {
    /// Get the next prayer after this one
    public var nextPrayer: Prayer {
        switch self {
        case .fajr: return .dhuhr
        case .dhuhr: return .asr
        case .asr: return .maghrib
        case .maghrib: return .isha
        case .isha: return .fajr
        }
    }
    
    /// Get the previous prayer before this one
    public var previousPrayer: Prayer {
        switch self {
        case .fajr: return .isha
        case .dhuhr: return .fajr
        case .asr: return .dhuhr
        case .maghrib: return .asr
        case .isha: return .maghrib
        }
    }
}