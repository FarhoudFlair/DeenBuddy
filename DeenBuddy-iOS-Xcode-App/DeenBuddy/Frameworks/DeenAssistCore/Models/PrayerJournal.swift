import Foundation

// MARK: - Prayer Journal Models

/// Represents a single prayer completion entry
public struct PrayerJournalEntry: Codable, Identifiable, Equatable {
    public let id: String
    public let prayer: Prayer
    public let date: Date
    public let completedAt: Date
    public let location: String?
    public let notes: String?
    public let mood: PrayerMood?
    public let method: PrayerMethod
    public let duration: TimeInterval?
    public let qiblaAccuracy: Double?
    public let isOnTime: Bool
    public let isQada: Bool // Makeup prayer
    public let congregation: CongregationType
    public let hadithRemembered: String?
    public let gratitudeNote: String?
    public let difficulty: PrayerDifficulty?
    public let tags: [String]
    
    public init(
        id: String = UUID().uuidString,
        prayer: Prayer,
        date: Date = Date(),
        completedAt: Date = Date(),
        location: String? = nil,
        notes: String? = nil,
        mood: PrayerMood? = nil,
        method: PrayerMethod = .individual,
        duration: TimeInterval? = nil,
        qiblaAccuracy: Double? = nil,
        isOnTime: Bool = true,
        isQada: Bool = false,
        congregation: CongregationType = .individual,
        hadithRemembered: String? = nil,
        gratitudeNote: String? = nil,
        difficulty: PrayerDifficulty? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.prayer = prayer
        self.date = date
        self.completedAt = completedAt
        self.location = location
        self.notes = notes
        self.mood = mood
        self.method = method
        self.duration = duration
        self.qiblaAccuracy = qiblaAccuracy
        self.isOnTime = isOnTime
        self.isQada = isQada
        self.congregation = congregation
        self.hadithRemembered = hadithRemembered
        self.gratitudeNote = gratitudeNote
        self.difficulty = difficulty
        self.tags = tags
    }
    
    /// Check if this prayer was completed in congregation
    public var isInCongregation: Bool {
        return congregation != .individual
    }
    
