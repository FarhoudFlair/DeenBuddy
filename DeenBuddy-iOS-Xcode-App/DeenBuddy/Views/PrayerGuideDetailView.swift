//
//  PrayerGuideDetailView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-03.
//

import SwiftUI

struct PrayerGuideDetailView: View {
    let guide: PrayerGuide
    @EnvironmentObject private var userPreferencesService: UserPreferencesService
    @State private var currentStepIndex = 0
    @State private var showingStepDetail = false
    @State private var showingVideoPlayer = false
    @State private var selectedVideoURL: URL?
    
    private var isBookmarked: Bool {
        userPreferencesService.isBookmarked(guide.id)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header section
                headerSection
                
                // Prayer steps
                if !(guide.textContent?.steps ?? []).isEmpty {
                    stepsSection
                }
                
                // Additional information
                additionalInfoSection
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: toggleBookmark) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundColor(isBookmarked ? .yellow : .gray)
                }
            }
        }
        .onAppear {
            // Bookmark status is automatically synced via UserPreferencesService
        }
        .sheet(isPresented: $showingVideoPlayer) {
            if let videoURL = selectedVideoURL {
                VideoPlayerView(videoURL: videoURL, title: guide.title)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(guide.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.leading)
            
            // Prayer info row
            HStack {
                Label(guide.prayer.displayName, systemImage: guide.prayer.systemImageName)
                    .foregroundColor(guide.prayer.color)
                    .font(.headline)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(guide.formattedDuration)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("\(guide.textContent?.steps.count ?? 0) Steps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Arabic name
            Text(guide.prayer.arabicName)
                .font(.title)
                .fontWeight(.semibold)
                .environment(\.layoutDirection, .rightToLeft)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            // Tradition and difficulty
            HStack {
                // Tradition badge
                Text(guide.sectDisplayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(guide.madhab.color.opacity(0.2))
                    .foregroundColor(guide.madhab.color)
                    .cornerRadius(6)
                
                // Difficulty badge
                Text(guide.difficulty.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(difficultyColor.opacity(0.2))
                    .foregroundColor(difficultyColor)
                    .cornerRadius(6)
                
                Spacer()
                
                // Status indicators
                HStack(spacing: 8) {
                    if guide.isAvailableOffline {
                        Label("Offline", systemImage: "arrow.down.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    if guide.isCompleted {
                        Label("Completed", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // Description
            if !guide.description.isEmpty {
                Text(guide.description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Prayer Steps")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(Array((guide.textContent?.steps ?? []).enumerated()), id: \.element.id) { index, step in
                    PrayerStepView(
                        step: step,
                        stepNumber: index + 1,
                        onPlayVideo: { url in
                            selectedVideoURL = url
                            showingVideoPlayer = true
                        },
                        onPlayAudio: { url in
                            // TODO: Implement audio playback with AVAudioPlayer
                            print("Play audio: \(url)")
                        }
                    )
                    .onTapGesture {
                        currentStepIndex = index
                        showingStepDetail = true
                    }
                }
            }
        }
    }
    
    private var additionalInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Additional Information")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRowView(
                    title: "Prayer Time",
                    value: guide.prayer.displayName,
                    icon: guide.prayer.systemImageName
                )
                
                InfoRowView(
                    title: "Tradition",
                    value: guide.sectDisplayName,
                    icon: "person.2"
                )
                
                InfoRowView(
                    title: "Difficulty",
                    value: guide.difficulty.displayName,
                    icon: "chart.bar"
                )
                
                InfoRowView(
                    title: "Duration",
                    value: guide.formattedDuration,
                    icon: "clock"
                )
                
                InfoRowView(
                    title: "Steps",
                    value: "\(guide.textContent?.steps.count ?? 0)",
                    icon: "list.number"
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var difficultyColor: Color {
        switch guide.difficulty {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
    
    private func toggleBookmark() {
        userPreferencesService.toggleBookmark(for: guide.id)
    }
}

struct InfoRowView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    NavigationStack {
        PrayerGuideDetailView(
            guide: PrayerGuide(
                id: "fajr_shafi",
                contentId: "fajr_shafi_guide",
                title: "Fajr Prayer Guide (Sunni)",
                prayerName: "fajr",
                sect: "shafi",
                rakahCount: 2,
                textContent: PrayerContent(steps: [
                    PrayerStep(
                        id: "step1",
                        title: "Preparation",
                        description: "Perform Wudu (ablution) and face the Qibla. Make sure you are in a clean place and wearing clean clothes.",
                        stepNumber: 1,
                        duration: 60
                    ),
                    PrayerStep(
                        id: "step2",
                        title: "Intention (Niyyah)",
                        description: "Make the intention to pray Fajr prayer for the sake of Allah.",
                        stepNumber: 2,
                        duration: 30
                    ),
                    PrayerStep(
                        id: "step3",
                        title: "First Rakah",
                        description: "Perform the first rakah of Fajr prayer with proper recitation.",
                        stepNumber: 3,
                        duration: 120
                    ),
                    PrayerStep(
                        id: "step4",
                        title: "Second Rakah",
                        description: "Perform the second rakah and complete the prayer with Tasleem.",
                        stepNumber: 4,
                        duration: 90
                    )
                ]),
                isAvailableOffline: true,
                difficulty: .beginner,
                duration: 300,
                description: "Complete guide for performing Fajr prayer according to Sunni tradition with detailed step-by-step instructions."

            )
        )
        .environmentObject(UserPreferencesService())
    }
}
