import SwiftUI

/// Small crown badge for indicating premium-only UI elements
public struct PremiumFeatureBadgeView: View {

    // MARK: - Properties

    private let color: Color
    private let font: Font
    private let padding: CGFloat
    private let label: String

    // MARK: - Initialization

    public init(
        color: Color = .orange,
        font: Font = .caption,
        padding: CGFloat = 6,
        accessibilityLabel: String = "Premium feature"
    ) {
        self.color = color
        self.font = font
        self.padding = padding
        self.label = accessibilityLabel
    }

    public var body: some View {
        Image(systemName: "crown.fill")
            .font(font)
            .foregroundStyle(color)
            .padding(padding)
            .background(color.opacity(0.12))
            .clipShape(Circle())
            .accessibilityLabel(label)
    }
}
