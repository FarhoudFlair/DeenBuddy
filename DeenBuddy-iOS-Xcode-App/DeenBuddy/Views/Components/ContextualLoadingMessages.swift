import SwiftUI

/// Context-aware loading messages for different screens in the DeenBuddy app
/// This ensures users see appropriate loading text based on what they're actually waiting for
public enum LoadingContext {
    // Prayer Times
    case prayerTimes
    case prayerTimesRefresh
    case prayerCalculation
    
    // Quran
    case quranData
    case quranVerses
    case quranSearch
    case quranChapter
    
    // Qibla Compass
    case qiblaDirection
    case compassCalibration
    case locationDetection
    
    // Islamic Calendar
    case islamicCalendar
    case calendarEvents
    case hijriDate
    
    // Settings
    case settings
    case settingsSync
    case preferences
    
    // Prayer Guides
    case prayerGuides
    case prayerInstructions
    
    // Tasbih/Dhikr
    case tasbihData
    case dhikrContent
    
    // Prayer Journal
    case prayerJournal
    case journalEntries
    case journalStats
    
    // Search
    case searchResults
    case contentSearch
    
    // General
    case dataSync
    case initialization
    case backgroundRefresh
    
    /// Primary loading message for the context
    public var primaryMessage: String {
        switch self {
        case .prayerTimes:
            return "Loading prayer times..."
        case .prayerTimesRefresh:
            return "Refreshing prayer times..."
        case .prayerCalculation:
            return "Calculating prayer times..."
            
        case .quranData:
            return "Loading Quran data..."
        case .quranVerses:
            return "Loading verses..."
        case .quranSearch:
            return "Searching Quran..."
        case .quranChapter:
            return "Loading chapter..."
            
        case .qiblaDirection:
            return "Finding Qibla direction..."
        case .compassCalibration:
            return "Calibrating compass..."
        case .locationDetection:
            return "Detecting location..."
            
        case .islamicCalendar:
            return "Loading calendar..."
        case .calendarEvents:
            return "Loading calendar events..."
        case .hijriDate:
            return "Loading Hijri date..."
            
        case .settings:
            return "Loading settings..."
        case .settingsSync:
            return "Syncing settings..."
        case .preferences:
            return "Loading preferences..."
            
        case .prayerGuides:
            return "Loading prayer guides..."
        case .prayerInstructions:
            return "Loading instructions..."
            
        case .tasbihData:
            return "Loading dhikr..."
        case .dhikrContent:
            return "Loading dhikr content..."
            
        case .prayerJournal:
            return "Loading prayer journal..."
        case .journalEntries:
            return "Loading journal entries..."
        case .journalStats:
            return "Loading statistics..."
            
        case .searchResults:
            return "Searching..."
        case .contentSearch:
            return "Searching content..."
            
        case .dataSync:
            return "Syncing data..."
        case .initialization:
            return "Initializing..."
        case .backgroundRefresh:
            return "Updating data..."
        }
    }
    
    /// Secondary descriptive message (optional)
    public var secondaryMessage: String? {
        switch self {
        case .prayerTimes, .prayerCalculation:
            return "Calculating accurate prayer times for your location"
        case .qiblaDirection:
            return "Determining direction to Mecca from your location"
        case .compassCalibration:
            return "Please move your device in a figure-8 pattern"
        case .locationDetection:
            return "Accessing your location for accurate calculations"
        case .quranData:
            return "Preparing complete Quran database"
        case .islamicCalendar:
            return "Loading Islamic calendar and events"
        case .prayerGuides:
            return "Preparing step-by-step prayer instructions"
        case .tasbihData:
            return "Loading dhikr and remembrance content"
        case .prayerJournal:
            return "Loading your prayer tracking data"
        default:
            return nil
        }
    }
    
    /// Loading style appropriate for the context
    public var loadingStyle: LoadingView.LoadingStyle {
        switch self {
        case .prayerTimes, .prayerTimesRefresh, .prayerCalculation:
            return .prayer
        case .qiblaDirection, .compassCalibration:
            return .pulse
        case .quranData, .quranVerses, .quranSearch:
            return .dots
        case .islamicCalendar, .calendarEvents:
            return .spinner
        case .tasbihData, .dhikrContent:
            return .prayer
        default:
            return .spinner
        }
    }
}

/// Enhanced loading view that uses contextual messages
public struct ContextualLoadingView: View {
    let context: LoadingContext
    let customMessage: String?
    
    public init(context: LoadingContext, customMessage: String? = nil) {
        self.context = context
        self.customMessage = customMessage
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            LoadingView(
                style: context.loadingStyle,
                message: customMessage ?? context.primaryMessage
            )
            
            if let secondaryMessage = context.secondaryMessage {
                Text(secondaryMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
}

/// Modern loading view with contextual messages
public struct ModernContextualLoadingView: View {
    let context: LoadingContext
    let customMessage: String?
    
    public init(context: LoadingContext, customMessage: String? = nil) {
        self.context = context
        self.customMessage = customMessage
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.cyan)
            
            Text(customMessage ?? context.primaryMessage)
                .font(.headline)
                .foregroundColor(.white)
            
            if let secondaryMessage = context.secondaryMessage {
                Text(secondaryMessage)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
    }
}

/// Extension to provide contextual loading for common scenarios
public extension LoadingView {
    static func contextual(_ context: LoadingContext, customMessage: String? = nil) -> LoadingView {
        LoadingView(
            style: context.loadingStyle,
            message: customMessage ?? context.primaryMessage
        )
    }
}

/// Extension for ModernLoadingView to support contextual messages
extension ModernLoadingView {
    init(context: LoadingContext, customMessage: String? = nil) {
        self.init(message: customMessage ?? context.primaryMessage)
    }
}

// MARK: - Preview

#Preview("Contextual Loading Messages") {
    ScrollView {
        VStack(spacing: 30) {
            Group {
                Text("Prayer Times Loading")
                    .font(.headline)
                ContextualLoadingView(context: .prayerTimes)
                
                Text("Quran Data Loading")
                    .font(.headline)
                ContextualLoadingView(context: .quranData)
                
                Text("Qibla Direction Loading")
                    .font(.headline)
                ContextualLoadingView(context: .qiblaDirection)
            }
            
            Group {
                Text("Islamic Calendar Loading")
                    .font(.headline)
                ContextualLoadingView(context: .islamicCalendar)
                
                Text("Settings Loading")
                    .font(.headline)
                ContextualLoadingView(context: .settings)
                
                Text("Prayer Guides Loading")
                    .font(.headline)
                ContextualLoadingView(context: .prayerGuides)
            }
        }
        .padding()
    }
    .background(Color.black)
}
