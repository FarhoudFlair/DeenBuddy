//
//  LanguageSettingsView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-09.
//

import SwiftUI

struct LanguageSettingsView: View {
    @StateObject private var localizationService = LocalizationService()
    @State private var selectedLanguage: AppLanguage
    @State private var showingLanguageDetail = false
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss: DismissAction
    
    init() {
        _selectedLanguage = State(initialValue: AppLanguage.systemPreferredLanguage)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ModernGradientBackground()
                
                VStack(spacing: 0) {
                    // Header with current language
                    currentLanguageHeader
                    
                    // Search bar
                    searchBar
                    
                    // Language list
                    languageList
                }
            }
            .navigationTitle("Language Settings")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        localizationService.changeLanguage(selectedLanguage)
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                    .fontWeight(.semibold)
                }
            }
            .environment(\.localizationService, localizationService)
            .rtlAware(localizationService)
            .onAppear {
                selectedLanguage = localizationService.currentLanguage
            }
        }
    }
    
    private var currentLanguageHeader: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "globe")
                        .font(.title2)
                        .foregroundColor(.cyan)
                    
                    Text("Current Language")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedLanguage.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(selectedLanguage.name)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(selectedLanguage.direction.displayName)
                            .font(.caption)
                            .foregroundColor(.cyan)
                        
                        Text(selectedLanguage.region.displayName)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                if selectedLanguage.isRTL {
                    HStack {
                        Image(systemName: "arrow.right.to.line")
                            .foregroundColor(.orange)
                        
                        Text("Right-to-Left Language")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Spacer()
                    }
                }
            }
            .padding()
        }
        .padding(.horizontal)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
            
            TextField("Search languages...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var languageList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredLanguages, id: \.id) { language in
                    LanguageRow(
                        language: language,
                        isSelected: language.id == selectedLanguage.id,
                        onSelect: {
                            selectedLanguage = language
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    private var filteredLanguages: [AppLanguage] {
        let languages = AppLanguage.supportedLanguages
        
        if searchText.isEmpty {
            return languages
        } else {
            return languages.filter { language in
                language.name.localizedCaseInsensitiveContains(searchText) ||
                language.nativeName.localizedCaseInsensitiveContains(searchText) ||
                language.region.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

struct LanguageRow: View {
    let language: AppLanguage
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            ModernCard {
                HStack(spacing: 16) {
                    // Language flag or icon
                    ZStack {
                        Circle()
                            .fill(language.isRTL ? Color.orange.opacity(0.3) : Color.blue.opacity(0.3))
                            .frame(width: 40, height: 40)
                        
                        Text(String(language.nativeName.prefix(2)))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(language.isRTL ? .orange : .blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(language.displayName)
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        
                        HStack {
                            Text(language.name)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            
                            if let dialect = language.dialect {
                                Text("• \(dialect)")
                                    .font(.caption)
                                    .foregroundColor(.cyan)
                            }
                        }
                        
                        HStack {
                            Label(language.region.displayName, systemImage: "location")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            
                            if language.isRTL {
                                Label("RTL", systemImage: "arrow.right.to.line")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.cyan)
                        } else {
                            Image(systemName: "circle")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.3))
                        }
                        
                        // Prayer name example
                        Text(language.prayerNames.fajr)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

struct LanguageRegionSection: View {
    let region: LanguageRegion
    let languages: [AppLanguage]
    let selectedLanguage: AppLanguage
    let onLanguageSelect: (AppLanguage) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(region.displayName)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.cyan)
                .padding(.horizontal)
            
            ForEach(languages, id: \.id) { language in
                LanguageRow(
                    language: language,
                    isSelected: language.id == selectedLanguage.id,
                    onSelect: {
                        onLanguageSelect(language)
                    }
                )
            }
        }
    }
}

// MARK: - Preview
#Preview {
    LanguageSettingsView()
}