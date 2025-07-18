import SwiftUI

/// Button component for marking individual prayers as complete
public struct PrayerCompletionButton: View {
    
    // MARK: - Properties
    
    let prayer: Prayer
    let isCompleted: Bool
    let onTap: () -> Void
    
    // MARK: - State
    
    @State private var isPressed: Bool = false
    
    // MARK: - Body
    
    public var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Prayer Icon with Status
                ZStack {
                    Circle()
                        .fill(backgroundGradient)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(borderColor, lineWidth: 2)
                        )
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: prayer.systemImageName)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(prayer.color)
                    }
                }
                
                // Prayer Information
                VStack(spacing: 4) {
                    Text(prayer.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(textColor)
                    
                    Text(prayer.arabicName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ColorPalette.secondary)
                        .environment(\.layoutDirection, .rightToLeft)
                    
                    // Rakah count
                    Text("\(prayer.defaultRakahCount) \(prayer.defaultRakahCount == 1 ? "Rakah" : "Rakahs")")
                        .font(.caption)
                        .foregroundColor(ColorPalette.secondary)
                }
                
                // Status Indicator
                statusIndicator
            }
            .padding()
            .background(cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                isPressed = pressing
            },
            perform: { }
        )
    }
    
    // MARK: - Computed Properties
    
    private var backgroundGradient: LinearGradient {
        if isCompleted {
            return LinearGradient(
                colors: [prayer.color, prayer.color.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [ColorPalette.surface, ColorPalette.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var borderColor: Color {
        if isCompleted {
            return prayer.color
        } else {
            return ColorPalette.surface
        }
    }
    
    private var textColor: Color {
        if isCompleted {
            return prayer.color
        } else {
            return ColorPalette.primary
        }
    }
    
    private var cardBackground: Color {
        if isCompleted {
            return prayer.color.opacity(0.05)
        } else {
            return Color.gray.opacity(0.1)
        }
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        HStack(spacing: 4) {
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(prayer.color)
                    .font(.caption)
                
                Text("Completed")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(prayer.color)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(ColorPalette.secondary)
                    .font(.caption)
                
                Text("Tap to complete")
                    .font(.caption)
                    .foregroundColor(ColorPalette.secondary)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PrayerCompletionButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                PrayerCompletionButton(
                    prayer: .fajr,
                    isCompleted: true,
                    onTap: { }
                )
                
                PrayerCompletionButton(
                    prayer: .dhuhr,
                    isCompleted: false,
                    onTap: { }
                )
            }
            
            HStack(spacing: 16) {
                PrayerCompletionButton(
                    prayer: .asr,
                    isCompleted: false,
                    onTap: { }
                )
                
                PrayerCompletionButton(
                    prayer: .maghrib,
                    isCompleted: true,
                    onTap: { }
                )
            }
            
            PrayerCompletionButton(
                prayer: .isha,
                isCompleted: false,
                onTap: { }
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .previewLayout(.sizeThatFits)
    }
}
#endif
