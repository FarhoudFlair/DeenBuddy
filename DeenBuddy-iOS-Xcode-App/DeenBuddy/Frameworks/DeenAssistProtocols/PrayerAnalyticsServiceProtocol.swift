import Foundation
import Combine

/// Protocol for prayer analytics and insights functionality
@MainActor
public protocol PrayerAnalyticsServiceProtocol: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Weekly prayer completion rate (0.0 to 1.0)
    var weeklyCompletionRate: Double { get }
    
    /// Monthly prayer completion rate (0.0 to 1.0)
    var monthlyCompletionRate: Double { get }
    
    /// Yearly prayer completion rate (0.0 to 1.0)
    var yearlyCompletionRate: Double { get }
    
    /// Best prayer streak achieved
    var bestStreak: Int { get }
    
    /// Average streak length
    var averageStreakLength: Double { get }
    
    /// Prayer with highest completion rate
    var mostConsistentPrayer: Prayer? { get }

    /// Prayer with lowest completion rate
    var leastConsistentPrayer: Prayer? { get }
    
    /// Whether analytics are currently loading
    var isAnalyticsLoading: Bool { get }
    
    /// Any analytics calculation error
    var analyticsError: Error? { get }
    
    // MARK: - Analytics Methods
    
    /// Calculate all analytics data
    func calculateAllAnalytics() async
    
    /// Get completion rate for a specific period
    /// - Parameter period: The analytics period to analyze
    /// - Returns: Completion rate (0.0 to 1.0)
    func getCompletionRate(for period: AnalyticsPeriod) async -> Double
    
    /// Get prayer-specific completion rate
    /// - Parameters:
    ///   - prayer: The specific prayer to analyze
    ///   - period: The analytics period to analyze
    /// - Returns: Completion rate for the prayer (0.0 to 1.0)
    func getPrayerCompletionRate(_ prayer: Prayer, for period: AnalyticsPeriod) async -> Double
    
    /// Get daily completion data for charts
    /// - Parameter period: The analytics period to analyze
    /// - Returns: Array of daily completion data
    func getDailyCompletionData(for period: AnalyticsPeriod) async -> [DailyCompletionData]
    
    /// Get prayer insights and recommendations
    /// - Returns: Array of prayer insights
    func getPrayerInsights() async -> [PrayerInsight]
    
    /// Get streak history data
    /// - Returns: Array of streak data
    func getStreakHistory() async -> [StreakData]
}

// MARK: - Supporting Types

/// Analytics time period
public enum AnalyticsPeriod: String, CaseIterable {
    case week = "week"
    case month = "month"
    case year = "year"
    
    public var title: String {
        switch self {
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        }
    }
}

/// Daily completion data for analytics charts
public struct DailyCompletionData: Identifiable, Codable {
    public let id = UUID()
    public let date: Date
    public let completionRate: Double
    public let prayerCount: Int
    
    public init(date: Date, completionRate: Double, prayerCount: Int) {
        self.date = date
        self.completionRate = completionRate
        self.prayerCount = prayerCount
    }
}

/// Streak data for analytics
public struct StreakData: Identifiable, Codable {
    public let id: String
    public let startDate: Date
    public let endDate: Date
    public let length: Int
    public let isActive: Bool
    
    public init(startDate: Date, endDate: Date, length: Int, isActive: Bool) {
        // Validation
        precondition(length > 0, "Streak length must be positive")
        precondition(startDate <= endDate, "Streak startDate must not be after endDate")
        self.startDate = startDate
        self.endDate = endDate
        self.length = length
        self.isActive = isActive
        // Use a hash of startDate and endDate for a stable, unique id
        self.id = "\(startDate.timeIntervalSince1970)-\(endDate.timeIntervalSince1970)"
    }
}
