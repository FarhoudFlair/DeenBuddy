import SwiftUI
import Charts

/// Comprehensive analytics view for prayer tracking data
public struct PrayerAnalyticsView: View {
    
    // MARK: - Properties
    
    @ObservedObject private var prayerTrackingService: any PrayerTrackingServiceProtocol
    private let onDismiss: () -> Void
    
    // MARK: - State
    
    @State private var selectedPeriod: AnalyticsPeriod = .week
    @State private var selectedMetric: AnalyticsMetric = .completion
    
    // MARK: - Initialization
    
    public init(
        prayerTrackingService: any PrayerTrackingServiceProtocol,
        onDismiss: @escaping () -> Void
    ) {
        self.prayerTrackingService = prayerTrackingService
        self.onDismiss = onDismiss
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Period Selector
                    periodSelector
                    
                    // Key Metrics Cards
                    keyMetricsSection
                    
                    // Charts Section
                    chartsSection
                    
                    // Prayer Breakdown
                    prayerBreakdownSection
                    
                    // Insights Section
                    insightsSection
                }
                .padding()
            }
            .navigationTitle("Prayer Analytics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Export functionality
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
    
    // MARK: - Period Selector
    
    @ViewBuilder
    private var periodSelector: some View {
        HStack(spacing: 0) {
            ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                Button(action: {
                    selectedPeriod = period
                }) {
                    Text(period.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selectedPeriod == period ? .white : ColorPalette.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedPeriod == period ? ColorPalette.primary : Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorPalette.surface)
        )
    }
    
    // MARK: - Key Metrics Section
    
    @ViewBuilder
    private var keyMetricsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Key Metrics")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                MetricCard(
                    title: "Completion Rate",
                    value: "\(Int(prayerTrackingService.todayCompletionRate * 100))%",
                    change: "+5%",
                    isPositive: true,
                    icon: "checkmark.circle.fill"
                )
                
                MetricCard(
                    title: "Current Streak",
                    value: "\(prayerTrackingService.currentStreak)",
                    change: "+2 days",
                    isPositive: true,
                    icon: "flame.fill"
                )
            }
            
            HStack(spacing: 16) {
                MetricCard(
                    title: "Total Prayers",
                    value: "\(prayerTrackingService.recentEntries.count)",
                    change: "+12",
                    isPositive: true,
                    icon: "list.bullet"
                )
                
                MetricCard(
                    title: "Best Prayer",
                    value: mostConsistentPrayer.displayName,
                    change: "85%",
                    isPositive: true,
                    icon: mostConsistentPrayer.systemImageName
                )
            }
        }
    }
    
    // MARK: - Charts Section
    
    @ViewBuilder
    private var chartsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Trends")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Metric Selector
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(AnalyticsMetric.allCases, id: \.self) { metric in
                        Text(metric.title).tag(metric)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            // Chart
            ModernCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text(selectedMetric.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ColorPalette.secondary)
                    
                    // Placeholder for chart - would use Swift Charts in real implementation
                    chartPlaceholder
                }
                .padding()
            }
        }
    }
    
    // MARK: - Prayer Breakdown Section
    
    @ViewBuilder
    private var prayerBreakdownSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Prayer Breakdown")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            ModernCard {
                VStack(spacing: 12) {
                    ForEach(Prayer.allCases, id: \.self) { prayer in
                        PrayerBreakdownRow(
                            prayer: prayer,
                            completionRate: getPrayerCompletionRate(prayer),
                            totalCount: getPrayerCount(prayer)
                        )
                        
                        if prayer != Prayer.allCases.last {
                            Divider()
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Insights Section
    
    @ViewBuilder
    private var insightsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                InsightCard(
                    icon: "lightbulb.fill",
                    title: "Great Progress!",
                    description: "You've maintained a \(prayerTrackingService.currentStreak)-day streak. Keep it up!",
                    color: .green
                )
                
                InsightCard(
                    icon: "clock.fill",
                    title: "Morning Consistency",
                    description: "Your Fajr prayer completion rate has improved by 15% this month.",
                    color: .blue
                )
                
                InsightCard(
                    icon: "target",
                    title: "Goal Suggestion",
                    description: "Try to complete all 5 prayers for the next 7 days to build momentum.",
                    color: .orange
                )
            }
        }
    }
    
    // MARK: - Chart Placeholder
    
    @ViewBuilder
    private var chartPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(ColorPalette.surface)
            .frame(height: 200)
            .overlay(
                VStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(ColorPalette.secondary)
                    
                    Text("Chart will be implemented with Swift Charts")
                        .font(.caption)
                        .foregroundColor(ColorPalette.secondary)
                        .multilineTextAlignment(.center)
                }
            )
    }
    
    // MARK: - Helper Methods
    
    private var mostConsistentPrayer: Prayer {
        // Calculate which prayer has the highest completion rate
        // For now, return Fajr as placeholder
        return .fajr
    }
    
    private func getPrayerCompletionRate(_ prayer: Prayer) -> Double {
        // Calculate completion rate for specific prayer
        // Placeholder implementation
        switch prayer {
        case .fajr: return 0.85
        case .dhuhr: return 0.92
        case .asr: return 0.78
        case .maghrib: return 0.95
        case .isha: return 0.88
        }
    }
    
    private func getPrayerCount(_ prayer: Prayer) -> Int {
        // Count total prayers of this type
        return prayerTrackingService.recentEntries.filter { $0.prayer == prayer }.count
    }
}

// MARK: - Supporting Types

private enum AnalyticsPeriod: CaseIterable {
    case week, month, year
    
    var title: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
}

private enum AnalyticsMetric: CaseIterable {
    case completion, streak, timing
    
    var title: String {
        switch self {
        case .completion: return "Completion Rate"
        case .streak: return "Streak Length"
        case .timing: return "Prayer Timing"
        }
    }
}

// MARK: - Supporting Views

private struct MetricCard: View {
    let title: String
    let value: String
    let change: String
    let isPositive: Bool
    let icon: String
    
    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(ColorPalette.primary)
                    
                    Spacer()
                    
                    Text(change)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isPositive ? .green : .red)
                }
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(ColorPalette.secondary)
            }
            .padding()
        }
    }
}

private struct PrayerBreakdownRow: View {
    let prayer: Prayer
    let completionRate: Double
    let totalCount: Int
    
    var body: some View {
        HStack {
            // Prayer Info
            HStack(spacing: 12) {
                Image(systemName: prayer.systemImageName)
                    .foregroundColor(prayer.color)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(prayer.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(totalCount) prayers")
                        .font(.caption)
                        .foregroundColor(ColorPalette.secondary)
                }
            }
            
            Spacer()
            
            // Completion Rate
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(completionRate * 100))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(prayer.color)
                
                // Progress Bar
                ProgressView(value: completionRate)
                    .progressViewStyle(LinearProgressViewStyle(tint: prayer.color))
                    .frame(width: 60)
            }
        }
    }
}

private struct InsightCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        ModernCard {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(ColorPalette.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding()
        }
    }
}
