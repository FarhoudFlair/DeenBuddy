import SwiftUI
import Combine

/// Main Prayer Tracking screen that replaces the Guides functionality
/// Provides prayer completion tracking, analytics, and motivational features
public struct PrayerTrackingScreen: View {
    
    // MARK: - Services
    
    private let prayerTrackingService: any PrayerTrackingServiceProtocol
    private let prayerTimeService: any PrayerTimeServiceProtocol
    private let notificationService: any NotificationServiceProtocol
    
    // MARK: - State
    
    @State private var selectedTab: TrackingTab = .today
    @State private var showingPrayerCompletion = false
    @State private var selectedPrayer: Prayer?
    @State private var showingAnalytics = false
    
    // MARK: - Callbacks
    
    private let onDismiss: () -> Void
    
    // MARK: - Initialization
    
    public init(
        prayerTrackingService: any PrayerTrackingServiceProtocol,
        prayerTimeService: any PrayerTimeServiceProtocol,
        notificationService: any NotificationServiceProtocol,
        onDismiss: @escaping () -> Void
    ) {
        self.prayerTrackingService = prayerTrackingService
        self.prayerTimeService = prayerTimeService
        self.notificationService = notificationService
        self.onDismiss = onDismiss
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                trackingTabSelector
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    // Today's Prayer Tracking
                    todayTrackingView
                        .tag(TrackingTab.today)
                    
                    // Analytics View
                    analyticsView
                        .tag(TrackingTab.analytics)
                    
                    // Streak View
                    streakView
                        .tag(TrackingTab.streak)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Prayer Tracking")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAnalytics = true
                    }) {
                        Image(systemName: "chart.bar.fill")
                    }
                }
            }
            .sheet(isPresented: $showingPrayerCompletion) {
                if let prayer = selectedPrayer {
                    PrayerCompletionView(
                        prayer: prayer,
                        prayerTrackingService: prayerTrackingService,
                        onDismiss: {
                            showingPrayerCompletion = false
                            selectedPrayer = nil
                        }
                    )
                }
            }
            .sheet(isPresented: $showingAnalytics) {
                PrayerAnalyticsView(
                    prayerTrackingService: prayerTrackingService,
                    onDismiss: {
                        showingAnalytics = false
                    }
                )
            }
        }
    }
    
    // MARK: - Tab Selector
    
    @ViewBuilder
    private var trackingTabSelector: some View {
        HStack(spacing: 0) {
            ForEach(TrackingTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 16, weight: .medium))
                        
                        Text(tab.title)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedTab == tab ? ColorPalette.primary : ColorPalette.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(ColorPalette.surface)
        .overlay(
            Rectangle()
                .fill(ColorPalette.primary)
                .frame(height: 2)
                .offset(x: tabIndicatorOffset, y: 0)
                .animation(.easeInOut(duration: 0.3), value: selectedTab),
            alignment: .bottom
        )
    }
    
    // MARK: - Tab Views
    
    @ViewBuilder
    private var todayTrackingView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Today's Progress Card
                todayProgressCard
                
                // Prayer Completion Grid
                prayerCompletionGrid
                
                // Quick Stats
                quickStatsCard
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var analyticsView: some View {
        PrayerAnalyticsView(
            prayerTrackingService: prayerTrackingService,
            onDismiss: { }
        )
    }
    
    @ViewBuilder
    private var streakView: some View {
        PrayerStreakView(
            prayerTrackingService: prayerTrackingService
        )
    }
    
    // MARK: - Today's Progress Card
    
    @ViewBuilder
    private var todayProgressCard: some View {
        ModernCard {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Progress")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("\(prayerTrackingService.todaysCompletedPrayers) of 5 prayers completed")
                            .font(.subheadline)
                            .foregroundColor(ColorPalette.secondary)
                    }
                    
                    Spacer()
                    
                    // Circular Progress
                    ZStack {
                        Circle()
                            .stroke(ColorPalette.surface, lineWidth: 8)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .trim(from: 0, to: prayerTrackingService.todayCompletionRate)
                            .stroke(ColorPalette.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1.0), value: prayerTrackingService.todayCompletionRate)
                        
                        Text("\(Int(prayerTrackingService.todayCompletionRate * 100))%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(ColorPalette.primary)
                    }
                }
                
                // Streak Information
                if prayerTrackingService.currentStreak > 0 {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        
                        Text("\(prayerTrackingService.currentStreak) day streak")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Prayer Completion Grid
    
    @ViewBuilder
    private var prayerCompletionGrid: some View {
        ModernCard {
            VStack(spacing: 0) {
                HStack {
                    Text("Mark Prayers Complete")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                .padding()
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(Prayer.allCases, id: \.self) { prayer in
                        PrayerCompletionButton(
                            prayer: prayer,
                            isCompleted: isPrayerCompleted(prayer),
                            onTap: {
                                selectedPrayer = prayer
                                showingPrayerCompletion = true
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }
    
    // MARK: - Quick Stats Card
    
    @ViewBuilder
    private var quickStatsCard: some View {
        ModernCard {
            VStack(spacing: 16) {
                HStack {
                    Text("Quick Stats")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                
                HStack(spacing: 20) {
                    PrayerStatItem(
                        title: "This Week",
                        value: "85%",
                        icon: "calendar.badge.clock"
                    )

                    PrayerStatItem(
                        title: "This Month",
                        value: "78%",
                        icon: "chart.line.uptrend.xyaxis"
                    )

                    PrayerStatItem(
                        title: "Best Streak",
                        value: "12 days",
                        icon: "flame.fill"
                    )
                }
            }
            .padding()
        }
    }
    
    // MARK: - Helper Methods
    
    private var tabIndicatorOffset: CGFloat {
        let tabWidth = UIScreen.main.bounds.width / CGFloat(TrackingTab.allCases.count)
        return tabWidth * CGFloat(selectedTab.rawValue) - (UIScreen.main.bounds.width / 2) + (tabWidth / 2)
    }
    
    private func isPrayerCompleted(_ prayer: Prayer) -> Bool {
        // Check if prayer is completed today
        let today = Calendar.current.startOfDay(for: Date())
        return prayerTrackingService.recentEntries.contains { entry in
            entry.prayer == prayer && Calendar.current.isDate(entry.completedAt, inSameDayAs: today)
        }
    }
}

// MARK: - Tracking Tab Enum

private enum TrackingTab: Int, CaseIterable {
    case today = 0
    case analytics = 1
    case streak = 2
    
    var title: String {
        switch self {
        case .today: return "Today"
        case .analytics: return "Analytics"
        case .streak: return "Streak"
        }
    }
    
    var systemImage: String {
        switch self {
        case .today: return "calendar.badge.checkmark"
        case .analytics: return "chart.bar.fill"
        case .streak: return "flame.fill"
        }
    }
}
