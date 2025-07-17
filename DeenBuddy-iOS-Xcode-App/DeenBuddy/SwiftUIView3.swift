import SwiftUI

//@main
struct PortfolioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView3()
        }
    }
}

struct ContentView3: View {
    @State private var selectedTab = 0
    @State private var showingRebalanceFlow = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView3()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Rebalance") {
                                showingRebalanceFlow = true
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                        }
                    }
            }
            .tabItem {
                Image(systemName: "chart.pie.fill")
                Text("Portfolio")
            }
            .tag(0)
            
            NavigationStack {
                MarketsView()
            }
            .tabItem {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("Markets")
            }
            .tag(1)
            
            NavigationStack {
                GoalsView()
            }
            .tabItem {
                Image(systemName: "target")
                Text("Goals")
            }
            .tag(2)
            
            NavigationStack {
                SettingsView3()
            }
            .tabItem {
                Image(systemName: "gearshape.fill")
                Text("Settings")
            }
            .tag(3)
        }
        .accentColor(.blue)
        .sheet(isPresented: $showingRebalanceFlow) {
            RebalancingFlowView()
        }
    }
}

// MARK: - Placeholder Views for Other Tabs

struct MarketsView: View {
    var body: some View {
        VStack {
            Text("Markets")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Market data and analysis coming soon")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Markets")
    }
}

struct GoalsView: View {
    var body: some View {
        VStack {
            Text("Goals")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Financial goals tracking coming soon")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Goals")
    }
}

struct SettingsView3: View {
    var body: some View {
        List {
            Section("Account") {
                SettingsRowView(
                    icon: "person.circle.fill",
                    title: "Profile",
                    color: .blue
                )
                
                SettingsRowView(
                    icon: "creditcard.fill",
                    title: "Connected Accounts",
                    color: .green
                )
                
                SettingsRowView(
                    icon: "bell.fill",
                    title: "Notifications",
                    color: .orange
                )
            }
            
            Section("Security") {
                SettingsRowView(
                    icon: "faceid",
                    title: "Face ID & Passcode",
                    color: .red
                )
                
                SettingsRowView(
                    icon: "lock.fill",
                    title: "Privacy",
                    color: .purple
                )
            }
            
            Section("Support") {
                SettingsRowView(
                    icon: "questionmark.circle.fill",
                    title: "Help Center",
                    color: .cyan
                )
                
                SettingsRowView(
                    icon: "envelope.fill",
                    title: "Contact Support",
                    color: .indigo
                )
            }
            
            Section {
                SettingsRowView(
                    icon: "arrow.right.square.fill",
                    title: "Sign Out",
                    color: .red
                )
            }
        }
        .navigationTitle("Settings")
    }
}

struct SettingsRowView: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            // Handle navigation
        }
    }
}

// MARK: - Additional UI Components

struct LoadingView3: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.2)
            
            Text("Loading portfolio data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct ErrorView3: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again") {
                retryAction()
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Custom View Modifiers

extension View {
    func cardStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    func primaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview("Main App") {
    ContentView3()
}

#Preview("Settings") {
    NavigationView {
        SettingsView3()
    }
}

#Preview("Loading") {
    LoadingView3()
}

#Preview("Error") {
    ErrorView3(
        message: "Unable to connect to server. Please check your internet connection.",
        retryAction: {}
    )
}


struct RebalancingFlowView: View {
    @State private var currentStep: RebalanceStep = .review
    @State private var isCompleted = false
    @Environment(\.dismiss) private var dismiss
    
    private let rebalanceActions = RebalanceAction.sampleRebalanceActions
    
    private var actionableRebalances: [RebalanceAction] {
        rebalanceActions.filter { $0.needsRebalance }
    }
    
    private var totalTrades: Int {
        actionableRebalances.count
    }
    
