import Foundation
import Combine

/// Service for managing prayer guide content
@MainActor
public class ContentService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isLoading = false
    @Published public var error: Error?
    @Published public var availableGuides: [PrayerGuide] = []
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Cache Keys
    
    private enum CacheKeys {
        static let guidesCache = "DeenAssist.PrayerGuides"
        static let lastSyncDate = "DeenAssist.GuidesLastSync"
    }
    
    // MARK: - Initialization
    
    public init() {
        loadCachedGuides()
        setupMockContent()
    }
    
    // MARK: - Public Methods
    
    /// Get prayer guides for a specific prayer and madhab
    public func getGuides(for prayer: Prayer, madhab: Madhab = .shafi) -> [PrayerGuide] {
        return availableGuides.filter { guide in
            guide.prayer == prayer && guide.madhab == madhab
        }
    }
    
    /// Get all guides for a specific madhab
    public func getAllGuides(for madhab: Madhab = .shafi) -> [PrayerGuide] {
        return availableGuides.filter { $0.madhab == madhab }
    }
    
    /// Refresh content from remote source
    public func refreshContent() async {
        isLoading = true
        error = nil
        
        do {
            // In a real implementation, this would fetch from Supabase
            // For now, we'll simulate with a delay and use mock data
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Update last sync date
            userDefaults.set(Date(), forKey: CacheKeys.lastSyncDate)
            
            print("Content refreshed successfully")
            
        } catch {
            self.error = error
            print("Failed to refresh content: \(error)")
        }
        
        isLoading = false
    }
    
    /// Check if content needs updating
    public var needsUpdate: Bool {
        guard let lastSync = userDefaults.object(forKey: CacheKeys.lastSyncDate) as? Date else {
            return true
        }
        
        // Update if last sync was more than 24 hours ago
        return Date().timeIntervalSince(lastSync) > 86400
    }
    
    /// Get guide by ID
    public func getGuide(by id: String) -> PrayerGuide? {
        return availableGuides.first { $0.id == id }
    }
    
    /// Mark guide as completed
    public func markGuideAsCompleted(_ guide: PrayerGuide) {
        if let index = availableGuides.firstIndex(where: { $0.id == guide.id }) {
            availableGuides[index].updateProgress(1.0)
            saveGuidesToCache()
        }
    }
    
    /// Get user's progress for a specific prayer
    public func getProgress(for prayer: Prayer) -> Double {
        let guides = getGuides(for: prayer)
        guard !guides.isEmpty else { return 0.0 }
        
        let completedCount = guides.filter { $0.isCompleted }.count
        return Double(completedCount) / Double(guides.count)
    }
    
    // MARK: - Private Methods
    
    private func setupMockContent() {
        // Create mock prayer guides for development
        let mockGuides = [
            // Fajr Guides
            PrayerGuide(
                id: "fajr_shafi_basic",
                contentId: "fajr_shafi_guide_v1",
                title: "Fajr Prayer - Basic Guide",
                prayerName: Prayer.fajr.rawValue,
                sect: Madhab.shafi.rawValue,
                rakahCount: Prayer.fajr.defaultRakahCount,
                contentType: "guide",
                textContent: nil,
                videoUrl: nil,
                thumbnailUrl: nil,
                isAvailableOffline: true,
                version: 1,
                difficulty: .beginner,
                duration: 300, // 5 minutes
                description: "Learn the basics of performing Fajr prayer according to Shafi madhab",
                createdAt: Date(),
                updatedAt: Date()
            ),
            
            // Dhuhr Guides
            PrayerGuide(
                id: "dhuhr_shafi_basic",
                contentId: "dhuhr_shafi_guide_v1",
                title: "Dhuhr Prayer - Basic Guide",
                prayerName: Prayer.dhuhr.rawValue,
                sect: Madhab.shafi.rawValue,
                rakahCount: Prayer.dhuhr.defaultRakahCount,
                contentType: "guide",
                textContent: nil,
                videoUrl: nil,
                thumbnailUrl: nil,
                isAvailableOffline: true,
                version: 1,
                difficulty: .beginner,
                duration: 600, // 10 minutes
                description: "Learn the basics of performing Dhuhr prayer according to Shafi madhab",
                createdAt: Date(),
                updatedAt: Date()
            ),
            
            // Asr Guide
            PrayerGuide(
                id: "asr_shafi_basic",
                contentId: "asr_shafi_guide_v1",
                title: "Asr Prayer - Basic Guide",
                prayerName: Prayer.asr.rawValue,
                sect: Madhab.shafi.rawValue,
                rakahCount: Prayer.asr.defaultRakahCount,
                contentType: "guide",
                textContent: nil,
                videoUrl: nil,
                thumbnailUrl: nil,
                isAvailableOffline: true,
                version: 1,
                difficulty: .beginner,
                duration: 600, // 10 minutes
                description: "Learn the basics of performing Asr prayer according to Shafi madhab",
                createdAt: Date(),
                updatedAt: Date()
            ),
            
            // Maghrib Guide
            PrayerGuide(
                id: "maghrib_shafi_basic",
                contentId: "maghrib_shafi_guide_v1",
                title: "Maghrib Prayer - Basic Guide",
                prayerName: Prayer.maghrib.rawValue,
                sect: Madhab.shafi.rawValue,
                rakahCount: Prayer.maghrib.defaultRakahCount,
                contentType: "guide",
                textContent: nil,
                videoUrl: nil,
                thumbnailUrl: nil,
                isAvailableOffline: true,
                version: 1,
                difficulty: .beginner,
                duration: 450, // 7.5 minutes
                description: "Learn the basics of performing Maghrib prayer according to Shafi madhab",
                createdAt: Date(),
                updatedAt: Date()
            ),
            
            // Isha Guide
            PrayerGuide(
                id: "isha_shafi_basic",
                contentId: "isha_shafi_guide_v1",
                title: "Isha Prayer - Basic Guide",
                prayerName: Prayer.isha.rawValue,
                sect: Madhab.shafi.rawValue,
                rakahCount: Prayer.isha.defaultRakahCount,
                contentType: "guide",
                textContent: nil,
                videoUrl: nil,
                thumbnailUrl: nil,
                isAvailableOffline: true,
                version: 1,
                difficulty: .beginner,
                duration: 600, // 10 minutes
                description: "Learn the basics of performing Isha prayer according to Shafi madhab",
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
        
        availableGuides = mockGuides
        saveGuidesToCache()
    }
    
    private func loadCachedGuides() {
        if let data = userDefaults.data(forKey: CacheKeys.guidesCache),
           let guides = try? JSONDecoder().decode([PrayerGuide].self, from: data) {
            availableGuides = guides
        }
    }
    
    private func saveGuidesToCache() {
        if let data = try? JSONEncoder().encode(availableGuides) {
            userDefaults.set(data, forKey: CacheKeys.guidesCache)
        }
    }
}

// MARK: - Note: Models are now defined in separate files
// - PrayerGuide: Sources/DeenAssistCore/Models/PrayerGuide.swift
// - PrayerStep: Sources/DeenAssistCore/Models/PrayerStep.swift
// - Prayer: Sources/DeenAssistCore/Models/Prayer.swift
// - Madhab: Sources/DeenAssistCore/Models/Madhab.swift
// - Difficulty: Sources/DeenAssistCore/Models/Difficulty.swift
