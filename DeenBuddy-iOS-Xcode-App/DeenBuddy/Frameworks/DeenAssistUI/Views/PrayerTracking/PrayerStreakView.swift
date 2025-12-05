import SwiftUI

/// View for displaying prayer streaks and consistency patterns
public struct PrayerStreakView: View {
    
    // MARK: - Properties
    
    private let prayerTrackingService: any PrayerTrackingServiceProtocol
    
    // MARK: - State

    @State private var selectedMonth: Date = Date()
    @State private var individualStreaks: [Prayer: IndividualPrayerStreak] = [:]
    @State private var isLoadingStreaks: Bool = false
    @State private var loadError: Error?

    // MARK: - Initialization
    
    public init(prayerTrackingService: any PrayerTrackingServiceProtocol) {
        self.prayerTrackingService = prayerTrackingService
    }
    
    // MARK: - Body
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Current Streak Card
                currentStreakCard

                // Individual Prayer Streaks (NEW)
                individualPrayerStreaksSection

                // Streak History
                streakHistorySection

                // Calendar Heat Map
                calendarHeatMapSection

                // Achievements
                achievementsSection

                // Motivational Section
                motivationalSection
            }
            .padding()
        }
        .task {
            do {
                try await loadIndividualStreaks()
                loadError = nil // Clear any previous errors on success
            } catch {
                loadError = error
                print("⚠️ Failed to load individual prayer streaks: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Current Streak Card
    
    @ViewBuilder
    private var currentStreakCard: some View {
        ModernCard {
            VStack(spacing: 20) {
                // Flame Icon with Streak
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.orange.opacity(0.3), .red.opacity(0.1)],
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: 50
                                )
                            )
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "flame.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    
                    Text("\(prayerTrackingService.currentStreak)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Day Streak")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                
                // Streak Description
                VStack(spacing: 8) {
                    if prayerTrackingService.currentStreak > 0 {
                        Text(streakMessage)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        // Progress to next milestone
                        streakProgressView
                    } else {
                        Text("Start your prayer streak today!")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Individual Prayer Streaks Section

    @ViewBuilder
    private var individualPrayerStreaksSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Individual Prayer Streaks")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                if isLoadingStreaks {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if isLoadingStreaks {
                ModernCard {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading streaks...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(height: 150)
                }
            } else if let error = loadError {
                individualStreaksErrorView(error)
            } else {
                // Display individual streak cards for all 5 prayers
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Prayer.allCases, id: \.self) { prayer in
                        if let streak = individualStreaks[prayer] {
                            IndividualPrayerStreakCard(streak: streak)
                        } else {
                            // Fallback empty card
                            IndividualPrayerStreakCard(
                                streak: IndividualPrayerStreak(
                                    prayer: prayer,
                                    currentStreak: 0,
                                    longestStreak: 0,
                                    lastCompleted: nil,
                                    isActiveToday: false,
                                    startDate: nil
                                )
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Streak History Section

    @ViewBuilder
    private var streakHistorySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Streak History")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            ModernCard {
                VStack(spacing: 12) {
                    StreakHistoryRow(
                        title: "Current Streak",
                        days: prayerTrackingService.currentStreak,
                        startDate: Calendar.current.date(byAdding: .day, value: -prayerTrackingService.currentStreak, to: Date()) ?? Date(),
                        isActive: true
                    )
                    
                    Divider()
                    
                    StreakHistoryRow(
                        title: "Best Streak",
                        days: 15, // Placeholder - would calculate from data
                        startDate: Date().addingTimeInterval(-30 * 86400),
                        isActive: false
                    )
                    
                    Divider()
                    
                    StreakHistoryRow(
                        title: "Previous Streak",
                        days: 8,
                        startDate: Date().addingTimeInterval(-45 * 86400),
                        isActive: false
                    )
                }
                .padding()
            }
        }
    }
    
    // MARK: - Calendar Heat Map Section
    
    @ViewBuilder
    private var calendarHeatMapSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Prayer Consistency")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Month Navigation
                HStack {
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                    }
                    
                    Text(selectedMonth.formatted(.dateTime.month(.wide).year()))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                    }
                }
                .foregroundColor(.primary)
            }
            
            ModernCard {
                VStack(spacing: 16) {
                    // Calendar Grid
                    calendarGrid
                    
                    // Legend
                    calendarLegend
                }
                .padding()
            }
        }
    }
    
    // MARK: - Achievements Section
    
    @ViewBuilder
    private var achievementsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                AchievementCard(
                    icon: "flame.fill",
                    title: "First Streak",
                    description: "Complete 3 days in a row",
                    isUnlocked: prayerTrackingService.currentStreak >= 3,
                    color: .orange
                )
                
                AchievementCard(
                    icon: "star.fill",
                    title: "Week Warrior",
                    description: "Complete 7 days in a row",
                    isUnlocked: prayerTrackingService.currentStreak >= 7,
                    color: .yellow
                )
                
                AchievementCard(
                    icon: "crown.fill",
                    title: "Prayer Master",
                    description: "Complete 30 days in a row",
                    isUnlocked: prayerTrackingService.currentStreak >= 30,
                    color: .purple
                )
                
                AchievementCard(
                    icon: "diamond.fill",
                    title: "Consistency King",
                    description: "Complete 100 prayers",
                    isUnlocked: prayerTrackingService.totalPrayersCompleted >= 100,
                    color: .blue
                )
            }
        }
    }
    
    // MARK: - Motivational Section
    
    @ViewBuilder
    private var motivationalSection: some View {
        ModernCard {
            VStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .font(.title)
                    .foregroundColor(.pink)
                
                Text("Keep Going!")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(motivationalMessage)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
    
    // MARK: - Calendar Grid
    
    @ViewBuilder
    private var calendarGrid: some View {
        let calendar = Calendar.current
        if let monthRange = calendar.range(of: .day, in: .month, for: selectedMonth),
           let dateInterval = calendar.dateInterval(of: .month, for: selectedMonth) {
            
            let firstOfMonth = dateInterval.start
            let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                // Weekday headers
                ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(height: 20)
                }
                
                // Empty cells for days before month starts
                ForEach(0..<(firstWeekday - 1), id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 30)
                }
                
                // Days of the month
                ForEach(1...monthRange.count, id: \.self) { day in
                    if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                        let completionRate = getDayCompletionRate(for: date)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(getHeatMapColor(for: completionRate))
                            .frame(height: 30)
                            .overlay(
                                Text("\(day)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(completionRate > 0.5 ? .white : .primary)
                            )
                    } else {
                        // Fallback for invalid dates
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.clear)
                            .frame(height: 30)
                            .overlay(
                                Text("\(day)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            )
                    }
                }
            }
        } else {
            // Fallback view for invalid calendar operations
            Text("Calendar unavailable")
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Calendar Legend
    
    @ViewBuilder
    private var calendarLegend: some View {
        HStack {
            Text("Less")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 2) {
                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { rate in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(getHeatMapColor(for: rate))
                        .frame(width: 12, height: 12)
                }
            }
            
            Text("More")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Streak Progress View
    
    @ViewBuilder
    private var streakProgressView: some View {
        let nextMilestone = getNextMilestone()
        let progress = Double(prayerTrackingService.currentStreak) / Double(nextMilestone)
        
        VStack(spacing: 8) {
            HStack {
                Text("Next milestone: \(nextMilestone) days")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(nextMilestone - prayerTrackingService.currentStreak) days to go")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
        }
    }
    
    // MARK: - Helper Methods
    
    private var streakMessage: String {
        let streak = prayerTrackingService.currentStreak
        switch streak {
        case 1: return "Great start! Keep the momentum going."
        case 2...6: return "You're building a solid habit!"
        case 7...13: return "Amazing! You're on fire! 🔥"
        case 14...29: return "Incredible consistency! You're inspiring!"
        case 30...99: return "You're a prayer champion! Mashallah!"
        default: return "Subhanallah! Your dedication is remarkable!"
        }
    }
    
    private var motivationalMessage: String {
        let streak = prayerTrackingService.currentStreak
        if streak == 0 {
            return "Every journey begins with a single step. Start your prayer streak today!"
        } else {
            return "Your consistency in prayer is a beautiful form of worship. May Allah accept your efforts."
        }
    }
    
    private func getNextMilestone() -> Int {
        let streak = prayerTrackingService.currentStreak
        let milestones = [3, 7, 14, 30, 60, 100, 365]
        return milestones.first { $0 > streak } ?? (streak + 30)
    }
    
    private func previousMonth() {
        selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
    }
    
    private func nextMonth() {
        selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
    }
    
    private func getDayCompletionRate(for date: Date) -> Double {
        // Calculate completion rate for a specific day
        // This would check how many of the 5 prayers were completed on that day
        // Placeholder implementation
        let dayEntries = prayerTrackingService.recentEntries.filter { entry in
            Calendar.current.isDate(entry.completedAt, inSameDayAs: date)
        }
        return min(Double(dayEntries.count) / 5.0, 1.0)
    }
    
    private func getHeatMapColor(for completionRate: Double) -> Color {
        switch completionRate {
        case 0: return Color.gray.opacity(0.1)
        case 0.01...0.25: return Color.blue.opacity(0.2)
        case 0.26...0.5: return Color.blue.opacity(0.4)
        case 0.51...0.75: return Color.blue.opacity(0.6)
        case 0.76...1.0: return Color.blue.opacity(0.8)
        default: return Color.gray.opacity(0.1)
        }
    }

    // Load individual prayer streaks
    private func loadIndividualStreaks() async throws {
        // Guard against concurrent loads, but allow reloading even if empty (after errors)
        guard !isLoadingStreaks else {
            return
        }

        isLoadingStreaks = true
        defer { isLoadingStreaks = false }

        // Fetch individual prayer streaks with error propagation
        individualStreaks = try await prayerTrackingService.getIndividualPrayerStreaks()
    }
    
    private func retryLoadIndividualStreaks() {
        Task {
            loadError = nil
            do {
                try await loadIndividualStreaks()
                loadError = nil
            } catch {
                loadError = error
            }
        }
    }
    
    private func individualStreaksErrorView(_ error: Error) -> some View {
        ModernCard {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("Unable to Load Streaks")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text(error.localizedDescription)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Button("Retry") {
                    retryLoadIndividualStreaks()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding()
        }
    }
}

// MARK: - Supporting Views

private struct StreakHistoryRow: View {
    let title: String
    let days: Int
    let startDate: Date
    let isActive: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(startDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                if isActive {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                
                Text("\(days) days")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isActive ? .orange : .primary)
            }
        }
    }
}

private struct AchievementCard: View {
    let icon: String
    let title: String
    let description: String
    let isUnlocked: Bool
    let color: Color
    
    var body: some View {
        ModernCard {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isUnlocked ? color : .secondary)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isUnlocked ? .primary : .secondary)

                Text(description)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding()
            .opacity(isUnlocked ? 1.0 : 0.6)
        }
    }
}
