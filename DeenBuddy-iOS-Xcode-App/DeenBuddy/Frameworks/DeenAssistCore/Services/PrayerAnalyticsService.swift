import Foundation
import Combine
// Note: The types Prayer, PrayerTrackingServiceProtocol, PrayerInsight, AnalyticsPeriod,
// DailyCompletionData, and StreakData are defined in the protocol files and model files.
// They should be accessible through the framework's module structure.

/// Service for calculating comprehensive prayer analytics and insights
@MainActor
public class PrayerAnalyticsService: ObservableObject, PrayerAnalyticsServiceProtocol {

    // MARK: - Constants
    private enum Defaults {
        static let weekDays = 7
        static let monthDays = 28 // Use 28 for month fallback (4 weeks, avoids overcounting)
        static let yearDays = 365
        static let weekInterval: TimeInterval = Double(weekDays) * 86400
        static let monthInterval: TimeInterval = Double(monthDays) * 86400
        static let yearInterval: TimeInterval = Double(yearDays) * 86400
    }

    // MARK: - Published Properties

    @Published public var weeklyCompletionRate: Double = 0.0
    @Published public var monthlyCompletionRate: Double = 0.0
    @Published public var yearlyCompletionRate: Double = 0.0
    @Published public var bestStreak: Int = 0
    @Published public var averageStreakLength: Double = 0.0
    @Published public var mostConsistentPrayer: Prayer? = nil
    @Published public var leastConsistentPrayer: Prayer? = nil
    @Published public var isAnalyticsLoading: Bool = false
    @Published public var analyticsError: Error? = nil

    // MARK: - Private Properties

    private let prayerTrackingService: any PrayerTrackingServiceProtocol
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Cache Keys

    private enum CacheKeys {
        static let weeklyAnalytics = "PrayerAnalytics.WeeklyData"
        static let monthlyAnalytics = "PrayerAnalytics.MonthlyData"
        static let yearlyAnalytics = "PrayerAnalytics.YearlyData"
        static let streakAnalytics = "PrayerAnalytics.StreakData"
        static let prayerConsistency = "PrayerAnalytics.PrayerConsistency"
        static let lastAnalyticsUpdate = "PrayerAnalytics.LastUpdate"
    }

    // MARK: - Initialization

    public init(prayerTrackingService: any PrayerTrackingServiceProtocol) {
        self.prayerTrackingService = prayerTrackingService
        setupObservers()
        loadCachedAnalytics()

        // Calculate analytics on initialization
        Task {
            await calculateAllAnalytics()
        }
    }

    // MARK: - Public Methods

    /// Calculate all analytics data
    public func calculateAllAnalytics() async {
        isAnalyticsLoading = true
        analyticsError = nil

        do {
            // Calculate completion rates
            await calculateCompletionRates()

            // Calculate streak analytics
            await calculateStreakAnalytics()

            // Calculate prayer consistency
            await calculatePrayerConsistency()

            // Cache the results
            cacheAnalytics()

        } catch {
            analyticsError = error
        }

        isAnalyticsLoading = false
    }

    /// Get completion rate for a specific period
    public func getCompletionRate(for period: AnalyticsPeriod) async -> Double {
        let entries = prayerTrackingService.recentEntries
        let calendar = Calendar.current
        let now = Date()

        let startDate = calculateStartDate(for: period, from: now)

        let periodEntries = entries.filter { $0.completedAt >= startDate }
        let totalDays = calendar.dateComponents([.day], from: startDate, to: now).day ?? 1
        let expectedPrayers = totalDays * 5 // 5 prayers per day

        return expectedPrayers > 0 ? Double(periodEntries.count) / Double(expectedPrayers) : 0.0
    }

    /// Get prayer-specific completion rate
    public func getPrayerCompletionRate(_ prayer: Prayer, for period: AnalyticsPeriod) async -> Double {
        let entries = prayerTrackingService.recentEntries
        let calendar = Calendar.current
        let now = Date()

        let startDate = calculateStartDate(for: period, from: now)

        let prayerEntries = entries.filter {
            $0.prayer == prayer && $0.completedAt >= startDate
        }
        let totalDays = calendar.dateComponents([.day], from: startDate, to: now).day ?? 1

        return totalDays > 0 ? Double(prayerEntries.count) / Double(totalDays) : 0.0
    }