    /// Get formatted duration string
    public var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(seconds)s"
    }
    
    /// Get completion time relative to prayer time
    public func timingDescription(prayerTime: Date) -> String {
        let timeDifference = completedAt.timeIntervalSince(prayerTime)
        
        if timeDifference < 0 {
            return "Early by \(formatTimeDifference(abs(timeDifference)))"
        } else if timeDifference < 300 { // Within 5 minutes
            return "On time"
        } else {
            return "Late by \(formatTimeDifference(timeDifference))"
        }
    }
    
    private func formatTimeDifference(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// NOTE: PrayerMood enum is defined in PrayerTracking.swift to avoid duplication

// NOTE: PrayerMethod enum is defined in PrayerTracking.swift to avoid duplication

// NOTE: CongregationType enum is defined in PrayerTracking.swift to avoid duplication

// NOTE: PrayerDifficulty enum is defined in PrayerTracking.swift to avoid duplication

// MARK: - Prayer Statistics

/// Daily prayer statistics
public struct DailyPrayerStats: Codable, Identifiable, Equatable {
    public let id: String
    public let date: Date
    public let completedPrayers: Set<Prayer>
    public let totalPrayers: Int
    public let onTimePrayers: Int
    public let congregationPrayers: Int
    public let qadaPrayers: Int
    public let averageDuration: TimeInterval?
    public let moodDistribution: [PrayerMood: Int]
    public let notes: String?
    
    public init(
        id: String = UUID().uuidString,
        date: Date,
        completedPrayers: Set<Prayer> = [],
        totalPrayers: Int = 5,
        onTimePrayers: Int = 0,
        congregationPrayers: Int = 0,
        qadaPrayers: Int = 0,
        averageDuration: TimeInterval? = nil,
        moodDistribution: [PrayerMood: Int] = [:],
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.completedPrayers = completedPrayers
        self.totalPrayers = totalPrayers
        self.onTimePrayers = onTimePrayers
        self.congregationPrayers = congregationPrayers
        self.qadaPrayers = qadaPrayers
        self.averageDuration = averageDuration
        self.moodDistribution = moodDistribution
        self.notes = notes
    }
    
    /// Completion percentage (0.0 to 1.0)
    public var completionPercentage: Double {
        return Double(completedPrayers.count) / Double(totalPrayers)
    }
    
    /// On-time percentage
    public var onTimePercentage: Double {
        guard completedPrayers.count > 0 else { return 0.0 }
        return Double(onTimePrayers) / Double(completedPrayers.count)
    }
    
    /// Congregation percentage
    public var congregationPercentage: Double {
        guard completedPrayers.count > 0 else { return 0.0 }
        return Double(congregationPrayers) / Double(completedPrayers.count)
    }
    
    /// Check if all prayers were completed
    public var isCompleteDay: Bool {
        return completedPrayers.count == totalPrayers
    }
    
    /// Get the most common mood for the day
    public var dominantMood: PrayerMood? {
        return moodDistribution.max(by: { $0.value < $1.value })?.key
    }
    
    /// Formatted average duration
    public var formattedAverageDuration: String? {
        guard let duration = averageDuration else { return nil }
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(seconds)s"
    }
}

/// Weekly prayer statistics
public struct WeeklyPrayerStats: Codable, Identifiable, Equatable {
    public let id: String
    public let startDate: Date
    public let endDate: Date
    public let dailyStats: [DailyPrayerStats]
    public let totalPossiblePrayers: Int
    public let totalCompletedPrayers: Int
    public let totalOnTimePrayers: Int
    public let totalCongregationPrayers: Int
    public let currentStreak: Int
    public let bestStreak: Int
    public let completeDays: Int
    
    public init(
        id: String = UUID().uuidString,
        startDate: Date,
        endDate: Date,
        dailyStats: [DailyPrayerStats] = [],
        totalPossiblePrayers: Int = 35,
        totalCompletedPrayers: Int = 0,
        totalOnTimePrayers: Int = 0,
        totalCongregationPrayers: Int = 0,
        currentStreak: Int = 0,
        bestStreak: Int = 0,
        completeDays: Int = 0
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.dailyStats = dailyStats
        self.totalPossiblePrayers = totalPossiblePrayers
        self.totalCompletedPrayers = totalCompletedPrayers
        self.totalOnTimePrayers = totalOnTimePrayers
        self.totalCongregationPrayers = totalCongregationPrayers
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.completeDays = completeDays
    }
    
    /// Overall completion percentage
    public var overallCompletionPercentage: Double {
        guard totalPossiblePrayers > 0 else { return 0.0 }
        return Double(totalCompletedPrayers) / Double(totalPossiblePrayers)
    }
    
    /// On-time percentage
    public var onTimePercentage: Double {
        guard totalCompletedPrayers > 0 else { return 0.0 }
        return Double(totalOnTimePrayers) / Double(totalCompletedPrayers)
    }
    
    /// Congregation percentage
    public var congregationPercentage: Double {
        guard totalCompletedPrayers > 0 else { return 0.0 }
        return Double(totalCongregationPrayers) / Double(totalCompletedPrayers)
    }
    
    /// Complete days percentage
    public var completeDaysPercentage: Double {
        return Double(completeDays) / 7.0
    }
    
    /// Average prayers per day
    public var averagePrayersPerDay: Double {
        return Double(totalCompletedPrayers) / 7.0
    }
}

/// Monthly prayer statistics
public struct MonthlyPrayerStats: Codable, Identifiable, Equatable {
    public let id: String
    public let month: Int
    public let year: Int
    public let weeklyStats: [WeeklyPrayerStats]
    public let totalPossiblePrayers: Int
    public let totalCompletedPrayers: Int
    public let bestWeek: Int?
    public let longestStreak: Int
    public let totalCompleteDays: Int
    public let averageCompletionRate: Double
    
    public init(
        id: String = UUID().uuidString,
        month: Int,
        year: Int,
        weeklyStats: [WeeklyPrayerStats] = [],
        totalPossiblePrayers: Int,
        totalCompletedPrayers: Int = 0,
        bestWeek: Int? = nil,
        longestStreak: Int = 0,
        totalCompleteDays: Int = 0,
        averageCompletionRate: Double = 0.0
    ) {
        self.id = id
        self.month = month
        self.year = year
        self.weeklyStats = weeklyStats
        self.totalPossiblePrayers = totalPossiblePrayers
        self.totalCompletedPrayers = totalCompletedPrayers
        self.bestWeek = bestWeek
        self.longestStreak = longestStreak
        self.totalCompleteDays = totalCompleteDays
        self.averageCompletionRate = averageCompletionRate
    }
    
    /// Month name
    public var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        let date = Calendar.current.date(from: DateComponents(year: year, month: month)) ?? Date()
        return formatter.string(from: date)
    }
    
    /// Overall completion percentage
    public var completionPercentage: Double {
        guard totalPossiblePrayers > 0 else { return 0.0 }
        return Double(totalCompletedPrayers) / Double(totalPossiblePrayers)
    }
}

