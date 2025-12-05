//
//  BuddyAnimationPreviewView.swift
//  DeenBuddy
//
//  Created by Claude on 2025-08-05.
//

import SwiftUI
import SpriteKit

/// Preview screen to test and showcase the buddy animation
struct BuddyAnimationPreviewView: View {
    @State private var selectedStyle: LoadingView.LoadingStyle = .prayerWithBuddy
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Style selector
                Picker("Loading Style", selection: $selectedStyle) {
                    Text("Prayer with Buddy").tag(LoadingView.LoadingStyle.prayerWithBuddy)
                    Text("Prayer Only").tag(LoadingView.LoadingStyle.prayer)
                    Text("Buddy Only").tag(LoadingView.LoadingStyle.spinner)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                Spacer()
                
                // Animation preview
                VStack(spacing: 20) {
                    if selectedStyle == .prayerWithBuddy {
                        LoadingView.prayerWithBuddy(message: "Loading DeenBuddy...")
                    } else if selectedStyle == .prayer {
                        LoadingView.prayer(message: "Loading prayer times...")
                    } else {
                        // Show just the buddy animation for comparison
                        VStack(spacing: 16) {
                            BuddyWaveView()
                                .frame(width: 80, height: 80)
                            
                            Text("Buddy Animation Only")
                                .bodyMedium()
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ColorPalette.surface)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .padding()
                
                Spacer()
                
                // Info text
                VStack(spacing: 8) {
                    Text("Buddy Animation Preview")
                        .headlineMedium()
                        .foregroundColor(ColorPalette.textPrimary)
                    
                    Text("Test the new animated loading screens with your friendly buddy companion")
                        .bodyMedium()
                        .foregroundColor(ColorPalette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .background(ColorPalette.backgroundPrimary)
            .navigationTitle("Animation Preview")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

#Preview("Buddy Animation Preview") {
    BuddyAnimationPreviewView()
}