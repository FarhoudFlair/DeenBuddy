import Foundation

/// Represents structured prayer content with steps and instructions
public struct PrayerContent: Codable, Hashable {
    public let steps: [PrayerStep]
    public let rakahInstructions: [String]?
    public let importantNotes: [String]?
    public let prerequisites: [String]?
    public let commonMistakes: [String]?
    
    enum CodingKeys: String, CodingKey {
        case steps
        case rakahInstructions = "rakah_instructions"
        case importantNotes = "important_notes"
        case prerequisites
        case commonMistakes = "common_mistakes"
    }
    
    public init(
        steps: [PrayerStep],
        rakahInstructions: [String]? = nil,
        importantNotes: [String]? = nil,
        prerequisites: [String]? = nil,
        commonMistakes: [String]? = nil
    ) {
        self.steps = steps
        self.rakahInstructions = rakahInstructions
        self.importantNotes = importantNotes
        self.prerequisites = prerequisites
        self.commonMistakes = commonMistakes
    }
}



// MARK: - Extensions

extension PrayerContent {
    /// Total estimated duration for all steps
    public var totalDuration: TimeInterval {
        return steps.compactMap { $0.duration }.reduce(0, +)
    }
    
    /// Number of steps with Arabic content
    public var arabicStepsCount: Int {
        return steps.filter { $0.hasArabicContent }.count
    }
    
    /// Number of optional steps
    public var optionalStepsCount: Int {
        return steps.filter { $0.isOptional }.count
    }
    
    /// Steps grouped by category
    public var stepsByCategory: [StepCategory: [PrayerStep]] {
        return Dictionary(grouping: steps) { $0.category }
    }
    
    /// Whether this content has any audio components
    public var hasAudioContent: Bool {
        return steps.contains { $0.hasAudioContent }
    }
    
    /// Whether this content has any visual components
    public var hasVisualContent: Bool {
        return steps.contains { $0.hasVisualContent }
    }
}

