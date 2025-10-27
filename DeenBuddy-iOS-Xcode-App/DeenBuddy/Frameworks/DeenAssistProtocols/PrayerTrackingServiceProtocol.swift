import Foundation
import Combine

// MARK: - Prayer Tracking Service Protocol

/// Protocol for enhanced prayer tracking functionality
/// This extends the existing PrayerTimeService with tracking capabilities
public protocol PrayerTrackingServiceProtocol: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current prayer streak
    var currentStreak: Int { get }
    
    /// Total prayers completed today
    var todaysCompletedPrayers: Int { get }
    
    /// Today's prayer progress (0.0 to 1.0)
    var todayCompletionRate: Double { get }
    
    /// Recent prayer entries
    var recentEntries: [PrayerEntry] { get }
    
    /// Total prayers completed across all time
    var totalPrayersCompleted: Int { get }
    
    /// Loading state for tracking operations
    var isTrackingLoading: Bool { get }
    
    /// Error state for tracking operations
    var trackingError: Error? { get }
    
    // MARK: - Prayer Completion Methods
    
    /// Log a prayer completion with basic information
    /// - Parameters:
    ///   - prayer: The prayer that was completed
    ///   - completedAt: When the prayer was completed (default: now)
    func logPrayerCompletion(_ prayer: Prayer, at completedAt: Date) async
    
    /// Log a prayer completion with detailed information
    /// - Parameters:
    ///   - prayer: The prayer that was completed
    ///   - completedAt: When the prayer was completed
    ///   - location: Where the prayer was performed
    ///   - notes: Optional notes about the prayer
    ///   - mood: How the person felt during prayer
    ///   - method: Individual or congregation
    ///   - duration: How long the prayer took
    ///   - congregation: Type of congregation
    ///   - isQada: Whether this is a make-up prayer
    ///   - hadithRemembered: Any hadith remembered during prayer
    ///   - gratitudeNote: What the person was grateful for
    ///   - difficulty: How difficult the prayer was
    ///   - tags: Custom tags for the prayer
    func logPrayerCompletion(
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
    ) async
    
    /// Mark a prayer as completed with basic information
    /// - Parameters:
    ///   - prayer: The prayer that was completed
    ///   - date: When the prayer was completed (default: now)
    ///   - location: Optional location where prayer was performed
    ///   - notes: Optional notes about the prayer
    ///   - mood: Optional mood during prayer
    ///   - method: Method of prayer (default: individual)
    ///   - duration: Optional duration of prayer
    ///   - congregation: Type of congregation (default: individual)
    ///   - isQada: Whether this is a make-up prayer (default: false)
    func markPrayerCompleted(
        _ prayer: Prayer,
        at date: Date,
        location: String?,
        notes: String?,
        mood: PrayerMood?,
        method: PrayerMethod,
        duration: TimeInterval?,
        congregation: CongregationType,
        isQada: Bool
    ) async
    
    /// Mark a prayer as missed
    /// - Parameters:
    ///   - prayer: The prayer that was missed
    ///   - date: When the prayer was missed (default: now)
    ///   - reason: Optional reason for missing the prayer
    func markPrayerMissed(_ prayer: Prayer, date: Date, reason: String?) async
    
    /// Undo the last prayer entry
    /// - Returns: True if successful, false if no entries to undo
    func undoLastPrayerEntry() async -> Bool
    
    /// Remove a prayer entry
    /// - Parameter entryId: The ID of the entry to remove
    func removePrayerEntry(_ entryId: UUID) async
    
    /// Update an existing prayer entry
    /// - Parameter entry: The updated prayer entry
    func updatePrayerEntry(_ entry: PrayerEntry) async
    
    // MARK: - Statistics Methods
    
    /// Get prayer statistics for a specific time period
    /// - Parameter period: The time period to analyze
    /// - Returns: Statistics for the given period
    func getPrayerStatistics(for period: DateInterval) async -> PrayerStatistics
    
    /// Get current prayer streak information
    /// - Returns: Current streak data
    func getCurrentStreak() async -> PrayerStreak
    
    /// Get prayer history with optional filtering
    /// - Parameters:
    ///   - limit: Maximum number of entries to return
    ///   - prayer: Filter by specific prayer (optional)
    ///   - startDate: Start date for filtering (optional)
    ///   - endDate: End date for filtering (optional)
    /// - Returns: Array of prayer entries
    func getPrayerHistory(
        limit: Int,
        prayer: Prayer?,
        startDate: Date?,
        endDate: Date?
    ) async -> [PrayerEntry]
    
    /// Get daily prayer progress for a specific date
    /// - Parameter date: The date to check
    /// - Returns: Daily prayer progress
    func getDailyProgress(for date: Date) async -> DailyPrayerProgress
    
    /// Get weekly prayer progress for a specific week
    /// - Parameter date: Any date within the week
    /// - Returns: Weekly prayer progress
    func getWeeklyProgress(for date: Date) async -> WeeklyPrayerProgress
    
    /// Get monthly prayer statistics
    /// - Parameter date: Any date within the month
    /// - Returns: Monthly statistics
    func getMonthlyStatistics(for date: Date) async -> PrayerStatistics
    
    /// Get prayer streak for a specific prayer
    /// - Parameter prayer: The prayer to get streak for
    /// - Returns: Prayer streak data, or nil if no streak found
    func getPrayerStreak(for prayer: Prayer) async -> PrayerStreak?

    /// Get individual streaks for all prayers
    /// - Returns: Dictionary mapping each prayer to its individual streak data
    func getIndividualPrayerStreaks() async -> [Prayer: IndividualPrayerStreak]

    /// Get individual streak for a specific prayer
    /// - Parameter prayer: The prayer to get individual streak for
    /// - Returns: Individual prayer streak data, or nil if missing/untracked
    func getIndividualPrayerStreak(for prayer: Prayer) async -> IndividualPrayerStreak?

    // MARK: - Reminder Methods
    
    /// Schedule a prayer reminder
    /// - Parameters:
    ///   - prayer: The prayer to remind about
    ///   - offset: How many minutes before prayer time to remind
    func schedulePrayerReminder(for prayer: Prayer, offset: TimeInterval) async
    
    /// Cancel a prayer reminder
    /// - Parameter prayer: The prayer to cancel reminder for
    func cancelPrayerReminder(for prayer: Prayer) async
    
    /// Update prayer reminder settings
    /// - Parameters:
    ///   - enabled: Whether reminders are enabled
    ///   - defaultOffset: Default reminder offset in minutes
    func updateReminderSettings(enabled: Bool, defaultOffset: TimeInterval) async
    
    /// Set a prayer reminder
    /// - Parameter reminder: The reminder to set
    func setPrayerReminder(_ reminder: PrayerReminderEntry) async
    
    /// Get all prayer reminders
    /// - Returns: Array of prayer reminders
    func getPrayerReminders() async -> [PrayerReminderEntry]
    
    /// Delete a prayer reminder for a specific prayer
    /// - Parameter prayer: The prayer to delete reminder for
    func deletePrayerReminder(for prayer: Prayer) async
    
    // MARK: - Journal Methods
    
    /// Add a prayer journal entry
    /// - Parameter entry: The journal entry to add
    func addPrayerJournalEntry(_ entry: PrayerJournalEntry) async
    
    /// Get prayer journal entries for a time period
    /// - Parameter period: The time period to get entries for
    /// - Returns: Array of journal entries
    func getPrayerJournalEntries(for period: DateInterval) async -> [PrayerJournalEntry]
    
    /// Update a prayer journal entry
    /// - Parameter entry: The updated journal entry
    func updatePrayerJournalEntry(_ entry: PrayerJournalEntry) async
    
    /// Delete a prayer journal entry
    /// - Parameter entryId: The ID of the entry to delete
    func deletePrayerJournalEntry(_ entryId: UUID) async
    
    // MARK: - Goal Methods
    
    /// Set a prayer completion goal
    /// - Parameters:
    ///   - goal: The goal to achieve (e.g., pray 5 times daily for 30 days)
    ///   - period: The time period for the goal
    func setPrayerGoal(_ goal: PrayerGoal, for period: DateInterval) async
    
    /// Get current prayer goals
    /// - Returns: Array of active goals
    func getCurrentGoals() async -> [PrayerGoal]
    
    /// Check progress towards goals
    /// - Returns: Array of goal progress
    func getGoalProgress() async -> [PrayerGoalProgress]
    
    // MARK: - Export Methods
    
    /// Export prayer data as CSV
    /// - Parameter period: Time period to export
    /// - Returns: CSV data as string
    func exportPrayerData(for period: DateInterval) async -> String
    
    /// Export prayer statistics as JSON
    /// - Parameter period: Time period to export
    /// - Returns: JSON data as string
    func exportPrayerStatistics(for period: DateInterval) async -> String
    
    // MARK: - Insights Methods
    
    /// Get prayer insights and recommendations
    /// - Returns: Array of insights
    func getPrayerInsights() async -> [PrayerInsight]
    
    /// Get prayer patterns analysis
    /// - Returns: Pattern analysis data
    func getPrayerPatterns() async -> PrayerPatternAnalysis
    
    /// Get personalized prayer tips
    /// - Returns: Array of tips based on user's prayer history
    func getPersonalizedTips() async -> [PrayerTip]
    
    // MARK: - Cache Methods
    
    /// Clear prayer tracking cache
    func clearTrackingCache() async
    
    /// Refresh prayer tracking data
    func refreshTrackingData() async
    
    /// Sync prayer data with remote storage (if available)
    func syncPrayerData() async throws
}

