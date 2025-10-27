import Foundation
import SwiftUI

// MARK: - Prayer Tracking Models

/// Entry representing a completed prayer
public struct PrayerEntry: Codable, Identifiable, Equatable {
    public let id: UUID
    public let prayer: Prayer
    public let completedAt: Date
    public let location: String?
    public let notes: String?
    public let mood: PrayerMood?
    public let method: PrayerMethod
    public let duration: TimeInterval?
    public let congregation: CongregationType
    public let isQada: Bool // Make-up prayer
    public let hadithRemembered: String?
    public let gratitudeNote: String?
    public let difficulty: PrayerDifficulty?
    public let tags: [String]
    
    public init(
        id: UUID = UUID(),
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
        self.id = id
        self.prayer = prayer
        self.completedAt = completedAt
        self.location = location
        self.notes = notes
        self.mood = mood
        self.method = method
        self.duration = duration
        self.congregation = congregation
        self.isQada = isQada
        self.hadithRemembered = hadithRemembered
        self.gratitudeNote = gratitudeNote
        self.difficulty = difficulty
        self.tags = tags
    }
    
    /// Quick initializer for simple prayer completion
    public static func quick(prayer: Prayer, at date: Date = Date()) -> PrayerEntry {
        return PrayerEntry(prayer: prayer, completedAt: date)
    }
}

/// Statistics about prayer completion
public struct PrayerStatistics: Codable, Equatable {
    public let totalPrayers: Int
    public let completedPrayers: Int
    public let currentStreak: Int
    public let longestStreak: Int
    public let averagePerDay: Double
    public let weeklyProgress: [Double] // 7 days
    public let monthlyProgress: [Double] // 30 days
    public let completionRate: Double
    public let mostMissedPrayer: Prayer?
    public let mostCompletedPrayer: Prayer?
    public let averageMood: PrayerMood?
    public let totalDuration: TimeInterval
    public let averageDuration: TimeInterval
    public let congregationRate: Double
    public let qadaCount: Int
    
    public init(
        totalPrayers: Int = 0,
        completedPrayers: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        averagePerDay: Double = 0.0,
        weeklyProgress: [Double] = Array(repeating: 0.0, count: 7),
        monthlyProgress: [Double] = Array(repeating: 0.0, count: 30),
        completionRate: Double = 0.0,
        mostMissedPrayer: Prayer? = nil,
        mostCompletedPrayer: Prayer? = nil,
        averageMood: PrayerMood? = nil,
        totalDuration: TimeInterval = 0,
        averageDuration: TimeInterval = 0,
        congregationRate: Double = 0.0,
        qadaCount: Int = 0
    ) {
        self.totalPrayers = totalPrayers
        self.completedPrayers = completedPrayers
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.averagePerDay = averagePerDay
        self.weeklyProgress = weeklyProgress
        self.monthlyProgress = monthlyProgress
        self.completionRate = completionRate
        self.mostMissedPrayer = mostMissedPrayer
        self.mostCompletedPrayer = mostCompletedPrayer
        self.averageMood = averageMood
        self.totalDuration = totalDuration
        self.averageDuration = averageDuration
        self.congregationRate = congregationRate
        self.qadaCount = qadaCount
    }
    
    /// Empty statistics for fallback
    public static let empty = PrayerStatistics()
    
    /// Completion percentage (0-100)
    public var completionPercentage: Int {
        return Int(completionRate * 100)
    }
    
    /// Formatted completion rate string
    public var completionRateString: String {
        return String(format: "%.1f%%", completionRate * 100)
    }
    
    /// Formatted average duration string
    public var averageDurationString: String {
        let minutes = Int(averageDuration / 60)
        let seconds = Int(averageDuration.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// Mood during prayer
public enum PrayerMood: String, Codable, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case neutral = "neutral"
    case difficult = "difficult"
    case distracted = "distracted"
    
    public var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .neutral: return "Neutral"
        case .difficult: return "Difficult"
        case .distracted: return "Distracted"
        }
    }
    
    public var emoji: String {
        switch self {
        case .excellent: return "🌟"
        case .good: return "😊"
        case .neutral: return "😐"
        case .difficult: return "😓"
        case .distracted: return "😵‍💫"
        }
    }
    
