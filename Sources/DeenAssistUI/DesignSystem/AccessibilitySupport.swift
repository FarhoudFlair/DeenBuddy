import SwiftUI

/// Accessibility support utilities and modifiers
public struct AccessibilitySupport {
    
    // MARK: - Dynamic Type Support
    
    /// Check if user prefers larger text sizes
    public static var prefersLargerText: Bool {
        UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory
    }
    
    /// Get scaled font size based on user preferences
    public static func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }
    
    // MARK: - VoiceOver Support
    
    /// Check if VoiceOver is running
    public static var isVoiceOverRunning: Bool {
        UIAccessibility.isVoiceOverRunning
    }
    
    /// Check if Switch Control is running
    public static var isSwitchControlRunning: Bool {
        UIAccessibility.isSwitchControlRunning
    }
    
    // MARK: - Reduce Motion Support
    
    /// Check if user prefers reduced motion
    public static var prefersReducedMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
    
    // MARK: - High Contrast Support
    
    /// Check if user prefers increased contrast
    public static var prefersHighContrast: Bool {
        UIAccessibility.isDarkerSystemColorsEnabled
    }
}

// MARK: - Accessibility Modifiers

public extension View {
    
    /// Add comprehensive accessibility support to a view
    func accessibilityEnhanced(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = [],
        actions: [AccessibilityAction] = []
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
            .accessibilityActions {
                ForEach(actions, id: \.name) { action in
                    Button(action.name, action: action.action)
                }
            }
    }
    
    /// Make view accessible for prayer time display
    func prayerTimeAccessibility(
        prayer: String,
        time: String,
        status: String,
        isNext: Bool = false
    ) -> some View {
        let label = isNext ? "Next prayer: \(prayer)" : "\(prayer) prayer"
        let value = "\(time), \(status)"
        let hint = isNext ? "This is your next prayer time" : ""
        
        return self.accessibilityEnhanced(
            label: label,
            hint: hint,
            value: value,
            traits: isNext ? [.startsMediaSession] : []
        )
    }
    
    /// Make countdown timer accessible
    func countdownAccessibility(
        prayer: String,
        timeRemaining: String
    ) -> some View {
        self.accessibilityEnhanced(
            label: "Next prayer countdown",
            hint: "Time remaining until \(prayer) prayer",
            value: timeRemaining,
            traits: [.updatesFrequently]
        )
    }
    
    /// Make button accessible with proper traits
    func buttonAccessibility(
        label: String,
        hint: String? = nil,
        isEnabled: Bool = true
    ) -> some View {
        var traits: AccessibilityTraits = [.isButton]
        if !isEnabled {
            traits.insert(.isNotEnabled)
        }
        
        return self.accessibilityEnhanced(
            label: label,
            hint: hint,
            traits: traits
        )
    }
    
    /// Make navigation accessible
    func navigationAccessibility(
        label: String,
        destination: String
    ) -> some View {
        self.accessibilityEnhanced(
            label: label,
            hint: "Navigates to \(destination)",
            traits: [.isButton, .isLink]
        )
    }
    
    /// Add haptic feedback for accessibility
    func accessibilityHaptic(
        style: UIImpactFeedbackGenerator.FeedbackStyle = .medium
    ) -> some View {
        self.onTapGesture {
            if AccessibilitySupport.isVoiceOverRunning {
                let impactFeedback = UIImpactFeedbackGenerator(style: style)
                impactFeedback.impactOccurred()
            }
        }
    }
    
    /// Conditional animation based on reduce motion preference
    func accessibilityAnimation<V: Equatable>(
        _ animation: Animation?,
        value: V
    ) -> some View {
        if AccessibilitySupport.prefersReducedMotion {
            return self.animation(nil, value: value)
        } else {
            return self.animation(animation, value: value)
        }
    }
    
    /// Conditional transition based on reduce motion preference
    func accessibilityTransition(_ transition: AnyTransition) -> some View {
        if AccessibilitySupport.prefersReducedMotion {
            return self.transition(.identity)
        } else {
            return self.transition(transition)
        }
    }
}

