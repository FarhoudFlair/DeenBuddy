import Foundation
import SwiftUI

/// Represents the major Islamic traditions (Sunni and Shia) with iOS-specific features
public enum Madhab: String, CaseIterable, Codable {
    case sunni = "sunni"
    case shia = "shia"
    
    // MARK: - Display Properties
    
    /// Localized display name for the tradition
    public var displayName: String {
        switch self {
        case .sunni: return "Sunni"
        case .shia: return "Shia"
        }
    }
    
    /// Arabic name of the tradition
    public var arabicName: String {
        switch self {
        case .sunni: return "سني"
        case .shia: return "شيعي"
        }
    }
    
    /// Transliteration of the Arabic name
    public var transliteration: String {
        switch self {
        case .sunni: return "Sunni"
        case .shia: return "Shi'i"
        }
    }
    
    /// Full formal name of the tradition
    public var formalName: String {
        switch self {
        case .sunni: return "Ahl as-Sunnah wa'l-Jamā'ah"
        case .shia: return "Shīʿat ʿAlī"
        }
    }
    
    // MARK: - Tradition Information
    
    /// Brief description of the tradition
    public var description: String {
        switch self {
        case .sunni: return "Sunni Islamic tradition following the Sunnah of Prophet Muhammad (PBUH)"
        case .shia: return "Shia Islamic tradition following the teachings of Ali ibn Abi Talib (AS)"
        }
    }
    
    /// Detailed description of the tradition
    public var detailedDescription: String {
        switch self {
        case .sunni:
            return "The largest denomination of Islam, emphasizing the Sunnah (traditions) of Prophet Muhammad (PBUH) and the consensus of the Muslim community."
        case .shia:
            return "The second-largest denomination of Islam, emphasizing the divine right of Ali ibn Abi Talib (AS) and his descendants to lead the Muslim community."
        }
    }
    
    /// Key distinguishing practices
    public var keyPractices: [String] {
        switch self {
        case .sunni:
            return [
                "Follows the Four Rightly-Guided Caliphs",
                "Emphasizes consensus (Ijma) and analogy (Qiyas)",
                "Four major schools of jurisprudence (Madhabs)",
                "Prayer with hands folded"
            ]
        case .shia:
            return [
                "Follows the Twelve Imams",
                "Emphasizes the authority of the Imam",
                "Temporary marriage (Mut'ah) permitted",
                "Prayer with hands at sides",
                "Observance of Ashura"
            ]
        }
    }
    
    // MARK: - iOS UI Properties
    
    /// SwiftUI color associated with this tradition
    public var color: Color {
        switch self {
        case .sunni: return .green
        case .shia: return .purple
        }
    }
    
    /// Secondary color for gradients
    public var secondaryColor: Color {
        switch self {
        case .sunni: return .mint
        case .shia: return .indigo
        }
    }
    
    /// Gradient colors for this tradition
    public var gradientColors: [Color] {
        return [color, secondaryColor]
    }
    
    /// SF Symbol name representing this tradition
    public var systemImageName: String {
        switch self {
        case .sunni: return "book.closed"
        case .shia: return "crown"
        }
    }
    
    /// Alternative SF Symbol for variety
    public var alternativeSystemImageName: String {
        switch self {
        case .sunni: return "text.book.closed"
        case .shia: return "star.circle"
        }
    }
    
    // MARK: - Prayer Differences
    
    /// Key differences in prayer practices
    public var prayerDifferences: [String] {
        switch self {
        case .sunni:
            return [
                "Hands folded during prayer",
                "Amen said aloud after Fatiha",
                "Feet together during standing"
            ]
        case .shia:
            return [
                "Hands at sides during prayer",
                "Amen said silently after Fatiha",
                "Feet slightly apart during standing",
                "Prostration on clay tablet (Turbah)"
            ]
        }
    }
    
    /// Recommended prayer times differences
    public var prayerTimingNotes: String {
        switch self {
        case .sunni:
            return "Generally follows standard calculation methods with slight variations by school"
        case .shia:
            return "May combine Dhuhr with Asr, and Maghrib with Isha prayers"
        }
    }
    
    // MARK: - Accessibility
    
    /// Accessibility label for VoiceOver
    public var accessibilityLabel: String {
        return "\(displayName) Islamic tradition"
    }
    
    /// Accessibility hint for VoiceOver
    public var accessibilityHint: String {
        return description
    }
    
    // MARK: - Utility Properties
    
    /// Percentage of global Muslim population (approximate)
    public var globalPercentage: Double {
        switch self {
        case .sunni: return 85.0
        case .shia: return 15.0
        }
    }
    
    /// Major geographic regions where this tradition is prevalent
    public var prevalentRegions: [String] {
        switch self {
        case .sunni:
            return [
                "Saudi Arabia", "Egypt", "Turkey", "Indonesia", "Pakistan",
                "Bangladesh", "Nigeria", "Morocco", "Algeria", "Sudan"
            ]
        case .shia:
            return [
                "Iran", "Iraq", "Azerbaijan", "Bahrain", "Lebanon",
                "Yemen (Houthis)", "Parts of Afghanistan", "Parts of Pakistan"
            ]
        }
    }
}

// MARK: - Extensions

// Note: description property is already defined in the main enum

extension Madhab {
    /// Returns the opposite tradition
    public var opposite: Madhab {
        switch self {
        case .sunni: return .shia
        case .shia: return .sunni
        }
    }
}
