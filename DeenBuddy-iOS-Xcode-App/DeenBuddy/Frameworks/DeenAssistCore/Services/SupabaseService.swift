import Foundation
import Combine
import Network
import UIKit

/// Service for managing Supabase backend integration
@MainActor
public class SupabaseService: ObservableObject {

    // MARK: - Published Properties

    @Published public var prayerGuides: [PrayerGuide] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var isOffline = false
    @Published public var syncProgress: Double = 0.0

    // MARK: - Private Properties

    private let configurationManager = ConfigurationManager.shared
    private let networkMonitor = NetworkMonitor.shared
    private let offlineService = OfflineService()
    private var cancellables = Set<AnyCancellable>()

    private var supabaseUrl: String {
        return configurationManager.getSupabaseConfiguration()?.url ?? ""
    }

    private var anonKey: String {
        return configurationManager.getSupabaseConfiguration()?.anonKey ?? ""
    }

    // MARK: - Initialization

    public init() {
        setupNetworkMonitoring()
        setupBackgroundSync()
    }

    // MARK: - Public Methods
    
    /// Check if Supabase service is properly configured
    public var isConfigured: Bool {
        guard let supabaseConfig = configurationManager.getSupabaseConfiguration() else {
            return false
        }
        return !supabaseConfig.url.isEmpty && !supabaseConfig.anonKey.isEmpty
    }

    /// Fetch prayer guides from Supabase with offline support
    public func fetchPrayerGuides(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil

        // Check configuration first
        guard isConfigured else {
            await MainActor.run {
                self.errorMessage = "Supabase configuration is missing or invalid"
                self.isLoading = false
            }
            
            // Try to load from cache if available
            if let cachedGuides = await offlineService.getCachedGuides() {
                self.prayerGuides = cachedGuides
                self.isOffline = true
            }
            return
        }

        // Try offline first if not forcing refresh
        if !forceRefresh, let cachedGuides = await offlineService.getCachedGuides() {
            self.prayerGuides = cachedGuides
            self.isLoading = false

            // Fetch updates in background
            Task {
                await fetchFromSupabase()
            }
            return
        }

        await fetchFromSupabase()
    }

    /// Fetch prayer guides from Supabase REST API
    private func fetchFromSupabase() async {
        // Validate Supabase configuration first
        guard let supabaseConfig = configurationManager.getSupabaseConfiguration(),
              !supabaseConfig.url.isEmpty,
              !supabaseConfig.anonKey.isEmpty else {
            await MainActor.run {
                self.errorMessage = "Supabase configuration is missing or invalid"
                self.isLoading = false
            }
            return
        }
        
        guard let url = URL(string: "\(supabaseConfig.url)/rest/v1/prayer_guides") else {
            await MainActor.run {
                self.errorMessage = "Invalid URL"
                self.isLoading = false
            }
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(supabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add query parameters for the data we need
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "select", value: "id,content_id,title,prayer_name,sect,rakah_count,text_content,video_url,thumbnail_url,is_available_offline,version,created_at,updated_at"),
            URLQueryItem(name: "order", value: "prayer_name,sect")
        ]

        guard let finalUrl = components?.url else {
            await MainActor.run {
                self.errorMessage = "Failed to build URL"
                self.isLoading = false
            }
            return
        }

        request.url = finalUrl

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run {
                    self.errorMessage = "Invalid response"
                    self.isLoading = false
                }
                return
            }

            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                let guides = try decoder.decode([SupabasePrayerGuide].self, from: data)
                let convertedGuides = guides.map { $0.toPrayerGuide() }

                await MainActor.run {
                    self.prayerGuides = convertedGuides
                    self.isLoading = false
                }

                // Cache for offline use
                await offlineService.cacheGuides(convertedGuides)

            } else {
                await MainActor.run {
                    self.errorMessage = "Server error: \(httpResponse.statusCode)"
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Network error: \(error.localizedDescription)"
                self.isLoading = false

                // Try to load from cache on error
                Task {
                    if let cachedGuides = await self.offlineService.getCachedGuides() {
                        self.prayerGuides = cachedGuides
                        self.isOffline = true
                    }
                }
            }
        }
    }

    // MARK: - iOS-specific methods

    private func setupNetworkMonitoring() {
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.isOffline = !isConnected
                if isConnected && self?.isConfigured == true {
                    Task {
                        await self?.syncIfNeeded()
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func setupBackgroundSync() {
        // iOS background app refresh handling
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self = self, self.isConfigured else { return }
                Task {
                    await self.syncIfNeeded()
                }
            }
            .store(in: &cancellables)
    }

    private func syncIfNeeded() async {
        guard !isOffline else { return }
        guard isConfigured else { return }

        let lastSync = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
        let shouldSync = lastSync == nil || Date().timeIntervalSince(lastSync!) > 3600 // 1 hour

        if shouldSync {
            await fetchPrayerGuides(forceRefresh: true)
            UserDefaults.standard.set(Date(), forKey: "lastSyncDate")
        }
    }
}

// MARK: - iOS-specific extensions
extension SupabaseService {
    public func getPrayerGuides(for madhab: Madhab) -> [PrayerGuide] {
        return prayerGuides.filter { $0.madhab == madhab }
    }

    public func getPrayerGuide(for prayer: Prayer, madhab: Madhab) -> PrayerGuide? {
        return prayerGuides.first {
            $0.prayer == prayer && $0.madhab == madhab
        }
    }

    public func refreshData() async {
        await fetchPrayerGuides(forceRefresh: true)
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

        // Convert text content to steps
        let steps = textContent?.steps.enumerated().map { index, step in
            PrayerStep(
                id: "\(contentId)_step_\(index + 1)",
                title: step.title,
                description: step.description,
                stepNumber: index + 1,
                arabic: step.arabic,
                transliteration: step.transliteration,
                translation: nil,
                audioUrl: nil,
                imageUrl: nil,
                videoUrl: videoUrl,
                duration: 60, // Default duration
                isOptional: false,
                category: .action,
                difficulty: .beginner,
                tags: []
            )
        } ?? []

        return PrayerGuide(
            id: contentId,
            contentId: contentId,
            title: title,
            prayerName: prayerName,
            sect: sect,
            rakahCount: rakahCount,
            contentType: "guide",
            textContent: textContent.map { content in 
                PrayerContent(
                    steps: steps,
                    rakahInstructions: content.rakahInstructions
                )
            },
            videoUrl: videoUrl,
            thumbnailUrl: thumbnailUrl,
            isAvailableOffline: isAvailableOffline,
            version: version,
            difficulty: .beginner, // Default difficulty
            duration: TimeInterval(steps.count * 60), // Estimate based on steps
            description: "Complete guide for \(title)",
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




