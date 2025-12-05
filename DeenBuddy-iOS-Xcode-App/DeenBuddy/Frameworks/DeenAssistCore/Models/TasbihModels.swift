import Foundation
import SwiftUI

// MARK: - Digital Tasbih Models

/// Represents a dhikr (remembrance) phrase for tasbih
public struct Dhikr: Codable, Identifiable, Equatable {
    public let id: UUID
    public let arabicText: String
    public let transliteration: String
    public let translation: String
    public let category: DhikrCategory
    public let reward: String?
    public let source: String?
    public let isCustom: Bool
    public let targetCount: Int
    public let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        arabicText: String,
        transliteration: String,
        translation: String,
        category: DhikrCategory,
        reward: String? = nil,
        source: String? = nil,
        isCustom: Bool = false,
        targetCount: Int = 33,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.arabicText = arabicText
        self.transliteration = transliteration
        self.translation = translation
        self.category = category
        self.reward = reward
        self.source = source
        self.isCustom = isCustom
        self.targetCount = targetCount
        self.createdAt = createdAt
    }
}

/// Categories of dhikr
public enum DhikrCategory: String, Codable, CaseIterable {
    case tasbih = "tasbih"           // SubhanAllah
    case tahmid = "tahmid"           // Alhamdulillah
    case takbir = "takbir"           // Allahu Akbar
    case tahlil = "tahlil"           // La ilaha illa Allah
    case istighfar = "istighfar"     // Astaghfirullah
    case salawat = "salawat"         // Salawat on Prophet
    case dua = "dua"                 // Supplications
    case quran = "quran"             // Quranic verses
    case custom = "custom"           // User-defined
    
    public var displayName: String {
        switch self {
        case .tasbih: return "Tasbih"
        case .tahmid: return "Tahmid"
        case .takbir: return "Takbir"
        case .tahlil: return "Tahlil"
        case .istighfar: return "Istighfar"
        case .salawat: return "Salawat"
        case .dua: return "Dua"
        case .quran: return "Quran"
        case .custom: return "Custom"
        }
    }
    
    public var color: Color {
        switch self {
        case .tasbih: return .green
        case .tahmid: return .blue
        case .takbir: return .orange
        case .tahlil: return .purple
        case .istighfar: return .red
        case .salawat: return .pink
        case .dua: return .teal
        case .quran: return .indigo
        case .custom: return .gray
        }
    }
}

/// Represents a tasbih counting session
public struct TasbihSession: Codable, Identifiable, Equatable {
    public let id: UUID
    public let dhikr: Dhikr
    public let counterId: UUID?
    public let startTime: Date
    public let endTime: Date?
    public let currentCount: Int
    public let targetCount: Int
    public let isCompleted: Bool
    public let isPaused: Bool
    public let totalDuration: TimeInterval
    public let notes: String?
    public let location: String?
    public let mood: SessionMood?
    
    public init(
        id: UUID = UUID(),
        dhikr: Dhikr,
        counterId: UUID? = nil,
        startTime: Date = Date(),
        endTime: Date? = nil,
        currentCount: Int = 0,
        targetCount: Int? = nil,
        isCompleted: Bool = false,
        isPaused: Bool = false,
        totalDuration: TimeInterval = 0,
        notes: String? = nil,
        location: String? = nil,
        mood: SessionMood? = nil
    ) {
        self.id = id
        self.dhikr = dhikr
        self.counterId = counterId
        self.startTime = startTime
        self.endTime = endTime
        self.currentCount = currentCount
        self.targetCount = targetCount ?? dhikr.targetCount
        self.isCompleted = isCompleted
        self.isPaused = isPaused
        self.totalDuration = totalDuration
        self.notes = notes
        self.location = location
        self.mood = mood
    }
    
    /// Progress as a percentage (0.0 to 1.0)
    public var progress: Double {
        guard targetCount > 0 else { return 0.0 }
        return min(Double(currentCount) / Double(targetCount), 1.0)
    }
    
    /// Remaining count to reach target
    public var remainingCount: Int {
        return max(0, targetCount - currentCount)
    }
}

/// Mood during tasbih session
public enum SessionMood: String, Codable, CaseIterable {
    case peaceful = "peaceful"
    case focused = "focused"
    case grateful = "grateful"
    case reflective = "reflective"
    case joyful = "joyful"
    case seeking = "seeking"
    case repentant = "repentant"
    case hopeful = "hopeful"
    
    public var displayName: String {
        return rawValue.capitalized
    }
    
    public var emoji: String {
        switch self {
        case .peaceful: return "☮️"
        case .focused: return "🎯"
        case .grateful: return "🙏"
        case .reflective: return "🤔"
        case .joyful: return "😊"
        case .seeking: return "🔍"
        case .repentant: return "😔"
        case .hopeful: return "🌟"
        }
    }
}

