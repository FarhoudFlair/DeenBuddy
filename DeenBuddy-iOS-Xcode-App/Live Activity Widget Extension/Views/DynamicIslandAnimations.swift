import SwiftUI
import ActivityKit

// Use the widget extension's WidgetPrayer type to avoid conflicts

// MARK: - Dynamic Island Animation Controller

@available(iOS 16.1, *)
struct DynamicIslandAnimations {
    
    // MARK: - Elastic Transitions
    
    static let elasticTiming = Animation.timingCurve(0.2, 0.8, 0.2, 1.0, duration: 0.8)
    static let biologicalTiming = Animation.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 1.2)
    
    // MARK: - Prayer Transition Animations
    
    static func prayerTransition(for prayer: WidgetPrayer, isUrgent: Bool) -> Animation {
        if isUrgent {
            return .easeInOut(duration: 0.3)
                .repeatCount(3, autoreverses: true)
        } else {
            return elasticTiming
        }
    }
    
    static func symbolPulse(isActive: Bool) -> Animation {
        isActive ? 
            .easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
            .default
    }
    
    // MARK: - Dynamic Island Shape Harmony
    
    static func concentricScale(for state: DynamicIslandState) -> CGFloat {
        switch state {
        case .minimal:
            return 0.7  // Harmonious with minimal pill shape
        case .compact:
            return 0.85 // Balanced for compact states
        case .expanded:
            return 1.0  // Full size for expanded
        }
    }
    
    enum DynamicIslandState {
        case minimal
        case compact
        case expanded
    }
}

// MARK: - Enhanced Prayer Symbol View

@available(iOS 16.1, *)
struct AnimatedIslamicSymbol: View {
    let prayer: WidgetPrayer?
    let state: DynamicIslandAnimations.DynamicIslandState
    let isUrgent: Bool
    let alwaysOnMode: Bool
    
    @State private var isAnimating = false
    
    // Use Image helper so Image-specific modifiers like .resizable() resolve correctly
    private var symbolImage: Image {
        alwaysOnMode ? Image("IslamicSymbolAlwaysOn") : Image(concentricSymbolName)
    }
    
    var body: some View {
        symbolImage
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: symbolSize, height: symbolSize)
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .opacity(isUrgent ? (isAnimating ? 1.0 : 0.7) : 1.0)
            .animation(
                DynamicIslandAnimations.prayerTransition(for: prayer ?? .fajr, isUrgent: isUrgent),
                value: isAnimating
            )
            .onAppear {
                if isUrgent {
                    withAnimation(DynamicIslandAnimations.symbolPulse(isActive: true)) {
                        isAnimating = true
                    }
                }
            }
            .onChange(of: isUrgent) { newValue in
                withAnimation(DynamicIslandAnimations.elasticTiming) {
                    isAnimating = newValue
                }
            }
            // Accessibility: announce prayer and urgency
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySymbolLabel)
            .accessibilityHint(NSLocalizedString("PrayerTimeHint", comment: "Hint for prayer symbol"))
            .accessibilityAddTraits(isUrgent ? .updatesFrequently : .isStaticText)
    }
    
    private var concentricSymbolName: String {
        switch state {
        case .minimal:
            return "IslamicSymbolMinimal"
        case .compact:
            return "IslamicSymbolConcentric"
        case .expanded:
            return "IslamicSymbol"
        }
    }
    
    private var symbolSize: CGFloat {
        let baseSize: CGFloat = {
            switch state {
            case .minimal: return 10
            case .compact: return 16
            case .expanded: return 24
            }
        }()
        
        return baseSize * DynamicIslandAnimations.concentricScale(for: state)
    }

    // MARK: - Accessibility
    private var accessibilitySymbolLabel: String {
        let prayerName: String = {
            switch prayer ?? .fajr {
            case .fajr: return NSLocalizedString("Prayer_Fajr", comment: "Fajr")
            case .dhuhr: return NSLocalizedString("Prayer_Dhuhr", comment: "Dhuhr")
            case .asr: return NSLocalizedString("Prayer_Asr", comment: "Asr")
            case .maghrib: return NSLocalizedString("Prayer_Maghrib", comment: "Maghrib")
            case .isha: return NSLocalizedString("Prayer_Isha", comment: "Isha")
            }
        }()
        if isUrgent {
            return "\(prayerName), \(NSLocalizedString("UrgentLabel", comment: "Urgent state"))"
        } else {
            return prayerName
        }
    }
}

