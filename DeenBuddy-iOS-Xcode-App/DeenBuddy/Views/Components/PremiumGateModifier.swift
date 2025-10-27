import SwiftUI

/// View modifier that gates content behind a premium subscription
public struct PremiumGateModifier: ViewModifier {
    let feature: PremiumFeature
    let coordinator: AppCoordinator
    
    public func body(content: Content) -> some View {
        let entitled = coordinator.subscriptionService.checkEntitlement(for: feature)
        return ZStack(alignment: .topTrailing) {
            // Underlying content is only interactive when entitled
            content
                .allowsHitTesting(entitled)

            // Tap-capturing overlay only when NOT entitled
            if !entitled {
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        coordinator.showPaywall()
                    }
            }

            // Crown overlay with accessibility for non-entitled state
            if !entitled {
                Image(systemName: "crown.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
                    .padding(6)
                    // Accessibility
                    .accessibilityLabel(Text("Premium feature"))
                    .accessibilityHint(Text("Available with premium subscription"))
                    .accessibilityAddTraits(.isImage)
                    .accessibilityHidden(false)
            }
        }
    }
}

public extension View {
    func requiresPremium(_ feature: PremiumFeature, coordinator: AppCoordinator) -> some View {
        modifier(PremiumGateModifier(feature: feature, coordinator: coordinator))
    }
}


