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
                    let beadIndex = (currentCount + index) % targetCount
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
        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7)) {
            offset += beadSize + beadSpacing
        }
        
        // Reset offset after animation to create infinite scroll illusion
        // This is a simplified approach; for a perfect loop, we'd need more complex logic
        // but for a simple visual feedback, shifting and resetting (if we were managing a real list) works.
        // However, since we calculate position based on index relative to center, 
        // we actually want the beads to physically move down.
        // To make it "infinite" without resetting offset abruptly, we can just let offset grow?
        // No, that would float away.
        // Better approach for "infinite" strand:
        // The ForEach loop depends on `currentCount`. When `currentCount` increases by 1,
        // the beads effectively shift "up" by one slot in the data model (index + 1).
        // So we want to animate the transition from "aligned" to "shifted".
        
        // Actually, let's try a simpler visual trick:
        // We always draw beads at fixed positions relative to the center.
        // When count increments, we animate them moving DOWN (or UP).
        // Wait, if I count "1", I pull a bead TOWARDS me.
        // Usually on a tasbih, you pull the bead down with your thumb.
        // So beads should move DOWN.
        
        // Reset offset immediately? No.
        // The state change `currentCount` causes a re-render.
        // If we just change `currentCount`, the beads will "jump" to the new index positions.
        // We want them to slide.
        
        // Let's rethink the animation strategy for a stateless "infinite" view.
        // 1. View is at state N. Beads are at positions P0, P1, P2...
        // 2. Count becomes N+1. Beads are now effectively shifted in data.
        // 3. We want to animate from N to N+1.
        
        // If we use `id: \.self` on the loop index, SwiftUI views it as the "same" views.
        // We need to offset them by -1 * spacing initially, then animate to 0?
        // Or start at 0 and animate to +1 * spacing, then reset?
        
        // To simulate pulling beads DOWN (towards the user), we want them to move in the positive Y direction.
        // When count increments, the visual list effectively shifts "up" by one index (index 0 becomes index -1).
        // So we need to animate from a "higher" position (negative offset) to 0?
        // Or from 0 to positive offset?
        
        // Let's try: Start at 0. Animate to +spacing. Then reset.
        // This looks like the current beads sliding down.
        
        offset = 0
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            offset = beadSize + beadSpacing
        }
        
        // We need to reset the offset for the next tap, but we need to do it *after* the animation?
        // Or can we do the "infinite scroll" trick where we swap the offset instantly?
        // Since this is a stateless view driven by `currentCount`, when `currentCount` updates,
        // the view re-renders with new data.
        // If we want a continuous flow:
        // 1. Tap -> `currentCount` increments.
        // 2. View updates. Beads shift positions based on index.
        // 3. We want to animate the transition.
        
        // If we want to pull DOWN:
        // We want the bead at (centerX, centerY) to move to (centerX, centerY + spacing).
        // That means `offset` should go from 0 to `beadSize + beadSpacing`.
        
        // However, we need to reset it for the next tap.
        // The issue with SwiftUI state changes is that `currentCount` changes instantly.
        // So the beads jump to new positions.
        // To smooth this:
        // When `currentCount` changes, we should start with `offset = -(beadSize + beadSpacing)`
        // (which puts the NEW beads in the OLD positions)
        // and animate to `offset = 0`.
        
        // Wait, if beads move DOWN, the bead at index `i` moves to `i+1`'s spot?
        // No, if I pull a bead down, the string moves down.
        // So the bead that was at the top moves to the center.
        // That means beads are moving in +Y direction.
        
        // If `currentCount` increases, the bead indices shift.
        // `beadIndex = (currentCount + index) % targetCount`
        // If count goes 0 -> 1:
        // Index 0 was bead 0. Now index 0 is bead 1.
        // So the bead at the center CHANGED from 0 to 1.
        // This effectively means the beads moved UP (0 went up, 1 came up to take its place).
        // This is the opposite of what we want visually (pulling down).
        
        // To make it look like we pulled DOWN:
        // We need the animation to oppose the data shift.
        // The data shift moves beads "up" the chain.
        // We want to animate them moving "down".
        
        // Actually, if we want the beads to move DOWN, we should probably render them in reverse order?
        // Or just change the animation.
        
        // Let's stick to the "slide" effect.
        // To make it look like they are sliding DOWN:
        // We need to start at `offset = -(beadSize + beadSpacing)` and animate to `0`?
        // No, that would make them slide UP (from -Y to 0).
        // We want to slide DOWN (from -Y to 0? No, from 0 to +Y?)
        
        // Let's try this:
        // When count increments, the data shifts "up" (index 0 becomes bead 1).
        // We want to animate bead 0 moving DOWN.
        // But bead 0 is gone from the center spot!
        
        // Okay, the "infinite loop" trick usually works like this:
        // Animate from 0 to `spacing`.
        // Then instantly snap back to 0 (but with data shifted).
        // But here data shifts FIRST (because it's driven by parent state).
        // So we are at step "Snap back with data shifted".
        // Now we need to be at "Start position".
        // If data shifted "Up", and we want to look like we moved "Down"?
        // That's conflicting.
        
        // If we want to simulate pulling down, the NEXT bead (bead 1) should come from ABOVE.
        // Currently:
        // Index -1 is above.
        // When count becomes 1, Index 0 is bead 1.
        // So bead 1 appeared at Index 0 (Center).
        // It "jumped" from Index -1 (Above) to Index 0 (Center).
        // That IS a downward movement!
        
        // So the data shift naturally creates a downward jump.
        // We just need to smooth it.
        // To smooth a jump from -1 to 0:
        // We should start the view with `offset = -(beadSize + beadSpacing)` (so it visually stays at -1)
        // And animate to `offset = 0` (so it slides to 0).
        
        // So... `offset = -(beadSize + beadSpacing)` to `0` IS the correct animation for downward movement
        // IF the data shift is "Up" (which it is).
        
        // Wait, my previous analysis said the current code moves them UP.
        // Current code:
        // `offset += beadSize + beadSpacing` (accumulates?)
        // `offset = -(beadSize + beadSpacing)` then animate to `0`.
        
        // Let's look at the previous code again.
        // `offset = -(beadSize + beadSpacing)`
        // `withAnimation { offset = 0 }`
        // This starts at -Y (higher) and moves to 0 (lower).
        // This IS a downward animation.
        
        // Why did I think it was Up?
        // Maybe I misread the coordinate system or the `position` modifier.
        // `y: centerY + (CGFloat(index) * (beadSize + beadSpacing)) - offset`
        // If offset is negative (-50), y becomes `centerY + ... + 50`.
        // So it starts LOWER (positive Y).
        // And moves to 0 (Higher).
        // So it moves UP.
        
        // AHA!
        // `y - offset`.
        // If offset starts at -50: `y - (-50) = y + 50`.
        // So it starts 50px LOWER.
        // And animates to `y - 0 = y`.
        // So it moves UP (from y+50 to y).
        
        // So to move DOWN:
        // We want to start HIGHER (negative Y relative to final pos).
        // So we want `y - offset` to be `y - 50`.
        // So `offset` should be `50`.
        // Start at `offset = beadSize + beadSpacing`.
        // Animate to `0`.
        
        offset = beadSize + beadSpacing
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            offset = 0
        }
    }
}
