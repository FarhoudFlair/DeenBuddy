import SwiftUI

// MARK: - Data Models
struct Account2: Identifiable {
    let id = UUID()
    let name: String
    let balance: Double
    let dailyChange: Double
}

// MARK: - UI Components
struct AllocationRing: View {
    let current: Double
    let target: Double
    
    private var variance: Double { current - target }
    private var ringColor: Color { variance > 0 ? .rebalancerRed : .rebalancerGreen }
    
    var body: some View {
        ZStack {
            // Target ring (dashed)
            Circle()
                .stroke(style: StrokeStyle(lineWidth: 12, dash: [3]))
                .foregroundColor(.gray.opacity(0.3))
            
            // Current allocation (animated)
            Circle()
                .trim(from: 0, to: current/100)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.8), value: current)
            
            // Variance label
            VStack {
                Text("\(Int(current))%")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("\(variance > 0 ? "+" : "")\(Int(variance))%")
                    .font(.caption)
                    .foregroundColor(ringColor)
                    .bold()
            }
        }
        .frame(width: 200, height: 200)
        .padding(.vertical)
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    
    var body: some View {
        Button(action: {}) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .symbolEffect(.bounce, value: color)
                    .frame(height: 24)
                
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(width: 80, height: 60)
            .contentShape(Rectangle()) // Expanded tap area
        }
        .tint(color)
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }
}

struct RebalanceActionBar: View {
    var body: some View {
        HStack(spacing: 12) {
            ActionButton(icon: "arrow.2.squarepath", label: "Rebalance", color: .blue)
            ActionButton(icon: "plus", label: "Add Funds", color: .green)
            ActionButton(icon: "list.bullet", label: "History", color: .gray)
        }
        .padding(.vertical, 8)
    }
}

struct AccountCard2: View {
    let account: Account2
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(account.name)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("$\(account.balance, specifier: "%.2f")")
                .font(.title3)
                .bold()
            
            HStack {
                Image(systemName: account.dailyChange >= 0 ? "arrow.up" : "arrow.down")
                Text("\(account.dailyChange, specifier: "%.2f")%")
            }
            .foregroundColor(account.dailyChange >= 0 ? .rebalancerGreen : .rebalancerRed)
            .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
}

struct AccountCarouselView: View {
    let accounts: [Account2]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(accounts) { account in
                    AccountCard2(account: account)
                        .containerRelativeFrame(.horizontal, count: Int(accounts.count > 2 ? 2.5 : 1), spacing: 16)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .safeAreaPadding(.horizontal, 16)
        .frame(height: 150)
    }
}

struct PerformanceChartPlaceholder: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cardBackground)
            
            VStack {
                HStack {
                    Text("Portfolio Performance")
                        .font(.headline)
                    Spacer()
                    Text("1Y")
                        .font(.caption)
                        .padding(4)
                        .background(Capsule().stroke(lineWidth: 1))
                }
                .padding(.horizontal)
                
                // Chart placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 120)
                    .padding(.horizontal)
                    .overlay(alignment: .center) {
                        Text("Interactive Chart Area")
                            .foregroundColor(.secondary)
                    }
                
                // Time selectors
                HStack {
                    ForEach(["1D", "1W", "1M", "3M", "1Y", "All"], id: \.self) { period in
                        Text(period)
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Main View
struct DashboardView2: View {
    let accounts: [Account2] = [
        Account2(name: "TFSA", balance: 54230.75, dailyChange: 1.2),
        Account2(name: "RRSP", balance: 121560.20, dailyChange: -0.8),
        Account2(name: "Taxable", balance: 87650.40, dailyChange: 0.4)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. Performance chart
                PerformanceChartPlaceholder()
                    .padding(.top, 8)
                
                // 2. Allocation ring
                AllocationRing(current: 75, target: 60)
                
                // 3. Action bar
                RebalanceActionBar()
                
                // 4. Account cards
                AccountCarouselView(accounts: accounts)
                
                Spacer()
            }
            .padding(.horizontal)
        }
        .background(Color.background)
    }
}

// MARK: - Color Extensions
extension Color {
    static let background = Color(UIColor.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let rebalancerGreen = Color(red: 0.2, green: 0.7, blue: 0.4)
    static let rebalancerRed = Color(red: 1, green: 0.4, blue: 0.4)
}

// MARK: - Previews
#Preview("Allocation Ring") {
    AllocationRing(current: 75.0, target: 60.0)
        .padding()
        .background(Color.background)
}

#Preview("Action Button") {
    RebalanceActionBar()
        .padding()
        .background(Color.background)
}

#Preview("Account Card") {
    AccountCard2(account: Account2(name: "TFSA", balance: 54230.75, dailyChange: 1.2))
        .padding()
        .background(Color.background)
}

#Preview("Account Carousel") {
    AccountCarouselView(accounts: [
        Account2(name: "TFSA", balance: 54230.75, dailyChange: 1.2),
        Account2(name: "RRSP", balance: 121560.20, dailyChange: -0.8),
        Account2(name: "Taxable", balance: 87650.40, dailyChange: 0.4)
    ])
    .frame(height: 180)
    .background(Color.background)
}

#Preview("Dashboard") {
    DashboardView2()
}

#Preview("Dashboard Dark") {
    DashboardView2()
        .preferredColorScheme(.dark)
}
