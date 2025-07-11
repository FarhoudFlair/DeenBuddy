//
//  IslamicKnowledgeDetailView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-09.
//

import SwiftUI

struct IslamicKnowledgeDetailView: View {
    let result: IslamicKnowledgeResult
    let service: IslamicKnowledgeService
    
    @State private var detailedExplanation: String?
    @State private var relatedContent: [IslamicKnowledgeResult] = []
    @State private var isLoadingExplanation = false
    @State private var isLoadingRelated = false
    @State private var showingShareSheet = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                ModernGradientBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Main content card
                        mainContentCard
                        
                        // Detailed explanation (AI-powered)
                        if service.isAIEnabled {
                            detailedExplanationCard
                        }
                        
                        // Related content
                        if !relatedContent.isEmpty {
                            relatedContentCard
                        }
                        
                        // Actions
                        actionButtonsCard
                    }
                    .padding()
                }
            }
            .navigationTitle(result.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .foregroundColor(.cyan)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [formatForSharing()])
            }
            .task {
                await loadAdditionalContent()
            }
        }
    }
    
    private var mainContentCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                // Header with type and relevance
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: result.type.systemImage)
                            .foregroundColor(result.type.color)
                        
                        Text(result.type.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(result.type.color)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(result.type.color.opacity(0.2))
                    .cornerRadius(12)
                    
                    Spacer()
                    
                    Text("Relevance: \(Int(result.relevanceScore * 100))%")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // Content based on type
                switch result.type {
                case .quranVerse:
                    if let verse = result.quranVerse {
                        quranVerseContent(verse)
                    }
                case .hadith:
                    if let hadith = result.hadith {
                        hadithContent(hadith)
                    }
                case .explanation:
                    explanationContent()
                }
            }
            .padding()
        }
    }
    
    private func quranVerseContent(_ verse: QuranVerse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Reference
            Text(verse.reference)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Arabic text
            Text(verse.textArabic)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.green)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            // Translation
            Text(verse.textTranslation)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
            
            // Transliteration (if available)
            if let transliteration = verse.textTransliteration {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Transliteration:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(transliteration)
                        .font(.subheadline)
                        //.fontStyle(.italic)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Additional info
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                    .background(Color.white.opacity(0.2))
                
                HStack {
                    infoItem(title: "Revelation", value: verse.revelationPlace.displayName)
                    Spacer()
                    infoItem(title: "Juz", value: "\(verse.juzNumber)")
                    Spacer()
                    infoItem(title: "Page", value: "\(verse.pageNumber)")
                }
                
                if !verse.themes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Themes:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.7))
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(verse.themes, id: \.self) { theme in
                                    Text(theme.capitalized)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.2))
                                        .foregroundColor(.green)
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                    }
                }
            }
        }
    }
    
    private func hadithContent(_ hadith: Hadith) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Reference
            Text(hadith.reference)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Arabic text
            Text(hadith.textArabic)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.orange)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            // Translation
            Text(hadith.textTranslation)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
            
            // Narrator and grade
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                    .background(Color.white.opacity(0.2))
                
                HStack {
                    infoItem(title: "Narrator", value: hadith.narrator)
                    Spacer()
                    infoItem(title: "Grade", value: hadith.grade.displayName)
                }
                
                if let chapter = hadith.chapterReference {
                    infoItem(title: "Chapter", value: chapter)
                }
                
                if !hadith.themes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Themes:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.7))
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(hadith.themes, id: \.self) { theme in
                                    Text(theme.capitalized)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.2))
                                        .foregroundColor(.orange)
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                    }
                }
            }
        }
    }
    
    private func explanationContent() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI-Powered Explanation")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(result.explanation)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
            
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                
                Text("Generated using AI for comprehensive Islamic guidance")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    private var detailedExplanationCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                    
                    Text("Detailed Explanation")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if isLoadingExplanation {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                            .scaleEffect(0.8)
                    }
                }
                
                if let explanation = detailedExplanation {
                    Text(explanation)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                } else if !isLoadingExplanation {
                    Button("Get AI Explanation") {
                        Task {
                            await loadDetailedExplanation()
                        }
                    }
                    .buttonStyle(SecondaryModernButtonStyle())
                }
            }
            .padding()
        }
    }
    
    private var relatedContentCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.cyan)
                    
                    Text("Related Content")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if isLoadingRelated {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                            .scaleEffect(0.8)
                    }
                }
                
                ForEach(relatedContent.prefix(3)) { relatedResult in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: relatedResult.type.systemImage)
                                .foregroundColor(relatedResult.type.color)
                                .font(.caption)
                            
                            Text(relatedResult.displayTitle)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Spacer()
                        }
                        
                        Text(relatedResult.explanation)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                    
                    if relatedResult.id != relatedContent.prefix(3).last?.id {
                        Divider()
                            .background(Color.white.opacity(0.1))
                    }
                }
            }
            .padding()
        }
    }
    
    private var actionButtonsCard: some View {
        ModernCard {
            VStack(spacing: 12) {
                Button(action: { showingShareSheet = true }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryModernButtonStyle())
                
                HStack(spacing: 12) {
                    Button("Copy Text") {
                        UIPasteboard.general.string = formatForSharing()
                    }
                    .buttonStyle(SecondaryModernButtonStyle())
                    
                    Button("Add to Bookmarks") {
                        // TODO: Implement bookmark functionality
                    }
                    .buttonStyle(SecondaryModernButtonStyle())
                }
            }
            .padding()
        }
    }
    
    private func infoItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.7))
            
            Text(value)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
        }
    }
    
    private func loadAdditionalContent() async {
        await withTaskGroup(of: Void.self) { group in
            // Load detailed explanation
            if service.isAIEnabled && detailedExplanation == nil {
                group.addTask {
                    await loadDetailedExplanation()
                }
            }
            
            // Load related content
            group.addTask {
                await loadRelatedContent()
            }
        }
    }
    
    private func loadDetailedExplanation() async {
        isLoadingExplanation = true
        detailedExplanation = await service.getDetailedExplanation(for: result)
        isLoadingExplanation = false
    }
    
    private func loadRelatedContent() async {
        isLoadingRelated = true
        relatedContent = await service.getRelatedContent(for: result)
        isLoadingRelated = false
    }
    
    private func formatForSharing() -> String {
        var shareText = "\(result.displayTitle)\n\n"
        shareText += result.displayText
        shareText += "\n\nShared from DeenBuddy - Islamic Prayer Companion"
        return shareText
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    IslamicKnowledgeDetailView(
        result: IslamicKnowledgeResult(
            type: .quranVerse,
            relevanceScore: 0.95,
            quranVerse: QuranVerse(
                surahNumber: 1,
                surahName: "Al-Fatiha",
                surahNameArabic: "الفاتحة",
                verseNumber: 1,
                textArabic: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
                textTranslation: "In the name of Allah, the Entirely Merciful, the Especially Merciful.",
                textTransliteration: "Bismillahi r-rahmani r-raheem",
                revelationPlace: .mecca,
                juzNumber: 1,
                hizbNumber: 1,
                rukuNumber: 1,
                manzilNumber: 1,
                pageNumber: 1,
                themes: ["mercy", "compassion", "beginning"],
                keywords: ["Allah", "Rahman", "Raheem"]
            ),
            explanation: "This verse begins the Quran and is recited at the start of each prayer."
        ),
        service: IslamicKnowledgeService(apiClient: APIClient())
    )
}
