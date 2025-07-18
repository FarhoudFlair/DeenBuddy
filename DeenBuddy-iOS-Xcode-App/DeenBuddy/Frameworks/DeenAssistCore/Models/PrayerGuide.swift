import Foundation
import SwiftUI

/// Main prayer guide model that matches the Supabase database schema exactly
public struct PrayerGuide: Codable, Identifiable, Hashable {
    public let id: String
    public let contentId: String
    public let title: String
    public let prayerName: String
    public let sect: String
    public let rakahCount: Int
    public let contentType: String
    public let textContent: PrayerContent?
    public let videoUrl: String?
    public let thumbnailUrl: String?
    public let isAvailableOffline: Bool
    public let version: Int
    public let difficulty: Difficulty
    public let duration: TimeInterval
    public let description: String
    public let createdAt: Date
    public let updatedAt: Date
    
    // iOS-specific properties (not stored in database)
    public var isBookmarked: Bool = false
    public var lastReadDate: Date?
    public var readingProgress: Double = 0.0
    public var isDownloaded: Bool = false
    public var downloadProgress: Double = 0.0
    
    enum CodingKeys: String, CodingKey {
        case id, title, version, difficulty, duration, description
        case contentId = "content_id"
        case prayerName = "prayer_name"
        case sect
        case rakahCount = "rakah_count"
        case contentType = "content_type"
        case textContent = "text_content"
        case videoUrl = "video_url"
        case thumbnailUrl = "thumbnail_url"
        case isAvailableOffline = "is_available_offline"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public init(
        id: String,
        contentId: String,
        title: String,
        prayerName: String,
        sect: String,
        rakahCount: Int,
        contentType: String = "guide",
        textContent: PrayerContent? = nil,
        videoUrl: String? = nil,
        thumbnailUrl: String? = nil,
        isAvailableOffline: Bool = false,
        version: Int = 1,
        difficulty: Difficulty = .beginner,
        duration: TimeInterval = 300,
        description: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isBookmarked: Bool = false,
        lastReadDate: Date? = nil,
        readingProgress: Double = 0.0,
        isDownloaded: Bool = false,
        downloadProgress: Double = 0.0
    ) {
        self.id = id
        self.contentId = contentId
        self.title = title
        self.prayerName = prayerName
        self.sect = sect
        self.rakahCount = rakahCount
        self.contentType = contentType
        self.textContent = textContent
        self.videoUrl = videoUrl
        self.thumbnailUrl = thumbnailUrl
        self.isAvailableOffline = isAvailableOffline
        self.version = version
        self.difficulty = difficulty
        self.duration = duration
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isBookmarked = isBookmarked
        self.lastReadDate = lastReadDate
        self.readingProgress = readingProgress
        self.isDownloaded = isDownloaded
        self.downloadProgress = downloadProgress
    }
    
    // MARK: - Computed Properties
    
    /// Converts prayer name string to Prayer enum
    public var prayer: Prayer {
        Prayer(rawValue: prayerName) ?? .fajr
    }
    
    /// Converts sect string to Madhab enum
    public var madhab: Madhab {
        Madhab(rawValue: sect) ?? .shafi
    }
    
    /// Display name for the sect/tradition
    public var sectDisplayName: String {
        return madhab.sectDisplayName
    }
    
    /// Display title combining prayer and tradition
    public var displayTitle: String {
        "\(prayer.displayName) (\(madhab.displayName))"
    }
    
    /// Short title for compact displays
    public var shortTitle: String {
        "\(prayer.displayName) - \(madhab.displayName)"
    }
    
    /// Rakah count as formatted text
    public var rakahText: String {
        "\(rakahCount) Rakah"
    }
    
    /// Estimated reading time based on content
    public var estimatedReadingTime: String {
        guard let content = textContent else { return "5 min" }
        let stepCount = content.steps.count
        let estimatedMinutes = max(1, stepCount * 2) // 2 minutes per step minimum
        return "\(estimatedMinutes) min"
    }

    /// Formatted duration string for display (compatibility with old ContentService)
    public var formattedDuration: String {
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }
    
    /// Progress as percentage string
    public var progressText: String {
        let percentage = Int(readingProgress * 100)
        return "\(percentage)%"
    }
    
    
    // MARK: - iOS UI Properties
    
