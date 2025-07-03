import Foundation
import Supabase
import Combine

/// Service for managing Supabase backend integration
@MainActor
public class SupabaseService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isConnected = false
    @Published public var isLoading = false
    @Published public var error: Error?
    
    // MARK: - Private Properties
    
    private var supabase: SupabaseClient?
    private let configuration: SupabaseConfiguration
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(configuration: SupabaseConfiguration) {
        self.configuration = configuration
        setupSupabaseClient()
    }
    
    // MARK: - Public Methods
    
    /// Initialize Supabase client and test connection
    public func initialize() async {
        isLoading = true
        error = nil
        
        do {
            // Test connection with a simple query
            try await testConnection()
            isConnected = true
            print("Supabase connection established successfully")
        } catch {
            self.error = error
            isConnected = false
            print("Failed to connect to Supabase: \(error)")
        }
        
        isLoading = false
    }
    
    /// Sync prayer guides from Supabase
    public func syncPrayerGuides() async throws -> [PrayerGuide] {
        guard let supabase = supabase else {
            throw SupabaseError.clientNotInitialized
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Query prayer guides from Supabase
            let response: [SupabasePrayerGuide] = try await supabase
                .from("prayer_guides")
                .select()
                .execute()
                .value
            
            // Convert to local models
            let guides = response.map { $0.toPrayerGuide() }
            
            print("Synced \(guides.count) prayer guides from Supabase")
            return guides
            
        } catch {
            self.error = error
            throw error
        }
    }
    
    /// Upload user progress to Supabase
    public func uploadProgress(for guide: PrayerGuide, userId: String) async throws {
        guard let supabase = supabase else {
            throw SupabaseError.clientNotInitialized
        }
        
        let progressData = SupabaseUserProgress(
            userId: userId,
            guideId: guide.id,
            isCompleted: guide.isCompleted,
            completedAt: guide.isCompleted ? Date() : nil,
            progress: calculateProgress(for: guide)
        )
        
        try await supabase
            .from("user_progress")
            .upsert(progressData)
            .execute()
        
        print("Uploaded progress for guide: \(guide.id)")
    }
    
    /// Download user progress from Supabase
    public func downloadProgress(for userId: String) async throws -> [SupabaseUserProgress] {
        guard let supabase = supabase else {
            throw SupabaseError.clientNotInitialized
        }
        
        let response: [SupabaseUserProgress] = try await supabase
            .from("user_progress")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        print("Downloaded progress for \(response.count) guides")
        return response
    }
    
    /// Check for content updates
    public func checkForUpdates(lastSyncDate: Date) async throws -> Bool {
        guard let supabase = supabase else {
            throw SupabaseError.clientNotInitialized
        }
        
        let formatter = ISO8601DateFormatter()
        let lastSyncString = formatter.string(from: lastSyncDate)
        
        let response: [SupabasePrayerGuide] = try await supabase
            .from("prayer_guides")
            .select("id, updated_at")
            .gt("updated_at", value: lastSyncString)
            .execute()
            .value
        
        return !response.isEmpty
    }
    
    // MARK: - Private Methods
    
    private func setupSupabaseClient() {
        guard !configuration.url.isEmpty && !configuration.anonKey.isEmpty else {
            print("Supabase configuration is incomplete")
            return
        }
        
        supabase = SupabaseClient(
            supabaseURL: URL(string: configuration.url)!,
            supabaseKey: configuration.anonKey
        )
    }
    
    private func testConnection() async throws {
        guard let supabase = supabase else {
            throw SupabaseError.clientNotInitialized
        }
        
        // Simple query to test connection
        let _: [SupabasePrayerGuide] = try await supabase
            .from("prayer_guides")
            .select("id")
            .limit(1)
            .execute()
            .value
    }
    
    private func calculateProgress(for guide: PrayerGuide) -> Double {
        let completedSteps = guide.steps.filter { $0.isCompleted }.count
        return Double(completedSteps) / Double(guide.steps.count)
    }
}

// MARK: - Configuration

public struct SupabaseConfiguration {
    public let url: String
    public let anonKey: String
    public let serviceKey: String?
    
    public init(url: String, anonKey: String, serviceKey: String? = nil) {
        self.url = url
        self.anonKey = anonKey
        self.serviceKey = serviceKey
    }
    
    /// Default configuration for development
    public static let development = SupabaseConfiguration(
        url: "https://hjgwbkcjjclwqamtmhsa.supabase.co",
        anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhqZ3dia2NqamNsd3FhbXRtaHNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1NzQwOTYsImV4cCI6MjA2NzE1MDA5Nn0.pipfeKNNDclXlfOimWQnhkf_VY-YTsV3_vZaoEbWSGM"
    )
    
