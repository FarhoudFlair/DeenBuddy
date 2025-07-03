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
            availableGuides[index].isCompleted = true
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
                title: "Fajr Prayer - Basic Guide",
                prayer: .fajr,
                madhab: .shafi,
                difficulty: .beginner,
                duration: 300, // 5 minutes
                description: "Learn the basics of performing Fajr prayer according to Shafi madhab",
                steps: [
                    PrayerStep(
                        id: "fajr_1",
                        title: "Preparation",
                        description: "Perform Wudu (ablution) and face the Qibla",
                        duration: 60,
                        videoURL: nil,
                        audioURL: nil
                    ),
                    PrayerStep(
                        id: "fajr_2",
                        title: "Intention (Niyyah)",
                        description: "Make the intention to pray Fajr",
                        duration: 30,
                        videoURL: nil,
                        audioURL: nil
                    ),
                    PrayerStep(
                        id: "fajr_3",
                        title: "First Rakah",
                        description: "Perform the first rakah of Fajr prayer",
                        duration: 120,
                        videoURL: nil,
                        audioURL: nil
                    ),
                    PrayerStep(
                        id: "fajr_4",
                        title: "Second Rakah",
                        description: "Perform the second rakah and complete the prayer",
                        duration: 90,
                        videoURL: nil,
                        audioURL: nil
                    )
                ],
                isAvailableOffline: true
            ),
            
            // Dhuhr Guides
            PrayerGuide(
                id: "dhuhr_shafi_basic",
                title: "Dhuhr Prayer - Basic Guide",
                prayer: .dhuhr,
                madhab: .shafi,
                difficulty: .beginner,
                duration: 600, // 10 minutes
                description: "Learn the basics of performing Dhuhr prayer according to Shafi madhab",
                steps: [
                    PrayerStep(
                        id: "dhuhr_1",
                        title: "Preparation",
                        description: "Perform Wudu (ablution) and face the Qibla",
                        duration: 60,
                        videoURL: nil,
                        audioURL: nil
                    ),
                    PrayerStep(
                        id: "dhuhr_2",
                        title: "Intention (Niyyah)",
                        description: "Make the intention to pray Dhuhr",
                        duration: 30,
                        videoURL: nil,
                        audioURL: nil
                    ),
                    PrayerStep(
                        id: "dhuhr_3",
                        title: "Four Rakahs",
                        description: "Perform all four rakahs of Dhuhr prayer",
                        duration: 510,
                        videoURL: nil,
                        audioURL: nil
                    )
                ],
                isAvailableOffline: true
            ),
            
            // Add more guides for other prayers...
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
