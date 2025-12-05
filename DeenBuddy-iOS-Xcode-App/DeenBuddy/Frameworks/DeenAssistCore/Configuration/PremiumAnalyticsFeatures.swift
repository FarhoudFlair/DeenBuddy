import Foundation

/// Premium analytics features gating system
public struct PremiumAnalyticsFeatures {

    // MARK: - Feature Flags

    /// Whether the user has premium access
    private let hasPremium: Bool

    /// Maximum history days for free tier
    public static let freeHistoryDays: Int = 7

    /// Maximum history days for premium tier
    public static let premiumHistoryDays: Int = 365

    // MARK: - Initialization

    public init(hasPremium: Bool = false) {
        self.hasPremium = hasPremium
    }

    // MARK: - Feature Access

    /// Unified feature access gate
    public func canAccess(_ feature: PremiumAnalyticsFeature) -> Bool {
        // All features currently require premium; explicit switch retained for future differentiation
        switch feature {
        case .individualStreaks:
            return hasPremium
        case .advancedCharts:
            return hasPremium
        case .patternAnalysis:
            return hasPremium
        case .moodCorrelation:
            return hasPremium
        case .congregationStats:
            return hasPremium
        case .dataExport:
            return hasPremium
        case .goalTracking:
            return hasPremium
        case .personalizedInsights:
            return hasPremium
        case .unlimitedHistory:
            return hasPremium
        }
    }

    /// Check if user can access individual prayer streaks
    @available(*, deprecated, message: "Use canAccess(_:) with .individualStreaks")
    public func canAccessIndividualStreaks() -> Bool {
        return canAccess(.individualStreaks)
    }

    /// Check if user can access advanced charts
    @available(*, deprecated, message: "Use canAccess(_:) with .advancedCharts")
    public func canAccessAdvancedCharts() -> Bool {
        return canAccess(.advancedCharts)
    }

    /// Check if user can access pattern analysis
    @available(*, deprecated, message: "Use canAccess(_:) with .patternAnalysis")
    public func canAccessPatternAnalysis() -> Bool {
        return canAccess(.patternAnalysis)
    }

    /// Check if user can access mood correlation
    @available(*, deprecated, message: "Use canAccess(_:) with .moodCorrelation")
    public func canAccessMoodCorrelation() -> Bool {
        return canAccess(.moodCorrelation)
    }

    /// Check if user can access congregation statistics
    @available(*, deprecated, message: "Use canAccess(_:) with .congregationStats")
    public func canAccessCongregationStats() -> Bool {
        return canAccess(.congregationStats)
    }

    /// Check if user can export data
    @available(*, deprecated, message: "Use canAccess(_:) with .dataExport")
    public func canExportData() -> Bool {
        return canAccess(.dataExport)
    }

    /// Check if user can access goal tracking
    @available(*, deprecated, message: "Use canAccess(_:) with .goalTracking")
    public func canAccessGoalTracking() -> Bool {
        return canAccess(.goalTracking)
    }

    /// Check if user can access personalized insights
    @available(*, deprecated, message: "Use canAccess(_:) with .personalizedInsights")
    public func canAccessPersonalizedInsights() -> Bool {
        return canAccess(.personalizedInsights)
    }

    /// Get maximum history days based on tier
    public func getMaxHistoryDays() -> Int {
        return hasPremium ? Self.premiumHistoryDays : Self.freeHistoryDays
    }

    /// Get available analytics periods based on tier (as strings)
    public func getAvailablePeriods() -> [String] {
        if hasPremium {
            return ["week", "month", "year"]
        } else {
            return ["week"] // Free tier only gets weekly stats
        }
    }

    /// Check if a period is available for the current tier
    public func isPeriodAvailable(_ period: String) -> Bool {
        let availablePeriods = getAvailablePeriods()
        return availablePeriods.contains(period)
    }
}

/// Premium feature type for upgrade prompts
public enum PremiumAnalyticsFeature: String, CaseIterable {
    case individualStreaks = "individual_streaks"
    case advancedCharts = "advanced_charts"
    case patternAnalysis = "pattern_analysis"
    case moodCorrelation = "mood_correlation"
    case congregationStats = "congregation_stats"
    case dataExport = "data_export"
    case goalTracking = "goal_tracking"
    case personalizedInsights = "personalized_insights"
    case unlimitedHistory = "unlimited_history"

    public var displayName: String {
        switch self {
        case .individualStreaks: return "Individual Prayer Streaks"
        case .advancedCharts: return "Advanced Charts"
        case .patternAnalysis: return "Pattern Analysis"
        case .moodCorrelation: return "Mood Correlation"
        case .congregationStats: return "Congregation Statistics"
        case .dataExport: return "Data Export"
        case .goalTracking: return "Goal Tracking"
        case .personalizedInsights: return "Personalized Insights"
        case .unlimitedHistory: return "Unlimited History"
        }
    }

    public var description: String {
        switch self {
        case .individualStreaks:
            return "Track streaks for each of the 5 daily prayers separately"
        case .advancedCharts:
            return "View detailed trend analysis and heatmaps"
        case .patternAnalysis:
            return "Discover patterns in your prayer habits"
        case .moodCorrelation:
            return "See how prayer affects your mood and well-being"
        case .congregationStats:
            return "Analyze mosque vs. home prayer statistics"
        case .dataExport:
            return "Export your prayer data as CSV or PDF reports"
        case .goalTracking:
            return "Set and track personalized prayer goals"
        case .personalizedInsights:
            return "Get AI-powered recommendations to improve consistency"
        case .unlimitedHistory:
            return "Access your complete prayer history (365 days)"
        }
    }

    public var icon: String {
        switch self {
        case .individualStreaks: return "flame.fill"
        case .advancedCharts: return "chart.line.uptrend.xyaxis"
        case .patternAnalysis: return "waveform.path.ecg"
        case .moodCorrelation: return "heart.fill"
        case .congregationStats: return "person.3.fill"
        case .dataExport: return "square.and.arrow.up"
        case .goalTracking: return "target"
        case .personalizedInsights: return "lightbulb.fill"
        case .unlimitedHistory: return "calendar"
        }
    }
}

/// Premium unlock prompt data
public struct PremiumUnlockPrompt {
    public let feature: PremiumAnalyticsFeature
    public let title: String
    public let message: String
    public let ctaText: String

    public init(feature: PremiumAnalyticsFeature) {
        self.feature = feature
        self.title = "Unlock \(feature.displayName)"
        self.message = feature.description
        self.ctaText = "Upgrade to Premium"
    }

    public static func forIndividualStreaks() -> PremiumUnlockPrompt {
        return PremiumUnlockPrompt(feature: .individualStreaks)
    }

    public static func forAdvancedCharts() -> PremiumUnlockPrompt {
        return PremiumUnlockPrompt(feature: .advancedCharts)
    }

    public static func forDataExport() -> PremiumUnlockPrompt {
        return PremiumUnlockPrompt(feature: .dataExport)
    }

    public static func forUnlimitedHistory() -> PremiumUnlockPrompt {
        return PremiumUnlockPrompt(feature: .unlimitedHistory)
    }
}
