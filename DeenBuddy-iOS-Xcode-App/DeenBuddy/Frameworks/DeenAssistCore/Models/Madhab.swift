import Foundation
import SwiftUI

/// Represents the major Islamic traditions (Sunni and Shia) with iOS-specific features
public enum Madhab: String, CaseIterable, Codable, Identifiable {
    public var id: String { rawValue }
    case sunni = "sunni"
    case shia = "shia"
    case shafi = "shafi"
    case hanafi = "hanafi"
    
    // MARK: - Display Properties
    
    /// Localized display name for the tradition
    public var displayName: String {
        switch self {
        case .sunni: return "Sunni"
        case .shia: return "Shia"
        case .shafi: return "Shafi"
        case .hanafi: return "Hanafi"
        }
    }
    
    /// Arabic name of the tradition
    public var arabicName: String {
        switch self {
        case .sunni: return "سني"
        case .shia: return "شيعي"
        case .shafi: return "شافعي"
        case .hanafi: return "حنفي"
        }
    }
    
    /// Transliteration of the Arabic name
    public var transliteration: String {
        switch self {
        case .sunni: return "Sunni"
        case .shia: return "Shi'i"
        case .shafi: return "Shafi'i"
        case .hanafi: return "Hanafi"
        }
    }
    
    /// Display name for sect/tradition selection
    public var sectDisplayName: String {
        return displayName
    }
    
    /// Full formal name of the tradition
    public var formalName: String {
        switch self {
        case .sunni: return "Ahl as-Sunnah wa'l-Jamā'ah"
        case .shia: return "Shīʿat ʿAlī"
        case .shafi: return "Madhhab ash-Shāfiʿī"
        case .hanafi: return "Madhhab al-Hanafī"
        }
    }
    
    // MARK: - Tradition Information
    
    /// Brief description of the tradition
    public var description: String {
        switch self {
        case .sunni: return "Sunni Islamic tradition following the Sunnah of Prophet Muhammad (PBUH)"
        case .shia: return "Shia Islamic tradition following the teachings of Ali ibn Abi Talib (AS)"
        case .shafi: return "Shafi'i school of Islamic jurisprudence founded by Imam ash-Shafi'i"
        case .hanafi: return "Hanafi school of Islamic jurisprudence founded by Imam Abu Hanifa"
        }
    }
    
    /// Detailed description of the tradition
    public var detailedDescription: String {
        switch self {
        case .sunni:
            return "The largest denomination of Islam, emphasizing the Sunnah (traditions) of Prophet Muhammad (PBUH) and the consensus of the Muslim community."
        case .shia:
            return "The second-largest denomination of Islam, emphasizing the divine right of Ali ibn Abi Talib (AS) and his descendants to lead the Muslim community."
        case .shafi:
            return "One of the four major Sunni schools of Islamic jurisprudence, founded by Imam ash-Shafi'i, emphasizing the Quran and Hadith as primary sources."
        case .hanafi:
            return "One of the four major Sunni schools of Islamic jurisprudence, founded by Imam Abu Hanifa, known for its use of reason and opinion."
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
        case .shafi:
            return [
                "Emphasizes Quran and Hadith as primary sources",
                "Uses consensus (Ijma) and analogy (Qiyas)",
                "Systematic approach to jurisprudence",
                "Moderate position on many issues"
            ]
        case .hanafi:
            return [
                "Uses reason (Ra'y) and opinion extensively",
                "Flexibility in interpretation",
                "Emphasizes local customs (Urf)",
                "Practical approach to jurisprudence"
            ]
        }
    }
    
    // MARK: - iOS UI Properties
    
    /// SwiftUI color associated with this tradition
    public var color: Color {
        switch self {
        case .sunni: return .green
        case .shia: return .purple
        case .shafi: return .blue
        case .hanafi: return .orange
        }
    }
    
    /// Secondary color for gradients
    public var secondaryColor: Color {
        switch self {
        case .sunni: return .mint
        case .shia: return .indigo
        case .shafi: return .cyan
        case .hanafi: return .yellow
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
        case .shafi: return "graduationcap"
        case .hanafi: return "building.columns"
        }
    }
    
    /// Alternative SF Symbol for variety
    public var alternativeSystemImageName: String {
        switch self {
        case .sunni: return "text.book.closed"
        case .shia: return "star.circle"
        case .shafi: return "person.badge.plus"
        case .hanafi: return "building.2"
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
        case .shafi:
            return [
                "Hands folded above navel",
                "Specific recitations in prayer",
                "Particular standing positions",
                "Emphasis on following Sunnah precisely"
            ]
        case .hanafi:
            return [
                "Hands folded below navel",
                "Silent recitation in certain prayers",
                "Specific prostration positions",
                "Flexibility in some prayer practices"
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
        case .shafi:
            return "Follows precise prayer time calculations based on Hadith and Quran"
        case .hanafi:
            return "Uses specific calculations for Fajr and Isha times, allowing for regional flexibility"
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
        case .shafi: return 28.0 // Approx percentage within Sunni Islam
        case .hanafi: return 45.0 // Approx percentage within Sunni Islam
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
        case .shafi:
            return [
                "Egypt", "Indonesia", "Malaysia", "Brunei", "Philippines",
                "Jordan", "Palestine", "Lebanon", "Eastern Africa"
            ]
        case .hanafi:
            return [
                "Turkey", "Central Asia", "Pakistan", "Afghanistan", "India",
                "Bangladesh", "Bosnia", "Albania", "Kosovo"
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
        case .shafi: return .hanafi
        case .hanafi: return .shafi
        }
    }
}