    /// Load configuration from environment or plist
    public static func fromEnvironment() -> SupabaseConfiguration {
        let url = ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? ""
        let anonKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
        let serviceKey = ProcessInfo.processInfo.environment["SUPABASE_SERVICE_KEY"]
        
        return SupabaseConfiguration(
            url: url,
            anonKey: anonKey,
            serviceKey: serviceKey
        )
    }
}

// MARK: - Supabase Models

public struct SupabasePrayerGuide: Codable {
    public let id: String
    public let contentId: String
    public let title: String
    public let prayerName: String
    public let sect: String
    public let rakahCount: Int
    public let contentType: String
    public let textContent: SupabaseTextContent?
    public let videoUrl: String?
    public let thumbnailUrl: String?
    public let isAvailableOffline: Bool
    public let version: Int
    public let createdAt: String
    public let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case contentId = "content_id"
        case title
        case prayerName = "prayer_name"
        case sect
        case rakahCount = "rakah_count"
        case contentType = "content_type"
        case textContent = "text_content"
        case videoUrl = "video_url"
        case thumbnailUrl = "thumbnail_url"
        case isAvailableOffline = "is_available_offline"
        case version
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public func toPrayerGuide() -> PrayerGuide {
        let formatter = ISO8601DateFormatter()

        // Convert sect to madhab (simplified mapping)
        let madhab: Madhab = sect.lowercased() == "shia" ? .hanafi : .shafi

        // Convert text content to steps
        let steps = textContent?.steps.enumerated().map { index, step in
            PrayerStep(
                id: "\(contentId)_step_\(index + 1)",
                title: step.title,
                description: step.description,
                duration: 60, // Default duration
                videoURL: videoUrl,
                audioURL: nil
            )
        } ?? []

        return PrayerGuide(
            id: contentId,
            title: title,
            prayer: Prayer(rawValue: prayerName) ?? .fajr,
            madhab: madhab,
            difficulty: .beginner, // Default difficulty
            duration: TimeInterval(steps.count * 60), // Estimate based on steps
            description: "Complete guide for \(title)",
            steps: steps,
            isAvailableOffline: isAvailableOffline,
            createdAt: formatter.date(from: createdAt) ?? Date(),
            updatedAt: formatter.date(from: updatedAt) ?? Date()
        )
    }
}

// MARK: - Text Content Models

public struct SupabaseTextContent: Codable {
    public let steps: [SupabaseStep]
    public let rakahInstructions: [String]?

    enum CodingKeys: String, CodingKey {
        case steps
        case rakahInstructions = "rakah_instructions"
    }
}

public struct SupabaseStep: Codable {
    public let step: Int
    public let title: String
    public let description: String
    public let arabic: String?
    public let transliteration: String?

    enum CodingKeys: String, CodingKey {
        case step
        case title
        case description
        case arabic
        case transliteration
    }
}

public struct SupabasePrayerStep: Codable {
    public let id: String
    public let title: String
    public let description: String
    public let duration: Int
    public let videoURL: String?
    public let audioURL: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case duration
        case videoURL = "video_url"
        case audioURL = "audio_url"
    }
    
    public func toPrayerStep() -> PrayerStep {
        return PrayerStep(
            id: id,
            title: title,
            description: description,
            duration: TimeInterval(duration),
            videoURL: videoURL,
            audioURL: audioURL
        )
    }
}

public struct SupabaseUserProgress: Codable {
    public let userId: String
    public let guideId: String
    public let isCompleted: Bool
    public let completedAt: Date?
    public let progress: Double
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case guideId = "guide_id"
        case isCompleted = "is_completed"
        case completedAt = "completed_at"
        case progress
    }
}

// MARK: - Error Types

public enum SupabaseError: LocalizedError {
    case clientNotInitialized
    case configurationMissing
    case connectionFailed
    case syncFailed(Error)
    case uploadFailed(Error)
    case downloadFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .clientNotInitialized:
            return "Supabase client is not initialized"
        case .configurationMissing:
            return "Supabase configuration is missing"
        case .connectionFailed:
            return "Failed to connect to Supabase"
        case .syncFailed(let error):
            return "Failed to sync data: \(error.localizedDescription)"
        case .uploadFailed(let error):
            return "Failed to upload data: \(error.localizedDescription)"
        case .downloadFailed(let error):
            return "Failed to download data: \(error.localizedDescription)"
        }
    }
}