// MARK: - Prayer Goals

/// Prayer goal for tracking progress
public struct PrayerGoal: Codable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let description: String
    public let type: PrayerGoalType
    public let targetValue: Double
    public let currentValue: Double
    public let startDate: Date
    public let endDate: Date
    public let isActive: Bool
    public let prayers: Set<Prayer>
    public let reward: String?
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        type: PrayerGoalType,
        targetValue: Double,
        currentValue: Double = 0.0,
        startDate: Date = Date(),
        endDate: Date,
        isActive: Bool = true,
        prayers: Set<Prayer> = Set(Prayer.allCases),
        reward: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
        self.prayers = prayers
        self.reward = reward
    }
    
    /// Progress percentage (0.0 to 1.0)
    public var progress: Double {
        guard targetValue > 0 else { return 0.0 }
        return min(currentValue / targetValue, 1.0)
    }
    
    /// Check if goal is completed
    public var isCompleted: Bool {
        return currentValue >= targetValue
    }
    
    /// Days remaining
    public var daysRemaining: Int {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
        return max(0, days)
    }
    
    /// Check if goal is overdue
    public var isOverdue: Bool {
        return Date() > endDate && !isCompleted
    }
}

/// Types of prayer goals
public enum PrayerGoalType: String, Codable, CaseIterable {
    case dailyCompletion = "daily_completion"
    case weeklyCompletion = "weekly_completion"
    case onTimePercentage = "on_time_percentage"
    case congregationPercentage = "congregation_percentage"
    case streak = "streak"
    case totalPrayers = "total_prayers"
    case consistency = "consistency"
    
    public var displayName: String {
        switch self {
        case .dailyCompletion: return "Daily Completion"
        case .weeklyCompletion: return "Weekly Completion"
        case .onTimePercentage: return "On-Time Percentage"
        case .congregationPercentage: return "Congregation Percentage"
        case .streak: return "Prayer Streak"
        case .totalPrayers: return "Total Prayers"
        case .consistency: return "Consistency"
        }
    }
    
    public var description: String {
        switch self {
        case .dailyCompletion: return "Complete all 5 daily prayers"
        case .weeklyCompletion: return "Complete prayers for entire weeks"
        case .onTimePercentage: return "Pray on time"
        case .congregationPercentage: return "Pray in congregation"
        case .streak: return "Maintain consecutive prayer days"
        case .totalPrayers: return "Total number of prayers completed"
        case .consistency: return "Maintain regular prayer habit"
        }
    }
    
    public var unit: String {
        switch self {
        case .dailyCompletion: return "days"
        case .weeklyCompletion: return "weeks"
        case .onTimePercentage: return "%"
        case .congregationPercentage: return "%"
        case .streak: return "days"
        case .totalPrayers: return "prayers"
        case .consistency: return "days"
        }
    }
}