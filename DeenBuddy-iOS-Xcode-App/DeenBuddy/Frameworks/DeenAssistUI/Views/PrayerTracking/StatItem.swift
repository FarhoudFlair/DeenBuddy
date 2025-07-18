import SwiftUI

/// Reusable component for displaying statistics with icon, title, and value
public struct StatItem: View {
    
    // MARK: - Properties
    
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    // MARK: - Initialization
    
    public init(
        title: String,
        value: String,
        icon: String,
        color: Color = ColorPalette.primary
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 8) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color)
            }
            
            // Value
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(ColorPalette.primary)
            
            // Title
            Text(title)
                .font(.caption)
                .foregroundColor(ColorPalette.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#if DEBUG
struct StatItem_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 20) {
            StatItem(
                title: "This Week",
                value: "85%",
                icon: "calendar.badge.clock"
            )
            
            StatItem(
                title: "This Month",
                value: "78%",
                icon: "chart.line.uptrend.xyaxis",
                color: .green
            )
            
            StatItem(
                title: "Best Streak",
                value: "12 days",
                icon: "flame.fill",
                color: .orange
            )
        }
        .padding()
        .background(ColorPalette.background)
        .previewLayout(.sizeThatFits)
    }
}
#endif
