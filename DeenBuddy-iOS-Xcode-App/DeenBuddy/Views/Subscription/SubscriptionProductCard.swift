import SwiftUI

/// Individual subscription product card
public struct SubscriptionProductCard: View {

    let product: SubscriptionProduct
    let isSelected: Bool
    let onTap: () -> Void

    public init(product: SubscriptionProduct, isSelected: Bool, onTap: @escaping () -> Void) {
        self.product = product
        self.isSelected = isSelected
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                if product.isPopular {
                    Text(LocalizedStringKey("MostPopularLabel"))
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(product.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(product.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(product.priceFormatted)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(isSelected ? .white : .primary)

                    Text(String(format: NSLocalizedString("per_period_format", comment: "Per period format, e.g., per Month"), product.period.shortDisplayName))
                        .font(.caption)
                        .foregroundColor(isSelected ? Color.white.opacity(0.8) : .secondary)

                    if let savings = product.savings, !savings.isEmpty {
                        Text(savings)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(isSelected ? Color.white.opacity(0.9) : .green)
                    }
                }
            }
            .frame(width: 220, height: 180, alignment: .leading)
            .padding(20)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(borderColor, lineWidth: isSelected ? 2.5 : 1)
            )
            .overlay(selectionIndicator, alignment: .topTrailing)
            .shadow(color: isSelected ? Color.orange.opacity(0.25) : Color.black.opacity(0.08), radius: isSelected ? 12 : 8, x: 0, y: isSelected ? 8 : 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(product.displayName), \(product.priceFormatted) per \(product.period.shortDisplayName)")
        .accessibilityHint(isSelected ? "Selected. Double tap to choose a different plan." : "Double tap to select this plan.")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var background: some View {
        Group {
            if isSelected {
                LinearGradient(
                    colors: [Color.orange, Color.orange.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else if product.isPopular {
                LinearGradient(
                    colors: [Color.orange.opacity(0.12), Color.orange.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color(.systemBackground)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var borderColor: Color {
        if isSelected {
            return .white
        } else if product.isPopular {
            return Color.orange.opacity(0.35)
        } else {
            return Color(.systemGray4)
        }
    }

    @ViewBuilder
    private var selectionIndicator: some View {
        if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
        }
    }
}

