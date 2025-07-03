import SwiftUI
import DeenAssistProtocols
import DeenAssistCore

/// Prayer Guides screen with comprehensive prayer instructions
public struct PrayerGuidesScreen: View {
    @StateObject private var contentService = ContentService()
    @ObservedObject private var settingsService: any SettingsServiceProtocol
    
    let onDismiss: () -> Void
    
    @State private var selectedPrayer: Prayer = .fajr
    @State private var selectedGuide: PrayerGuide?
    @State private var showingGuideDetail = false
    
    public init(
        settingsService: any SettingsServiceProtocol,
        onDismiss: @escaping () -> Void
    ) {
        self.settingsService = settingsService
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Prayer selector
                prayerSelector
                
                // Guides list
                if contentService.isLoading {
                    LoadingView.prayer(message: "Loading prayer guides...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    guidesList
                }
            }
            .navigationTitle("Prayer Guides")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await contentService.refreshContent()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(contentService.isLoading)
                }
            }
            .sheet(isPresented: $showingGuideDetail) {
                if let guide = selectedGuide {
                    GuideDetailView(
                        guide: guide,
                        contentService: contentService,
                        onDismiss: {
                            showingGuideDetail = false
                            selectedGuide = nil
                        }
                    )
                }
            }
        }
        .onAppear {
            if contentService.needsUpdate {
                Task {
                    await contentService.refreshContent()
                }
            }
        }
    }
    
    @ViewBuilder
    private var prayerSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Prayer.allCases, id: \.self) { prayer in
                    PrayerSelectorButton(
                        prayer: prayer,
                        isSelected: selectedPrayer == prayer,
                        progress: contentService.getProgress(for: prayer)
                    ) {
                        selectedPrayer = prayer
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(ColorPalette.surface)
    }
    
    @ViewBuilder
    private var guidesList: some View {
        let guides = contentService.getGuides(for: selectedPrayer, madhab: settingsService.madhab)
        
        if guides.isEmpty {
            emptyState
        } else {
            List(guides) { guide in
                GuideCard(guide: guide) {
                    selectedGuide = guide
                    showingGuideDetail = true
                }
            }
            .listStyle(PlainListStyle())
        }
    }
    
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(ColorPalette.textSecondary)
            
            VStack(spacing: 8) {
                Text("No Guides Available")
                    .headlineMedium()
                    .foregroundColor(ColorPalette.textPrimary)
                
                Text("Prayer guides for \(selectedPrayer.displayName) (\(settingsService.madhab.displayName)) are not available yet.")
                    .bodyMedium()
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            CustomButton.secondary("Refresh Content") {
                Task {
                    await contentService.refreshContent()
                }
            }
            .disabled(contentService.isLoading)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Supporting Views

private struct PrayerSelectorButton: View {
    let prayer: Prayer
    let isSelected: Bool
    let progress: Double
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(ColorPalette.border, lineWidth: 2)
                        .frame(width: 50, height: 50)
                    
                    if progress > 0 {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(ColorPalette.accent, lineWidth: 3)
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                    }
                    
                    Text(prayer.displayName.prefix(1))
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? ColorPalette.primary : ColorPalette.textSecondary)
                }
                
                Text(prayer.displayName)
                    .captionMedium()
                    .foregroundColor(isSelected ? ColorPalette.primary : ColorPalette.textSecondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct GuideCard: View {
    let guide: PrayerGuide
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(guide.title)
                            .headlineSmall()
                            .foregroundColor(ColorPalette.textPrimary)
                        
                        Text(guide.description)
                            .bodySmall()
                            .foregroundColor(ColorPalette.textSecondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        DifficultyBadge(difficulty: guide.difficulty)
                        
                        Text(guide.formattedDuration)
                            .captionSmall()
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                }
                
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: guide.isAvailableOffline ? "wifi.slash" : "wifi")
                            .font(.caption)
                            .foregroundColor(guide.isAvailableOffline ? .green : .orange)
                        
                        Text(guide.isAvailableOffline ? "Offline" : "Online")
                            .captionSmall()
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    
                    Spacer()
                    
                    if guide.isCompleted {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Text("Completed")
                                .captionSmall()
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorPalette.surface)
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

private struct DifficultyBadge: View {
    let difficulty: PrayerGuide.Difficulty
    
    var body: some View {
        Text(difficulty.displayName)
            .captionSmall()
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(difficultyColor.opacity(0.2))
            )
            .foregroundColor(difficultyColor)
    }
    
    private var difficultyColor: Color {
        switch difficulty {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
}

// MARK: - Guide Detail View

private struct GuideDetailView: View {
    let guide: PrayerGuide
    @ObservedObject var contentService: ContentService
    let onDismiss: () -> Void
    
    @State private var currentStepIndex = 0
    @State private var showingStepDetail = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Guide header
                    VStack(alignment: .leading, spacing: 12) {
                        Text(guide.title)
                            .headlineLarge()
                            .foregroundColor(ColorPalette.textPrimary)
                        
                        Text(guide.description)
                            .bodyMedium()
                            .foregroundColor(ColorPalette.textSecondary)
                        
                        HStack {
                            DifficultyBadge(difficulty: guide.difficulty)
                            
                            Text(guide.formattedDuration)
                                .captionMedium()
                                .foregroundColor(ColorPalette.textSecondary)
                            
                            Spacer()
                            
                            if guide.isCompleted {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Completed")
                                        .captionMedium()
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ColorPalette.surface)
                    )
                    
                    // Steps list
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Steps")
                            .headlineMedium()
                            .foregroundColor(ColorPalette.textPrimary)
                        
                        ForEach(Array(guide.steps.enumerated()), id: \.element.id) { index, step in
                            StepCard(
                                step: step,
                                stepNumber: index + 1,
                                isCompleted: step.isCompleted
                            ) {
                                currentStepIndex = index
                                showingStepDetail = true
                            }
                        }
                    }
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        if !guide.isCompleted {
                            CustomButton.primary("Mark as Completed") {
                                contentService.markGuideAsCompleted(guide)
                            }
                        }
                        
                        CustomButton.secondary("Start Practice") {
                            currentStepIndex = 0
                            showingStepDetail = true
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Guide Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingStepDetail) {
            if currentStepIndex < guide.steps.count {
                StepDetailView(
                    step: guide.steps[currentStepIndex],
                    stepNumber: currentStepIndex + 1,
                    totalSteps: guide.steps.count,
                    onNext: {
                        if currentStepIndex < guide.steps.count - 1 {
                            currentStepIndex += 1
                        } else {
                            showingStepDetail = false
                        }
                    },
                    onDismiss: {
                        showingStepDetail = false
                    }
                )
            }
        }
    }
}

private struct StepCard: View {
    let step: PrayerStep
    let stepNumber: Int
    let isCompleted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Step number
                ZStack {
                    Circle()
                        .fill(isCompleted ? .green : ColorPalette.primary)
                        .frame(width: 32, height: 32)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    } else {
                        Text("\(stepNumber)")
                            .captionMedium()
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .bodyMedium()
                        .fontWeight(.medium)
                        .foregroundColor(ColorPalette.textPrimary)
                    
                    Text(step.description)
                        .bodySmall()
                        .foregroundColor(ColorPalette.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Text(step.formattedDuration)
                    .captionSmall()
                    .foregroundColor(ColorPalette.textSecondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ColorPalette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isCompleted ? .green : ColorPalette.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct StepDetailView: View {
    let step: PrayerStep
    let stepNumber: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Progress indicator
                VStack(spacing: 8) {
                    Text("Step \(stepNumber) of \(totalSteps)")
                        .captionMedium()
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    ProgressView(value: Double(stepNumber), total: Double(totalSteps))
                        .progressViewStyle(LinearProgressViewStyle(tint: ColorPalette.primary))
                }
                
                // Step content
                VStack(alignment: .leading, spacing: 16) {
                    Text(step.title)
                        .headlineLarge()
                        .foregroundColor(ColorPalette.textPrimary)
                    
                    Text(step.description)
                        .bodyMedium()
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    // Placeholder for video/audio content
                    if step.videoURL != nil || step.audioURL != nil {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ColorPalette.surface)
                            .frame(height: 200)
                            .overlay(
                                VStack {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(ColorPalette.primary)
                                    Text("Media content will be available soon")
                                        .bodySmall()
                                        .foregroundColor(ColorPalette.textSecondary)
                                }
                            )
                    }
                }
                
                Spacer()
                
                // Navigation buttons
                HStack(spacing: 16) {
                    CustomButton.secondary("Close") {
                        onDismiss()
                    }
                    
                    CustomButton.primary(stepNumber == totalSteps ? "Complete" : "Next") {
                        onNext()
                    }
                }
            }
            .padding()
            .navigationTitle("Prayer Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
}
