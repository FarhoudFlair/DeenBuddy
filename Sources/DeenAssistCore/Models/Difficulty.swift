import Foundation
import SwiftUI

/// Represents the difficulty level of a prayer guide or step
public enum Difficulty: String, CaseIterable, Codable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    
    // MARK: - Display Properties
    
    /// Localized display name for the difficulty
    public var displayName: String {
        return rawValue.capitalized
    }
    
    /// Brief description of the difficulty level
    public var description: String {
        switch self {
        case .beginner:
            return "Perfect for those new to Islamic prayer"
        case .intermediate:
            return "For those with some prayer experience"
        case .advanced:
            return "For experienced practitioners seeking deeper understanding"
        }
    }
    
    // MARK: - iOS UI Properties
    
    /// SwiftUI color associated with this difficulty
    public var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
    
    /// SF Symbol name for this difficulty
    public var systemImageName: String {
        switch self {
        case .beginner: return "1.circle.fill"
        case .intermediate: return "2.circle.fill"
        case .advanced: return "3.circle.fill"
        }
    }
    
    /// Alternative SF Symbol for variety
    public var alternativeSystemImageName: String {
        switch self {
        case .beginner: return "leaf.fill"
        case .intermediate: return "flame.fill"
        case .advanced: return "star.fill"
        }
    }
    
    // MARK: - Utility Properties
    
    /// Estimated time multiplier for this difficulty
    public var timeMultiplier: Double {
        switch self {
        case .beginner: return 1.5  // Takes longer for beginners
        case .intermediate: return 1.0  // Standard time
        case .advanced: return 0.8  // Faster for advanced users
        }
    }
    
    /// Recommended prerequisites for this difficulty
    public var prerequisites: [String] {
        switch self {
        case .beginner:
            return [
                "Basic understanding of Islamic prayer",
                "Willingness to learn step by step"
            ]
        case .intermediate:
            return [
                "Familiarity with basic prayer movements",
                "Knowledge of essential Arabic phrases",
                "Completed beginner-level guides"
            ]
        case .advanced:
            return [
                "Proficient in all prayer movements",
                "Strong Arabic recitation skills",
                "Deep understanding of prayer meanings",
                "Completed intermediate-level guides"
            ]
        }
    }
    
    // MARK: - Accessibility
    
    /// Accessibility label for VoiceOver
    public var accessibilityLabel: String {
        return "\(displayName) difficulty level"
    }
    
    /// Accessibility hint for VoiceOver
    public var accessibilityHint: String {
        return description
    }
}

// MARK: - Extensions

extension Difficulty: Comparable {
    public static func < (lhs: Difficulty, rhs: Difficulty) -> Bool {
        let order: [Difficulty] = [.beginner, .intermediate, .advanced]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

// Note: description property is already defined in the main enum
