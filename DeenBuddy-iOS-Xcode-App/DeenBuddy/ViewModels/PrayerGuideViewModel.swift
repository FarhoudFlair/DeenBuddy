//
//  PrayerGuideViewModel.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-03.
//

import Foundation
import SwiftUI
import Combine

/// ViewModel that bridges SupabaseService with SwiftUI views
@MainActor
public class PrayerGuideViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var prayerGuides: [PrayerGuide] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var isOffline = false
    @Published public var selectedMadhab: Madhab = .shafi
    
    // MARK: - Private Properties
    
    private let supabaseService: SupabaseService
    private let contentService: ContentService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init() {
        // Initialize services with default configuration
        let config = SupabaseConfiguration(
            url: ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "",
            anonKey: ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
        )
        
        self.supabaseService = SupabaseService(configuration: config)
        self.contentService = ContentService()
        
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Fetch prayer guides from Supabase
    public func fetchPrayerGuides() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Try to fetch from Supabase first
            let guides = try await supabaseService.syncPrayerGuides()
            self.prayerGuides = guides
            print("Fetched \(guides.count) prayer guides from Supabase")
        } catch {
            // Fall back to local content if Supabase fails
            print("Supabase fetch failed, using local content: \(error)")
            self.errorMessage = "Using offline content"
            self.isOffline = true
            
            // Use ContentService for mock data
            await contentService.loadContent()
            self.prayerGuides = contentService.availableGuides
        }
        
        isLoading = false
    }
    
    /// Refresh data with force refresh
    public func refreshData() async {
        await fetchPrayerGuides()
    }
    
    /// Get filtered guides for selected madhab
    public var filteredGuides: [PrayerGuide] {
        return prayerGuides.filter { $0.madhab == selectedMadhab }
            .sorted { $0.prayer.rawValue < $1.prayer.rawValue }
    }
    
    /// Get guides for specific prayer and madhab
    public func getGuide(for prayer: Prayer, madhab: Madhab) -> PrayerGuide? {
        return prayerGuides.first { $0.prayer == prayer && $0.madhab == madhab }
    }
    
    /// Get summary statistics
    public var totalGuides: Int { prayerGuides.count }
    public var shafiGuides: Int { prayerGuides.filter { $0.madhab == .shafi }.count }
    public var hanafiGuides: Int { prayerGuides.filter { $0.madhab == .hanafi }.count }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind to SupabaseService state
        supabaseService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        supabaseService.$error
            .receive(on: DispatchQueue.main)
            .map { error in
                if let error = error {
                    return "Connection error: \(error.localizedDescription)"
                }
                return nil
            }
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
        
        supabaseService.$isConnected
            .receive(on: DispatchQueue.main)
            .map { !$0 }
            .assign(to: \.isOffline, on: self)
            .store(in: &cancellables)
    }
}

// MARK: - Extensions for Display

extension Madhab {
    /// Map to sect names for display purposes
    public var sectDisplayName: String {
        switch self {
        case .shafi: return "Sunni"
        case .hanafi: return "Shia"
        }
    }
    
    public var color: Color {
        switch self {
        case .shafi: return .green
        case .hanafi: return .purple
        }
    }
}

extension Prayer {
    public var systemImageName: String {
        switch self {
        case .fajr: return "sunrise"
        case .dhuhr: return "sun.max"
        case .asr: return "sun.min"
        case .maghrib: return "sunset"
        case .isha: return "moon"
        }
    }
    
    public var color: Color {
        switch self {
        case .fajr: return .orange
        case .dhuhr: return .yellow
        case .asr: return .blue
        case .maghrib: return .red
        case .isha: return .indigo
        }
    }
    
    public var arabicName: String {
        switch self {
        case .fajr: return "الفجر"
        case .dhuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        }
    }
}

extension PrayerGuide {
    public var rakahText: String {
        let steps = self.steps.count
        return "\(steps) Steps"
    }
    
    public var sectDisplayName: String {
        return madhab.sectDisplayName
    }
}
