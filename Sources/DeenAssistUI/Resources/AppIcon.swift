import SwiftUI

/// App icon and branding assets
public struct AppIcon {
    
    /// Main app icon view for use in UI
    public static func iconView(size: CGFloat = 60) -> some View {
        ZStack {
            // Background gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            ColorPalette.primary,
                            ColorPalette.secondary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // Crescent moon and star symbol
            ZStack {
                // Crescent moon
                Image(systemName: "moon.fill")
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundColor(.white)
                    .offset(x: -size * 0.05, y: -size * 0.02)
                
                // Star
                Image(systemName: "star.fill")
                    .font(.system(size: size * 0.2, weight: .medium))
                    .foregroundColor(.white)
                    .offset(x: size * 0.15, y: -size * 0.15)
            }
        }
        .shadow(color: Color.black.opacity(0.2), radius: size * 0.1, x: 0, y: size * 0.05)
    }
    
    /// Large app icon for splash screens
    public static func largeIconView(size: CGFloat = 120) -> some View {
        iconView(size: size)
    }
    
    /// Small app icon for navigation bars
    public static func smallIconView(size: CGFloat = 32) -> some View {
        iconView(size: size)
    }
    
    /// App icon with text for branding
    public static func brandingView(iconSize: CGFloat = 80) -> some View {
        VStack(spacing: 16) {
            iconView(size: iconSize)
            
            VStack(spacing: 4) {
                Text("Deen Assist")
                    .font(.system(size: iconSize * 0.3, weight: .bold, design: .default))
                    .foregroundColor(ColorPalette.textPrimary)
                
                Text("Your companion for daily worship")
                    .font(.system(size: iconSize * 0.15, weight: .medium, design: .default))
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

/// Launch screen view
public struct LaunchScreen: View {
    @State private var isAnimating = false
    @State private var showText = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    ColorPalette.backgroundPrimary,
                    ColorPalette.backgroundSecondary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // App icon with animation
                AppIcon.largeIconView(size: 120)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .appAnimation(AppAnimations.smoothSpring.delay(0.2), value: isAnimating)
                
                // App name with animation
                if showText {
                    VStack(spacing: 8) {
                        Text("Deen Assist")
                            .font(.system(size: 32, weight: .bold, design: .default))
                            .foregroundColor(ColorPalette.textPrimary)
                        
                        Text("Your companion for daily worship")
                            .font(.system(size: 16, weight: .medium, design: .default))
                            .foregroundColor(ColorPalette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .appTransition(.fade)
                }
                
                Spacer()
                
                // Loading indicator
                if isAnimating {
                    VStack(spacing: 12) {
                        AnimatedLoadingDots()
                        
                        Text("Preparing your prayer schedule...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ColorPalette.textTertiary)
                    }
                    .appTransition(.fade)
                }
            }
            .padding(40)
        }
        .onAppear {
            // Animate icon appearance
            withAnimation(AppAnimations.smoothSpring.delay(0.1)) {
                isAnimating = true
            }
            
            // Show text after icon animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(AppAnimations.standard) {
                    showText = true
                }
            }
        }
    }
}

/// App icon variants for different contexts
public struct AppIconVariants {
    
    /// Monochrome version for system contexts
    public static func monochromeIcon(size: CGFloat = 60) -> some View {
        ZStack {
            Circle()
                .fill(Color.primary)
                .frame(width: size, height: size)
            
            ZStack {
                Image(systemName: "moon.fill")
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundColor(Color(UIColor.systemBackground))
                    .offset(x: -size * 0.05, y: -size * 0.02)
                
                Image(systemName: "star.fill")
                    .font(.system(size: size * 0.2, weight: .medium))
                    .foregroundColor(Color(UIColor.systemBackground))
                    .offset(x: size * 0.15, y: -size * 0.15)
            }
        }
    }
    
    /// High contrast version for accessibility
    public static func highContrastIcon(size: CGFloat = 60) -> some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: size, height: size)
            
            Circle()
                .stroke(Color.white, lineWidth: size * 0.05)
                .frame(width: size, height: size)
            
            ZStack {
                Image(systemName: "moon.fill")
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: -size * 0.05, y: -size * 0.02)
                
                Image(systemName: "star.fill")
                    .font(.system(size: size * 0.2, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: size * 0.15, y: -size * 0.15)
            }
        }
    }
    
    /// Notification icon for push notifications
    public static func notificationIcon(size: CGFloat = 40) -> some View {
        ZStack {
            Circle()
                .fill(ColorPalette.primary)
                .frame(width: size, height: size)
            
            Image(systemName: "bell.fill")
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundColor(.white)
        }
    }
    
    /// Widget icon for home screen widgets
    public static func widgetIcon(size: CGFloat = 60) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2)
                .fill(
                    LinearGradient(
                        colors: [ColorPalette.primary, ColorPalette.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            VStack(spacing: size * 0.05) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: size * 0.3, weight: .medium))
                    .foregroundColor(.white)
                
                Text("Deen")
                    .font(.system(size: size * 0.15, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

/// App store assets and marketing materials
public struct AppStoreAssets {
    
    /// App store icon (1024x1024)
    public static func appStoreIcon() -> some View {
        AppIcon.iconView(size: 1024)
            .background(
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 1024, height: 1024)
            )
    }
    
    /// Feature graphic for app store
    public static func featureGraphic() -> some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    ColorPalette.primary,
                    ColorPalette.secondary,
                    ColorPalette.accent
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            HStack(spacing: 40) {
                // App icon
                AppIcon.iconView(size: 200)
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Deen Assist")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Your companion for daily worship")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    VStack(alignment: .leading, spacing: 12) {
                        FeaturePoint(text: "Accurate prayer times")
                        FeaturePoint(text: "Qibla compass")
                        FeaturePoint(text: "Prayer guides")
                        FeaturePoint(text: "Works offline")
                    }
                }
                
                Spacer()
            }
            .padding(60)
        }
        .frame(width: 1200, height: 630)
    }
    
    private struct FeaturePoint: View {
        let text: String
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                
                Text(text)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Preview

#Preview("App Icons") {
    VStack(spacing: 30) {
        HStack(spacing: 20) {
            AppIcon.smallIconView()
            AppIcon.iconView()
            AppIcon.largeIconView()
        }
        
        AppIcon.brandingView()
        
        HStack(spacing: 20) {
            AppIconVariants.monochromeIcon()
            AppIconVariants.highContrastIcon()
            AppIconVariants.notificationIcon()
            AppIconVariants.widgetIcon()
        }
    }
    .padding()
    .background(ColorPalette.backgroundPrimary)
}

#Preview("Launch Screen") {
    LaunchScreen()
}