    /// Primary color based on prayer type
    public var primaryColor: Color {
        return prayer.color
    }
    
    /// Secondary color based on tradition
    public var secondaryColor: Color {
        return madhab.color
    }
    
    /// Gradient colors combining prayer and tradition
    public var gradientColors: [Color] {
        return [primaryColor, secondaryColor]
    }
    
    /// SF Symbol for the prayer
    public var systemImageName: String {
        return prayer.systemImageName
    }
    
    /// SF Symbol for the tradition
    public var traditionImageName: String {
        return madhab.systemImageName
    }
    
    // MARK: - Content Properties
    
    /// Whether this guide has video content
    public var hasVideo: Bool {
        return videoUrl != nil && !videoUrl!.isEmpty
    }
    
    /// Whether this guide has thumbnail
    public var hasThumbnail: Bool {
        return thumbnailUrl != nil && !thumbnailUrl!.isEmpty
    }
    
    /// Whether this guide has structured text content
    public var hasTextContent: Bool {
        return textContent != nil && !textContent!.steps.isEmpty
    }
    
    /// Whether this guide has Arabic content
    public var hasArabicContent: Bool {
        return textContent?.arabicStepsCount ?? 0 > 0
    }
    
    /// Whether this guide has audio content
    public var hasAudioContent: Bool {
        return textContent?.hasAudioContent ?? false
    }
    
    /// Total number of steps in the guide
    public var stepCount: Int {
        return textContent?.steps.count ?? 0
    }
    
    /// Number of completed steps based on reading progress
    public var completedSteps: Int {
        return Int(Double(stepCount) * readingProgress)
    }
    
    // MARK: - Status Properties
    
    /// Whether the guide is fully read
    public var isCompleted: Bool {
        return readingProgress >= 1.0
    }
    
    /// Whether the guide is partially read
    public var isInProgress: Bool {
        return readingProgress > 0.0 && readingProgress < 1.0
    }
    
    /// Whether the guide is unread
    public var isUnread: Bool {
        return readingProgress == 0.0
    }
    
    /// Status text for display
    public var statusText: String {
        if isCompleted {
            return "Completed"
        } else if isInProgress {
            return "In Progress"
        } else {
            return "Not Started"
        }
    }
    
    /// Status color for UI
    public var statusColor: Color {
        if isCompleted {
            return .green
        } else if isInProgress {
            return .orange
        } else {
            return .gray
        }
    }
    
    // MARK: - Accessibility
    
    /// Accessibility label for VoiceOver
    public var accessibilityLabel: String {
        return "\(displayTitle), \(rakahText), \(statusText)"
    }
    
    /// Accessibility hint for VoiceOver
    public var accessibilityHint: String {
        var hint = "Prayer guide for \(prayer.timingDescription)"
        if isBookmarked {
            hint += ", bookmarked"
        }
        if isAvailableOffline {
            hint += ", available offline"
        }
        return hint
    }
}

// MARK: - Extensions

extension PrayerGuide {
    /// Updates reading progress
    public mutating func updateProgress(_ progress: Double) {
        readingProgress = max(0.0, min(1.0, progress))
        lastReadDate = Date()
    }
    
    /// Marks as bookmarked
    public mutating func bookmark() {
        isBookmarked = true
    }
    
    /// Removes bookmark
    public mutating func removeBookmark() {
        isBookmarked = false
    }
    
    /// Toggles bookmark status
    public mutating func toggleBookmark() {
        isBookmarked.toggle()
    }
    
    /// Marks as downloaded
    public mutating func markAsDownloaded() {
        isDownloaded = true
        downloadProgress = 1.0
    }
    
    /// Updates download progress
    public mutating func updateDownloadProgress(_ progress: Double) {
        downloadProgress = max(0.0, min(1.0, progress))
        if downloadProgress >= 1.0 {
            isDownloaded = true
        }
    }
}

extension PrayerGuide: Comparable {
    public static func < (lhs: PrayerGuide, rhs: PrayerGuide) -> Bool {
        // Sort by prayer order first, then by tradition
        if lhs.prayer != rhs.prayer {
            return lhs.prayer < rhs.prayer
        }
        return lhs.madhab.rawValue < rhs.madhab.rawValue
    }
}