// MARK: - Supporting Models

// NOTE: PrayerGoal struct is defined in PrayerJournal.swift to avoid duplication

/// Prayer goal progress
public struct PrayerGoalProgress: Codable, Identifiable {
    public let id: UUID
    public let goal: PrayerGoal
    public let completedPrayers: Int
    public let completedDays: Int
    public let completionRate: Double
    public let isCompleted: Bool
    public let estimatedCompletionDate: Date?
    
    public init(
        goal: PrayerGoal,
        completedPrayers: Int,
        completedDays: Int
    ) {
        self.id = UUID(uuidString: goal.id) ?? UUID()
        self.goal = goal
        self.completedPrayers = completedPrayers
        self.completedDays = completedDays

        // Calculate completion rate based on goal type
        switch goal.type {
        case .totalPrayers:
            self.completionRate = Double(completedPrayers) / goal.targetValue
        case .dailyCompletion, .weeklyCompletion, .consistency, .streak:
            // For these goal types, use completed days
            self.completionRate = Double(completedDays) / goal.targetValue
        default:
            // For percentage-based goals, use the goal's own progress
            self.completionRate = goal.progress
        }

        self.isCompleted = self.completionRate >= 1.0

        // Estimate completion date based on current progress
        if !isCompleted && completedDays > 0 {
            let daysElapsed = Calendar.current.dateComponents([.day], from: goal.startDate, to: Date()).day ?? 1
            let progressRate = self.completionRate / Double(max(daysElapsed, 1))
            let remainingProgress = 1.0 - self.completionRate
            let estimatedDaysToComplete = remainingProgress / max(progressRate, 0.01)
            self.estimatedCompletionDate = Date().addingTimeInterval(estimatedDaysToComplete * 24 * 60 * 60)
        } else {
            self.estimatedCompletionDate = nil
        }
    }
}