// MARK: - Prayer-Specific Visual Identity

@available(iOS 16.1, *)
struct PrayerSpecificSymbol: View {
    let prayer: WidgetPrayer
    let state: DynamicIslandAnimations.DynamicIslandState
    let timeRemaining: TimeInterval?
    let alwaysOnMode: Bool
    
    @State private var rotationAngle: Double = 0
    @State private var breathingScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Background breathing effect for imminent prayers
            if isImminent {
                Circle()
                    .fill(prayerColor.opacity(0.2))
                    .scaleEffect(breathingScale)
                    .animation(
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: breathingScale
                    )
            }
            
            // Prayer-specific icon with rotation for time progression
            prayerIconView
                .rotationEffect(.degrees(rotationAngle))
                .animation(
                    DynamicIslandAnimations.biologicalTiming,
                    value: rotationAngle
                )
        }
        .onAppear {
            updateAnimations()
        }
        .onChange(of: timeRemaining) { _ in
            updateAnimations()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityPrayerLabel)
        .accessibilityHint(accessibilityHintText)
        .accessibilityAddTraits(isImminent ? .updatesFrequently : [])
    }
    
    // Use Image helper so Image-specific modifiers like .resizable() resolve correctly
    private var prayerIconView: some View {
        let image = alwaysOnMode ? Image("PrayerIconsAlwaysOn") : Image(iconAssetName)
        return image
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: iconSize, height: iconSize)
            .foregroundStyle(prayerColor)
    }
    
    private var iconSize: CGFloat {
        switch state {
        case .minimal: return 8
        case .compact: return 12
        case .expanded: return 18
        }
    }
    
    private var iconAssetName: String {
        switch prayer {
        case .fajr: return "FajrIcon"
        case .dhuhr: return "DhuhrIcon"
        case .asr: return "AsrIcon"
        case .maghrib: return "MaghribIcon"
        case .isha: return "IshaIcon"
        }
    }
    
    private var prayerColor: Color {
        if isImminent {
            return .red
        }
        
        switch prayer {
            case .fajr: return .orange
            case .dhuhr: return .yellow
            case .asr: return .blue
            case .maghrib: return .purple
            case .isha: return .indigo
        }
    }
    
    private var isImminent: Bool {
        guard let timeRemaining = timeRemaining else { return false }
        return timeRemaining < 300 // 5 minutes
    }
    
    private func updateAnimations() {
        if isImminent {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                breathingScale = 1.3
            }
            
            if rotationAngle == 0 {
                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                    rotationAngle = 360
                }
            }
        } else {
            breathingScale = 1.0
            rotationAngle = 0
        }
    }

    // MARK: - Accessibility
    private var accessibilityHintText: Text {
        if isImminent {
            return Text(NSLocalizedString("ImminentHint", comment: "Indicates the prayer is imminent"))
        } else {
            return Text(NSLocalizedString("PrayerIconHint", comment: "Describes the prayer status icon"))
        }
    }
    
    private var accessibilityPrayerLabel: String {
        let prayerName: String
        switch prayer {
        case .fajr: prayerName = NSLocalizedString("Prayer_Fajr", comment: "Fajr prayer")
        case .dhuhr: prayerName = NSLocalizedString("Prayer_Dhuhr", comment: "Dhuhr prayer")
        case .asr: prayerName = NSLocalizedString("Prayer_Asr", comment: "Asr prayer")
        case .maghrib: prayerName = NSLocalizedString("Prayer_Maghrib", comment: "Maghrib prayer")
        case .isha: prayerName = NSLocalizedString("Prayer_Isha", comment: "Isha prayer")
        }
        return String(format: NSLocalizedString("PrayerLabelFormat", comment: "Format: %@ prayer"), prayerName)
    }
}

// MARK: - Remove ambiguous extension and local enum to avoid type conflicts

// (Removed) extension Prayer providing iconName
// (Removed) local enum Prayer duplicate
