import SwiftUI
import Charts   // iOS 17+

struct DashboardView: View {
    @State private var period: Period = .oneMonth
    
    enum Period: String, CaseIterable, Identifiable {
        case oneDay = "1D", oneWeek = "1W", oneMonth = "1M",
             threeMonths = "3M", oneYear = "1Y", all = "All"
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Performance Hero Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Total Return")
                            .font(.headline)
                        Chart(mockPerformance) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(Color.accentColor.gradient)
                        }
                        .frame(height: 180)
                        
                        Picker("Period", selection: $period) {
                            ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
                    .padding(.horizontal)
                    
                    // MARK: - Allocation Wheel
                    AllocationWheel()
                        .padding(.horizontal)
                    
                    // MARK: - Quick Actions
                    HStack(spacing: 12) {
                        QuickAction(title: "Rebalance", systemImage: "arrow.2.squarepath")
                        QuickAction(title: "Add Portfolio", systemImage: "plus.square")
                    }
                    .padding(.horizontal)
                    
                    // MARK: - Account Cards
                    AccountSection()
                    
                    Spacer()
                }
                .navigationTitle("Portfolio")
            }
        }
    }
}


struct AllocationWheel: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Asset Allocation")
                .font(.headline)
            Chart(mockSlices) { slice in
                SectorMark(
                    angle: .value("Weight", slice.weight),
                    innerRadius: .ratio(0.6)
                )
                .foregroundStyle(by: .value("Asset", slice.name))
            }
            .chartLegend(.hidden)
            .frame(height: 220)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }
}


struct QuickAction: View {
    let title: String
    let systemImage: String
    
    var body: some View {
        Button(action: {}) {
            Label(title, systemImage: systemImage)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}

struct AccountSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accounts")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(mockAccounts) { acct in
                        AccountCard(account: acct)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct AccountCard: View {
    let account: Account
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(account.name).font(.headline)
            Text(account.value, format: .currency(code: "CAD"))
                .font(.title3.monospacedDigit())
            Text("\(account.gain > 0 ? "+" : "")\(account.gain.formatted(.currency(code: "CAD")))")
                .font(.subheadline)
                .foregroundColor(account.gain >= 0 ? .green : .red)
        }
        .padding()
        .frame(width: 160, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}


// MARK: - Mocks
struct PerfPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}
let mockPerformance: [PerfPoint] = stride(from: 0, to: 30, by: 1).map {
    PerfPoint(date: Calendar.current.date(byAdding: .day, value: -$0, to: .now)!,
              value: Double.random(in: 95...105))
}

struct Slice: Identifiable {
    let id = UUID()
    let name: String
    let weight: Double
}
let mockSlices = [
    Slice(name: "Equity", weight: 60),
    Slice(name: "Bonds", weight: 30),
    Slice(name: "Cash", weight: 10)
]

struct Account: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
    let gain: Double
}
let mockAccounts = [
    Account(name: "TFSA", value: 42_300, gain: 1_240),
    Account(name: "RRSP", value: 89_120, gain: -560),
    Account(name: "Non-Reg", value: 15_780, gain: 330)
]


#if DEBUG
#Preview {
    DashboardView()
}
#endif