// MARK: - Accessibility Action

public struct AccessibilityAction {
    let name: String
    let action: () -> Void
    
    public init(name: String, action: @escaping () -> Void) {
        self.name = name
        self.action = action
    }
}

// MARK: - High Contrast Colors

public extension ColorPalette {
    
    /// Get high contrast version of primary color
    static var accessiblePrimary: Color {
        AccessibilitySupport.prefersHighContrast ? 
            Color(red: 0.0, green: 0.4, blue: 0.2) : // Darker green
            primary
    }
    
    /// Get high contrast version of text color
    static var accessibleTextPrimary: Color {
        AccessibilitySupport.prefersHighContrast ?
            Color.primary : // Pure black/white
            textPrimary
    }
    
    /// Get high contrast version of background color
    static var accessibleBackground: Color {
        AccessibilitySupport.prefersHighContrast ?
            Color(.systemBackground) : // System background
            backgroundPrimary
    }
}

// MARK: - Accessibility-Aware Components

/// Button that adapts to accessibility preferences
public struct AccessibleButton: View {
    let title: String
    let action: () -> Void
    let style: CustomButton.ButtonStyle
    let isEnabled: Bool
    
    public init(
        _ title: String,
        style: CustomButton.ButtonStyle = .primary,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isEnabled = isEnabled
        self.action = action
    }
    
    public var body: some View {
        CustomButton(title, style: style) {
            // Add haptic feedback for accessibility
            if AccessibilitySupport.isVoiceOverRunning {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
            action()
        }
        .buttonAccessibility(
            label: title,
            hint: "Double tap to activate",
            isEnabled: isEnabled
        )
        .disabled(!isEnabled)
    }
}

/// Text that scales with Dynamic Type
public struct AccessibleText: View {
    let text: String
    let style: Font
    let color: Color
    
    public init(
        _ text: String,
        style: Font = Typography.bodyMedium,
        color: Color = ColorPalette.textPrimary
    ) {
        self.text = text
        self.style = style
        self.color = AccessibilitySupport.prefersHighContrast ? 
            ColorPalette.accessibleTextPrimary : color
    }
    
    public var body: some View {
        Text(text)
            .font(style)
            .foregroundColor(color)
            .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}

// MARK: - Accessibility Testing Helpers

#if DEBUG
public struct AccessibilityTestView: View {
    @State private var showingAccessibilityInfo = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 16) {
            Button("Show Accessibility Info") {
                showingAccessibilityInfo = true
            }
            
            Text("VoiceOver: \(AccessibilitySupport.isVoiceOverRunning ? "On" : "Off")")
            Text("Reduce Motion: \(AccessibilitySupport.prefersReducedMotion ? "On" : "Off")")
            Text("High Contrast: \(AccessibilitySupport.prefersHighContrast ? "On" : "Off")")
            Text("Large Text: \(AccessibilitySupport.prefersLargerText ? "On" : "Off")")
        }
        .alert("Accessibility Settings", isPresented: $showingAccessibilityInfo) {
            Button("OK") {}
        } message: {
            Text("""
            VoiceOver: \(AccessibilitySupport.isVoiceOverRunning ? "Enabled" : "Disabled")
            Reduce Motion: \(AccessibilitySupport.prefersReducedMotion ? "Enabled" : "Disabled")
            High Contrast: \(AccessibilitySupport.prefersHighContrast ? "Enabled" : "Disabled")
            Large Text: \(AccessibilitySupport.prefersLargerText ? "Enabled" : "Disabled")
            """)
        }
    }
}
#endif

// MARK: - Preview

#Preview("Accessibility Support") {
    VStack(spacing: 20) {
        AccessibleText("Sample Text", style: Typography.headlineSmall)
        
        AccessibleButton("Accessible Button") {
            print("Button tapped")
        }
        
        #if DEBUG
        AccessibilityTestView()
        #endif
    }
    .padding()
    .background(ColorPalette.accessibleBackground)
}
