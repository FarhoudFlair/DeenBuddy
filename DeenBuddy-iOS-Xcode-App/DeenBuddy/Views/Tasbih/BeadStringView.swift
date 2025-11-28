import SwiftUI

struct BeadStringView: View {
    let currentCount: Int
    let targetCount: Int
    let themeColor: Color
    
    // Animation state
    @State private var offset: CGFloat = 0
    
    // Constants
    private let beadSize: CGFloat = 40
    private let beadSpacing: CGFloat = 15
    private let visibleBeads = 7 // Number of beads visible on screen
    
    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2
            
            ZStack {
                // Draw the string
                Path { path in
                    path.move(to: CGPoint(x: centerX, y: 0))
                    path.addLine(to: CGPoint(x: centerX, y: geometry.size.height))
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                
                // Draw beads
                ForEach(-2..<visibleBeads + 2, id: \.self) { index in
                    let safeTarget = max(1, targetCount)
                    let beadIndex = (currentCount + index) % safeTarget
                    let isTargetBead = beadIndex == 0 && currentCount > 0
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    isTargetBead ? themeColor.opacity(0.8) : Color.white,
                                    isTargetBead ? themeColor : Color(UIColor.systemGray4)
                                ]),
                                center: .topLeading,
                                startRadius: 5,
                                endRadius: 30
                            )
                        )
                        .frame(width: beadSize, height: beadSize)
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 2, y: 2)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                        )
                        .position(
                            x: centerX,
                            y: centerY + (CGFloat(index) * (beadSize + beadSpacing)) - offset
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: offset)
                }
            }
            .drawingGroup() // Optimize rendering
            .contentShape(Rectangle())
            .clipped()
        }
        .onChange(of: currentCount) { _ in
            animateBeadMovement()
        }
    }
    
    private func animateBeadMovement() {
        // To simulate pulling beads DOWN (towards the user), we start with a positive offset
        // (which renders beads lower) and animate to 0.
        offset = beadSize + beadSpacing
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            offset = 0
        }
    }
}
