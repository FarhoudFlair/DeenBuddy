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

enum ExportFormat: String, CaseIterable {
    case csv = "CSV"
    case pdf = "PDF"
    case text = "Text"

    var icon: String {
        switch self {
        case .csv: return "tablecells"
        case .pdf: return "doc.richtext"
        case .text: return "doc.text"
        }
    }

    var description: String {
        switch self {
        case .csv: return "Spreadsheet format for data analysis"
        case .pdf: return "Formatted document for sharing"
        case .text: return "Plain text format"
        }
    }
}

enum ExportStatus {
    case idle
    case exporting
    case success
    case failure
}

struct ExportData {
    let period: String
    let completionRate: String
    let currentStreak: String
    let totalPrayers: String
    let bestPrayer: String
    let insights: [String]
    let prayers: [PrayerExportData]
}

struct PrayerExportData {
    let name: String
    let completionRate: Double
    let totalCount: Int
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
    @State private var exportStatus: ExportStatus = .idle
    @State private var exportMessage: String = ""

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
                PrayerMetricCard(
                    title: "Completion Rate",
                    value: "85%",
                    change: "+5%",
                    isPositive: true,
                    icon: "checkmark.circle.fill"
                )

                PrayerMetricCard(
                    title: "Current Streak",
                    value: "5",
                    change: "+2 days",
                    isPositive: true,
                    icon: "flame.fill"
                )
            }

            HStack(spacing: 16) {
                PrayerMetricCard(
                    title: "Total Prayers",
                    value: "127",
                    change: "+12",
                    isPositive: true,
                    icon: "list.bullet"
                )

                PrayerMetricCard(
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
                VStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)

                    Text("Chart will be implemented with Swift Charts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
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

    private func exportData(format: ExportFormat) {
        let exportData = generateExportData()

        switch format {
        case .csv:
            shareCSV(data: exportData)
        case .pdf:
            sharePDF(data: exportData)
        case .text:
            shareText(data: exportData)
        }

        showingExportSheet = false
    }

    private func generateExportData() -> ExportData {
        return ExportData(
            period: selectedPeriod,
            completionRate: "85%",
            currentStreak: "5 days",
            totalPrayers: "127",
            bestPrayer: mostConsistentPrayer,
            insights: insights.map { "\($0.title): \($0.description)" },
            prayers: ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"].map { prayer in
                PrayerExportData(
                    name: prayer,
                    completionRate: getPrayerCompletionRate(prayer),
                    totalCount: getPrayerCount(prayer)
                )
            }
        )
    }

    private func shareCSV(data: ExportData) {
        // Build properly escaped CSV content
        var csvContent = "\(escapeCsvValue("Prayer Analytics Export - \(data.period.capitalized)"))\n\n"

        // Summary section with proper CSV formatting
        csvContent += "\(escapeCsvValue("Summary"))\n"
        csvContent += "\(escapeCsvValue("Completion Rate")),\(escapeCsvValue(data.completionRate))\n"
        csvContent += "\(escapeCsvValue("Current Streak")),\(escapeCsvValue(data.currentStreak))\n"
        csvContent += "\(escapeCsvValue("Total Prayers")),\(escapeCsvValue(data.totalPrayers))\n"
        csvContent += "\(escapeCsvValue("Best Prayer")),\(escapeCsvValue(data.bestPrayer))\n\n"

        // Prayer breakdown section with headers
        csvContent += "\(escapeCsvValue("Prayer Breakdown"))\n"
        csvContent += "\(escapeCsvValue("Prayer")),\(escapeCsvValue("Completion Rate")),\(escapeCsvValue("Total Count"))\n"

        // Prayer data with proper escaping
        for prayer in data.prayers {
            let completionRateText = "\(Int(prayer.completionRate * 100))%"
            csvContent += "\(escapeCsvValue(prayer.name)),\(escapeCsvValue(completionRateText)),\(escapeCsvValue(String(prayer.totalCount)))\n"
        }

        // Insights section
        csvContent += "\n\(escapeCsvValue("Insights"))\n"
        for insight in data.insights {
            csvContent += "\(escapeCsvValue(insight))\n"
        }

        shareContent(csvContent, fileName: "prayer_analytics_\(data.period).csv")
    }

    private func sharePDF(data: ExportData) {
        // Generate formatted text content for PDF-style export
        let pdfContent = formatDataForPDF(data)

        // Validate content before sharing
        guard !pdfContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ PDF export failed: No content to export")
            return
        }

        shareContent(pdfContent, fileName: "prayer_analytics_\(data.period).txt")
    }

    private func shareText(data: ExportData) {
        let textContent = formatDataAsText(data)

        // Validate content before sharing
        guard !textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ Text export failed: No content to export")
            return
        }

        shareContent(textContent, fileName: "prayer_analytics_\(data.period).txt")
    }

    private func formatDataForPDF(_ data: ExportData) -> String {
        var content = "PRAYER ANALYTICS REPORT\n"
        content += "Period: \(data.period.capitalized)\n"
        content += "Generated: \(Date().formatted(date: .abbreviated, time: .shortened))\n\n"
        content += "SUMMARY\n"
        content += "• Completion Rate: \(data.completionRate)\n"
        content += "• Current Streak: \(data.currentStreak)\n"
        content += "• Total Prayers: \(data.totalPrayers)\n"
        content += "• Best Prayer: \(data.bestPrayer)\n\n"
        content += "PRAYER BREAKDOWN\n"

        for prayer in data.prayers {
            content += "• \(prayer.name): \(Int(prayer.completionRate * 100))% (\(prayer.totalCount) prayers)\n"
        }

        content += "\nINSIGHTS\n"
        for insight in data.insights {
            content += "• \(insight)\n"
        }

        return content
    }

    private func formatDataAsText(_ data: ExportData) -> String {
        return formatDataForPDF(data) // Same format for now
    }

    // MARK: - CSV Helper Functions

    /// Escapes CSV field values by wrapping in quotes and escaping internal quotes
    /// - Parameter value: The string value to escape
    /// - Returns: Properly escaped CSV field value
    private func escapeCsvValue(_ value: String) -> String {
        // Wrap all values in double quotes and escape internal quotes by doubling them
        let escapedValue = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escapedValue)\""
    }

    // MARK: - Sharing Implementation

    private func shareContent(_ content: String, fileName: String) {
        // Update export status
        exportStatus = .exporting
        exportMessage = "Preparing export..."

        // Validate content before attempting to share
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            exportStatus = .failure
            exportMessage = "Export failed: Content is empty"
            print("❌ Export failed: Content is empty")
            return
        }

        // Validate filename
        guard !fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            exportStatus = .failure
            exportMessage = "Export failed: Invalid filename"
            print("❌ Export failed: Invalid filename")
            return
        }

        do {
            // Create temporary file
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileURL = tempDirectory.appendingPathComponent(fileName)

            // Write content to file
            try content.write(to: fileURL, atomically: true, encoding: .utf8)

            // Share the file
            DispatchQueue.main.async {
                self.shareFile(at: fileURL, fileName: fileName)
            }

        } catch {
            exportStatus = .failure
            exportMessage = "Export failed: \(error.localizedDescription)"
            print("❌ Export failed: \(error.localizedDescription)")
        }
    }

    private func shareFile(at url: URL, fileName: String) {
        // Verify file was created successfully
        guard FileManager.default.fileExists(atPath: url.path) else {
            exportStatus = .failure
            exportMessage = "File creation failed: File does not exist"
            print("❌ File creation failed: File does not exist at \(url.path)")
            return
        }

        // Get file size for validation
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0

            guard fileSize > 0 else {
                exportStatus = .failure
                exportMessage = "File creation failed: File is empty"
                print("❌ File creation failed: File is empty")
                return
            }

            print("✅ File created successfully: \(fileName)")
            print("📁 File location: \(url.path)")
            print("💡 File size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
            print("📤 Content ready for sharing")

            // Copy to Documents directory for easier access
            copyToDocumentsDirectory(from: url, fileName: fileName)

            // Update status to success
            exportStatus = .success
            exportMessage = "Export completed successfully! File saved to Documents."

        } catch {
            exportStatus = .failure
            exportMessage = "File validation failed: \(error.localizedDescription)"
            print("❌ File validation failed: \(error.localizedDescription)")
        }
    }

    private func copyToDocumentsDirectory(from sourceURL: URL, fileName: String) {
        do {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationURL = documentsDirectory.appendingPathComponent(fileName)

            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            // Copy file to Documents directory
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            print("📋 File copied to Documents: \(destinationURL.path)")
            print("💡 Users can access this file through the Files app")

        } catch {
            print("⚠️ Could not copy to Documents directory: \(error.localizedDescription)")
            print("💡 File is still available at: \(sourceURL.path)")
        }
    }


}

// MARK: - Supporting Views

private struct PrayerMetricCard: View {
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

// MARK: - Export Options View

private struct ExportOptionsView: View {
    let selectedPeriod: String
    let onExport: (ExportFormat) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)

                    Text("Export Prayer Analytics")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Export your \(selectedPeriod) prayer analytics data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                VStack(spacing: 12) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        ExportFormatRow(
                            format: format,
                            onTap: {
                                onExport(format)
                                dismiss()
                            }
                        )
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ExportFormatRow: View {
    let format: ExportFormat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .overlay(
                    HStack(spacing: 16) {
                        Image(systemName: format.icon)
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(format.rawValue)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text(format.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
