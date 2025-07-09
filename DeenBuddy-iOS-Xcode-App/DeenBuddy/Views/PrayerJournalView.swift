//
//  PrayerJournalView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-09.
//

import SwiftUI
import Charts

struct PrayerJournalView: View {
    @StateObject private var journalService: PrayerJournalService
    @State private var selectedTab = 0
    @State private var showingAddEntry = false
    @State private var showingGoals = false
    @State private var selectedTimeRange: TimeRange = .week
    
    init(journalService: PrayerJournalService = PrayerJournalService(prayerTimeService: PrayerTimeService())) {
        _journalService = StateObject(wrappedValue: journalService)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ModernGradientBackground()
                
                VStack(spacing: 0) {
                    // Time range selector
                    timeRangeSelector
                    
                    // Main content
                    TabView(selection: $selectedTab) {
                        overviewTab
                            .tag(0)
                        
                        statisticsTab
                            .tag(1)
                        
                        goalsTab
                            .tag(2)
                        
                        entriesTab
                            .tag(3)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    
                    // Tab selector
                    tabSelector
                }
            }
            .navigationTitle("Prayer Journal")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddEntry = true }) {
                        Image(systemName: "plus")
                    }
                    .foregroundColor(.cyan)
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                AddPrayerEntryView(journalService: journalService)
            }
            .sheet(isPresented: $showingGoals) {
                PrayerGoalsView(journalService: journalService)
            }
        }
    }
    
    private var timeRangeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    TimeRangeButton(
                        title: range.displayName,
                        isSelected: selectedTimeRange == range,
                        color: .cyan
                    ) {
                        selectedTimeRange = range
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var overviewTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Today's progress
                todayProgressCard
                
                // Streak info
                streakCard
                
                // Recent entries
                recentEntriesCard
                
                // Quick stats
                quickStatsCard
            }
            .padding()
        }
    }
    
    private var statisticsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Completion chart
                completionChartCard
                
                // Prayer distribution
                prayerDistributionCard
                
                // Time analysis
                timeAnalysisCard
                
                // Mood tracking
                moodTrackingCard
            }
            .padding()
        }
    }
    
    private var goalsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Active goals
                activeGoalsCard
                
                // Progress overview
                goalsProgressCard
                
                // Completed goals
                completedGoalsCard
            }
            .padding()
        }
    }
    
    private var entriesTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(journalService.entries.prefix(50)) { entry in
                    PrayerEntryCard(entry: entry, journalService: journalService)
                }
                
                if journalService.entries.isEmpty {
                    EmptyJournalView {
                        showingAddEntry = true
                    }
                }
            }
            .padding()
        }
    }
    
    private var todayProgressCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Today's Progress")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(Int(journalService.getTodayCompletionPercentage() * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                }
                
                // Progress bar
                ProgressView(value: journalService.getTodayCompletionPercentage())
                    .progressViewStyle(LinearProgressViewStyle(tint: .cyan))
                    .scaleEffect(y: 2)
                
                // Prayer checkboxes
                HStack(spacing: 16) {
                    ForEach(Prayer.allCases, id: \.self) { prayer in
                        VStack(spacing: 4) {
                            Image(systemName: journalService.isPrayerCompletedToday(prayer) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundColor(journalService.isPrayerCompletedToday(prayer) ? prayer.color : .white.opacity(0.4))
                            
                            Text(prayer.shortName)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                
                // Next prayer reminder
                if let nextPrayer = journalService.getNextPrayerToComplete() {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                        
                        Text("Next: \(nextPrayer.displayName)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                        
                        Button("Log Now") {
                            showingAddEntry = true
                        }
                        .buttonStyle(CompactModernButtonStyle())
                    }
                }
            }
            .padding()
        }
    }
    
    private var streakCard: some View {
        ModernCard {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Streak")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("\(journalService.currentStreak)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        
                        Text("days")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Best Streak")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("\(journalService.bestStreak)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.gold)
                        
                        Text("days")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                // Streak visualization (last 7 days)
                streakVisualization
            }
            .padding()
        }
    }
    
    private var streakVisualization: some View {
        HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { dayOffset in
                let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
                let dayStats = journalService.getDailyStats(for: date)
                
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(dayStats.isCompleteDay ? Color.green : Color.white.opacity(0.2))
                        .frame(width: 20, height: 20)
                    
                    Text(Calendar.current.component(.day, from: date), format: .number)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }
    
    private var recentEntriesCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent Prayers")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("View All") {
                        selectedTab = 3
                    }
                    .font(.subheadline)
                    .foregroundColor(.cyan)
                }
                
                if journalService.entries.isEmpty {
                    Text("No prayers logged yet")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical)
                } else {
                    ForEach(journalService.entries.prefix(3)) { entry in
                        RecentEntryRow(entry: entry)
                        
                        if entry.id != journalService.entries.prefix(3).last?.id {
                            Divider()
                                .background(Color.white.opacity(0.1))
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var quickStatsCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Quick Stats")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                let weeklyStats = journalService.getWeeklyStats()
                
                HStack(spacing: 20) {
                    StatItem(
                        title: "This Week",
                        value: "\(Int(weeklyStats.overallCompletionPercentage * 100))%",
                        color: .cyan
                    )
                    
                    StatItem(
                        title: "On Time",
                        value: "\(Int(weeklyStats.onTimePercentage * 100))%",
                        color: .green
                    )
                    
                    StatItem(
                        title: "Congregation",
                        value: "\(Int(weeklyStats.congregationPercentage * 100))%",
                        color: .orange
                    )
                }
            }
            .padding()
        }
    }
    
    private var completionChartCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Prayer Completion Trend")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                // Chart placeholder - would implement with Swift Charts
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 200)
                    .overlay(
                        Text("Chart coming soon")
                            .foregroundColor(.white.opacity(0.6))
                    )
            }
            .padding()
        }
    }
    
    private var prayerDistributionCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Prayer Distribution")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                // Prayer completion percentages
                ForEach(Prayer.allCases, id: \.self) { prayer in
                    let entries = journalService.entries.filter { $0.prayer == prayer }
                    let percentage = entries.isEmpty ? 0.0 : 1.0 // Simplified calculation
                    
                    HStack {
                        Image(systemName: prayer.systemImageName)
                            .foregroundColor(prayer.color)
                            .frame(width: 20)
                        
                        Text(prayer.displayName)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(entries.count)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding()
        }
    }
    
    private var timeAnalysisCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Time Analysis")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                let avgDuration = journalService.entries.compactMap { $0.duration }.reduce(0, +) / Double(max(1, journalService.entries.count))
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Average Duration")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(formatDuration(avgDuration))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.cyan)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Total Time")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        let totalTime = journalService.entries.compactMap { $0.duration }.reduce(0, +)
                        Text(formatDuration(totalTime))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding()
        }
    }
    
    private var moodTrackingCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Mood Tracking")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                let moodCounts = Dictionary(grouping: journalService.entries.compactMap { $0.mood }) { $0 }
                    .mapValues { $0.count }
                
                if moodCounts.isEmpty {
                    Text("No mood data available")
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(Array(moodCounts.keys), id: \.self) { mood in
                            VStack(spacing: 4) {
                                Text(mood.emoji)
                                    .font(.title2)
                                
                                Text("\(moodCounts[mood] ?? 0)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text(mood.displayName)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var activeGoalsCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Active Goals")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Manage") {
                        showingGoals = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.cyan)
                }
                
                if journalService.activeGoals.isEmpty {
                    Text("No active goals")
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical)
                } else {
                    ForEach(journalService.activeGoals.prefix(3)) { goal in
                        GoalProgressRow(goal: goal)
                        
                        if goal.id != journalService.activeGoals.prefix(3).last?.id {
                            Divider()
                                .background(Color.white.opacity(0.1))
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var goalsProgressCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Goals Overview")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                HStack(spacing: 20) {
                    StatItem(
                        title: "Active",
                        value: "\(journalService.activeGoals.count)",
                        color: .blue
                    )
                    
                    StatItem(
                        title: "Completed",
                        value: "\(journalService.completedGoals.count)",
                        color: .green
                    )
                    
                    let avgProgress = journalService.activeGoals.isEmpty ? 0.0 : 
                        journalService.activeGoals.map { $0.progress }.reduce(0, +) / Double(journalService.activeGoals.count)
                    
                    StatItem(
                        title: "Avg Progress",
                        value: "\(Int(avgProgress * 100))%",
                        color: .purple
                    )
                }
            }
            .padding()
        }
    }
    
    private var completedGoalsCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Completed Goals")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                if journalService.completedGoals.isEmpty {
                    Text("No completed goals yet")
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical)
                } else {
                    ForEach(journalService.completedGoals.prefix(5)) { goal in
                        CompletedGoalRow(goal: goal)
                        
                        if goal.id != journalService.completedGoals.prefix(5).last?.id {
                            Divider()
                                .background(Color.white.opacity(0.1))
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            TabSelectorButton(title: "Overview", isSelected: selectedTab == 0) { selectedTab = 0 }
            TabSelectorButton(title: "Stats", isSelected: selectedTab == 1) { selectedTab = 1 }
            TabSelectorButton(title: "Goals", isSelected: selectedTab == 2) { selectedTab = 2 }
            TabSelectorButton(title: "Entries", isSelected: selectedTab == 3) { selectedTab = 3 }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(seconds)s"
    }
}

// MARK: - Supporting Views

enum TimeRange: CaseIterable {
    case week, month, quarter, year
    
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .quarter: return "Quarter"
        case .year: return "Year"
        }
    }
}

