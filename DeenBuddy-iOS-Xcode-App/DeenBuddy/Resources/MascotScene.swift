//
//  MascotScene.swift
//  DeenBuddy
//
//  Created by Claude on 2025-08-05.
//

import Foundation
import SpriteKit
import UIKit

/// Advanced mascot animation scene using iOS Sprite Atlas
class MascotScene: SKScene {
    private var mascot: SKSpriteNode!
    private var waveAnimation: SKAction!
    private var isWaving = false
    
    override func didMove(to view: SKView) {
        backgroundColor = .clear
        setupMascot()
        createWaveAnimation()
    }
    
    private func setupMascot() {
        // Load from Sprite Atlas - proper iOS way
        let atlas = SKTextureAtlas(named: "MascotSprites")
        let firstFrame = atlas.textureNamed("mascot_frames")
        
        mascot = SKSpriteNode(texture: firstFrame)
        mascot.position = CGPoint(x: size.width / 2, y: size.height / 2)
        
        // Scale to fit the scene size appropriately  
        let scaleX = size.width * 0.8 / mascot.size.width
        let scaleY = size.height * 0.8 / mascot.size.height
        let scale = min(scaleX, scaleY)
        mascot.setScale(scale)
        
        addChild(mascot)
    }
    
    private func createWaveAnimation() {
        // Slower, calmer animation for spiritual context
        waveAnimation = loadAnimationFrames(timePerFrame: 0.15) // 8 frames = 1.2 seconds
    }
    
    /// Load animation frames from sprite atlas and create SKAction
    /// - Parameter timePerFrame: Duration per frame (default 0.15s for calm animation)
    /// - Returns: SKAction animation ready to run
    private func loadAnimationFrames(timePerFrame: TimeInterval = 0.15) -> SKAction {
        // Load sprite atlas
        let atlas = SKTextureAtlas(named: "MascotSprites")
        let spriteSheetTexture = atlas.textureNamed("mascot_frames")
        let spriteSheetImage = spriteSheetTexture.cgImage()
        let spriteSheet = UIImage(cgImage: spriteSheetImage)
        
        var frames: [SKTexture] = []
        let frameWidth = spriteSheet.size.width / 4  // 4 columns
        let frameHeight = spriteSheet.size.height / 2 // 2 rows
        
        // Extract 8 frames from 4x2 grid
        for row in 0..<2 {
            for col in 0..<4 {
                let x = CGFloat(col) * frameWidth
                let y = CGFloat(row) * frameHeight
                let rect = CGRect(x: x, y: y, width: frameWidth, height: frameHeight)
                
                if let frameImage = cropImage(spriteSheet, toRect: rect) {
                    let texture = SKTexture(image: frameImage)
                    texture.filteringMode = .nearest  // Pixel-perfect sprites
                    frames.append(texture)
                }
            }
        }
        
        // Return animation action with specified timing
        return SKAction.animate(with: frames, timePerFrame: timePerFrame)
    }
    
    private func cropImage(_ image: UIImage, toRect rect: CGRect) -> UIImage? {
        let scale = image.scale
        let scaledRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.size.width * scale,
            height: rect.size.height * scale
        )
        
        guard let cgImage = image.cgImage?.cropping(to: scaledRect) else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: image.imageOrientation)
    }
    
    func startWaving() {
        guard !isWaving else { return }
        isWaving = true
        
        let repeatWave = SKAction.repeatForever(waveAnimation)
        mascot.run(repeatWave, withKey: "waving")
    }
    
    func stopWaving() {
        isWaving = false
        mascot.removeAction(forKey: "waving")
        
        // Return to first frame from atlas
        let atlas = SKTextureAtlas(named: "MascotSprites")
        let firstFrame = atlas.textureNamed("mascot_frames")
        mascot.texture = firstFrame
    }
    
    func waveOnce() {
        guard !isWaving else { return }
        isWaving = true
        
        let waveOnce = SKAction.sequence([
            waveAnimation,
            SKAction.run { [weak self] in
                self?.stopWaving()
            }
        ])
        
        mascot.run(waveOnce)
    }
    
    // For prayer celebration - more enthusiastic waving
    func celebrateAchievement() {
        guard !isWaving else { return }
        isWaving = true
        
        // Faster celebration animation (0.1s vs 0.15s for normal wave)
        let celebrationAnimation = loadAnimationFrames(timePerFrame: 0.1)
        let repeatCelebration = SKAction.repeat(celebrationAnimation, count: 3)
        let returnToIdle = SKAction.run { [weak self] in
            self?.stopWaving()
        }
        
        let fullCelebration = SKAction.sequence([repeatCelebration, returnToIdle])
        mascot.run(fullCelebration)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        waveOnce()
    }
}