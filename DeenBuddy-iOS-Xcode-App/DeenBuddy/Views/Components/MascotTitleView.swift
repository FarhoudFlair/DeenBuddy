//
//  MascotTitleView.swift
//  DeenBuddy
//
//  Created by Claude on 2025-08-05.
//

import SwiftUI

/// Custom title view showing mascot character next to DeenBuddy title
struct MascotTitleView: View {
    let showMascot: Bool
    let titleText: String
    let mascotSize: CGFloat
    
    init(showMascot: Bool = true, titleText: String = "DeenBuddy", mascotSize: CGFloat = 45) {
        self.showMascot = showMascot
        self.titleText = titleText
        self.mascotSize = mascotSize
    }
    
    var body: some View {
        HStack(spacing: 10) {
            if showMascot {
                // Mascot character
                Image("DeenBuddyMascot")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: mascotSize, height: mascotSize)
                    .accessibilityLabel("DeenBuddy mascot character")
            }
            
            // App title
            Text(titleText)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(ColorPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .layoutPriority(1)
        }
        .accessibilityLabel(showMascot ? "DeenBuddy app with mascot" : titleText)
    }
}

// MARK: - Convenience Initializers

extension MascotTitleView {
    /// For main home screen title
    static func homeTitle(titleText: String = "DeenBuddy") -> MascotTitleView {
        MascotTitleView(showMascot: true, titleText: titleText, mascotSize: 45)
    }
    
    /// For navigation bar title (smaller)
    static func navigationTitle(titleText: String = "DeenBuddy") -> MascotTitleView {
        MascotTitleView(showMascot: true, titleText: titleText, mascotSize: 32)
    }
    
    /// For section headers
    static func sectionTitle(titleText: String, mascotSize: CGFloat = 30) -> MascotTitleView {
        MascotTitleView(showMascot: true, titleText: titleText, mascotSize: mascotSize)
    }
    
    /// Text only version
    static func textOnly(titleText: String) -> MascotTitleView {
        MascotTitleView(showMascot: false, titleText: titleText, mascotSize: 0)
    }
}

// MARK: - Preview

#Preview("Mascot Title Variations") {
    VStack(spacing: 30) {
        Text("Title Variations")
            .font(.headline)
            .padding(.top)
        
        VStack(spacing: 20) {
            MascotTitleView.homeTitle()
            
            MascotTitleView.navigationTitle()
            
            MascotTitleView.sectionTitle(titleText: "Prayer Times", mascotSize: 25)
            
            MascotTitleView.textOnly(titleText: "Settings")
        }
        
        Spacer()
    }
    .padding()
    .background(ColorPalette.backgroundPrimary)
}