    private var estimatedCost: Double {
        Double(totalTrades) * 4.95
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isCompleted {
                    RebalanceCompletionView()
                } else {
                    rebalanceContentView
                }
            }
            .navigationTitle("Rebalance Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var rebalanceContentView: some View {
        VStack(spacing: 0) {
            // Progress Bar
            ProgressBarView(currentStep: currentStep)
            
            ScrollView {
                VStack(spacing: 20) {
                    switch currentStep {
                    case .review:
                        RebalanceReviewView(
                            actions: actionableRebalances,
                            estimatedCost: estimatedCost,
                            totalTrades: totalTrades,
                            onContinue: { currentStep = .confirm }
                        )
                        
                    case .confirm:
                        RebalanceConfirmView(
                            totalTrades: totalTrades,
                            estimatedCost: estimatedCost,
                            onExecute: {
                                isCompleted = true
                            },
                            onBack: { currentStep = .review }
                        )
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Rebalance Steps

enum RebalanceStep: Int, CaseIterable {
    case review = 1
    case confirm = 2
    
    var title: String {
        switch self {
        case .review: return "Review"
        case .confirm: return "Confirm"
        }
    }
    
    var progress: Double {
        Double(rawValue) / Double(RebalanceStep.allCases.count)
    }
}

// MARK: - Progress Bar

struct ProgressBarView: View {
    let currentStep: RebalanceStep
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Step \(currentStep.rawValue) of \(RebalanceStep.allCases.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(currentStep.title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            ProgressView(value: currentStep.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

// MARK: - Review View

struct RebalanceReviewView: View {
    let actions: [RebalanceAction]
    let estimatedCost: Double
    let totalTrades: Int
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Recommended Trades Card
            VStack(alignment: .leading, spacing: 16) {
                Text("Recommended Trades")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                ForEach(actions) { action in
                    RebalanceActionRowView(action: action)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            
            // Cost Summary Card
            CostSummaryView(
                totalTrades: totalTrades,
                estimatedCost: estimatedCost
            )
            
            Spacer()
            
            // Continue Button
            Button(action: onContinue) {
                Text("Review & Confirm")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Confirm View

struct RebalanceConfirmView: View {
    let totalTrades: Int
    let estimatedCost: Double
    let onExecute: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Warning Card
            WarningCardView()
            
            // Execution Details
            VStack(alignment: .leading, spacing: 16) {
                Text("Execution Details")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(spacing: 12) {
                    DetailRowView(label: "Total Trades", value: "\(totalTrades)")
                    DetailRowView(label: "Estimated Commission", value: estimatedCost.formatted(.currency(code: "CAD")))
                    DetailRowView(label: "Order Type", value: "Market Order")
                    DetailRowView(label: "Account", value: "TFSA", isHighlighted: true)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 12) {
                Button(action: onExecute) {
                    Text("Execute Trades")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button("Back", action: onBack)
                    .buttonStyle(SecondaryButtonStyle3())
            }
        }
    }
}

// MARK: - Completion View

struct RebalanceCompletionView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Success Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.green)
            }
            
            // Success Message
            VStack(spacing: 8) {
                Text("Rebalance Complete")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Your portfolio has been successfully rebalanced")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Summary Card
            VStack(spacing: 12) {
                Text("Trade Summary")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 8) {
                    DetailRowView(label: "Total Trades", value: "4")
                    DetailRowView(label: "Commission Cost", value: "$19.80")
                    DetailRowView(label: "Execution Time", value: "2.3 seconds")
                    
                    Divider()
                    
                    DetailRowView(
                        label: "Status",
                        value: "Complete",
                        valueColor: .green,
                        isHighlighted: true
                    )
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 12) {
                Button("Back to Portfolio") {
                    dismiss()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Button("View Details") {
                    // View details action
                }
                .buttonStyle(SecondaryButtonStyle3())
            }
        }
        .padding()
    }
}

// MARK: - Supporting Views

struct RebalanceActionRowView: View {
    let action: RebalanceAction
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(action.color)
                        .frame(width: 12, height: 12)
                    
                    Text(action.asset)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                Text(action.action.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(action.action.backgroundColor)
                    .foregroundColor(action.action.color)
                    .clipShape(Capsule())
            }
            
            HStack {
                Text("\(action.current)% → \(action.target)%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(action.formattedAmount) (\(action.shares) shares)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct CostSummaryView: View {
    let totalTrades: Int
    let estimatedCost: Double
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Estimated Cost")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Text("\(totalTrades) trades at $4.95 each")
                    .font(.caption)
                    .foregroundColor(.blue.opacity(0.8))
            }
            
            Spacer()
            
            Text(estimatedCost.formatted(.currency(code: "CAD")))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct WarningCardView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Trade Execution")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("This will execute 4 trades immediately. Market orders will be placed at current prices.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DetailRowView: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    var isHighlighted: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(isHighlighted ? .subheadline : .subheadline)
                .fontWeight(isHighlighted ? .semibold : .regular)
                .foregroundColor(isHighlighted ? .primary : .secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(isHighlighted ? .semibold : .medium)
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Preview

#Preview("Dashboard") {
    DashboardView3()
}

#Preview("Rebalancing Flow") {
    RebalancingFlowView()
}

#Preview("Rebalance Review") {
    NavigationView {
        RebalanceReviewView(
            actions: RebalanceAction.sampleRebalanceActions.filter { $0.needsRebalance },
            estimatedCost: 19.80,
            totalTrades: 4,
            onContinue: {}
        )
        .padding()
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Rebalance Confirm") {
    NavigationView {
        RebalanceConfirmView(
            totalTrades: 4,
            estimatedCost: 19.80,
            onExecute: {},
            onBack: {}
        )
        .padding()
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Confirm")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Completion") {
    NavigationView {
        RebalanceCompletionView()
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Complete")
            .navigationBarTitleDisplayMode(.inline)
    }
}




struct DashboardView3: View {
    @State private var selectedPeriod = "1M"
    
    private let timePeriods = ["1D", "1W", "1M", "3M", "1Y", "All"]
    private let accounts = Account3.sampleAccounts
    private let allocations = AssetAllocation.sampleAllocations
    
    private var totalValue: Double {
        accounts.reduce(0) { $0 + $1.balance }
    }
    
    private var totalGrowth: Double {
        accounts.reduce(0) { $0 + $1.growth }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Portfolio Performance Section
                    PerformanceCardView(
                        totalValue: totalValue,
                        totalGrowth: totalGrowth,
                        selectedPeriod: $selectedPeriod,
                        timePeriods: timePeriods
                    )
                    
                    // Account Cards Section
                    AccountsSectionView(accounts: accounts)
                    
                    // Asset Allocation Section
                    AllocationSectionView(allocations: allocations)
                    
                    // Quick Actions Section
                    QuickActionsView()
                    
                    // Bottom padding for tab bar
                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Portfolio")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileButtonView()
                }
            }
        }
    }
}

// MARK: - Performance Card

struct PerformanceCardView: View {
    let totalValue: Double
    let totalGrowth: Double
    @Binding var selectedPeriod: String
    let timePeriods: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Value")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(totalValue.formatted(.currency(code: "CAD")))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(totalGrowth.formatted(.currency(code: "CAD")))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(totalGrowth >= 0 ? .green : .red)
                }
            }
            
            // Time Period Picker
            Picker("Time Period", selection: $selectedPeriod) {
                ForEach(timePeriods, id: \.self) { period in
                    Text(period).tag(period)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Chart Placeholder
            PerformanceChartView()
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

struct PerformanceChartView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [
                        Color.green.opacity(0.1),
                        Color.green.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 120)
            .overlay(
                // Simulated chart line
                Path { path in
                    let width: CGFloat = 300
                    let height: CGFloat = 80
                    let points: [(CGFloat, CGFloat)] = [
                        (0, 60), (50, 45), (100, 50), (150, 30),
                        (200, 25), (250, 15), (300, 10)
                    ]
                    
                    guard let firstPoint = points.first else { return }
                    path.move(to: CGPoint(x: firstPoint.0, y: firstPoint.1))
                    
                    for point in points.dropFirst() {
                        path.addLine(to: CGPoint(x: point.0, y: point.1))
                    }
                }
                .stroke(Color.green, lineWidth: 2)
                .frame(width: 300, height: 80)
            )
    }
}

// MARK: - Accounts Section

struct AccountsSectionView: View {
    let accounts: [Account3]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Accounts")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            ForEach(accounts) { account in
                AccountCardView(account: account)
            }
        }
    }
}

struct AccountCardView: View {
    let account: Account3
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(account.type)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(account.formattedBalance)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                Text(account.formattedGrowth)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(account.isPositive ? .green : .red)
                
                Text(account.formattedGrowthPercent)
                    .font(.caption)
                    .foregroundColor(account.isPositive ? .green : .red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }
}

// MARK: - Asset Allocation Section

struct AllocationSectionView: View {
    let allocations: [AssetAllocation]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Asset Allocation")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("View Details") {
                    // Navigation action
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            ForEach(allocations) { allocation in
                AllocationRowView(allocation: allocation)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

struct AllocationRowView: View {
    let allocation: AssetAllocation
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(allocation.color)
                        .frame(width: 12, height: 12)
                    
                    Text(allocation.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("\(allocation.current)%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(allocation.isOffTarget ? .primary : .secondary)
                    
                    Text("(\(allocation.target)% target)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                        .clipShape(Capsule())
                    
                    Rectangle()
                        .fill(allocation.color)
                        .frame(
                            width: geometry.size.width * CGFloat(allocation.current) / 100,
                            height: 6
                        )
                        .clipShape(Capsule())
                        .opacity(allocation.isOffTarget ? 1.0 : 0.7)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Quick Actions

struct QuickActionsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Button(action: {
                // Rebalance action
            }) {
                Text("Rebalance Portfolio")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            HStack(spacing: 12) {
                Button("Add Funds") {
                    // Add funds action
                }
                .buttonStyle(SecondaryButtonStyle3())
                
                Button("View Trades") {
                    // View trades action
                }
                .buttonStyle(SecondaryButtonStyle3())
            }
        }
    }
}

// MARK: - Profile Button

struct ProfileButtonView: View {
    var body: some View {
        Button(action: {}) {
            Circle()
                .fill(Color.blue)
                .frame(width: 32, height: 32)
                .overlay(
                    Text("AM")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                )
        }
    }
}

// MARK: - Button Styles

struct SecondaryButtonStyle3: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    DashboardView3()
}



// MARK: - Data Models

struct Account3: Identifiable {
    let id = UUID()
    let type: String
    let balance: Double
    let growth: Double
    let growthPercent: Double
    
    var formattedBalance: String {
        return balance.formatted(.currency(code: "CAD"))
    }
    
    var formattedGrowth: String {
        let sign = growth >= 0 ? "+" : ""
        return "\(sign)\(growth.formatted(.currency(code: "CAD")))"
    }
    
    var formattedGrowthPercent: String {
        let sign = growthPercent >= 0 ? "+" : ""
        return "\(sign)\(growthPercent.formatted(.number.precision(.fractionLength(2))))%"
    }
    
    var isPositive: Bool {
        return growth >= 0
    }
}

struct AssetAllocation: Identifiable {
    let id = UUID()
    let name: String
    let current: Int
    let target: Int
    let color: Color
    
    var isOffTarget: Bool {
        abs(current - target) > 2
    }
    
    var difference: Int {
        return current - target
    }
}

struct RebalanceAction: Identifiable {
    let id = UUID()
    let asset: String
    let current: Int
    let target: Int
    let action: TradeAction
    let amount: Double
    let shares: Int
    let color: Color
    
    enum TradeAction: String, CaseIterable {
        case buy = "BUY"
        case sell = "SELL"
        case hold = "HOLD"
        
        var color: Color {
            switch self {
            case .buy: return .green
            case .sell: return .red
            case .hold: return .gray
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .buy: return Color.green.opacity(0.1)
            case .sell: return Color.red.opacity(0.1)
            case .hold: return Color.gray.opacity(0.1)
            }
        }
    }
    
    var formattedAmount: String {
        return amount.formatted(.currency(code: "CAD"))
    }
    
    var needsRebalance: Bool {
        return action != .hold
    }
}

// MARK: - Sample Data

extension Account3 {
    static let sampleAccounts = [
        Account3(type: "TFSA", balance: 127450, growth: 2340, growthPercent: 1.87),
        Account3(type: "RRSP", balance: 89720, growth: 1180, growthPercent: 1.33),
        Account3(type: "Non-Registered", balance: 45890, growth: -890, growthPercent: -1.90)
    ]
}

extension AssetAllocation {
    static let sampleAllocations = [
        AssetAllocation(name: "Canadian Equity", current: 28, target: 25, color: .blue),
        AssetAllocation(name: "US Equity", current: 42, target: 45, color: .green),
        AssetAllocation(name: "International Equity", current: 18, target: 20, color: .orange),
        AssetAllocation(name: "Fixed Income", current: 12, target: 10, color: .purple)
    ]
}

extension RebalanceAction {
    static let sampleRebalanceActions = [
        RebalanceAction(
            asset: "Canadian Equity",
            current: 28,
            target: 25,
            action: .sell,
            amount: 7860,
            shares: 142,
            color: .blue
        ),
        RebalanceAction(
            asset: "US Equity",
            current: 42,
            target: 45,
            action: .buy,
            amount: 7860,
            shares: 89,
            color: .green
        ),
        RebalanceAction(
            asset: "International Equity",
            current: 18,
            target: 20,
            action: .buy,
            amount: 5240,
            shares: 67,
            color: .orange
        ),
        RebalanceAction(
            asset: "Fixed Income",
            current: 12,
            target: 10,
            action: .sell,
            amount: 5240,
            shares: 48,
            color: .purple
        )
    ]
}
