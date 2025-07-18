import Foundation
import Combine

/// Service for calculating comprehensive prayer analytics and insights
@MainActor
public class PrayerAnalyticsService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var weeklyCompletionRate: Double = 0.0
    @Published public var monthlyCompletionRate: Double = 0.0
    @Published public var yearlyCompletionRate: Double = 0.0
    @Published public var bestStreak: Int = 0
    @Published public var averageStreakLength: Double = 0.0
    @Published public var mostConsistentPrayer: Prayer = .fajr
    @Published public var leastConsistentPrayer: Prayer = .fajr
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
        
        let startDate: Date
        switch period {
        case .week:
            startDate = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now.addingTimeInterval(-7 * 86400)
        case .month:
            startDate = calendar.dateInterval(of: .month, for: now)?.start ?? now.addingTimeInterval(-30 * 86400)
        case .year:
            startDate = calendar.dateInterval(of: .year, for: now)?.start ?? now.addingTimeInterval(-365 * 86400)
        }
        
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
        
        let startDate: Date
        switch period {
        case .week:
            startDate = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now.addingTimeInterval(-7 * 86400)
        case .month:
            startDate = calendar.dateInterval(of: .month, for: now)?.start ?? now.addingTimeInterval(-30 * 86400)
        case .year:
            startDate = calendar.dateInterval(of: .year, for: now)?.start ?? now.addingTimeInterval(-365 * 86400)
        }
        
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
        
        let startDate: Date
        let days: Int
        
        switch period {
        case .week:
            startDate = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now.addingTimeInterval(-7 * 86400)
            days = 7
        case .month:
            startDate = calendar.dateInterval(of: .month, for: now)?.start ?? now.addingTimeInterval(-30 * 86400)
            days = 30
        case .year:
            startDate = calendar.dateInterval(of: .year, for: now)?.start ?? now.addingTimeInterval(-365 * 86400)
            days = 365
        }
        
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
                type: .streak,
                title: "Current Streak",
                message: message,
                priority: .high
            ))
        }
        
        // Prayer consistency insights
        let prayerRates = await getPrayerConsistencyRates()
        if let weakestPrayer = prayerRates.min(by: { $0.value < $1.value }) {
            if weakestPrayer.value < 0.7 {
                insights.append(PrayerInsight(
                    type: .consistency,
                    title: "Improve \(weakestPrayer.key.displayName)",
                    message: "Your \(weakestPrayer.key.displayName) prayer completion rate is \(Int(weakestPrayer.value * 100))%. Try setting a reminder to improve consistency.",
                    priority: .medium
                ))
            }
        }
        
        // Weekly progress insight
        let weeklyRate = await getCompletionRate(for: .week)
        if weeklyRate > 0.8 {
            insights.append(PrayerInsight(
                type: .progress,
                title: "Excellent Progress",
                message: "You've completed \(Int(weeklyRate * 100))% of your prayers this week. Keep up the great work!",
                priority: .low
            ))
        }
        
        return insights
    }
    
    /// Get streak history data
    public func getStreakHistory() async -> [StreakData] {
        // This would analyze prayer entries to identify streak periods
        // For now, return sample data
        return [
            StreakData(startDate: Date().addingTimeInterval(-30 * 86400), endDate: Date(), length: prayerTrackingService.currentStreak, isActive: true),
            StreakData(startDate: Date().addingTimeInterval(-60 * 86400), endDate: Date().addingTimeInterval(-35 * 86400), length: 15, isActive: false),
            StreakData(startDate: Date().addingTimeInterval(-90 * 86400), endDate: Date().addingTimeInterval(-70 * 86400), length: 8, isActive: false)
        ]
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe changes in prayer tracking service
        prayerTrackingService.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.calculateAllAnalytics()
                }
            }
            .store(in: &cancellables)
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

// MARK: - Supporting Types

public enum AnalyticsPeriod: CaseIterable {
    case week, month, year
    
    public var title: String {
        switch self {
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        }
    }
}

public struct DailyCompletionData: Identifiable {
    public let id = UUID()
    public let date: Date
    public let completionRate: Double
    public let prayerCount: Int
}

public struct PrayerInsight: Identifiable {
    public let id = UUID()
    public let type: InsightType
    public let title: String
    public let message: String
    public let priority: InsightPriority
    
    public enum InsightType {
        case streak, consistency, progress, recommendation
    }
    
    public enum InsightPriority {
        case high, medium, low
    }
}

public struct StreakData: Identifiable {
    public let id = UUID()
    public let startDate: Date
    public let endDate: Date
    public let length: Int
    public let isActive: Bool
}