    public var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .neutral: return .gray
        case .difficult: return .orange
        case .distracted: return .red
        }
    }
    
    public var value: Double {
        switch self {
        case .excellent: return 5.0
        case .good: return 4.0
        case .neutral: return 3.0
        case .difficult: return 2.0
        case .distracted: return 1.0
        }
    }
}

/// Method of prayer
public enum PrayerMethod: String, Codable, CaseIterable {
    case individual = "individual"
    case congregation = "congregation"
    case following = "following" // Following imam remotely
    case makeup = "makeup" // Qada prayer
    
    public var displayName: String {
        switch self {
        case .individual: return "Individual"
        case .congregation: return "Congregation"
        case .following: return "Following"
        case .makeup: return "Make-up"
        }
    }
    
    public var icon: String {
        switch self {
        case .individual: return "person"
        case .congregation: return "person.3"
        case .following: return "person.wave.2"
        case .makeup: return "clock.arrow.circlepath"
        }
    }
    
    public var reward: Double {
        switch self {
        case .individual: return 1.0
        case .congregation: return 27.0 // As per hadith
        case .following: return 25.0
        case .makeup: return 1.0
        }
    }
}

/// Type of congregation
public enum CongregationType: String, Codable, CaseIterable {
    case individual = "individual"
    case mosque = "mosque"
    case home = "home"
    case work = "work"
    case travel = "travel"
    case online = "online"
    
    public var displayName: String {
        switch self {
        case .individual: return "Individual"
        case .mosque: return "Mosque"
        case .home: return "Home"
        case .work: return "Work"
        case .travel: return "Travel"
        case .online: return "Online"
        }
    }
    
    public var icon: String {
        switch self {
        case .individual: return "person"
        case .mosque: return "building.columns"
        case .home: return "house"
        case .work: return "building.2"
        case .travel: return "airplane"
        case .online: return "wifi"
        }
    }
}

/// Difficulty level of prayer
public enum PrayerDifficulty: String, Codable, CaseIterable {
    case easy = "easy"
    case moderate = "moderate"
    case challenging = "challenging"
    case veryDifficult = "very_difficult"
    
    public var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .moderate: return "Moderate"
        case .challenging: return "Challenging"
        case .veryDifficult: return "Very Difficult"
        }
    }
    
    public var color: Color {
        switch self {
        case .easy: return .green
        case .moderate: return .blue
        case .challenging: return .orange
        case .veryDifficult: return .red
        }
    }
    
    public var value: Int {
        switch self {
        case .easy: return 1
        case .moderate: return 2
        case .challenging: return 3
        case .veryDifficult: return 4
        }
    }
}

/// Prayer streak information
public struct PrayerStreak: Codable, Equatable {
    public let current: Int
    public let longest: Int
    public let startDate: Date?
    public let endDate: Date?
    public let isActive: Bool

    public init(
        current: Int = 0,
        longest: Int = 0,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isActive: Bool = false
    ) {
        self.current = current
        self.longest = longest
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
    }

    /// Empty streak for fallback
    public static let empty = PrayerStreak()

    /// Duration of current streak
    public var currentStreakDuration: TimeInterval? {
        guard let startDate = startDate else { return nil }
        return Date().timeIntervalSince(startDate)
    }

    /// Days in current streak
    public var currentStreakDays: Int {
        guard let duration = currentStreakDuration else { return 0 }
        return Int(duration / (24 * 60 * 60))
    }
}

/// Individual prayer streak information - tracks streak for a specific prayer
public struct IndividualPrayerStreak: Codable, Equatable, Identifiable {
    public let id: UUID
    public let prayer: Prayer
    public let currentStreak: Int
    public let longestStreak: Int
    public let lastCompleted: Date?
    public let isActiveToday: Bool
    public let startDate: Date?

    public init(
        id: UUID = UUID(),
        prayer: Prayer,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastCompleted: Date? = nil,
        isActiveToday: Bool = false,
        startDate: Date? = nil
    ) {
        self.id = id
        self.prayer = prayer
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastCompleted = lastCompleted
        self.isActiveToday = isActiveToday
        self.startDate = startDate
    }

    /// Get next milestone for this prayer streak
    public var nextMilestone: Int {
        let milestones = [3, 7, 14, 30, 60, 100, 365]
        return milestones.first { $0 > currentStreak } ?? (currentStreak + 30)
    }

