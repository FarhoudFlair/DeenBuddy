import SwiftUI

/// Loading view component with different styles
public struct LoadingView: View {
    let style: LoadingStyle
    let message: String?
    
    @State private var isAnimating = false
    
    public init(style: LoadingStyle = .spinner, message: String? = nil) {
        self.style = style
        self.message = message
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            loadingIndicator
            
            if let message = message {
                Text(message)
                    .bodyMedium()
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
    
    @ViewBuilder
    private var loadingIndicator: some View {
        switch style {
        case .spinner:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ColorPalette.primary))
                .scaleEffect(1.2)
            
        case .dots:
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(ColorPalette.primary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isAnimating ? 1.0 : 0.5)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
            }
            
        case .pulse:
            Circle()
                .fill(ColorPalette.primary.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .fill(ColorPalette.primary)
                        .frame(width: 20, height: 20)
                        .scaleEffect(isAnimating ? 1.5 : 1.0)
                        .opacity(isAnimating ? 0.0 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 1.0).repeatForever(),
                            value: isAnimating
                        )
                )
            
        case .prayer:
            VStack(spacing: 12) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 32))
                    .foregroundColor(ColorPalette.primary)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 2.0).repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                
                Text("Loading prayer times...")
                    .labelLarge()
                    .foregroundColor(ColorPalette.textSecondary)
            }
            
        case .prayerWithBuddy:
            VStack(spacing: 16) {
                // Legacy buddy waving animation at the top
                BuddyWaveView()
                    .frame(width: 80, height: 80)
                
                // Prayer moon icon below
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 28))
                    .foregroundColor(ColorPalette.primary)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 2.0).repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
            
        case .prayerWithMascot:
            VStack(spacing: 16) {
                // Simple PNG mascot with gentle pulse
                SimpleMascotView.loading(size: 80)
                
                // Prayer moon icon below
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 28))
                    .foregroundColor(ColorPalette.primary)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 2.0).repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
        }
    }
}

// MARK: - Loading Styles

public extension LoadingView {
    enum LoadingStyle {
        case spinner
        case dots
        case pulse
        case prayer
        case prayerWithBuddy    // Compatibility variant
        case prayerWithMascot   // New improved version
    }
}

// MARK: - Convenience Initializers

public extension LoadingView {
    static func spinner(message: String? = nil) -> LoadingView {
        LoadingView(style: .spinner, message: message)
    }
    
    static func dots(message: String? = nil) -> LoadingView {
        LoadingView(style: .dots, message: message)
    }
    
    static func pulse(message: String? = nil) -> LoadingView {
        LoadingView(style: .pulse, message: message)
    }
    
    static func prayer(message: String? = nil) -> LoadingView {
        LoadingView(style: .prayer, message: message)
    }
    
    static func prayerWithBuddy(message: String? = nil) -> LoadingView {
        LoadingView(style: .prayerWithBuddy, message: message)
    }
    
    static func prayerWithMascot(message: String? = nil) -> LoadingView {
        LoadingView(style: .prayerWithMascot, message: message)
    }
}

// MARK: - Full Screen Loading

public struct FullScreenLoadingView: View {
    let loadingView: LoadingView
    
    public init(style: LoadingView.LoadingStyle = .spinner, message: String? = nil) {
        self.loadingView = LoadingView(style: style, message: message)
    }
    
    public var body: some View {
        ZStack {
            ColorPalette.backgroundPrimary
                .ignoresSafeArea()
            
            loadingView
        }
    }
}

// MARK: - Preview

#Preview("Loading Views") {
    VStack(spacing: 40) {
        LoadingView.contextual(.settings)
        LoadingView.contextual(.prayerTimes)
        LoadingView.contextual(.qiblaDirection)
        LoadingView.contextual(.quranData)
    }
    .padding()
    .background(ColorPalette.backgroundPrimary)
}
