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
                // We render a range of beads centered around the current count
                ForEach(-3..<visibleBeads + 2, id: \.self) { index in
                    // Calculate the actual bead number (0 to targetCount-1)
                    // We handle negative indices to wrap around correctly for the loop
                    let rawIndex = currentCount + index
                    let beadIndex = (rawIndex % targetCount + targetCount) % targetCount
                    
                    let isMarkerBead = beadIndex == 0
                    
                    // Coloring Logic:
                    // index > 0: Already counted (passed center) -> Theme Color
                    // index == 0: Currently at center (Active) -> Theme Color
                    // index < 0: Upcoming (from top) -> White/Gray
                    let isCounted = index >= 0
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    colorForBead(isCounted: isCounted, isMarker: isMarkerBead, shade: .light),
                                    colorForBead(isCounted: isCounted, isMarker: isMarkerBead, shade: .dark)
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
                        // Marker indicator (small dot or ring)
                        .overlay(
                            Group {
                                if isMarkerBead {
                                    Circle()
                                        .stroke(Color.orange, lineWidth: 2)
                                        .frame(width: beadSize + 4, height: beadSize + 4)
                                }
                            }
                        )
                        .position(
                            x: centerX,
                            // Animation Logic:
                            // We add 'offset' to Y.
                            // When count increments, we snap offset to -(size+spacing) [Shift UP]
                            // Then animate offset to 0 [Slide DOWN]
                            y: centerY + (CGFloat(index) * (beadSize + beadSpacing)) + offset
                        )
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
    
    private enum Shade { case light, dark }
    
    private func colorForBead(isCounted: Bool, isMarker: Bool, shade: Shade) -> Color {
        if isMarker {
            // Gold/Orange for marker
            switch shade {
            case .light: return Color.orange.opacity(0.8)
            case .dark: return Color.orange
            }
        } else if isCounted {
            // Green/Theme for counted beads
            switch shade {
            case .light: return themeColor.opacity(0.8)
            case .dark: return themeColor
            }
        } else {
            // White/Gray for upcoming
            switch shade {
            case .light: return Color.white
            case .dark: return Color(UIColor.systemGray4)
            }
        }
    }
    
    private func animateBeadMovement() {
        // 1. Snap to "Previous" visual state (shifted UP)
        offset = -(beadSize + beadSpacing)
        
        // 2. Animate to "Current" state (Slide DOWN to 0)
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.8)) {
            offset = 0
        }
    }
}