/// Prayer insight
public struct PrayerInsight: Codable, Identifiable {
    public let id: UUID
    public let title: String
    public let description: String
    public let type: PrayerInsightType
    public let importance: PrayerInsightImportance
    public let actionRequired: Bool
    public let actionText: String?
    public let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        type: PrayerInsightType,
        importance: PrayerInsightImportance,
        actionRequired: Bool = false,
        actionText: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.importance = importance
        self.actionRequired = actionRequired
        self.actionText = actionText
        self.createdAt = createdAt
    }
}

/// Types of prayer insights
public enum PrayerInsightType: String, Codable, CaseIterable {
    case streak = "streak"
    case pattern = "pattern"
    case improvement = "improvement"
    case concern = "concern"
    case achievement = "achievement"
    case recommendation = "recommendation"
    
    public var displayName: String {
        switch self {
        case .streak: return "Streak"
        case .pattern: return "Pattern"
        case .improvement: return "Improvement"
        case .concern: return "Concern"
        case .achievement: return "Achievement"
        case .recommendation: return "Recommendation"
        }
    }
    
    public var icon: String {
        switch self {
        case .streak: return "flame"
        case .pattern: return "chart.line.uptrend.xyaxis"
        case .improvement: return "arrow.up.circle"
        case .concern: return "exclamationmark.triangle"
        case .achievement: return "trophy"
        case .recommendation: return "lightbulb"
        }
    }
}

/// Importance levels for insights
public enum PrayerInsightImportance: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    public var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "blue"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

/// Prayer pattern analysis
public struct PrayerPatternAnalysis: Codable {
    public let mostActiveDay: String
    public let mostActiveTime: String
    public let averageDelay: TimeInterval
    public let consistencyScore: Double
    public let trends: [PrayerTrend]
    public let recommendations: [String]
    
    public init(
        mostActiveDay: String,
        mostActiveTime: String,
        averageDelay: TimeInterval,
        consistencyScore: Double,
        trends: [PrayerTrend],
        recommendations: [String]
    ) {
        self.mostActiveDay = mostActiveDay
        self.mostActiveTime = mostActiveTime
        self.averageDelay = averageDelay
        self.consistencyScore = consistencyScore
        self.trends = trends
        self.recommendations = recommendations
    }
}