    /// Progress to next milestone (0.0 to 1.0)
    public var milestoneProgress: Double {
        let previous = getPreviousMilestone()
        let next = nextMilestone
        let range = Double(next - previous)
        let current = Double(currentStreak - previous)
        return range > 0 ? min(current / range, 1.0) : 0.0
    }

    /// Days remaining to next milestone
    public var daysToMilestone: Int {
        return max(0, nextMilestone - currentStreak)
    }

    /// Get streak intensity level for visual representation
    public var intensityLevel: StreakIntensity {
        switch currentStreak {
        case 0:
            return .none
        case 1...3:
            return .starting
        case 4...7:
            return .building
        case 8...30:
            return .strong
        case 31...99:
            return .excellent
        default:
            return .legendary
        }
    }

    private func getPreviousMilestone() -> Int {
        let milestones = [0, 3, 7, 14, 30, 60, 100, 365]
        return milestones.last { $0 <= currentStreak } ?? 0
    }
}

/// Streak intensity levels for visual representation
public enum StreakIntensity: String, Codable {
    case none = "none"
    case starting = "starting"
    case building = "building"
    case strong = "strong"
    case excellent = "excellent"
    case legendary = "legendary"

    public var displayName: String {
        switch self {
        case .none: return "Start Your Streak"
        case .starting: return "Getting Started"
        case .building: return "Building Momentum"
        case .strong: return "Strong Streak!"
        case .excellent: return "Excellent Work!"
        case .legendary: return "Legendary!"
        }
    }

    public var color: Color {
        switch self {
        case .none: return .gray
        case .starting: return .orange
        case .building: return .yellow
        case .strong: return .green
        case .excellent: return .blue
        case .legendary: return .purple
        }
    }

    public var icon: String {
        switch self {
        case .none: return "flame"
        case .starting: return "flame.fill"
        case .building: return "flame.fill"
        case .strong: return "flame.fill"
        case .excellent: return "star.fill"
        case .legendary: return "crown.fill"
        }
    }
}

/// Daily prayer progress
public struct DailyPrayerProgress: Codable, Equatable {
    public let date: Date
    public let fajrCompleted: Bool
    public let dhuhrCompleted: Bool
    public let asrCompleted: Bool
    public let maghribCompleted: Bool
    public let ishaCompleted: Bool
    public let totalCompleted: Int
    public let completionRate: Double
    public let entries: [PrayerEntry]
    
    public init(
        date: Date,
        fajrCompleted: Bool = false,
        dhuhrCompleted: Bool = false,
        asrCompleted: Bool = false,
        maghribCompleted: Bool = false,
        ishaCompleted: Bool = false,
        entries: [PrayerEntry] = []
    ) {
        self.date = date
        self.fajrCompleted = fajrCompleted
        self.dhuhrCompleted = dhuhrCompleted
        self.asrCompleted = asrCompleted
        self.maghribCompleted = maghribCompleted
        self.ishaCompleted = ishaCompleted
        self.entries = entries
        
        // Calculate derived values
        let completed = [fajrCompleted, dhuhrCompleted, asrCompleted, maghribCompleted, ishaCompleted]
        self.totalCompleted = completed.filter { $0 }.count
        self.completionRate = Double(totalCompleted) / 5.0
    }
    
    /// Check if specific prayer is completed
    public func isCompleted(_ prayer: Prayer) -> Bool {
        switch prayer {
        case .fajr: return fajrCompleted
        case .dhuhr: return dhuhrCompleted
        case .asr: return asrCompleted
        case .maghrib: return maghribCompleted
        case .isha: return ishaCompleted
        }
    }
    
    /// Get entry for specific prayer
    public func getEntry(for prayer: Prayer) -> PrayerEntry? {
        return entries.first { $0.prayer == prayer }
    }
    
    /// Check if all prayers are completed
    public var isFullyCompleted: Bool {
        return totalCompleted == 5
    }
    
    /// Get missing prayers
    public var missingPrayers: [Prayer] {
        var missing: [Prayer] = []
        if !fajrCompleted { missing.append(.fajr) }
        if !dhuhrCompleted { missing.append(.dhuhr) }
        if !asrCompleted { missing.append(.asr) }
        if !maghribCompleted { missing.append(.maghrib) }
        if !ishaCompleted { missing.append(.isha) }
        return missing
    }
    
