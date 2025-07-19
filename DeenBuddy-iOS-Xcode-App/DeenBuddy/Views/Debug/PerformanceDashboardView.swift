import SwiftUI
import Combine

/// Performance monitoring dashboard for debugging and optimization
/// Only available in debug builds
struct PerformanceDashboardView: View {
    
    @StateObject private var performanceService = PerformanceMonitoringService.shared
    @State private var isExpanded = false
    @State private var showingReport = false
    @State private var currentReport: PerformanceReport?
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "speedometer")
                    .foregroundColor(alertColor)
                
                Text("Performance Monitor")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            if isExpanded {
                // Quick Metrics
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    MetricCard(
                        title: "Memory",
                        value: "\(performanceService.currentMetrics.memoryUsage / 1024 / 1024)MB",
                        icon: "memorychip",
                        color: memoryColor
                    )
                    
                    MetricCard(
                        title: "Battery",
                        value: "\(Int(performanceService.currentMetrics.batteryLevel * 100))%",
                        icon: "battery.100",
                        color: batteryColor
                    )
                    
                    MetricCard(
                        title: "Timers",
                        value: "\(performanceService.currentMetrics.activeTimerCount)",
                        icon: "timer",
                        color: timerColor
                    )
                    
                    MetricCard(
                        title: "Cache Hit",
                        value: "\(String(format: "%.1f%%", performanceService.currentMetrics.cacheHitRate * 100))",
                        icon: "externaldrive",
                        color: cacheColor
                    )
                }
                
                // Alert Level
                HStack {
                    Image(systemName: alertIcon)
                        .foregroundColor(alertColor)
                    
                    Text("Status: \(performanceService.alertLevel.displayName)")
                        .font(.subheadline)
                        .foregroundColor(alertColor)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button("Optimize") {
                        performanceService.optimizePerformance()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    
                    Button("Full Report") {
                        currentReport = performanceService.getPerformanceReport()
                        showingReport = true
                    }
                    .buttonStyle(.bordered)
                    
                    Button(performanceService.isMonitoring ? "Stop" : "Start") {
                        if performanceService.isMonitoring {
                            performanceService.stopMonitoring()
                        } else {
                            performanceService.startMonitoring()
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(performanceService.isMonitoring ? .red : .green)
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
        .sheet(isPresented: $showingReport) {
            if let report = currentReport {
                PerformanceReportView(report: report)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var alertColor: Color {
        switch performanceService.alertLevel {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
    
    private var alertIcon: String {
        switch performanceService.alertLevel {
        case .normal: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "xmark.circle"
        }
    }
    
    private var memoryColor: Color {
        let memoryMB = performanceService.currentMetrics.memoryUsage / 1024 / 1024
        if memoryMB > 150 { return .red }
        if memoryMB > 100 { return .orange }
        return .green
    }
    
    private var batteryColor: Color {
        let batteryPercent = performanceService.currentMetrics.batteryLevel
        if batteryPercent < 0.2 { return .red }
        if batteryPercent < 0.5 { return .orange }
        return .green
    }
    
    private var timerColor: Color {
        let timerCount = performanceService.currentMetrics.activeTimerCount
        if timerCount > 10 { return .red }
        if timerCount > 5 { return .orange }
        return .green
    }
    
    private var cacheColor: Color {
        let hitRate = performanceService.currentMetrics.cacheHitRate
        if hitRate < 0.6 { return .red }
        if hitRate < 0.8 { return .orange }
        return .green
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Performance Report View

struct PerformanceReportView: View {
    let report: PerformanceReport
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary")
                            .font(.headline)
                        
                        Text(report.summary)
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // Recommendations
                    if !report.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recommendations")
                                .font(.headline)
                            
                            ForEach(report.recommendations, id: \.self) { recommendation in
                                HStack(alignment: .top) {
                                    Image(systemName: "lightbulb")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    
                                    Text(recommendation)
                                        .font(.body)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Detailed Metrics
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detailed Metrics")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Timer Statistics:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(report.timerStatistics.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cache Metrics:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(report.cacheMetrics.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("Performance Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Debug Only

#if DEBUG
struct PerformanceDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        PerformanceDashboardView()
            .padding()
    }
}
#endif
