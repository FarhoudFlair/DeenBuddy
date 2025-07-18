import Foundation
import SwiftUI

/// Represents the major Islamic schools of jurisprudence with prayer timing calculations
public enum Madhab: String, CaseIterable, Codable, Identifiable {
    public var id: String { rawValue }
    case hanafi = "hanafi"
    case shafi = "shafi"
    case jafari = "jafari"

    // MARK: - Prayer Timing Properties

    /// Shadow multiplier for Asr prayer calculation
    public var asrShadowMultiplier: Double {
        switch self {
        case .hanafi: return 2.0  // Hanafi: shadow length = 2x object height
        case .shafi: return 1.0   // Shafi'i: shadow length = 1x object height
        case .jafari: return 1.0  // Ja'fari: shadow length = 1x object height
        }
    }

    /// Twilight angle for Isha prayer calculation (degrees below horizon)
    public var ishaTwilightAngle: Double {
        switch self {
        case .hanafi: return 18.0  // Hanafi: 18 degrees
        case .shafi: return 17.0   // Shafi'i: 17 degrees
        case .jafari: return 14.0  // Ja'fari: 14 degrees
        }
    }

    /// Delay in minutes after sunset for Maghrib prayer
    public var maghribDelayMinutes: Double {
        switch self {
        case .hanafi: return 0.0   // Hanafi: at sunset
        case .shafi: return 0.0    // Shafi'i: at sunset
        case .jafari: return 4.0   // Ja'fari: 4 minutes after sunset
        }
    }

    /// Twilight angle for Fajr prayer calculation (degrees below horizon)
    public var fajrTwilightAngle: Double {
        switch self {
        case .hanafi: return 18.0  // Hanafi: 18 degrees
        case .shafi: return 18.0   // Shafi'i: 18 degrees (when using Muslim World League)
        case .jafari: return 16.0  // Ja'fari: 16 degrees
        }
    }

    // MARK: - Display Properties

    /// Localized display name for the school
    public var displayName: String {
        switch self {
        case .hanafi: return "Hanafi"
        case .shafi: return "Shafi'i (Maliki/Hanbali)"
        case .jafari: return "Ja'fari (Shia)"
        }
    }

    /// Arabic name of the school
    public var arabicName: String {
        switch self {
        case .hanafi: return "حنفي"
        case .shafi: return "شافعي"
        case .jafari: return "جعفري"
        }
    }

    /// Transliteration of the Arabic name
    public var transliteration: String {
        switch self {
        case .hanafi: return "Hanafi"
        case .shafi: return "Shafi'i"
        case .jafari: return "Ja'fari"
        }
    }

    /// Display name for sect/tradition selection
    public var sectDisplayName: String {
        return displayName
    }

    /// Full formal name of the school
    public var formalName: String {
        switch self {
        case .hanafi: return "Madhhab al-Hanafī"
        case .shafi: return "Madhhab ash-Shāfiʿī"
        case .jafari: return "Madhhab al-Ja'farī"
        }
    }

    // MARK: - School Information

    /// Brief description of the school
    public var description: String {
        switch self {
        case .hanafi: return "Hanafi school of Islamic jurisprudence founded by Imam Abu Hanifa"
        case .shafi: return "Shafi'i school representing Maliki and Hanbali prayer timing methods"
        case .jafari: return "Ja'fari school of Islamic jurisprudence followed by Twelver Shia Muslims"
        }
    }

    /// Detailed description of the school
    public var detailedDescription: String {
        switch self {
        case .hanafi:
            return "One of the four major Sunni schools of Islamic jurisprudence, founded by Imam Abu Hanifa, known for its use of reason and opinion in prayer timing calculations."
        case .shafi:
            return "Represents the Shafi'i, Maliki, and Hanbali schools which share similar prayer timing methodologies, emphasizing the Quran and Hadith as primary sources."
        case .jafari:
            return "The primary school of jurisprudence in Twelver Shia Islam, founded by Imam Ja'far as-Sadiq, with distinct prayer timing calculations."
        }
    }

    /// Key distinguishing practices
    public var keyPractices: [String] {
        switch self {
        case .hanafi:
            return [
                "Uses reason (Ra'y) and opinion extensively",
                "Flexibility in interpretation",
                "Emphasizes local customs (Urf)",
                "Practical approach to jurisprudence",
                "Later Asr prayer timing (2x shadow length)"
            ]
        case .shafi:
            return [
                "Emphasizes Quran and Hadith as primary sources",
                "Uses consensus (Ijma) and analogy (Qiyas)",
                "Systematic approach to jurisprudence",
                "Moderate position on many issues",
                "Earlier Asr prayer timing (1x shadow length)"
            ]
        case .jafari:
            return [
                "Follows the Twelve Imams",
                "Emphasizes the authority of the Imam",
                "Distinct prayer timing calculations",
                "Maghrib prayer 4 minutes after sunset",
                "Different twilight angles for Fajr and Isha"
            ]
        }
    }