/// Prayer trend data
public struct PrayerTrend: Codable, Identifiable {
    public let id: UUID
    public let prayer: Prayer
    public let trendType: PrayerTrendType
    public let direction: PrayerTrendDirection
    public let strength: Double
    public let description: String
    
    public init(
        id: UUID = UUID(),
        prayer: Prayer,
        trendType: PrayerTrendType,
        direction: PrayerTrendDirection,
        strength: Double,
        description: String
    ) {
        self.id = id
        self.prayer = prayer
        self.trendType = trendType
        self.direction = direction
        self.strength = strength
        self.description = description
    }
}

/// Types of prayer trends
public enum PrayerTrendType: String, Codable, CaseIterable {
    case completion = "completion"
    case timing = "timing"
    case mood = "mood"
    case congregation = "congregation"
    case duration = "duration"
    
    public var displayName: String {
        switch self {
        case .completion: return "Completion"
        case .timing: return "Timing"
        case .mood: return "Mood"
        case .congregation: return "Congregation"
        case .duration: return "Duration"
        }
    }
}

/// Direction of prayer trends
public enum PrayerTrendDirection: String, Codable, CaseIterable {
    case improving = "improving"
    case declining = "declining"
    case stable = "stable"
    
    public var displayName: String {
        switch self {
        case .improving: return "Improving"
        case .declining: return "Declining"
        case .stable: return "Stable"
        }
    }
    
    public var icon: String {
        switch self {
        case .improving: return "arrow.up"
        case .declining: return "arrow.down"
        case .stable: return "minus"
        }
    }
}

/// Prayer tip
public struct PrayerTip: Codable, Identifiable {
    public let id: UUID
    public let title: String
    public let description: String
    public let category: PrayerTipCategory
    public let personalizedFor: Prayer?
    public let source: String?
    public let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        category: PrayerTipCategory,
        personalizedFor: Prayer? = nil,
        source: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.personalizedFor = personalizedFor
        self.source = source
        self.createdAt = createdAt
    }
}

/// Categories of prayer tips
public enum PrayerTipCategory: String, Codable, CaseIterable {
    case focus = "focus"
    case timing = "timing"
    case preparation = "preparation"
    case spirituality = "spirituality"
    case motivation = "motivation"
    case technique = "technique"
    
    public var displayName: String {
        switch self {
        case .focus: return "Focus"
        case .timing: return "Timing"
        case .preparation: return "Preparation"
        case .spirituality: return "Spirituality"
        case .motivation: return "Motivation"
        case .technique: return "Technique"
        }
    }
    
    public var icon: String {
        switch self {
        case .focus: return "eye"
        case .timing: return "clock"
        case .preparation: return "checklist"
        case .spirituality: return "heart"
        case .motivation: return "flame"
        case .technique: return "hands.clap"
        }
    }
}

// MARK: - Default Implementation Helpers

public extension PrayerTrackingServiceProtocol {
    
    /// Quick prayer completion logging
    func logPrayerCompletion(_ prayer: Prayer) async {
        await logPrayerCompletion(prayer, at: Date())
    }
    
    /// Get today's prayer statistics
    func getTodayStatistics() async -> PrayerStatistics {
        let today = Date()
        let startOfDay = Calendar.current.startOfDay(for: today)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let period = DateInterval(start: startOfDay, end: endOfDay)
        return await getPrayerStatistics(for: period)
    }
    
    /// Get this week's prayer statistics
    func getThisWeekStatistics() async -> PrayerStatistics {
        let today = Date()
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)!.start
        let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)!.end
        let period = DateInterval(start: startOfWeek, end: endOfWeek)
        return await getPrayerStatistics(for: period)
    }
    
    /// Get this month's prayer statistics
    func getThisMonthStatistics() async -> PrayerStatistics {
        let today = Date()
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: today)!.start
        let endOfMonth = calendar.dateInterval(of: .month, for: today)!.end
        let period = DateInterval(start: startOfMonth, end: endOfMonth)
        return await getPrayerStatistics(for: period)
    }
    
    /// Check if prayer was completed today
    func isPrayerCompletedToday(_ prayer: Prayer) async -> Bool {
        let dailyProgress = await getDailyProgress(for: Date())
        return dailyProgress.isCompleted(prayer)
    }
    
    /// Get completion rate for specific prayer
    func getCompletionRate(for prayer: Prayer, in period: DateInterval) async -> Double {
        let statistics = await getPrayerStatistics(for: period)
        // This would need to be implemented based on specific prayer data
        return statistics.completionRate
    }
}