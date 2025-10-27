//
//  MascotDemoView.swift
//  DeenBuddy
//
//  Created by Claude on 2025-08-05.
//

import SwiftUI
import SpriteKit

/// Comprehensive demo and testing view for the new mascot animation system
struct MascotDemoView: View {
    @State private var continuousWaving = false
    @State private var triggerWaveOnce = false
    @State private var triggerCelebration = false
    @State private var selectedAnimationType: AnimationType = .continuous
    
    enum AnimationType: String, CaseIterable {
        case continuous = "Continuous Waving"
        case onDemand = "Wave Once"
        case celebration = "Prayer Celebration"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    headerSection
                    
                    // Main animation display
                    mainAnimationSection
                    
                    // Control buttons
                    controlButtonsSection
                    
                    // Animation type selector
                    animationTypeSection
                    
                    // Usage examples
                    usageExamplesSection
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Mascot Demo")
            .navigationBarTitleDisplayMode(.inline)
            .background(ColorPalette.backgroundPrimary)
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("🌙 DeenBuddy Mascot")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(ColorPalette.textPrimary)
            
            Text("Your friendly Islamic companion")
                .font(.subheadline)
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    @ViewBuilder
    private var mainAnimationSection: some View {
        VStack(spacing: 16) {
            // Main mascot display
            mascotDisplayView
                .frame(width: 200, height: 200)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(ColorPalette.surface)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                )
                .onTapGesture {
                    triggerInteraction()
                }
            
            Text("Tap the mascot to interact!")
                .font(.caption)
                .foregroundColor(ColorPalette.textSecondary)
        }
    }
    
    @ViewBuilder
    private var mascotDisplayView: some View {
        switch selectedAnimationType {
        case .continuous:
            MascotAnimationView(shouldWave: $continuousWaving, type: .continuous, size: CGSize(width: 180, height: 180))
            
        case .onDemand:
            MascotAnimationView(shouldWave: $triggerWaveOnce, type: .onDemand, size: CGSize(width: 180, height: 180))
            
        case .celebration:
            MascotAnimationView(shouldWave: $triggerCelebration, type: .celebration, size: CGSize(width: 180, height: 180))
        }
    }
    
    @ViewBuilder
    private var controlButtonsSection: some View {
        VStack(spacing: 16) {
            Text("Animation Controls")
                .font(.headline)
                .foregroundColor(ColorPalette.textPrimary)
            
            HStack(spacing: 15) {
                Button("Start Waving") {
                    continuousWaving = true
                }
                .buttonStyle(MascotPrimaryButtonStyle())
                .disabled(!selectedAnimationType.isContinuous)
                
                Button("Stop Waving") {
                    continuousWaving = false
                }
                .buttonStyle(MascotSecondaryButtonStyle())
                .disabled(!selectedAnimationType.isContinuous)
            }
            
            HStack(spacing: 15) {
                Button("Wave Once") {
                    triggerWaveOnce.toggle()
                }
                .buttonStyle(MascotPrimaryButtonStyle())
                .disabled(selectedAnimationType.isContinuous)
                
                Button("Celebrate Prayer! 🤲") {
                    triggerCelebration.toggle()
                }
                .buttonStyle(MascotCelebrationButtonStyle())
            }
        }
    }
    
    @ViewBuilder
    private var animationTypeSection: some View {
        VStack(spacing: 12) {
            Text("Animation Type")
                .font(.headline)
                .foregroundColor(ColorPalette.textPrimary)
            
            Picker("Animation Type", selection: $selectedAnimationType) {
                ForEach(AnimationType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedAnimationType) { _ in
                resetAnimations()
            }
        }
    }
    
    @ViewBuilder
    private var usageExamplesSection: some View {
        VStack(spacing: 20) {
            Text("Usage Examples")
                .font(.headline)
                .foregroundColor(ColorPalette.textPrimary)
            
            VStack(spacing: 16) {
                UsageExampleRow(
                    title: "Loading Screen",
                    description: "Gentle continuous waving during app loading",
                    mascotView: MascotAnimationView.loading(size: CGSize(width: 60, height: 60))
                )
                
                UsageExampleRow(
                    title: "Prayer Completed",
                    description: "Celebration animation when prayer is marked complete",
                    mascotView: MascotAnimationView.celebration(
                        isTriggered: .constant(false),
                        size: CGSize(width: 60, height: 60)
                    )
                )
                
                UsageExampleRow(
                    title: "Settings Preview",
                    description: "Interactive mascot in app settings",
                    mascotView: MascotAnimationView.interactive(
                        shouldWave: .constant(false),
                        size: CGSize(width: 60, height: 60)
                    )
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorPalette.surface.opacity(0.5))
        )
    }
    
    private func triggerInteraction() {
        switch selectedAnimationType {
        case .continuous:
            continuousWaving.toggle()
        case .onDemand:
            triggerWaveOnce.toggle()
        case .celebration:
            triggerCelebration.toggle()
        }
    }
    
    private func resetAnimations() {
        continuousWaving = false
        triggerWaveOnce = false
        triggerCelebration = false
    }
}

// MARK: - Usage Example Row

struct UsageExampleRow: View {
    let title: String
    let description: String
    let mascotView: MascotAnimationView
    
    var body: some View {
        HStack(spacing: 16) {
            mascotView
                .frame(width: 60, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorPalette.backgroundSecondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ColorPalette.textPrimary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(ColorPalette.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
}

// MARK: - Button Styles

struct MascotPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(ColorPalette.primary)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct MascotSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(ColorPalette.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ColorPalette.primary, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct MascotCelebrationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [ColorPalette.accent, ColorPalette.primary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Extensions

extension MascotDemoView.AnimationType {
    var isContinuous: Bool {
        self == .continuous
    }
}

// MARK: - Preview

#Preview("Mascot Demo") {
    MascotDemoView()
}