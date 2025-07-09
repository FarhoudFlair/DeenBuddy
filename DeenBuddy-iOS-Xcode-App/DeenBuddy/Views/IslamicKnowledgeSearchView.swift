//
//  IslamicKnowledgeSearchView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-09.
//

import SwiftUI

struct IslamicKnowledgeSearchView: View {
    @StateObject private var knowledgeService: IslamicKnowledgeService
    @State private var searchText = ""
    @State private var selectedContentType: IslamicKnowledgeType?
    @State private var includeQuran = true
    @State private var includeHadith = true
    @State private var useAI = true
    @State private var showingFilters = false
    @State private var selectedResult: IslamicKnowledgeResult?
    @State private var showingDetail = false
    
    init(knowledgeService: IslamicKnowledgeService = IslamicKnowledgeService(apiClient: APIClient())) {
        _knowledgeService = StateObject(wrappedValue: knowledgeService)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark background
                ModernGradientBackground()
                
                VStack(spacing: 0) {
                    // Search type selector
                    searchTypeSelector
                    
                    // Main content
                    if knowledgeService.isLoading {
                        loadingView
                    } else if knowledgeService.searchResults.isEmpty && !knowledgeService.lastQuery.isEmpty {
                        emptyStateView
                    } else if !knowledgeService.searchResults.isEmpty {
                        searchResultsView
                    } else {
                        welcomeView
                    }
                }
            }
            .navigationTitle("Islamic Knowledge")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .searchable(text: $searchText, prompt: "Ask about Quran, Hadith, or Islamic topics...")
            .onSubmit(of: .search) {
                performSearch()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Filters") {
                        showingFilters = true
                    }
                    .foregroundColor(.cyan)
                }
            }
            .sheet(isPresented: $showingFilters) {
                filterView
            }
            .sheet(isPresented: $showingDetail) {
                if let result = selectedResult {
                    IslamicKnowledgeDetailView(result: result, service: knowledgeService)
                }
            }
        }
    }
    
    private var searchTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                SearchTypeButton(
                    title: "All",
                    isSelected: selectedContentType == nil,
                    color: .cyan
                ) {
                    selectedContentType = nil
                }
                
                SearchTypeButton(
                    title: "Quran",
                    isSelected: selectedContentType == .quranVerse,
                    color: .green
                ) {
                    selectedContentType = .quranVerse
                }
                
                SearchTypeButton(
                    title: "Hadith",
                    isSelected: selectedContentType == .hadith,
                    color: .orange
                ) {
                    selectedContentType = .hadith
                }
                
                SearchTypeButton(
                    title: "AI Insights",
                    isSelected: selectedContentType == .explanation,
                    color: .purple
                ) {
                    selectedContentType = .explanation
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var welcomeView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Welcome content
            VStack(spacing: 16) {
                Image(systemName: "book.closed")
                    .font(.system(size: 60))
                    .foregroundColor(.cyan)
                
                Text("Islamic Knowledge Search")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Ask questions about Quran, Hadith, or Islamic topics using natural language")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Example queries
            VStack(spacing: 12) {
                Text("Try asking:")
                    .font(.headline)
                    .foregroundColor(.white)
                
                VStack(spacing: 8) {
                    ExampleQueryButton(query: "What does the Quran say about prayer?") {
                        searchText = "What does the Quran say about prayer?"
                        performSearch()
                    }
                    
                    ExampleQueryButton(query: "Hadith about kindness to parents") {
                        searchText = "Hadith about kindness to parents"
                        performSearch()
                    }
                    
                    ExampleQueryButton(query: "How to perform wudu properly?") {
                        searchText = "How to perform wudu properly?"
                        performSearch()
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                .scaleEffect(1.5)
            
            Text("Searching Islamic knowledge...")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
            
            if useAI {
                Text("Including AI-powered insights")
                    .font(.caption)
                    .foregroundColor(.purple.opacity(0.8))
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.4))
            
            Text("No Results Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Try adjusting your search query or filters")
                .font(.body)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            
            Button("Search Again") {
                performSearch()
            }
            .buttonStyle(PrimaryModernButtonStyle())
            
            Spacer()
        }
        .padding()
    }
    
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredResults) { result in
                    IslamicKnowledgeResultCard(result: result) {
                        selectedResult = result
                        showingDetail = true
                    }
                }
            }
            .padding()
        }
    }
    
    private var filteredResults: [IslamicKnowledgeResult] {
        var results = knowledgeService.searchResults
        
        if let selectedType = selectedContentType {
            results = results.filter { $0.type == selectedType }
        }
        
        return results
    }
    
    private var filterView: some View {
        NavigationStack {
            ZStack {
                ModernGradientBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Content type filter
                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Content Type")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Picker("Content Type", selection: $selectedContentType) {
                                    Text("All Content").tag(IslamicKnowledgeType?.none)
                                    ForEach(IslamicKnowledgeType.allCases, id: \.self) { type in
                                        Text(type.displayName).tag(IslamicKnowledgeType?.some(type))
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.cyan)
                            }
                            .padding()
                        }
                        
                        // Source filters
                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Sources")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Toggle("Include Quran", isOn: $includeQuran)
                                    .tint(.green)
                                
                                Toggle("Include Hadith", isOn: $includeHadith)
                                    .tint(.orange)
                                
                                Toggle("AI-Powered Insights", isOn: $useAI)
                                    .tint(.purple)
                            }
                            .padding()
                        }
                        
                        // AI Settings
                        if useAI {
                            ModernCard {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("AI Features")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    HStack {
                                        Image(systemName: "sparkles")
                                            .foregroundColor(.purple)
                                        
                                        Text("Enhanced search with GPT-powered insights and explanations")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    
                                    Text("Status: \(knowledgeService.isAIEnabled ? "Enabled" : "Disabled")")
                                        .font(.caption)
                                        .foregroundColor(knowledgeService.isAIEnabled ? .green : .red)
                                }
                                .padding()
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Search Filters")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingFilters = false
                    }
                    .foregroundColor(.cyan)
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        Task {
            await knowledgeService.searchKnowledge(
                query: searchText,
                includeQuran: includeQuran,
                includeHadith: includeHadith,
                useAI: useAI
            )
        }
    }
}

// MARK: - Supporting Views

struct SearchTypeButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .black : color)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? color : color.opacity(0.2))
                .cornerRadius(20)
        }
    }
}

struct ExampleQueryButton: View {
    let query: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundColor(.cyan)
                
                Text(query)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

struct IslamicKnowledgeResultCard: View {
    let result: IslamicKnowledgeResult
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ModernCard {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack {
                        Image(systemName: result.type.systemImage)
                            .foregroundColor(result.type.color)
                        
                        Text(result.displayTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Relevance score
                        Text("\(Int(result.relevanceScore * 100))%")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    // Content preview
                    Text(result.displayText)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    // Footer
                    HStack {
                        Text(result.type.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(result.type.color.opacity(0.2))
                            .foregroundColor(result.type.color)
                            .cornerRadius(8)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .padding()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Extensions

extension IslamicKnowledgeType {
    var systemImage: String {
        switch self {
        case .quranVerse: return "book.closed"
        case .hadith: return "text.book.closed"
        case .explanation: return "sparkles"
        }
    }
    
    var color: Color {
        switch self {
        case .quranVerse: return .green
        case .hadith: return .orange
        case .explanation: return .purple
        }
    }
}

#Preview {
    IslamicKnowledgeSearchView()
}