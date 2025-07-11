//
//  AddPrayerEntryView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-09.
//

import SwiftUI

struct AddPrayerEntryView: View {
    let journalService: PrayerJournalService
    
    @State private var selectedPrayer: Prayer = .fajr
    @State private var completedAt = Date()
    @State private var location = ""
    @State private var notes = ""
    @State private var selectedMood: PrayerMood?
    @State private var selectedMethod: PrayerMethod = .individual
    @State private var congregation: CongregationType = .individual
    @State private var isQada = false
    @State private var duration: TimeInterval = 300 // 5 minutes default
    @State private var gratitudeNote = ""
    @State private var hadithRemembered = ""
    @State private var difficulty: PrayerDifficulty?
    @State private var selectedTags: Set<String> = []
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingSuccess = false
    
    private let commonTags = ["peaceful", "rushed", "focused", "distracted", "grateful", "seeking", "family", "work", "travel", "mosque"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                ModernGradientBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Basic information
                        basicInfoSection
                        
                        // Timing and location
                        timingLocationSection
                        
                        // Experience details
                        experienceSection
                        
                        // Reflection section
                        reflectionSection
                        
                        // Tags section
                        tagsSection
                        
                        // Save button
                        saveButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Log Prayer")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
            .alert("Prayer Logged!", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your \(selectedPrayer.displayName) prayer has been recorded.")
            }
        }
    }
    
    private var basicInfoSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Prayer Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                // Prayer selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prayer")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Prayer.allCases, id: \.self) { prayer in
                                PrayerSelectionButton(
                                    prayer: prayer,
                                    isSelected: selectedPrayer == prayer
                                ) {
                                    selectedPrayer = prayer
                                }
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
                
                // Qada toggle
                Toggle("This is a makeup prayer (Qada)", isOn: $isQada)
                    .tint(.orange)
            }
            .padding()
        }
    }
    
    private var timingLocationSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Time & Location")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                // Completion time
                VStack(alignment: .leading, spacing: 8) {
                    Text("Completed At")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                    
                    DatePicker("", selection: $completedAt, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .colorScheme(.dark)
                }
                
                // Duration
                VStack(alignment: .leading, spacing: 8) {
                    Text("Duration (minutes)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                    
                    HStack {
                        Slider(value: Binding(
                            get: { duration / 60 },
                            set: { duration = $0 * 60 }
                        ), in: 1...30, step: 1)
                        .tint(.cyan)
                        
                        Text("\(Int(duration / 60))m")
                            .font(.subheadline)
                            .foregroundColor(.cyan)
                            .frame(width: 30)
                    }
                }
                
                // Location
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                    
                    TextField("e.g. Home, Office, Mosque", text: $location)
                        .textFieldStyle(ModernTextFieldStyle())
                }
            }
            .padding()
        }
    }
    
    private var experienceSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Prayer Experience")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                // Method
                VStack(alignment: .leading, spacing: 8) {
                    Text("Method")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Picker("Method", selection: $selectedMethod) {
                        ForEach(PrayerMethod.allCases, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.cyan)
                }
                
                // Congregation type
                if selectedMethod == .congregation {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Congregation Type")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Picker("Congregation", selection: $congregation) {
                            ForEach(CongregationType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.cyan)
                    }
                }
                
                // Mood
                VStack(alignment: .leading, spacing: 8) {
                    Text("How did you feel?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(PrayerMood.allCases, id: \.self) { mood in
                            MoodSelectionButton(
                                mood: mood,
                                isSelected: selectedMood == mood
                            ) {
                                selectedMood = selectedMood == mood ? nil : mood
                            }
                        }
                    }
                }
                
                // Difficulty
                VStack(alignment: .leading, spacing: 8) {
                    Text("Difficulty Level")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                    
                    HStack(spacing: 8) {
                        ForEach(PrayerDifficulty.allCases, id: \.self) { level in
                            DifficultyButton(
                                difficulty: level,
                                isSelected: difficulty == level
                            ) {
                                difficulty = difficulty == level ? nil : level
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var reflectionSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Reflection")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                    
                    TextField("Any thoughts or observations...", text: $notes, axis: .vertical)
                        .textFieldStyle(ModernTextFieldStyle())
                        .lineLimit(3...5)
                }
                
                // Gratitude
                VStack(alignment: .leading, spacing: 8) {
                    Text("What are you grateful for?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                    
                    TextField("I'm grateful for...", text: $gratitudeNote, axis: .vertical)
                        .textFieldStyle(ModernTextFieldStyle())
                        .lineLimit(2...3)
                }
                
                // Hadith remembered
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hadith or Verse Remembered")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                    
                    TextField("Any hadith or verse that came to mind...", text: $hadithRemembered, axis: .vertical)
                        .textFieldStyle(ModernTextFieldStyle())
                        .lineLimit(2...3)
                }
            }
            .padding()
        }
    }
    
    private var tagsSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tags")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Add tags to help categorize this prayer")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(commonTags, id: \.self) { tag in
                        TagButton(
                            tag: tag,
                            isSelected: selectedTags.contains(tag)
                        ) {
                            if selectedTags.contains(tag) {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var saveButton: some View {
        Button(action: savePrayerEntry) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Log Prayer")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryModernButtonStyle())
    }
    
    private func savePrayerEntry() {
        journalService.logPrayerCompletion(
            prayer: selectedPrayer,
            completedAt: completedAt,
            location: location.isEmpty ? nil : location,
            notes: notes.isEmpty ? nil : notes,
            mood: selectedMood,
            method: selectedMethod,
            duration: duration,
            congregation: congregation,
            isQada: isQada,
            hadithRemembered: hadithRemembered.isEmpty ? nil : hadithRemembered,
            gratitudeNote: gratitudeNote.isEmpty ? nil : gratitudeNote,
            difficulty: difficulty,
            tags: Array(selectedTags)
        )
        
        showingSuccess = true
    }
}

// MARK: - Supporting Views

struct PrayerSelectionButton: View {
    let prayer: Prayer
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: prayer.systemImageName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .black : prayer.color)
                
                Text(prayer.shortName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .black : .white)
            }
            .frame(width: 70, height: 60)
            .background(isSelected ? prayer.color : Color.white.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

struct MoodSelectionButton: View {
    let mood: PrayerMood
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(mood.emoji)
                    .font(.title2)
                
                Text(mood.displayName)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isSelected ? .black : .white.opacity(0.8))
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct DifficultyButton: View {
    let difficulty: PrayerDifficulty
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(difficulty.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.1))
                .cornerRadius(16)
        }
    }
}

struct TagButton: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(tag.capitalized)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .black : .cyan)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.cyan : Color.cyan.opacity(0.2))
                .cornerRadius(16)
        }
    }
}

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .foregroundColor(.white)
    }
}

#Preview {
    AddPrayerEntryView(journalService: PrayerJournalService(prayerTimeService: MockPrayerTimeService()))
}