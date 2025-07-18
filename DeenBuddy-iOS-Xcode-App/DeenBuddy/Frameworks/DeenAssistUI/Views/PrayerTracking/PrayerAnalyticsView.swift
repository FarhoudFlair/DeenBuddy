import SwiftUI
import Charts

// MARK: - Temporary Data Models

struct InsightData: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let color: Color
}

/// Comprehensive analytics view for prayer tracking data
public struct PrayerAnalyticsView: View {

    // MARK: - Properties

    // Temporarily using Any to avoid type resolution issues
    private let prayerTrackingService: Any
    private let onDismiss: () -> Void

    // MARK: - State

    @State private var selectedPeriod: String = "week"
    @State private var selectedMetric: String = "completion"
    @State private var insights: [InsightData] = []
    @State private var isLoadingInsights: Bool = false
    @State private var showingExportSheet: Bool = false

    // MARK: - Initialization

    public init(
        prayerTrackingService: Any,
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
                        showingExportSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }

            }
            .task {
                await loadInsights()
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportOptionsView(
                    selectedPeriod: selectedPeriod,
                    onExport: { format in
                        exportData(format: format)
                    }
                )
            }
        }
    }
    
    // MARK: - Period Selector
    
    @ViewBuilder
    private var periodSelector: some View {
        let periods = ["week", "month", "year"]
        let periodTitles = ["This Week", "This Month", "This Year"]

        HStack(spacing: 0) {
            ForEach(Array(zip(periods, periodTitles)), id: \.0) { period, title in
                Button(action: {
                    selectedPeriod = period
                }) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selectedPeriod == period ? .white : .blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedPeriod == period ? .blue : Color.clear)
                        )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
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
                    value: "85%",
                    change: "+5%",
                    isPositive: true,
                    icon: "checkmark.circle.fill"
                )

                MetricCard(
                    title: "Current Streak",
                    value: "5",
                    change: "+2 days",
                    isPositive: true,
                    icon: "flame.fill"
                )
            }

            HStack(spacing: 16) {
                MetricCard(
                    title: "Total Prayers",
                    value: "127",
                    change: "+12",
                    isPositive: true,
                    icon: "list.bullet"
                )

                MetricCard(
                    title: "Best Prayer",
                    value: mostConsistentPrayer,
                    change: "85%",
                    isPositive: true,
                    icon: "sunrise.fill"
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
                let metrics = ["completion", "streak", "timing"]
                let metricTitles = ["Completion Rate", "Streak Length", "Prayer Timing"]

                Picker("Metric", selection: $selectedMetric) {
                    ForEach(Array(zip(metrics, metricTitles)), id: \.0) { metric, title in
                        Text(title).tag(metric)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }

            // Chart
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .overlay(
                    VStack(alignment: .leading, spacing: 16) {
                        Text(metricTitle(for: selectedMetric))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        // Placeholder for chart - would use Swift Charts in real implementation
                        chartPlaceholder
                    }
                    .padding()
                )
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
            
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .overlay(
                    VStack(spacing: 12) {
                        let prayers = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
                        ForEach(Array(prayers.enumerated()), id: \.offset) { index, prayer in
                            PrayerBreakdownRow(
                                prayer: prayer,
                                completionRate: getPrayerCompletionRate(prayer),
                                totalCount: getPrayerCount(prayer)
                            )

                            if index < prayers.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding()
                )
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

                if isLoadingInsights {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if insights.isEmpty && !isLoadingInsights {
                // Empty state
                RoundedRectangle(cornerRadius: 16)
                    .fill(.background)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "lightbulb")
                                .font(.title2)
                                .foregroundColor(.secondary)

                            Text("No insights available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text("Complete more prayers to see personalized insights")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    )
                    .frame(height: 120)
            } else {
                VStack(spacing: 12) {
                    ForEach(insights) { insight in
                        InsightCard(
                            icon: insight.icon,
                            title: insight.title,
                            description: insight.description,
                            color: insight.color
                        )
                    }
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadInsights() async {
        isLoadingInsights = true
        defer { isLoadingInsights = false }

        // Generate sample insights based on mock data
        insights = generateSampleInsights()
    }

    private func generateSampleInsights() -> [InsightData] {
        return [
            InsightData(
                icon: "flame.fill",
                title: "Great Progress!",
                description: "You've maintained a 5-day streak. Keep it up!",
                color: .orange
            ),
            InsightData(
                icon: "clock.fill",
                title: "Morning Consistency",
                description: "Your Fajr prayer completion rate has improved by 15% this month.",
                color: .blue
            ),
            InsightData(
                icon: "target",
                title: "Goal Suggestion",
                description: "Try to complete all 5 prayers for the next 7 days to build momentum.",
                color: .green
            )
        ]
    }

    // MARK: - Chart Placeholder
    
    @ViewBuilder
    private var chartPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.background)
            .frame(height: 200)
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
<<<<<<< HEAD
                        .foregroundColor(.secondary)

                    Text("Chart will be implemented with Swift Charts")
=======
                        .foregroundColor(ColorPalette.primary)

                    Text("Prayer Analytics")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(ColorPalette.textPrimary)

                    Text("Visual charts showing your prayer patterns and progress over time")
>>>>>>> c54cbeadcd0d147f3e0a3fb6e51a2498ccc96886
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            )
    }
    
    // MARK: - Helper Methods

    private var mostConsistentPrayer: String {
        // Placeholder for most consistent prayer
        return "Fajr"
    }

    private func getPrayerCompletionRate(_ prayer: String) -> Double {
        // Placeholder completion rates
        switch prayer {
        case "Fajr": return 0.85
        case "Dhuhr": return 0.92
        case "Asr": return 0.78
        case "Maghrib": return 0.95
        case "Isha": return 0.88
        default: return 0.80
        }
    }

    private func getPrayerCount(_ prayer: String) -> Int {
        // Placeholder prayer counts
        return Int.random(in: 15...30)
    }

    private func metricTitle(for metric: String) -> String {
        switch metric {
        case "completion": return "Completion Rate"
        case "streak": return "Streak Length"
        case "timing": return "Prayer Timing"
        default: return "Completion Rate"
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
        RoundedRectangle(cornerRadius: 16)
            .fill(.background)
            .overlay(
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: icon)
                            .foregroundColor(.blue)

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
                        .foregroundColor(.secondary)
                }
                .padding()
            )
    }
}

private struct PrayerBreakdownRow: View {
    let prayer: String
    let completionRate: Double
    let totalCount: Int

    var body: some View {
        HStack {
            // Prayer Info
            HStack(spacing: 12) {
                Image(systemName: prayerIcon(for: prayer))
                    .foregroundColor(prayerColor(for: prayer))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(prayer)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("\(totalCount) prayers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Completion Rate
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(completionRate * 100))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(prayerColor(for: prayer))

                // Progress Bar
                ProgressView(value: completionRate)
                    .progressViewStyle(LinearProgressViewStyle(tint: prayerColor(for: prayer)))
                    .frame(width: 60)
            }
        }
    }

    private func prayerIcon(for prayer: String) -> String {
        switch prayer {
        case "Fajr": return "sunrise.fill"
        case "Dhuhr": return "sun.max.fill"
        case "Asr": return "sun.min.fill"
        case "Maghrib": return "sunset.fill"
        case "Isha": return "moon.stars.fill"
        default: return "circle.fill"
        }
    }

    private func prayerColor(for prayer: String) -> Color {
        switch prayer {
        case "Fajr": return .orange
        case "Dhuhr": return .yellow
        case "Asr": return .blue
        case "Maghrib": return .red
        case "Isha": return .purple
        default: return .gray
        }
    }
}

private struct InsightCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.background)
            .overlay(
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
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()
                }
                .padding()
            )
    }
}