/// Tasbih counter with customizable settings
public struct TasbihCounter: Codable, Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let maxCount: Int
    public let resetOnComplete: Bool
    public let hapticFeedback: Bool
    public let soundFeedback: Bool
    public let soundName: String?
    public let vibrationPattern: VibrationPattern
    public let countIncrement: Int
    public let isDefault: Bool
    public let createdAt: Date
    
    /// Defaults to `soundFeedback = true` so new counters provide audible cues unless explicitly disabled.
    public init(
        id: UUID = UUID(),
        name: String,
        maxCount: Int = 99,
        resetOnComplete: Bool = true,
        hapticFeedback: Bool = true,
        soundFeedback: Bool = true,
        soundName: String? = nil,
        vibrationPattern: VibrationPattern = .light,
        countIncrement: Int = 1,
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.maxCount = maxCount
        self.resetOnComplete = resetOnComplete
        self.hapticFeedback = hapticFeedback
        self.soundFeedback = soundFeedback
        self.soundName = soundName
        self.vibrationPattern = vibrationPattern
        self.countIncrement = countIncrement
        self.isDefault = isDefault
        self.createdAt = createdAt
    }
}

/// Vibration patterns for tasbih feedback
public enum VibrationPattern: String, Codable, CaseIterable {
    case none = "none"
    case light = "light"
    case medium = "medium"
    case heavy = "heavy"
    case custom = "custom"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}

/// Statistics for tasbih sessions
public struct TasbihStatistics: Codable, Equatable {
    public let totalSessions: Int
    public let completedSessions: Int
    public let totalDhikrCount: Int
    public let totalDuration: TimeInterval
    public let averageSessionDuration: TimeInterval
    public let longestSession: TimeInterval
    public let currentStreak: Int
    public let longestStreak: Int
    public let favoriteCategory: DhikrCategory?
    public let mostUsedDhikr: Dhikr?
    public let weeklyProgress: [Int] // Last 7 days
    public let monthlyProgress: [Int] // Last 30 days
    public let completionRate: Double
    public let averageDailyCount: Double
    public let bestDay: Date?
    public let bestDayCount: Int
    
    public init(
        totalSessions: Int = 0,
        completedSessions: Int = 0,
        totalDhikrCount: Int = 0,
        totalDuration: TimeInterval = 0,
        averageSessionDuration: TimeInterval = 0,
        longestSession: TimeInterval = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        favoriteCategory: DhikrCategory? = nil,
        mostUsedDhikr: Dhikr? = nil,
        weeklyProgress: [Int] = Array(repeating: 0, count: 7),
        monthlyProgress: [Int] = Array(repeating: 0, count: 30),
        completionRate: Double = 0.0,
        averageDailyCount: Double = 0.0,
        bestDay: Date? = nil,
        bestDayCount: Int = 0
    ) {
        self.totalSessions = totalSessions
        self.completedSessions = completedSessions
        self.totalDhikrCount = totalDhikrCount
        self.totalDuration = totalDuration
        self.averageSessionDuration = averageSessionDuration
        self.longestSession = longestSession
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.favoriteCategory = favoriteCategory
        self.mostUsedDhikr = mostUsedDhikr
        self.weeklyProgress = weeklyProgress
        self.monthlyProgress = monthlyProgress
        self.completionRate = completionRate
        self.averageDailyCount = averageDailyCount
        self.bestDay = bestDay
        self.bestDayCount = bestDayCount
    }
}

/// Tasbih goal for motivation
public struct TasbihGoal: Codable, Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let description: String
    public let targetCount: Int
    public let currentCount: Int
    public let targetDate: Date
    public let category: DhikrCategory?
    public let specificDhikr: Dhikr?
    public let isCompleted: Bool
    public let createdAt: Date
    public let completedAt: Date?
    public let reward: String?
    
    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        targetCount: Int,
        currentCount: Int = 0,
        targetDate: Date,
        category: DhikrCategory? = nil,
        specificDhikr: Dhikr? = nil,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        reward: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.targetCount = targetCount
        self.currentCount = currentCount
        self.targetDate = targetDate
        self.category = category
        self.specificDhikr = specificDhikr
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.reward = reward
    }
    
    /// Progress as a percentage (0.0 to 1.0)
    public var progress: Double {
        guard targetCount > 0 else { return 0.0 }
        return min(Double(currentCount) / Double(targetCount), 1.0)
    }
    
    /// Days remaining to reach target
    public var daysRemaining: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: targetDate).day ?? 0
        return max(0, days)
    }
}
