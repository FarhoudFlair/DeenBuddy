import SwiftUI

/// Animation system for consistent app-wide animations
public struct AppAnimations {
    
    // MARK: - Standard Animations
    
    /// Quick animation for button presses and small interactions
    public static let quick = Animation.easeInOut(duration: 0.2)
    
    /// Standard animation for most UI transitions
    public static let standard = Animation.easeInOut(duration: 0.3)
    
    /// Smooth animation for larger transitions
    public static let smooth = Animation.easeInOut(duration: 0.5)
    
    /// Gentle animation for subtle changes
    public static let gentle = Animation.easeInOut(duration: 0.8)
    
    // MARK: - Spring Animations
    
    /// Bouncy spring for playful interactions
    public static let bouncy = Animation.spring(
        response: 0.5,
        dampingFraction: 0.6,
        blendDuration: 0.3
    )
    
    /// Smooth spring for natural feeling transitions
    public static let smoothSpring = Animation.spring(
        response: 0.4,
        dampingFraction: 0.8,
        blendDuration: 0.2
    )
    
    /// Snappy spring for quick feedback
    public static let snappy = Animation.spring(
        response: 0.3,
        dampingFraction: 0.9,
        blendDuration: 0.1
    )
    
    // MARK: - Specialized Animations
    
    /// Animation for prayer time updates
    public static let prayerUpdate = Animation.easeInOut(duration: 0.4)
    
    /// Animation for countdown timer updates
    public static let timerUpdate = Animation.linear(duration: 1.0)
    
    /// Animation for loading states
    public static let loading = Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
    
    /// Animation for error states
    public static let error = Animation.spring(
        response: 0.3,
        dampingFraction: 0.7,
        blendDuration: 0.2
    )
    
    /// Animation for success states
    public static let success = Animation.spring(
        response: 0.4,
        dampingFraction: 0.6,
        blendDuration: 0.3
    )
}

// MARK: - Transition System

public struct AppTransitions {
    
    /// Slide transition for screen changes
    nonisolated(unsafe) public static let slide = AnyTransition.asymmetric(
        insertion: .move(edge: .trailing),
        removal: .move(edge: .leading)
    )
    
    /// Fade transition for overlays
    nonisolated(unsafe) public static let fade = AnyTransition.opacity
    
    /// Scale transition for modals
    nonisolated(unsafe) public static let scale = AnyTransition.scale(scale: 0.8).combined(with: .opacity)
    
    /// Push transition for navigation
    nonisolated(unsafe) public static let push = AnyTransition.asymmetric(
        insertion: .move(edge: .bottom),
        removal: .move(edge: .top)
    )
    
    /// Slide up transition for sheets
    nonisolated(unsafe) public static let slideUp = AnyTransition.move(edge: .bottom)
    
    /// Custom transition for prayer cards
    nonisolated(unsafe) public static let prayerCard = AnyTransition.asymmetric(
        insertion: .scale(scale: 0.8).combined(with: .opacity),
        removal: .scale(scale: 1.1).combined(with: .opacity)
    )
}

// MARK: - Haptic Feedback System

public struct HapticFeedback {
    
