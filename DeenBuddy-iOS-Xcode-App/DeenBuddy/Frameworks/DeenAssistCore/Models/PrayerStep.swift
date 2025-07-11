import Foundation
import SwiftUI

/// Represents an individual step in a prayer guide with iOS-specific features
public struct PrayerStep: Codable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let description: String
    public let stepNumber: Int
    public let arabic: String?
    public let transliteration: String?
    public let translation: String?
    public let audioUrl: String?
    public let imageUrl: String?
    public let videoUrl: String?
    public let duration: TimeInterval?
    public let isOptional: Bool
    public let category: StepCategory
    public let difficulty: StepDifficulty
    public let tags: [String]
    
    // iOS-specific properties
    public var isCompleted: Bool = false
    public var isFavorite: Bool = false
    public var personalNotes: String = ""
    public var lastViewedAt: Date?
    public var viewCount: Int = 0
    
    enum CodingKeys: String, CodingKey {
        case id, title, description
        case stepNumber = "step_number"
        case arabic, transliteration, translation
        case audioUrl = "audio_url"
        case imageUrl = "image_url"
        case videoUrl = "video_url"
        case duration
        case isOptional = "is_optional"
        case category, difficulty, tags
    }
    
    public init(
        id: String,
        title: String,
        description: String,
        stepNumber: Int,
        arabic: String? = nil,
        transliteration: String? = nil,
        translation: String? = nil,
        audioUrl: String? = nil,
        imageUrl: String? = nil,
        videoUrl: String? = nil,
        duration: TimeInterval? = nil,
        isOptional: Bool = false,
        category: StepCategory = .action,
        difficulty: StepDifficulty = .beginner,
        tags: [String] = [],
        isCompleted: Bool = false,
        isFavorite: Bool = false,
        personalNotes: String = "",
        lastViewedAt: Date? = nil,
        viewCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.stepNumber = stepNumber
        self.arabic = arabic
        self.transliteration = transliteration
        self.translation = translation
        self.audioUrl = audioUrl
        self.imageUrl = imageUrl
        self.videoUrl = videoUrl
        self.duration = duration
        self.isOptional = isOptional
        self.category = category
        self.difficulty = difficulty
        self.tags = tags
        self.isCompleted = isCompleted
        self.isFavorite = isFavorite
        self.personalNotes = personalNotes
        self.lastViewedAt = lastViewedAt
        self.viewCount = viewCount
    }
    
    // MARK: - Display Properties
    
    /// Formatted step number for display
    public var displayStepNumber: String {
        return "Step \(stepNumber)"
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
    
    /// Short description for compact displays
    public var shortDescription: String {
        if description.count <= 50 {
            return description
        }
        return String(description.prefix(47)) + "..."
    }
    
    // MARK: - Content Properties
    
    /// Whether this step has Arabic content
    public var hasArabicContent: Bool {
        return arabic != nil && !arabic!.isEmpty
    }
    
    /// Whether this step has transliteration
    public var hasTransliteration: Bool {
        return transliteration != nil && !transliteration!.isEmpty
    }
    
    /// Whether this step has translation
    public var hasTranslation: Bool {
        return translation != nil && !translation!.isEmpty
    }
    
    /// Whether this step has audio content
    public var hasAudioContent: Bool {
        return audioUrl != nil && !audioUrl!.isEmpty
    }
    
    /// Whether this step has visual content
    public var hasVisualContent: Bool {
        return imageUrl != nil && !imageUrl!.isEmpty
    }
    
    /// Whether this step has video content
    public var hasVideoContent: Bool {
        return videoUrl != nil && !videoUrl!.isEmpty
    }
    
    /// Whether this step has any multimedia content
    public var hasMultimediaContent: Bool {
        return hasAudioContent || hasVisualContent || hasVideoContent
    }
    
    /// Whether this step has personal notes
    public var hasPersonalNotes: Bool {
        return !personalNotes.isEmpty
    }
    
    // MARK: - iOS UI Properties
    
    /// Primary color based on category
    public var primaryColor: Color {
        return category.color
    }
    
    /// SF Symbol for this step's category
    public var systemImageName: String {
        return category.systemImageName
    }
    
    /// Difficulty color
    public var difficultyColor: Color {
        return difficulty.color
    }
    
    /// Completion status color
    public var statusColor: Color {
        return isCompleted ? .green : .gray
    }
    
    /// Background color for the step card
    public var backgroundColor: Color {
        if isCompleted {
            return .green.opacity(0.1)
        } else if isFavorite {
            return .yellow.opacity(0.1)
        } else {
            return .clear
        }
    }
    
    // MARK: - Accessibility
    
    /// Accessibility label for VoiceOver
    public var accessibilityLabel: String {
        var label = "\(displayStepNumber): \(title)"
        if isOptional {
            label += ", optional"
        }
        if isCompleted {
            label += ", completed"
        }
        if isFavorite {
            label += ", favorite"
        }
        return label
    }
    
    /// Accessibility hint for VoiceOver
    public var accessibilityHint: String {
        var hint = description
        if let duration = formattedDuration {
            hint += ", estimated duration: \(duration)"
        }
        return hint
    }
    
    // MARK: - Mutating Methods
    
    /// Marks the step as completed
    public mutating func markCompleted() {
        isCompleted = true
        recordView()
    }
    
    /// Marks the step as incomplete
    public mutating func markIncomplete() {
        isCompleted = false
    }
    
    /// Toggles completion status
    public mutating func toggleCompletion() {
        isCompleted.toggle()
        if isCompleted {
            recordView()
        }
    }
    
    /// Toggles favorite status
    public mutating func toggleFavorite() {
        isFavorite.toggle()
    }
    
    /// Updates personal notes
    public mutating func updateNotes(_ notes: String) {
        personalNotes = notes
    }
    
    /// Records a view of this step
    public mutating func recordView() {
        lastViewedAt = Date()
        viewCount += 1
    }
}

// MARK: - Step Category

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
    
    public var color: Color {
        switch self {
        case .preparation: return .blue
        case .intention: return .purple
        case .recitation: return .green
        case .movement: return .orange
        case .dua: return .pink
        case .action: return .red
        case .completion: return .mint
        }
    }
}

// MARK: - Step Difficulty

public enum StepDifficulty: String, CaseIterable, Codable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    
    public var displayName: String {
        return rawValue.capitalized
    }
    
    public var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
    
    public var systemImageName: String {
        switch self {
        case .beginner: return "1.circle"
        case .intermediate: return "2.circle"
        case .advanced: return "3.circle"
        }
    }
}

// MARK: - Extensions

extension PrayerStep: Comparable {
    public static func < (lhs: PrayerStep, rhs: PrayerStep) -> Bool {
        return lhs.stepNumber < rhs.stepNumber
    }
}

extension Array where Element == PrayerStep {
    /// Returns steps for a specific category
    public func steps(for category: StepCategory) -> [PrayerStep] {
        return filter { $0.category == category }
    }
    
    /// Returns completed steps
    public var completedSteps: [PrayerStep] {
        return filter { $0.isCompleted }
    }
    
    /// Returns favorite steps
    public var favoriteSteps: [PrayerStep] {
        return filter { $0.isFavorite }
    }
    
    /// Returns optional steps
    public var optionalSteps: [PrayerStep] {
        return filter { $0.isOptional }
    }
    
    /// Returns required steps
    public var requiredSteps: [PrayerStep] {
        return filter { !$0.isOptional }
    }
    
    /// Completion percentage
    public var completionPercentage: Double {
        guard !isEmpty else { return 0.0 }
        let completed = completedSteps.count
        return Double(completed) / Double(count)
    }
}