    // MARK: - iOS UI Properties

    /// SwiftUI color associated with this school
    public var color: Color {
        switch self {
        case .hanafi: return .orange
        case .shafi: return .blue
        case .jafari: return .purple
        }
    }

    /// Secondary color for gradients
    public var secondaryColor: Color {
        switch self {
        case .hanafi: return .yellow
        case .shafi: return .cyan
        case .jafari: return .indigo
        }
    }

    /// Gradient colors for this school
    public var gradientColors: [Color] {
        return [color, secondaryColor]
    }

    /// SF Symbol name representing this school
    public var systemImageName: String {
        switch self {
        case .hanafi: return "building.columns"
        case .shafi: return "graduationcap"
        case .jafari: return "crown"
        }
    }

    /// Alternative SF Symbol for variety
    public var alternativeSystemImageName: String {
        switch self {
        case .hanafi: return "building.2"
        case .shafi: return "person.badge.plus"
        case .jafari: return "star.circle"
        }
    }

    // MARK: - Prayer Differences

    /// Key differences in prayer practices
    public var prayerDifferences: [String] {
        switch self {
        case .hanafi:
            return [
                "Hands folded below navel",
                "Silent recitation in certain prayers",
                "Specific prostration positions",
                "Flexibility in some prayer practices",
                "Asr prayer when shadow = 2x object height"
            ]
        case .shafi:
            return [
                "Hands folded above navel",
                "Specific recitations in prayer",
                "Particular standing positions",
                "Emphasis on following Sunnah precisely",
                "Asr prayer when shadow = 1x object height"
            ]
        case .jafari:
            return [
                "Hands at sides during prayer",
                "Amen said silently after Fatiha",
                "Feet slightly apart during standing",
                "Prostration on clay tablet (Turbah)",
                "Maghrib prayer 4 minutes after sunset"
            ]
        }
    }

    /// Recommended prayer times differences
    public var prayerTimingNotes: String {
        switch self {
        case .hanafi:
            return "Uses specific calculations for Fajr and Isha times, with Asr prayer typically 30-40 minutes later than other schools"
        case .shafi:
            return "Represents Shafi'i, Maliki, and Hanbali timing methods with precise calculations based on Hadith and Quran"
        case .jafari:
            return "Distinct Shia timing calculations with Maghrib 4 minutes after sunset and may combine Dhuhr with Asr, Maghrib with Isha"
        }
    }

    // MARK: - Accessibility

    /// Accessibility label for VoiceOver
    public var accessibilityLabel: String {
        return "\(displayName) Islamic school of jurisprudence"
    }

    /// Accessibility hint for VoiceOver
    public var accessibilityHint: String {
        return description
    }

    // MARK: - Utility Properties

    /// Percentage of global Muslim population (approximate)
    public var globalPercentage: Double {
        switch self {
        case .hanafi: return 45.0 // Largest Sunni school
        case .shafi: return 43.0  // Combined Shafi'i, Maliki, Hanbali
        case .jafari: return 12.0 // Twelver Shia Muslims
        }
    }

    /// Major geographic regions where this school is prevalent
    public var prevalentRegions: [String] {
        switch self {
        case .hanafi:
            return [
                "Turkey", "Central Asia", "Pakistan", "Afghanistan", "India",
                "Bangladesh", "Bosnia", "Albania", "Kosovo", "Parts of Iraq"
            ]
        case .shafi:
            return [
                "Egypt", "Indonesia", "Malaysia", "Brunei", "Philippines",
                "Jordan", "Palestine", "Lebanon", "Eastern Africa", "Saudi Arabia",
                "Morocco", "Algeria", "Tunisia", "Libya", "West Africa"
            ]
        case .jafari:
            return [
                "Iran", "Iraq", "Azerbaijan", "Bahrain", "Lebanon",
                "Yemen (Houthis)", "Parts of Afghanistan", "Parts of Pakistan",
                "Parts of India", "Parts of Syria"
            ]
        }
    }
}

// MARK: - Extensions

// Note: description property is already defined in the main enum

extension Madhab {
    /// Returns an alternative school for comparison
    public var alternative: Madhab {
        switch self {
        case .hanafi: return .shafi
        case .shafi: return .hanafi
        case .jafari: return .shafi
        }
    }

    /// Whether this school uses earlier Asr timing (1x shadow)
    public var usesEarlyAsr: Bool {
        return asrShadowMultiplier == 1.0
    }

    /// Whether this school delays Maghrib after sunset
    public var delaysMaghrib: Bool {
        return maghribDelayMinutes > 0
    }
}
