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
        // Initialize services
        self.supabaseService = SupabaseService()
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
            await supabaseService.fetchPrayerGuides()
            self.prayerGuides = supabaseService.prayerGuides
            print("Fetched \(prayerGuides.count) prayer guides from Supabase")
        } catch {
            // Fall back to local content if Supabase fails
            print("Supabase fetch failed, using local content: \(error)")
            self.errorMessage = "Using offline content"
            self.isOffline = true
            
            // Use ContentService for mock data
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
            .assign(to: &self.$isLoading)
        
        supabaseService.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &self.$errorMessage)

        supabaseService.$isOffline
            .receive(on: DispatchQueue.main)
            .assign(to: &self.$isOffline)
    }
}


