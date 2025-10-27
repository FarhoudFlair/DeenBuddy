//
//  MascotAnimationView.swift
//  DeenBuddy
//
//  Created by Claude on 2025-08-05.
//

import SwiftUI
import SpriteKit

/// SwiftUI wrapper for the mascot animation system
struct MascotAnimationView: UIViewRepresentable {
    @Binding var shouldWave: Bool
    let animationType: AnimationType
    let size: CGSize
    
    enum AnimationType {
        case continuous    // For loading screens
        case onDemand     // For celebrations/interactions
        case celebration  // Special celebration animation
    }
    
    init(shouldWave: Binding<Bool> = .constant(false), 
         type: AnimationType = .continuous,
         size: CGSize = CGSize(width: 80, height: 80)) {
        self._shouldWave = shouldWave
        self.animationType = type
        self.size = size
    }
    
    func makeUIView(context: Context) -> SKView {
        let skView = SKView()
        skView.backgroundColor = UIColor.clear
        skView.allowsTransparency = true
        skView.showsFPS = false
        skView.showsNodeCount = false
        
        let scene = MascotScene()
        scene.size = size
        scene.scaleMode = .aspectFit
        scene.backgroundColor = UIColor.clear
        
        skView.presentScene(scene)
        
        // Store scene reference for updates
        context.coordinator.scene = scene
        
        return skView
    }
    
    func updateUIView(_ skView: SKView, context: Context) {
        guard let scene = context.coordinator.scene else { return }
        let was = context.coordinator.previousShouldWave
        let now = shouldWave

        switch animationType {
        case .continuous:
            if now {
                scene.startWaving()
            } else {
                scene.stopWaving()
            }
            
        case .onDemand:
            if now && !was {
                scene.waveOnce()
            }
            
        case .celebration:
            if now && !was {
                scene.celebrateAchievement()
            }
        }
        
        // Update previous state after handling transitions
        context.coordinator.previousShouldWave = now
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var scene: MascotScene?
        var previousShouldWave: Bool = false
    }
}

// MARK: - Convenience Initializers

extension MascotAnimationView {
    /// For loading screens - continuous gentle waving
    static func loading(size: CGSize = CGSize(width: 80, height: 80)) -> MascotAnimationView {
        MascotAnimationView(shouldWave: .constant(true), type: .continuous, size: size)
    }
    
    /// For prayer celebrations - triggered animation
    static func celebration(isTriggered: Binding<Bool>, size: CGSize = CGSize(width: 60, height: 60)) -> MascotAnimationView {
        MascotAnimationView(shouldWave: isTriggered, type: .celebration, size: size)
    }
    
    /// For interactive elements - wave once on demand
    static func interactive(shouldWave: Binding<Bool>, size: CGSize = CGSize(width: 80, height: 80)) -> MascotAnimationView {
        MascotAnimationView(shouldWave: shouldWave, type: .onDemand, size: size)
    }
}

// MARK: - Preview

#Preview("Mascot Animation Types") {
    VStack(spacing: 30) {
        Text("DeenBuddy Mascot Animations")
            .font(.title2)
            .fontWeight(.bold)
        
        VStack(spacing: 20) {
            VStack {
                Text("Loading Animation")
                    .font(.headline)
                MascotAnimationView.loading()
                    .frame(width: 100, height: 100)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }
            
            VStack {
                Text("Interactive Animation")
                    .font(.headline)
                MascotAnimationView.interactive(shouldWave: .constant(false))
                    .frame(width: 120, height: 120)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                Text("Tap to wave")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    .padding()
}