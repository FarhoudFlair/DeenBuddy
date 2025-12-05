import SwiftUI

struct TasbihView: View {
    @StateObject private var viewModel: TasbihViewModel<TasbihService>
    private let onShowHistory: () -> Void
    private let onShowSettings: () -> Void
    
    // Local optimistic counter to prevent race conditions in haptic feedback
    @State private var localCount: Int = 0
    
    // Haptic generators
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    
    init(
        tasbihService: TasbihService,
        onShowHistory: @escaping () -> Void,
        onShowSettings: @escaping () -> Void
    ) {
        self._viewModel = StateObject(wrappedValue: TasbihViewModel(service: tasbihService))
        self.onShowHistory = onShowHistory
        self.onShowSettings = onShowSettings
    }
    
    var body: some View {
        ZStack {
            // Background
            ColorPalette.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                    .padding(.horizontal)
                    .padding(.top)
                
                // Main Content
                ZStack {
                    // Bead String (Background Layer)
                    BeadStringView(
                        currentCount: viewModel.currentCount,
                        targetCount: viewModel.targetCount,
                        themeColor: ColorPalette.primary
                    )
                    .frame(maxWidth: 100) // Constrain width of the bead path
                    .padding(.vertical)
                    
                    // Info Overlay (Foreground Layer)
                    VStack {
                        Spacer()
                        
                        // Dhikr Text
                        if let dhikr = viewModel.currentSession?.dhikr ?? viewModel.availableDhikr.first(where: { $0.id == viewModel.selectedDhikrID }) {
                            VStack(spacing: 8) {
                                Text(dhikr.arabicText)
                                    .font(.system(size: 32, weight: .bold))
                                    .multilineTextAlignment(.center)
                                
                                Text(dhikr.transliteration)
                                    .font(.headline)
                                    .foregroundColor(ColorPalette.textSecondary)
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                        } else {
                            // Fallback for initial load
                            VStack(spacing: 8) {
                                Text("Select Dhikr")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(ColorPalette.textSecondary)
                                
                                Text("Tap to start")
                                    .font(.headline)
                                    .foregroundColor(ColorPalette.textSecondary)
                            }
                            .padding()
                        }
                        
                        Spacer()
                        
                        // Counter Display
                        VStack(spacing: 4) {
                            Text("\(viewModel.currentCount)")
                                .font(.system(size: 72, weight: .bold, design: .rounded))
                                .foregroundColor(ColorPalette.primary)
                                .contentTransition(.numericText())
                            
                            Text("Target: \(viewModel.targetCount)")
                                .font(.subheadline)
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        
                        Spacer()
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle()) // Make entire area tappable
                .onTapGesture {
                    performCount()
                }
                .accessibilityLabel("Count")
                .accessibilityHint("Double tap to increment count. Current count is \(viewModel.currentCount), target is \(viewModel.targetCount)")
                .accessibilityValue("\(viewModel.currentCount)")
                .accessibilityAddTraits(.isButton)
                
                // Footer Controls
                HStack {
                    Button(action: {
                        Task { await viewModel.service.resetSession() }
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                            .foregroundColor(ColorPalette.textSecondary)
                            .padding()
                            .background(ColorPalette.surfaceSecondary)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Dhikr Selector Button
                    Menu {
                        ForEach(viewModel.availableDhikr) { dhikr in
                            Button {
                                Task { await viewModel.changeDhikr(to: dhikr) }
                            } label: {
                                HStack {
                                    Text(dhikr.transliteration)
                                    if viewModel.selectedDhikrID == dhikr.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text("Change Dhikr")
                            Image(systemName: "chevron.up")
                        }
                        .font(.headline)
                        .foregroundColor(ColorPalette.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(ColorPalette.surfaceSecondary)
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        let newSoundState = !viewModel.service.currentCounter.soundFeedback
                        Task { await viewModel.service.setSoundFeedback(newSoundState) }
                    }) {
                        Image(systemName: viewModel.service.currentCounter.soundFeedback ? "speaker.wave.2.fill" : "speaker.slash")
                            .font(.title2)
                            .foregroundColor(ColorPalette.textSecondary)
                            .padding()
                            .background(ColorPalette.surfaceSecondary)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .task { 
            await viewModel.ensureSession()
            localCount = viewModel.currentCount
        }
        .onChange(of: viewModel.availableDhikr.count) { _ in
            // If a session still hasn't started and dhikr list is ready, start one
            Task { await viewModel.ensureSession() }
        }
        .onChange(of: viewModel.currentSession?.id) { _ in
            viewModel.syncStateWithSession()
            localCount = viewModel.currentCount
        }
        .onChange(of: viewModel.currentCount) { newVal in
            // Sync local count if it falls behind or resets
            if newVal == 0 || newVal > localCount {
                localCount = newVal
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { viewModel.showError = false }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    private var header: some View {
        HStack {
            Text("Tasbih")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: onShowHistory) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundColor(ColorPalette.textPrimary)
                }
                
                Button(action: onShowSettings) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundColor(ColorPalette.textPrimary)
                }
            }
        }
    }
    
    private func performCount() {
        // Optimistically increment local count
        localCount += 1
        
        // Haptic feedback logic based on local count
        if viewModel.service.currentCounter.hapticFeedback {
            if localCount % 33 == 0 {
                heavyImpact.impactOccurred()
            } else {
                lightImpact.impactOccurred()
            }
        }
        
        Task {
            await viewModel.increment(by: 1, playHaptics: false, playSound: true)
        }
    }
}