    /// Completion percentage (0-100)
    public var completionPercentage: Int {
        return Int(completionRate * 100)
    }
}

/// Weekly prayer progress
public struct WeeklyPrayerProgress: Codable, Equatable {
    public let startDate: Date
    public let endDate: Date
    public let dailyProgress: [DailyPrayerProgress]
    public let totalPrayers: Int
    public let completedPrayers: Int
    public let completionRate: Double
    public let bestDay: Date?
    public let worstDay: Date?
    
    public init(
        startDate: Date,
        endDate: Date,
        dailyProgress: [DailyPrayerProgress] = []
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.dailyProgress = dailyProgress
        
        // Calculate derived values
        self.totalPrayers = dailyProgress.count * 5
        self.completedPrayers = dailyProgress.reduce(0) { $0 + $1.totalCompleted }
        self.completionRate = totalPrayers > 0 ? Double(completedPrayers) / Double(totalPrayers) : 0.0
        
        // Find best and worst days
        self.bestDay = dailyProgress.max { $0.completionRate < $1.completionRate }?.date
        self.worstDay = dailyProgress.min { $0.completionRate < $1.completionRate }?.date
    }
    
    /// Get progress for specific day
    public func getProgress(for date: Date) -> DailyPrayerProgress? {
        return dailyProgress.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    /// Average completion rate for the week
    public var averageCompletionRate: Double {
        guard !dailyProgress.isEmpty else { return 0.0 }
        return dailyProgress.reduce(0) { $0 + $1.completionRate } / Double(dailyProgress.count)
    }
    
    /// Days with full completion
    public var perfectDays: Int {
        return dailyProgress.filter { $0.isFullyCompleted }.count
    }
    
    /// Completion percentage (0-100)
    public var completionPercentage: Int {
        return Int(completionRate * 100)
    }
}

// MARK: - Extensions

extension PrayerEntry {
    /// Check if prayer was on time
    public func wasOnTime(prayerTime: Date, tolerance: TimeInterval = 30 * 60) -> Bool {
        let timeDifference = abs(completedAt.timeIntervalSince(prayerTime))
        return timeDifference <= tolerance
    }
    
    /// Get relative time string
    public var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: completedAt, relativeTo: Date())
    }
    
    /// Get formatted duration string
    public var durationString: String? {
        guard let duration = duration else { return nil }
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension Prayer {
    /// Get default tags for this prayer
    public var defaultTags: [String] {
        switch self {
        case .fajr: return ["morning", "dawn", "blessed"]
        case .dhuhr: return ["midday", "work", "break"]
        case .asr: return ["afternoon", "focus", "reflection"]
        case .maghrib: return ["sunset", "family", "gratitude"]
        case .isha: return ["night", "peace", "rest"]
        }
    }
    
    /// Get suggested mood prompts
    public var moodPrompts: [String] {
        switch self {
        case .fajr: return ["How did you feel waking up early?", "Did you feel blessed?"]
        case .dhuhr: return ["How was your focus during the day?", "Did you take time from work?"]
        case .asr: return ["How was your afternoon reflection?", "Did you feel peaceful?"]
        case .maghrib: return ["How grateful did you feel?", "Did you reflect on the day?"]
        case .isha: return ["How peaceful was your night prayer?", "Did you feel ready for rest?"]
        }
    }
}

extension PrayerMood {
    /// Create mood from value (1-5, supports averages)
    public static func from(value: Double) -> PrayerMood? {
        switch value {
        case 4.5...5.0:
            return .excellent
        case 3.5..<4.5:
            return .good
        case 2.5..<3.5:
            return .neutral
        case 1.5..<2.5:
            return .difficult
        case 1.0..<1.5:
            return .distracted
        default:
            return nil
        }
    }
    
    /// Get average mood from array
    public static func average(from moods: [PrayerMood]) -> PrayerMood? {
        guard !moods.isEmpty else { return nil }
        let average = moods.reduce(0) { $0 + $1.value } / Double(moods.count)
        return PrayerMood.from(value: average)
    }
}