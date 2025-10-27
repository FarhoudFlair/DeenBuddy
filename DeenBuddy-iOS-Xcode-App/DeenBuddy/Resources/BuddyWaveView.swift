//
//  BuddyWaveView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-08-04.
//

import SwiftUI
import SpriteKit
import UIKit

struct BuddyWaveView: UIViewRepresentable {
   func makeUIView(context: Context) -> SKView {
      let skView = SKView()
      let placeholderSize = CGSize(width: 200, height: 200)
      let scene = BuddyWaveScene(size: placeholderSize)
      scene.scaleMode = .aspectFit
      skView.presentScene(scene)
      skView.backgroundColor = .clear
      skView.allowsTransparency = true
      return skView
   }
   func updateUIView(_ uiView: SKView, context: Context) {
      let newSize = uiView.bounds.size
      if newSize.width > 0 && newSize.height > 0 {
         if let scene = uiView.scene as? BuddyWaveScene, scene.size != newSize {
            scene.size = newSize
         }
      }
   }
}
