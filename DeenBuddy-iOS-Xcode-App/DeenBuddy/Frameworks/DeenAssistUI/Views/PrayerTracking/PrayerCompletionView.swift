import SwiftUI

/// View for marking a prayer as completed with optional details
public struct PrayerCompletionView: View {
    
    // MARK: - Properties
    
    let prayer: Prayer
    @ObservedObject private var prayerTrackingService: any PrayerTrackingServiceProtocol
    private let onDismiss: () -> Void
    
    // MARK: - State
    
    @State private var notes: String = ""
    @State private var selectedMood: PrayerMood?
    @State private var selectedMethod: PrayerMethod = .individual
    @State private var selectedCongregation: CongregationType = .individual
    @State private var isQada: Bool = false
    @State private var gratitudeNote: String = ""
    @State private var isLoading: Bool = false
    
    // MARK: - Initialization
    
    public init(
        prayer: Prayer,
        prayerTrackingService: any PrayerTrackingServiceProtocol,
        onDismiss: @escaping () -> Void
    ) {
        self.prayer = prayer
        self.prayerTrackingService = prayerTrackingService
        self.onDismiss = onDismiss
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Prayer Header
                    prayerHeader
                    
                    // Quick Complete Button
                    quickCompleteButton
                    
                    // Divider
                    Divider()
                        .padding(.horizontal)
                    
                    // Detailed Options
                    detailedOptionsSection
                }
                .padding()
            }
            .navigationTitle("Complete Prayer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveDetailedCompletion()
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
    }
    
    // MARK: - Prayer Header
    
    @ViewBuilder
    private var prayerHeader: some View {
        VStack(spacing: 12) {
            // Prayer Icon
            ZStack {
                Circle()
                    .fill(prayer.color.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: prayer.systemImageName)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(prayer.color)
            }
            
            // Prayer Name
            VStack(spacing: 4) {
                Text(prayer.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(prayer.arabicName)
                    .font(.title3)
                    .fontWeight(.medium)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            
            // Current Time
            Text("Completed at \(Date().formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundColor(ColorPalette.secondary)
        }
    }
    
    // MARK: - Quick Complete Button
    
    @ViewBuilder
    private var quickCompleteButton: some View {
        Button(action: {
            Task {
                await quickComplete()
            }
        }) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                
                Text("Mark as Completed")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(prayer.color)
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }
    
    // MARK: - Detailed Options Section
    
    @ViewBuilder
    private var detailedOptionsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Add Details (Optional)")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Prayer Method
            methodSelection
            
            // Congregation Type
            congregationSelection
            
            // Mood Selection
            moodSelection
            
            // Qada Toggle
            qadaToggle
            
            // Notes
            notesSection
            
            // Gratitude Note
            gratitudeSection
        }
    }
    
    // MARK: - Method Selection
    
    @ViewBuilder
    private var methodSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prayer Method")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 12) {
                ForEach([PrayerMethod.individual, PrayerMethod.congregation], id: \.self) { method in
                    Button(action: {
                        selectedMethod = method
                    }) {
                        HStack {
                            Image(systemName: selectedMethod == method ? "checkmark.circle.fill" : "circle")
                            Text(method.displayName)
                        }
                        .foregroundColor(selectedMethod == method ? prayer.color : ColorPalette.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedMethod == method ? prayer.color.opacity(0.1) : ColorPalette.surface)
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Congregation Selection
    
    @ViewBuilder
    private var congregationSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Congregation")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 12) {
                ForEach([CongregationType.individual, CongregationType.congregation, CongregationType.family], id: \.self) { type in
                    Button(action: {
                        selectedCongregation = type
                    }) {
                        HStack {
                            Image(systemName: selectedCongregation == type ? "checkmark.circle.fill" : "circle")
                            Text(type.displayName)
                        }
                        .font(.caption)
                        .foregroundColor(selectedCongregation == type ? prayer.color : ColorPalette.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedCongregation == type ? prayer.color.opacity(0.1) : ColorPalette.surface)
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Mood Selection
    
    @ViewBuilder
    private var moodSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How did you feel?")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 12) {
                ForEach([PrayerMood.peaceful, PrayerMood.grateful, PrayerMood.focused, PrayerMood.rushed], id: \.self) { mood in
                    Button(action: {
                        selectedMood = selectedMood == mood ? nil : mood
                    }) {
                        VStack(spacing: 4) {
                            Text(mood.emoji)
                                .font(.title2)
                            
                            Text(mood.displayName)
                                .font(.caption2)
                        }
                        .foregroundColor(selectedMood == mood ? prayer.color : ColorPalette.secondary)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedMood == mood ? prayer.color.opacity(0.1) : ColorPalette.surface)
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Qada Toggle
    
    @ViewBuilder
    private var qadaToggle: some View {
        HStack {
            Toggle("Make-up Prayer (Qada)", isOn: $isQada)
                .font(.subheadline)
        }
    }
    
    // MARK: - Notes Section
    
    @ViewBuilder
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextField("Any thoughts or reflections...", text: $notes, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
        }
    }
    
    // MARK: - Gratitude Section
    
    @ViewBuilder
    private var gratitudeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gratitude")
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextField("What are you grateful for today?", text: $gratitudeNote, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(2...4)
        }
    }
    
    // MARK: - Actions
    
    private func quickComplete() async {
        isLoading = true
        await prayerTrackingService.logPrayerCompletion(prayer)
        isLoading = false
        onDismiss()
    }
    
    private func saveDetailedCompletion() async {
        isLoading = true
        
        await prayerTrackingService.logPrayerCompletion(
            prayer,
            at: Date(),
            location: nil,
            notes: notes.isEmpty ? nil : notes,
            mood: selectedMood,
            method: selectedMethod,
            duration: nil,
            congregation: selectedCongregation,
            isQada: isQada,
            hadithRemembered: nil,
            gratitudeNote: gratitudeNote.isEmpty ? nil : gratitudeNote,
            difficulty: nil,
            tags: []
        )
        
        isLoading = false
        onDismiss()
    }
}

// MARK: - Extensions

private extension PrayerMethod {
    var displayName: String {
        switch self {
        case .individual: return "Individual"
        case .congregation: return "Congregation"
        }
    }
}

private extension CongregationType {
    var displayName: String {
        switch self {
        case .individual: return "Individual"
        case .congregation: return "Mosque"
        case .family: return "Family"
        }
    }
}

private extension PrayerMood {
    var displayName: String {
        switch self {
        case .peaceful: return "Peaceful"
        case .grateful: return "Grateful"
        case .focused: return "Focused"
        case .rushed: return "Rushed"
        }
    }
    
    var emoji: String {
        switch self {
        case .peaceful: return "😌"
        case .grateful: return "🙏"
        case .focused: return "🧘"
        case .rushed: return "⏰"
        }
    }
}