struct TimeRangeButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .black : color)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? color : color.opacity(0.2))
                .cornerRadius(20)
        }
    }
}

struct TabSelectorButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .cyan : .white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.cyan.opacity(0.2) : Color.clear)
                .cornerRadius(8)
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }
}

struct RecentEntryRow: View {
    let entry: PrayerJournalEntry
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.prayer.systemImageName)
                .foregroundColor(entry.prayer.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.prayer.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(entry.completedAt, style: .time)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            if let mood = entry.mood {
                Text(mood.emoji)
                    .font(.title3)
            }
            
            if entry.isOnTime {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}

struct GoalProgressRow: View {
    let goal: PrayerGoal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(goal.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(Int(goal.progress * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.cyan)
            }
            
            ProgressView(value: goal.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .cyan))
                .scaleEffect(y: 1.5)
            
            HStack {
                Text("\(Int(goal.currentValue))/\(Int(goal.targetValue)) \(goal.type.unit)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                if goal.daysRemaining > 0 {
                    Text("\(goal.daysRemaining) days left")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }
}

struct CompletedGoalRow: View {
    let goal: PrayerGoal
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text("Completed \(goal.endDate, style: .date)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
    }
}

struct EmptyJournalView: View {
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 50))
                .foregroundColor(.white.opacity(0.4))
            
            Text("No Prayer Entries")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Start tracking your prayers to see insights and build consistency")
                .font(.body)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            
            Button("Log Your First Prayer") {
                action()
            }
            .buttonStyle(PrimaryModernButtonStyle())
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

extension Color {
    static let gold = Color(red: 1.0, green: 0.8, blue: 0.0)
}

extension Prayer {
    var shortName: String {
        switch self {
        case .fajr: return "Fajr"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        }
    }
}

struct CompactModernButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.cyan.opacity(configuration.isPressed ? 0.8 : 1.0))
            .foregroundColor(.black)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    PrayerJournalView()
}