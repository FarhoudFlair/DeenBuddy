import Foundation

/// Represents structured prayer content with steps and instructions
public struct PrayerContent: Codable {
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

/// Represents an individual step in a prayer guide
public struct PrayerStep: Codable, Identifiable, Hashable {
    public let id = UUID()
    public let step: Int
    public let title: String
    public let description: String
    public let arabic: String?
    public let transliteration: String?
    public let translation: String?
    public let audioUrl: String?
    public let imageUrl: String?
    public let duration: TimeInterval?
    public let isOptional: Bool
    public let category: StepCategory
    
    enum CodingKeys: String, CodingKey {
        case step, title, description, arabic, transliteration, translation
        case audioUrl = "audio_url"
        case imageUrl = "image_url"
        case duration
        case isOptional = "is_optional"
        case category
    }
    
    public init(
        step: Int,
        title: String,
        description: String,
        arabic: String? = nil,
        transliteration: String? = nil,
        translation: String? = nil,
        audioUrl: String? = nil,
        imageUrl: String? = nil,
        duration: TimeInterval? = nil,
        isOptional: Bool = false,
        category: StepCategory = .action
    ) {
        self.step = step
        self.title = title
        self.description = description
        self.arabic = arabic
        self.transliteration = transliteration
        self.translation = translation
        self.audioUrl = audioUrl
        self.imageUrl = imageUrl
        self.duration = duration
        self.isOptional = isOptional
        self.category = category
    }
    
    /// Formatted duration string for display
    public var formattedDuration: String? {
        guard let duration = duration else { return nil }
        
        if duration < 60 {
            return "\(Int(duration))s"
        } else {
            let minutes = Int(duration / 60)
            let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
            return seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
        }
    }
    
    /// Whether this step has Arabic content
    public var hasArabicContent: Bool {
        return arabic != nil && !arabic!.isEmpty
    }
    
    /// Whether this step has audio content
    public var hasAudioContent: Bool {
        return audioUrl != nil && !audioUrl!.isEmpty
    }
    
    /// Whether this step has visual content
    public var hasVisualContent: Bool {
        return imageUrl != nil && !imageUrl!.isEmpty
    }
}

/// Categories for prayer steps to help with organization and UI
public enum StepCategory: String, CaseIterable, Codable {
    case preparation = "preparation"
    case intention = "intention"
    case recitation = "recitation"
    case movement = "movement"
    case dua = "dua"
    case action = "action"
    case completion = "completion"
    
    public var displayName: String {
        switch self {
        case .preparation: return "Preparation"
        case .intention: return "Intention (Niyyah)"
        case .recitation: return "Recitation"
        case .movement: return "Movement"
        case .dua: return "Supplication (Du'a)"
        case .action: return "Action"
        case .completion: return "Completion"
        }
    }
    
    public var arabicName: String {
        switch self {
        case .preparation: return "التحضير"
        case .intention: return "النية"
        case .recitation: return "التلاوة"
        case .movement: return "الحركة"
        case .dua: return "الدعاء"
        case .action: return "العمل"
        case .completion: return "الإتمام"
        }
    }
    
    public var systemImageName: String {
        switch self {
        case .preparation: return "hands.sparkles"
        case .intention: return "heart"
        case .recitation: return "text.quote"
        case .movement: return "figure.walk"
        case .dua: return "hands.and.sparkles"
        case .action: return "hand.raised"
        case .completion: return "checkmark.circle"
        }
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

extension Array where Element == PrayerStep {
    /// Returns steps for a specific category
    public func steps(for category: StepCategory) -> [PrayerStep] {
        return filter { $0.category == category }
    }
    
    /// Returns the next step after the given step
    public func nextStep(after step: PrayerStep) -> PrayerStep? {
        guard let index = firstIndex(where: { $0.id == step.id }),
              index + 1 < count else {
            return nil
        }
        return self[index + 1]
    }
    
    /// Returns the previous step before the given step
    public func previousStep(before step: PrayerStep) -> PrayerStep? {
        guard let index = firstIndex(where: { $0.id == step.id }),
              index > 0 else {
            return nil
        }
        return self[index - 1]
    }
}
