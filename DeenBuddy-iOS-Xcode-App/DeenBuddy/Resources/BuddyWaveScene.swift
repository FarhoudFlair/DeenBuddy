//
//  BuddyWaveScene.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-08-04.
//

import Foundation
import SpriteKit

final class BuddyWaveScene: SKScene {

   // MARK: – Config
   private let cols = 4
   private let rows = 4
   private let fps  = 8.0
   private let frameCount = 16         // 4x4 = 16 cells

   // MARK: – Lifecycle
   override func didMove(to view: SKView) {
      backgroundColor = .clear
      let sheet = SKTexture(imageNamed: "waving-spritesheet")
      let tex   = slice(sheet: sheet)

      // Guard against empty texture array
      guard !tex.isEmpty, let firstTexture = tex.first else {
         print("⚠️ BuddyWaveScene: Failed to slice sprite sheet, no textures available")
         return
      }

      let buddy = SKSpriteNode(texture: firstTexture)
      buddy.position = CGPoint(x: size.width/2, y: size.height/2)
      addChild(buddy)

      let animation = SKAction.animate(with: tex,
                                       timePerFrame: 1.0 / fps,
                                       resize: false,
                                       restore: false)
      let repeatAction = SKAction.repeatForever(animation)
      buddy.run(repeatAction)
   }

   // MARK: – Helper
   private func slice(sheet: SKTexture) -> [SKTexture] {
      var textures: [SKTexture] = []
      
      // Read frames left-to-right, top-to-bottom
      for row in 0..<rows {
         for col in 0..<cols {
            // SKTexture uses normalized coordinates (0,0) = bottom-left
            let x = CGFloat(col) / CGFloat(cols)
            let y = CGFloat(rows - 1 - row) / CGFloat(rows)  // Flip Y for top-to-bottom reading
            let width = 1.0 / CGFloat(cols)
            let height = 1.0 / CGFloat(rows)
            
            let rect = CGRect(x: x, y: y, width: width, height: height)
            let texture = SKTexture(rect: rect, in: sheet)
            textures.append(texture)
            
            // Stop if we've reached the desired frame count
            if textures.count >= frameCount {
               break
            }
         }
         if textures.count >= frameCount {
            break
         }
      }
      
      return textures
   }
}

