//
//  PrayerEntryCard.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-09.
//

import SwiftUI

struct PrayerEntryCard: View {
    let entry: PrayerJournalEntry
    let journalService: PrayerJournalService
    
    @State private var showingDetail = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        Button(action: { showingDetail = true }) {
            ModernCard {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack {
                        // Prayer icon and name
                        HStack(spacing: 8) {
                            Image(systemName: entry.prayer.systemImageName)
                                .foregroundColor(entry.prayer.color)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.prayer.displayName)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                Text(entry.completedAt, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        
                        Spacer()
                        
                        // Status indicators
                        HStack(spacing: 8) {
                            if entry.isQada {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                            
                            if entry.isOnTime {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                            
                            if entry.isInCongregation {
                                Image(systemName: "person.3.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                            }
                        }
                    }
                    
                    // Details row
                    HStack(spacing: 16) {
                        // Duration
                        if let duration = entry.formattedDuration {
                            DetailChip(
                                icon: "timer",
                                text: duration,
                                color: .cyan
                            )
                        }
                        
                        // Location
                        if let location = entry.location {
                            DetailChip(
                                icon: "location",
                                text: location,
                                color: .blue
                            )
                        }
                        
                        // Mood
                        if let mood = entry.mood {
                            DetailChip(
                                icon: nil,
                                text: "\(mood.emoji) \(mood.displayName)",
                                color: .purple
                            )
                        }
                        
                        Spacer()
                    }
                    
                    // Notes preview
                    if let notes = entry.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    // Footer with date and method
                    HStack {
                        Text(entry.completedAt, style: .date)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Spacer()
                        
                        Text(entry.method.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.white.opacity(0.8))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(action: { showingDetail = true }) {
                Label("View Details", systemImage: "eye")
            }
            
            Button(action: { showingDeleteAlert = true }) {
                Label("Delete Entry", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingDetail) {
            PrayerEntryDetailView(entry: entry, journalService: journalService)
        }
        .alert("Delete Prayer Entry", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                journalService.removePrayerEntry(entry)
            }
        } message: {
            Text("Are you sure you want to delete this prayer entry? This action cannot be undone.")
        }
    }
}

struct DetailChip: View {
    let icon: String?
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .cornerRadius(8)
    }
}

struct PrayerEntryDetailView: View {
    let entry: PrayerJournalEntry
    let journalService: PrayerJournalService
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingEdit = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                ModernGradientBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header card
                        headerCard
                        
                        // Details card
                        detailsCard
                        
                        // Experience card
                        experienceCard
                        
                        // Reflection card
                        if hasReflectionContent {
                            reflectionCard
                        }
                        
                        // Actions card
                        actionsCard
                    }
                    .padding()
                }
            }
            .navigationTitle(entry.prayer.displayName)
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
                    Button("Edit") {
                        showingEdit = true
                    }
                    .foregroundColor(.cyan)
                }
            }
            .sheet(isPresented: $showingEdit) {
                EditPrayerEntryView(entry: entry, journalService: journalService)
            }
        }
    }
    
    private var headerCard: some View {
        ModernCard {
            VStack(spacing: 16) {
                // Prayer icon and time
                HStack {
                    Image(systemName: entry.prayer.systemImageName)
                        .font(.system(size: 40))
                        .foregroundColor(entry.prayer.color)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.prayer.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(entry.completedAt, style: .time)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(entry.completedAt, style: .date)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                }
                
                // Status indicators
                HStack(spacing: 12) {
                    StatusIndicator(
                        icon: entry.isOnTime ? "checkmark.circle.fill" : "clock.circle",
                        text: entry.isOnTime ? "On Time" : "Late",
                        color: entry.isOnTime ? .green : .orange
                    )
                    
                    if entry.isQada {
                        StatusIndicator(
                            icon: "clock.arrow.circlepath",
                            text: "Makeup",
                            color: .orange
                        )
                    }
                    
                    if entry.isInCongregation {
                        StatusIndicator(
                            icon: "person.3.fill",
                            text: "Congregation",
                            color: .blue
                        )
                    }
                    
                    Spacer()
                }
            }
            .padding()
        }
    }
    
    private var detailsCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                VStack(spacing: 12) {
                    if let duration = entry.formattedDuration {
                        DetailRow(title: "Duration", value: duration, icon: "timer")
                    }
                    
                    if let location = entry.location {
                        DetailRow(title: "Location", value: location, icon: "location")
                    }
                    
                    DetailRow(title: "Method", value: entry.method.displayName, icon: "person")
                    
                    if entry.isInCongregation {
                        DetailRow(title: "Congregation", value: entry.congregation.displayName, icon: "person.3")
                    }
                    
                    if let qiblaAccuracy = entry.qiblaAccuracy {
                        DetailRow(title: "Qibla Accuracy", value: "\(Int(qiblaAccuracy))°", icon: "location.north")
                    }
                }
            }
            .padding()
        }
    }
    
    private var experienceCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Experience")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                VStack(spacing: 12) {
                    if let mood = entry.mood {
                        HStack {
                            Text(mood.emoji)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mood")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text(mood.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    if let difficulty = entry.difficulty {
                        DetailRow(title: "Difficulty", value: difficulty.displayName, icon: "chart.bar")
                    }
                    
                    if !entry.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                                ForEach(Array(entry.tags), id: \.self) { tag in
                                    Text(tag.capitalized)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.cyan.opacity(0.2))
                                        .foregroundColor(.cyan)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var reflectionCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Reflection")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 12) {
                    if let notes = entry.notes, !notes.isEmpty {
                        ReflectionSection(title: "Notes", content: notes, icon: "note.text")
                    }
                    
                    if let gratitude = entry.gratitudeNote, !gratitude.isEmpty {
                        ReflectionSection(title: "Gratitude", content: gratitude, icon: "heart")
                    }
                    
                    if let hadith = entry.hadithRemembered, !hadith.isEmpty {
                        ReflectionSection(title: "Hadith/Verse", content: hadith, icon: "book.closed")
                    }
                }
            }
            .padding()
        }
    }
    
    private var actionsCard: some View {
        ModernCard {
            VStack(spacing: 12) {
                Button(action: { showingEdit = true }) {
                    Label("Edit Entry", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryModernButtonStyle())
                
                HStack(spacing: 12) {
                    Button("Share") {
                        shareEntry()
                    }
                    .buttonStyle(SecondaryModernButtonStyle())
                    
                    Button("Duplicate") {
                        duplicateEntry()
                    }
                    .buttonStyle(SecondaryModernButtonStyle())
                }
            }
            .padding()
        }
    }
    
    private var hasReflectionContent: Bool {
        (entry.notes?.isEmpty == false) ||
        (entry.gratitudeNote?.isEmpty == false) ||
        (entry.hadithRemembered?.isEmpty == false)
    }
    
    private func shareEntry() {
        let text = formatEntryForSharing()
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func formatEntryForSharing() -> String {
        var text = "\(entry.prayer.displayName) Prayer - \(entry.completedAt.formatted(date: .abbreviated, time: .shortened))\n\n"
        
        if let location = entry.location {
            text += "📍 \(location)\n"
        }
        
        if let duration = entry.formattedDuration {
            text += "⏱️ \(duration)\n"
        }
        
        if let mood = entry.mood {
            text += "\(mood.emoji) \(mood.displayName)\n"
        }
        
        if let notes = entry.notes {
            text += "\n💭 \(notes)\n"
        }
        
        text += "\nShared from DeenBuddy - Prayer Journal"
        return text
    }
    
    private func duplicateEntry() {
        journalService.logPrayerCompletion(
            prayer: entry.prayer,
            completedAt: Date(),
            location: entry.location,
            notes: entry.notes,
            mood: entry.mood,
            method: entry.method,
            duration: entry.duration,
            congregation: entry.congregation,
            isQada: false
        )
        dismiss()
    }
}

struct StatusIndicator: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .cornerRadius(8)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.cyan)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }
}

struct ReflectionSection: View {
    let title: String
    let content: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.purple)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Text(content)
                .font(.body)
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
        }
    }
}

// Placeholder for edit view
struct EditPrayerEntryView: View {
    let entry: PrayerJournalEntry
    let journalService: PrayerJournalService
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                ModernGradientBackground()
                
                VStack {
                    Text("Edit functionality coming soon")
                        .foregroundColor(.white)
                }
            }
            .navigationTitle("Edit Prayer")
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
        }
    }
}

#Preview {
    PrayerEntryCard(
        entry: PrayerJournalEntry(
            prayer: .fajr,
            completedAt: Date(),
            location: "Home",
            notes: "Peaceful morning prayer with deep reflection",
            mood: .peaceful,
            method: .individual,
            duration: 420,
            isOnTime: true,
            congregation: .individual
        ),
        journalService: PrayerJournalService(prayerTimeService: MockPrayerTimeService())
    )
}