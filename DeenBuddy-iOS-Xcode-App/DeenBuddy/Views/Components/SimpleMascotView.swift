//
//  SimpleMascotView.swift
//  DeenBuddy
//
//  Created by Claude on 2025-08-05.
//

import SwiftUI

/// Simple, reliable mascot view using static PNG
struct SimpleMascotView: View {
    let size: CGFloat
    let showPulse: Bool
    
    @State private var isPulsing = false
    
    init(size: CGFloat = 80, showPulse: Bool = true) {
        self.size = size
        self.showPulse = showPulse
    }
    
    var body: some View {
        Image("DeenBuddyMascot")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .scaleEffect(showPulse && isPulsing ? 1.05 : 1.0)
            .animation(
                showPulse ? 
                Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true) : 
                nil,
                value: isPulsing
            )
            .onAppear {
                if showPulse {
                    isPulsing = true
                }
            }
            .onDisappear {
                isPulsing = false
            }
            .accessibilityLabel("DeenBuddy mascot")
            .accessibilityHint("Friendly companion for your Islamic prayer journey")
    }
}

// MARK: - Convenience Initializers

extension SimpleMascotView {
    /// For loading screens with gentle pulse
    static func loading(size: CGFloat = 80) -> SimpleMascotView {
        SimpleMascotView(size: size, showPulse: true)
    }
    
    /// For corner placement without animation
    static func corner(size: CGFloat = 50) -> SimpleMascotView {
        SimpleMascotView(size: size, showPulse: false)
    }
    
    /// For celebrations with pulse
    static func celebration(size: CGFloat = 60) -> SimpleMascotView {
        SimpleMascotView(size: size, showPulse: true)
    }
    
    /// Static version without any animation
    static func still(size: CGFloat = 80) -> SimpleMascotView {
        SimpleMascotView(size: size, showPulse: false)
    }
}

// MARK: - Preview

#Preview("Simple Mascot Variations") {
    VStack(spacing: 30) {
        Text("DeenBuddy Mascot Variations")
            .font(.title2)
            .fontWeight(.bold)
        
        HStack(spacing: 20) {
            VStack {
                SimpleMascotView.loading()
                Text("Loading (80px)")
                    .font(.caption)
            }
            
            VStack {
                SimpleMascotView.corner()
                Text("Corner (50px)")
                    .font(.caption)
            }
            
            VStack {
                SimpleMascotView.celebration()
                Text("Celebration (60px)")
                    .font(.caption)
            }
        }
        
        VStack {
            SimpleMascotView.still(size: 100)
            Text("Static (100px)")
                .font(.caption)
        }
    }
    .padding()
}