import SwiftUI
import ActivityKit

// MARK: - Prayer-Specific Contextual Variations

@available(iOS 16.1, *)
struct PrayerContextualVariations {
    
    // MARK: - Fajr-Specific Display
    
    struct FajrVariation: View {
        let state: PrayerCountdownActivity.ContentState
        let displayMode: DisplayMode
        
        var body: some View {
            Group {
                switch displayMode {
                case .dynamicIslandMinimal:
                    fajrMinimalView
                case .dynamicIslandCompact:
                    fajrCompactView
                case .dynamicIslandExpanded:
                    fajrExpandedView
                case .lockScreenCircular:
                    fajrCircularView
                }
            }
        }
        
        private var fajrMinimalView: some View {
            HStack(spacing: 2) {
                Image("FajrIcon")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 8, height: 8)
                    .foregroundStyle(.orange)
                
                Text("Dawn")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.primary)
            }
        }
        
        private var fajrCompactView: some View {
            VStack(spacing: 1) {
                Image("FajrIcon")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(.orange)
                
                Text("Fajr")
                    .font(.caption2)
                    .foregroundStyle(.primary)
                
                if state.isImminent {
                    Text("Soon!")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.red)
                }
            }
        }
        
        private var fajrExpandedView: some View {
            VStack(spacing: 4) {
                HStack {
                    Image("FajrIcon")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.orange)
                    
                    VStack(alignment: .leading) {
                        Text("Fajr Prayer")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text("Dawn Prayer - The Light of Faith")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                Text("\"Whoever prays Fajr is under Allah's protection.\"")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .italic()
                    .multilineTextAlignment(.center)
            }
        }
        
        private var fajrCircularView: some View {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.1))
                
                VStack(spacing: 1) {
                    Image("FajrIcon")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 10, height: 10)
                        .foregroundStyle(.orange)
                    
                    Text("Dawn")
                        .font(.system(size: 7))
                        .foregroundStyle(.primary)
                }
            }
        }
    }
    
    // MARK: - Maghrib-Specific Display (Sunset)
    
    struct MaghribVariation: View {
        let state: PrayerCountdownActivity.ContentState
        let displayMode: DisplayMode
        
        var body: some View {
            Group {
                switch displayMode {
                case .dynamicIslandMinimal:
                    maghribMinimalView
                case .dynamicIslandCompact:
                    maghribCompactView  
                case .dynamicIslandExpanded:
                    maghribExpandedView
                case .lockScreenCircular:
                    maghribCircularView
                }
            }
        }
        
        private var maghribMinimalView: some View {
            HStack(spacing: 2) {
                Image("MaghribIcon")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 8, height: 8)
                    .foregroundStyle(.purple)
                
                Text(state.formattedTimeRemaining)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(state.isImminent ? .red : .primary)
                    .monospacedDigit()
            }
        }
        
        private var maghribCompactView: some View {
            VStack(spacing: 1) {
                Image("MaghribIcon")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 14, height: 14)
                    .foregroundStyle(.purple)
                
                Text("Maghrib")
                    .font(.caption2)
                    .foregroundStyle(.primary)
                
                if state.isImminent {
                    Text("Break Fast!")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.orange)
                }
            }
        }
        
        private var maghribExpandedView: some View {
            VStack(spacing: 4) {
                HStack {
                    Image("MaghribIcon")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.purple)
                    
                    VStack(alignment: .leading) {
                        Text("Maghrib Prayer")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text("Sunset Prayer - Time to Break Fast")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                if isRamadanSeason() {
                    HStack {
                        Image(systemName: "moon.stars")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        
                        Text("Time to break your fast")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        
        private var maghribCircularView: some View {
            ZStack {
                Circle()
                    .fill(.purple.opacity(0.1))
                
                VStack(spacing: 1) {
                    Image("MaghribIcon")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 10, height: 10)
                        .foregroundStyle(.purple)
                    
                    if isRamadanSeason() {
                        Image(systemName: "moon.stars")
                            .font(.system(size: 6))
                            .foregroundStyle(.orange)
                    } else {
                        Text("Sunset")
                            .font(.system(size: 7))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        
        private func isRamadanSeason() -> Bool {
            let islamicCalendar = Calendar(identifier: .islamicUmmAlQura)
            let components = islamicCalendar.dateComponents([.month], from: Date())
            guard let month = components.month else {
                return false
            }
            return month == 9
        }
    }
    
    // MARK: - Isha-Specific Display (Night Prayer)
    
    struct IshaVariation: View {
        let state: PrayerCountdownActivity.ContentState
        let displayMode: DisplayMode
        
        var body: some View {
            Group {
                switch displayMode {
                case .dynamicIslandMinimal:
                    ishaMinimalView
                case .dynamicIslandCompact:
                    ishaCompactView
                case .dynamicIslandExpanded:
                    ishaExpandedView
                case .lockScreenCircular:
                    ishaCircularView
                }
            }
        }
        
        private var ishaMinimalView: some View {
            HStack(spacing: 2) {
                Image("IshaIcon")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 8, height: 8)
                    .foregroundStyle(.indigo)
                
                Text("Night")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.primary)
            }
        }
        
        private var ishaCompactView: some View {
            VStack(spacing: 1) {
                ZStack {
                    Image("IshaIcon")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(.indigo)
                    
                    // Add subtle star effect for night prayer
                    if !state.isImminent {
                        starField
                    }
                }
                
                Text("Isha")
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }
        }
        
        private var ishaExpandedView: some View {
            VStack(spacing: 4) {
                HStack {
                    ZStack {
                        Image("IshaIcon")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundStyle(.indigo)
                        
                        starField
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Isha Prayer")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text("Night Prayer - End of Day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                Text("\"The night prayer is the honor of the believer.\"")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .italic()
                    .multilineTextAlignment(.center)
            }
        }
        
        private var ishaCircularView: some View {
            ZStack {
                Circle()
                    .fill(.indigo.opacity(0.1))
                
                VStack(spacing: 1) {
                    Image("IshaIcon")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 10, height: 10)
                        .foregroundStyle(.indigo)
                    
                    Text("Night")
                        .font(.system(size: 7))
                        .foregroundStyle(.primary)
                }
                
                starField
                    .opacity(0.3)
            }
        }
        
        private let starPositions: [(x: CGFloat, y: CGFloat)] = [
            (-6, -4), (7, 2), (-3, 5)
        ]
        
        private var starField: some View {
            ZStack {
                ForEach(Array(starPositions.enumerated()), id: \.offset) { index, position in
                    Circle()
                        .fill(.white.opacity(0.6))
                        .frame(width: 1, height: 1)
                        .offset(
                            x: position.x,
                            y: position.y
                        )
                }
            }
        }
    }
    
    // MARK: - Display Mode Enum
    
    enum DisplayMode {
        case dynamicIslandMinimal
        case dynamicIslandCompact
        case dynamicIslandExpanded
        case lockScreenCircular
    }
}

// MARK: - Contextual Prayer View Selector

@available(iOS 16.1, *)
struct ContextualPrayerView: View {
    let state: PrayerCountdownActivity.ContentState
    let displayMode: PrayerContextualVariations.DisplayMode
    
    var body: some View {
        Group {
            switch currentPrayer {
            case .fajr:
                PrayerContextualVariations.FajrVariation(
                    state: state,
                    displayMode: displayMode
                )
            case .maghrib:
                PrayerContextualVariations.MaghribVariation(
                    state: state,
                    displayMode: displayMode
                )
            case .isha:
                PrayerContextualVariations.IshaVariation(
                    state: state,
                    displayMode: displayMode
                )
            default:
                // Generic display for Dhuhr and Asr
                genericPrayerView
            }
        }
    }
    
    private var currentPrayer: Prayer {
        switch state.nextPrayer.displayName.lowercased() {
        case "fajr": return .fajr
        case "dhuhr": return .dhuhr
        case "asr": return .asr
        case "maghrib": return .maghrib
        case "isha": return .isha
        default: return .fajr
        }
    }
    
    private var genericPrayerView: some View {
        HStack(spacing: 4) {
            AnimatedIslamicSymbol(
                prayer: WidgetPrayer(rawValue: currentPrayer.rawValue),
                state: displayModeToAnimationState(displayMode),
                isUrgent: state.isImminent,
                alwaysOnMode: false
            )
            
            Text(state.nextPrayer.displayName)
                .font(.caption2)
                .foregroundStyle(.primary)
        }
    }
    
    private func displayModeToAnimationState(_ mode: PrayerContextualVariations.DisplayMode) -> DynamicIslandAnimations.DynamicIslandState {
        switch mode {
        case .dynamicIslandMinimal:
            return .minimal
        case .dynamicIslandCompact:
            return .compact
        case .dynamicIslandExpanded:
            return .expanded
        case .lockScreenCircular:
            return .compact
        }
    }
}