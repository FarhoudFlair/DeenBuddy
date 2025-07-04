//
//  MockModels.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-03.
//
//  TEMPORARY FILE: This provides mock implementations for development.
//  TODO: Replace with actual DeenAssistCore package integration.

import Foundation
import SwiftUI

// MARK: - Mock Models (Temporary)

// Note: Prayer and Madhab enums are now defined in PrayerTimeModels.swift and CalculationModels.swift

public struct PrayerStep: Codable, Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let duration: TimeInterval
    public let videoURL: String?
    public let audioURL: String?
    public var isCompleted: Bool = false
    
    public init(
        id: String,
        title: String,
        description: String,
        duration: TimeInterval,
        videoURL: String? = nil,
        audioURL: String? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.duration = duration
        self.videoURL = videoURL
        self.audioURL = audioURL
        self.isCompleted = isCompleted
    }
}

public struct PrayerGuide: Codable, Identifiable {
    public let id: String
    public let title: String
    public let prayer: Prayer
    public let madhab: Madhab
    public let difficulty: Difficulty
    public let duration: TimeInterval
    public let description: String
    public let steps: [PrayerStep]
    public let isAvailableOffline: Bool
    public var isCompleted: Bool = false
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: String,
        title: String,
        prayer: Prayer,
        madhab: Madhab,
        difficulty: Difficulty,
        duration: TimeInterval,
        description: String,
        steps: [PrayerStep],
        isAvailableOffline: Bool,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.prayer = prayer
        self.madhab = madhab
        self.difficulty = difficulty
        self.duration = duration
        self.description = description
        self.steps = steps
        self.isAvailableOffline = isAvailableOffline
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    public var formattedDuration: String {
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }
    
    public var sectDisplayName: String {
        return madhab.sectDisplayName
    }
    
    public var rakahText: String {
        return "\(steps.count) Steps"
    }
    
    public enum Difficulty: String, CaseIterable, Codable {
        case beginner = "beginner"
        case intermediate = "intermediate"
        case advanced = "advanced"
        
        public var displayName: String {
            return rawValue.capitalized
        }
    }
}

// MARK: - Mock Services

public struct SupabaseConfiguration {
    public let url: String
    public let anonKey: String
    
    public init(url: String, anonKey: String) {
        self.url = url
        self.anonKey = anonKey
    }
}

@MainActor
public class SupabaseService: ObservableObject {
    @Published public var isConnected = false
    @Published public var isLoading = false
    @Published public var error: Error?
    
    private let configuration: SupabaseConfiguration
    
    public init(configuration: SupabaseConfiguration) {
        self.configuration = configuration
    }
    
    public func initialize() async {
        isLoading = true
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isConnected = true
        isLoading = false
    }
    
    public func syncPrayerGuides() async throws -> [PrayerGuide] {
        // Return mock data
        return MockData.prayerGuides
    }
}

@MainActor
public class ContentService: ObservableObject {
    @Published public var availableGuides: [PrayerGuide] = []
    
    public init() {}
    
    public func loadContent() async {
        availableGuides = MockData.prayerGuides
    }
}

// MARK: - Mock Data

struct MockData {
    static let prayerGuides: [PrayerGuide] = [
        // Sunni Guides (Shafi)
        PrayerGuide(
            id: "fajr_sunni",
            title: "Fajr Prayer Guide (Sunni)",
            prayer: .fajr,
            madhab: .shafi,
            difficulty: .beginner,
            duration: 300,
            description: "Complete guide for performing Fajr prayer according to Sunni tradition",
            steps: [
                PrayerStep(id: "fajr_1", title: "Preparation", description: "Perform Wudu and face Qibla", duration: 60),
                PrayerStep(id: "fajr_2", title: "Intention", description: "Make intention for Fajr prayer", duration: 30),
                PrayerStep(id: "fajr_3", title: "First Rakah", description: "Perform first rakah", duration: 105),
                PrayerStep(id: "fajr_4", title: "Second Rakah", description: "Perform second rakah", duration: 105)
            ],
            isAvailableOffline: true
        ),
        
        PrayerGuide(
            id: "dhuhr_sunni",
            title: "Dhuhr Prayer Guide (Sunni)",
            prayer: .dhuhr,
            madhab: .shafi,
            difficulty: .intermediate,
            duration: 600,
            description: "Complete guide for performing Dhuhr prayer according to Sunni tradition",
            steps: [
                PrayerStep(id: "dhuhr_1", title: "Preparation", description: "Perform Wudu and face Qibla", duration: 60),
                PrayerStep(id: "dhuhr_2", title: "Intention", description: "Make intention for Dhuhr prayer", duration: 30),
                PrayerStep(id: "dhuhr_3", title: "Four Rakahs", description: "Perform all four rakahs", duration: 510)
            ],
            isAvailableOffline: true
        ),
        
        // Shia Guides (Hanafi)
        PrayerGuide(
            id: "fajr_shia",
            title: "Fajr Prayer Guide (Shia)",
            prayer: .fajr,
            madhab: .hanafi,
            difficulty: .beginner,
            duration: 320,
            description: "Complete guide for performing Fajr prayer according to Shia tradition",
            steps: [
                PrayerStep(id: "fajr_shia_1", title: "Preparation", description: "Perform Wudu and face Qibla", duration: 60),
                PrayerStep(id: "fajr_shia_2", title: "Intention", description: "Make intention for Fajr prayer", duration: 30),
                PrayerStep(id: "fajr_shia_3", title: "First Rakah", description: "Perform first rakah with Shia method", duration: 115),
                PrayerStep(id: "fajr_shia_4", title: "Second Rakah", description: "Perform second rakah with Shia method", duration: 115)
            ],
            isAvailableOffline: false
        ),
        
        PrayerGuide(
            id: "dhuhr_shia",
            title: "Dhuhr Prayer Guide (Shia)",
            prayer: .dhuhr,
            madhab: .hanafi,
            difficulty: .intermediate,
            duration: 620,
            description: "Complete guide for performing Dhuhr prayer according to Shia tradition",
            steps: [
                PrayerStep(id: "dhuhr_shia_1", title: "Preparation", description: "Perform Wudu and face Qibla", duration: 60),
                PrayerStep(id: "dhuhr_shia_2", title: "Intention", description: "Make intention for Dhuhr prayer", duration: 30),
                PrayerStep(id: "dhuhr_shia_3", title: "Four Rakahs", description: "Perform all four rakahs with Shia method", duration: 530)
            ],
            isAvailableOffline: true
        )
    ]
}