    /// Light haptic feedback for subtle interactions
    @MainActor
    public static func light() {
        guard !AccessibilitySupport.prefersReducedMotion else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    /// Medium haptic feedback for standard interactions
    @MainActor
    public static func medium() {
        guard !AccessibilitySupport.prefersReducedMotion else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    /// Heavy haptic feedback for important interactions
    @MainActor
    public static func heavy() {
        guard !AccessibilitySupport.prefersReducedMotion else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    /// Success haptic feedback
    @MainActor
    public static func success() {
        guard !AccessibilitySupport.prefersReducedMotion else { return }
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    /// Warning haptic feedback
    @MainActor
    public static func warning() {
        guard !AccessibilitySupport.prefersReducedMotion else { return }
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
    }
    
    /// Error haptic feedback
    @MainActor
    public static func error() {
        guard !AccessibilitySupport.prefersReducedMotion else { return }
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
    
    /// Selection haptic feedback
    @MainActor
    public static func selection() {
        guard !AccessibilitySupport.prefersReducedMotion else { return }
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
}

// MARK: - Animation Modifiers

public extension View {
    
    /// Apply standard app animation with accessibility support
    @MainActor
    func appAnimation<V: Equatable>(
        _ animation: Animation?,
        value: V
    ) -> some View {
        if AccessibilitySupport.prefersReducedMotion {
            return self.animation(nil, value: value)
        } else {
            return self.animation(animation, value: value)
        }
    }
    
    /// Apply standard app transition with accessibility support
    @MainActor
    func appTransition(_ transition: AnyTransition) -> some View {
        if AccessibilitySupport.prefersReducedMotion {
            return AnyView(self.transition(.identity))
        } else {
            return AnyView(self.transition(transition))
        }
    }
    
    /// Add button press animation with haptic feedback
    func buttonPressAnimation(
        haptic: Bool = true,
        style: UIImpactFeedbackGenerator.FeedbackStyle = .medium
    ) -> some View {
        self.scaleEffect(1.0)
            .onTapGesture {
                if haptic {
                    Task { @MainActor in
                        let impactFeedback = UIImpactFeedbackGenerator(style: style)
                        impactFeedback.impactOccurred()
                    }
                }
            }
            .appAnimation(AppAnimations.quick, value: UUID())
    }
    
    /// Add loading animation
    func loadingAnimation(isLoading: Bool) -> some View {
        self
            .opacity(isLoading ? 0.6 : 1.0)
            .appAnimation(AppAnimations.standard, value: isLoading)
    }
    
    /// Add shake animation for errors
    func shakeAnimation(trigger: Bool) -> some View {
        self
            .offset(x: trigger ? 5 : 0)
            .appAnimation(
                trigger ? 
                Animation.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true) :
                AppAnimations.quick,
                value: trigger
            )
    }
    
    /// Add pulse animation for attention
    func pulseAnimation(isActive: Bool) -> some View {
        self
            .scaleEffect(isActive ? 1.05 : 1.0)
            .appAnimation(
                isActive ?
                Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                AppAnimations.standard,
                value: isActive
            )
    }
    
    /// Add slide in animation
    func slideInAnimation(
        from edge: Edge = .bottom,
        delay: Double = 0
    ) -> some View {
        self
            .appTransition(.move(edge: edge))
            .appAnimation(
                AppAnimations.smoothSpring.delay(delay),
                value: true
            )
    }
    
    /// Add fade in animation
    func fadeInAnimation(delay: Double = 0) -> some View {
        self
            .opacity(1.0)
            .appTransition(.opacity)
            .appAnimation(
                AppAnimations.standard.delay(delay),
                value: true
            )
    }
}

// MARK: - Animated Components

/// Animated loading dots
public struct AnimatedLoadingDots: View {
    @State private var isAnimating = false
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(ColorPalette.primary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .appAnimation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

/// Animated checkmark
public struct AnimatedCheckmark: View {
    let isVisible: Bool
    
    public init(isVisible: Bool) {
        self.isVisible = isVisible
    }
    
    public var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundColor(ColorPalette.success)
            .scaleEffect(isVisible ? 1.0 : 0.0)
            .appAnimation(AppAnimations.bouncy, value: isVisible)
    }
}

/// Animated progress ring
public struct AnimatedProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    
    public init(progress: Double, lineWidth: CGFloat = 8) {
        self.progress = progress
        self.lineWidth = lineWidth
    }
    
    public var body: some View {
        ZStack {
            Circle()
                .stroke(ColorPalette.textTertiary.opacity(0.3), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ColorPalette.primary,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .appAnimation(AppAnimations.smooth, value: progress)
        }
    }
}

// MARK: - Preview

#Preview("Animations") {
    VStack(spacing: 30) {
        AnimatedLoadingDots()
        
        AnimatedCheckmark(isVisible: true)
        
        AnimatedProgressRing(progress: 0.7)
            .frame(width: 60, height: 60)
        
        Button("Test Button") {}
            .buttonPressAnimation()
    }
    .padding()
    .background(ColorPalette.backgroundPrimary)
}
