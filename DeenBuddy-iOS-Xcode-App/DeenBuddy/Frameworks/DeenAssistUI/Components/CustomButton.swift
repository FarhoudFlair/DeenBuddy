import SwiftUI

/// Custom button component with consistent styling
public struct CustomButton: View {
    let title: String
    let style: ButtonStyle
    let size: ButtonSize
    let action: () -> Void
    
    @State private var isPressed = false
    
    public init(
        _ title: String,
        style: ButtonStyle = .primary,
        size: ButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            HapticFeedback.medium()
            action()
        }) {
            Text(title)
                .buttonText()
                .foregroundColor(textColor)
                .frame(maxWidth: size.maxWidth)
                .frame(height: size.height)
                .background(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: size.cornerRadius)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
                .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius))
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .appAnimation(AppAnimations.quick, value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .buttonAccessibility(
            label: title,
            hint: "Double tap to activate"
        )
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return ColorPalette.primary
        case .secondary:
            return ColorPalette.surfacePrimary
        case .tertiary:
            return Color.clear
        case .destructive:
            return ColorPalette.error
        case .success:
            return ColorPalette.success
        }
    }
    
    private var textColor: Color {
        switch style {
        case .primary, .destructive, .success:
            return .white
        case .secondary:
            return ColorPalette.textPrimary
        case .tertiary:
            return ColorPalette.primary
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .primary, .destructive, .success:
            return Color.clear
        case .secondary:
            return ColorPalette.textTertiary.opacity(0.3)
        case .tertiary:
            return ColorPalette.primary
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .primary, .destructive, .success:
            return 0
        case .secondary, .tertiary:
            return 1
        }
    }
}

// MARK: - Button Styles

public extension CustomButton {
    enum ButtonStyle {
        case primary
        case secondary
        case tertiary
        case destructive
        case success
    }
    
    enum ButtonSize {
        case small
        case medium
        case large
        case extraLarge
        
        var height: CGFloat {
            switch self {
            case .small: return 36
            case .medium: return 44
            case .large: return 52
            case .extraLarge: return 60
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 10
            case .large: return 12
            case .extraLarge: return 14
            }
        }
        
        var maxWidth: CGFloat? {
            switch self {
            case .small: return 120
            case .medium, .large, .extraLarge: return .infinity
            }
        }
    }
}

// MARK: - Convenience Initializers

public extension CustomButton {
    static func primary(_ title: String, action: @escaping () -> Void) -> CustomButton {
        CustomButton(title, style: .primary, action: action)
    }
    
    static func secondary(_ title: String, action: @escaping () -> Void) -> CustomButton {
        CustomButton(title, style: .secondary, action: action)
    }
    
    static func tertiary(_ title: String, action: @escaping () -> Void) -> CustomButton {
        CustomButton(title, style: .tertiary, action: action)
    }
    
    static func destructive(_ title: String, action: @escaping () -> Void) -> CustomButton {
        CustomButton(title, style: .destructive, action: action)
    }
    
    static func success(_ title: String, action: @escaping () -> Void) -> CustomButton {
        CustomButton(title, style: .success, action: action)
    }
}

// MARK: - Preview

#Preview("Custom Buttons") {
    VStack(spacing: 16) {
        CustomButton.primary("Primary Button") {}
        CustomButton.secondary("Secondary Button") {}
        CustomButton.tertiary("Tertiary Button") {}
        CustomButton.success("Success Button") {}
        CustomButton.destructive("Destructive Button") {}
        
        HStack(spacing: 12) {
            CustomButton("Small", style: .primary, size: .small) {}
            CustomButton("Medium", style: .secondary, size: .medium) {}
        }
    }
    .padding()
    .background(ColorPalette.backgroundPrimary)
}