    /// Get daily completion data for charts
    public func getDailyCompletionData(for period: AnalyticsPeriod) async -> [DailyCompletionData] {
        let entries = prayerTrackingService.recentEntries
        let calendar = Calendar.current
        let now = Date()

        let startDate = calculateStartDate(for: period, from: now)
        let days = calculateDaysInPeriod(for: period, from: startDate, to: now)

        var dailyData: [DailyCompletionData] = []

        for dayOffset in 0..<days {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) ?? startDate
            let dayEntries = entries.filter { calendar.isDate($0.completedAt, inSameDayAs: date) }
            let completionRate = Double(dayEntries.count) / 5.0 // 5 prayers per day

            dailyData.append(DailyCompletionData(
                date: date,
                completionRate: min(completionRate, 1.0),
                prayerCount: dayEntries.count
            ))
        }

        return dailyData
    }

    /// Get prayer insights and recommendations
    public func getPrayerInsights() async -> [PrayerInsight] {
        var insights: [PrayerInsight] = []

        // Current streak insight
        let currentStreak = prayerTrackingService.currentStreak
        if currentStreak > 0 {
            let message = getStreakMessage(for: currentStreak)
            insights.append(PrayerInsight(
                title: "Current Streak",
                description: message,
                type: .streak,
                importance: .high
            ))
        }

        // Prayer consistency insights
        let prayerRates = await getPrayerConsistencyRates()
        if let weakestPrayer = prayerRates.min(by: { $0.value < $1.value }) {
            if weakestPrayer.value < 0.7 {
                insights.append(PrayerInsight(
                    title: "Improve \(weakestPrayer.key.displayName)",
                    description: "Your \(weakestPrayer.key.displayName) prayer completion rate is \(Int(weakestPrayer.value * 100))%. Try setting a reminder to improve consistency.",
                    type: .improvement,
                    importance: .medium
                ))
            }
        }

        // Weekly progress insight
        let weeklyRate = await getCompletionRate(for: .week)
        if weeklyRate > 0.8 {
            insights.append(PrayerInsight(
                title: "Excellent Progress",
                description: "You've completed \(Int(weeklyRate * 100))% of your prayers this week. Keep up the great work!",
                type: .achievement,
                importance: .low
            ))
        }

        return insights
    }

    /// Get streak history data
    public func getStreakHistory() async -> [StreakData] {
        let entries = prayerTrackingService.recentEntries
        let calendar = Calendar.current
        var streaks: [StreakData] = []

        // Group entries by date
        let entriesByDate = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.completedAt)
        }

        // Sort dates
        let sortedDates = entriesByDate.keys.sorted()

        var currentStreakStart: Date?
        var currentStreakLength = 0
        var lastDate: Date?

        for date in sortedDates {
            let dayEntries = entriesByDate[date] ?? []
            let completedPrayers = Set(dayEntries.map { $0.prayer }).count

            // Consider a day complete if at least 3 prayers were completed
            let isDayComplete = completedPrayers >= 3

            if isDayComplete {
                if currentStreakStart == nil {
                    currentStreakStart = date
                    currentStreakLength = 1
                } else if let lastDate = lastDate,
                          calendar.dateComponents([.day], from: lastDate, to: date).day == 1 {
                    // Consecutive day
                    currentStreakLength += 1
                } else {
                    // Gap found, save previous streak
                    if let streakStart = currentStreakStart, currentStreakLength > 0 {
                        let streakEnd = lastDate ?? streakStart
                        streaks.append(StreakData(
                            startDate: streakStart,
                            endDate: streakEnd,
                            length: currentStreakLength,
                            isActive: false
                        ))
                    }
                    currentStreakStart = date
                    currentStreakLength = 1
                }
                lastDate = date
            } else {
                // Incomplete day breaks the streak
                if let streakStart = currentStreakStart, currentStreakLength > 0 {
                    let streakEnd = lastDate ?? streakStart
                    streaks.append(StreakData(
                        startDate: streakStart,
                        endDate: streakEnd,
                        length: currentStreakLength,
                        isActive: false
                    ))
                }
                currentStreakStart = nil
                currentStreakLength = 0
                lastDate = nil
            }
        }

        // Handle ongoing streak
        if let streakStart = currentStreakStart, currentStreakLength > 0 {
            let streakEnd = lastDate ?? streakStart
            let isActive = calendar.isDateInToday(streakEnd) ||
                          calendar.isDateInYesterday(streakEnd)

            streaks.append(StreakData(
                startDate: streakStart,
                endDate: streakEnd,
                length: currentStreakLength,
                isActive: isActive
            ))
        }

        return streaks.sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Private Methods

    private func setupObservers() {
        // Note: Observer setup would be implemented here
        // For now, we'll rely on manual refresh calls
        // In a full implementation, we'd observe prayer tracking changes
        print("📊 PrayerAnalyticsService observers setup")
    }

    private func loadCachedAnalytics() {
        // Load cached analytics if available and recent
        if let lastUpdate = userDefaults.object(forKey: CacheKeys.lastAnalyticsUpdate) as? Date,
           Date().timeIntervalSince(lastUpdate) < 3600 { // 1 hour cache

            weeklyCompletionRate = userDefaults.double(forKey: CacheKeys.weeklyAnalytics)
            monthlyCompletionRate = userDefaults.double(forKey: CacheKeys.monthlyAnalytics)
            yearlyCompletionRate = userDefaults.double(forKey: CacheKeys.yearlyAnalytics)
            bestStreak = userDefaults.integer(forKey: CacheKeys.streakAnalytics)
        }
    }

    private func calculateCompletionRates() async {
        weeklyCompletionRate = await getCompletionRate(for: .week)
        monthlyCompletionRate = await getCompletionRate(for: .month)
        yearlyCompletionRate = await getCompletionRate(for: .year)
    }

    private func calculateStreakAnalytics() async {
        let streakHistory = await getStreakHistory()
        bestStreak = streakHistory.map(\.length).max() ?? 0
        averageStreakLength = streakHistory.isEmpty ? 0 : Double(streakHistory.map(\.length).reduce(0, +)) / Double(streakHistory.count)
    }

    private func calculatePrayerConsistency() async {
        let prayerRates = await getPrayerConsistencyRates()

        if let mostConsistent = prayerRates.max(by: { $0.value < $1.value }) {
            mostConsistentPrayer = mostConsistent.key
        }

        if let leastConsistent = prayerRates.min(by: { $0.value < $1.value }) {
            leastConsistentPrayer = leastConsistent.key
        }
    }

    private func getPrayerConsistencyRates() async -> [Prayer: Double] {
        var rates: [Prayer: Double] = [:]

        for prayer in Prayer.allCases {
            rates[prayer] = await getPrayerCompletionRate(prayer, for: .month)
        }

        return rates
    }

    private func cacheAnalytics() {
        userDefaults.set(weeklyCompletionRate, forKey: CacheKeys.weeklyAnalytics)
        userDefaults.set(monthlyCompletionRate, forKey: CacheKeys.monthlyAnalytics)
        userDefaults.set(yearlyCompletionRate, forKey: CacheKeys.yearlyAnalytics)
        userDefaults.set(bestStreak, forKey: CacheKeys.streakAnalytics)
        userDefaults.set(Date(), forKey: CacheKeys.lastAnalyticsUpdate)
    }

    /// Calculate start date for a given analytics period
    private func calculateStartDate(for period: AnalyticsPeriod, from currentDate: Date) -> Date {
        let calendar = Calendar.current

        switch period {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start ??
                   currentDate.addingTimeInterval(-Defaults.weekInterval)
        case .month:
            return calendar.dateInterval(of: .month, for: currentDate)?.start ??
                   currentDate.addingTimeInterval(-Defaults.monthInterval)
        case .year:
            return calendar.dateInterval(of: .year, for: currentDate)?.start ??
                   currentDate.addingTimeInterval(-Defaults.yearInterval)
        }
    }

    /// Calculate actual number of days in period using calendar calculations
    private func calculateDaysInPeriod(for period: AnalyticsPeriod, from startDate: Date, to endDate: Date) -> Int {
        let calendar = Calendar.current

        switch period {
        case .week:
            return calendar.dateComponents([.day], from: startDate, to: endDate).day ?? Defaults.weekDays
        case .month:
            return calendar.dateComponents([.day], from: startDate, to: endDate).day ?? Defaults.monthDays
        case .year:
            return calendar.dateComponents([.day], from: startDate, to: endDate).day ?? Defaults.yearDays
        }
    }

    private func getStreakMessage(for streak: Int) -> String {
        switch streak {
        case 1: return "Great start! You've begun your prayer journey."
        case 2...6: return "Building momentum! Keep the consistency going."
        case 7...13: return "One week strong! You're developing a beautiful habit."
        case 14...29: return "Two weeks of dedication! Your commitment is inspiring."
        case 30...99: return "A month of consistent prayer! Mashallah, keep it up!"
        default: return "Subhanallah! Your dedication to prayer is truly remarkable."
        }
    }
}

// Note: Supporting types (AnalyticsPeriod, DailyCompletionData, StreakData) are defined in PrayerAnalyticsServiceProtocol.swift
// to avoid duplication and ambiguity issues
