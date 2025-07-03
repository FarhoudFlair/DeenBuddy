import SwiftUI
import CoreLocation

@main
struct DeenAssistApp: App {
    
    // MARK: - Properties
    
    /// Core data manager for the application
    private let dataManager = CoreDataManager.shared
    
    /// Prayer time calculator
    private let prayerCalculator = PrayerTimeCalculator()
    
    // MARK: - App Body
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppDependencies(
                    dataManager: dataManager,
                    prayerCalculator: prayerCalculator
                ))
                .onAppear {
                    setupApp()
                }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupApp() {
        // Initialize default user settings if none exist
        if dataManager.getUserSettings() == nil {
            do {
                try dataManager.resetUserSettings()
            } catch {
                print("Failed to initialize default user settings: \(error)")
            }
        }
        
        // Clean up old cached prayer times (older than 30 days)
        prayerCalculator.cleanupOldCache()
    }
}

// MARK: - App Dependencies

/// Dependency injection container for the app
public class AppDependencies: ObservableObject {
    let dataManager: DataManagerProtocol
    let prayerCalculator: PrayerCalculatorProtocol
    
    init(dataManager: DataManagerProtocol, prayerCalculator: PrayerCalculatorProtocol) {
        self.dataManager = dataManager
        self.prayerCalculator = prayerCalculator
    }
}

// MARK: - Content View (Placeholder)

/// Placeholder content view - will be replaced by Engineer 3 (UI/UX)
struct ContentView: View {
    @EnvironmentObject var dependencies: AppDependencies
    @State private var userSettings: UserSettings?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Deen Assist")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Islamic Prayer Companion")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                if let settings = userSettings {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Settings:")
                            .font(.headline)
                        
                        Text("Calculation Method: \(settings.calculationMethod)")
                        Text("Madhab: \(settings.madhab)")
                        Text("Notifications: \(settings.notificationsEnabled ? "Enabled" : "Disabled")")
                        Text("Theme: \(settings.theme)")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button("Test Prayer Times") {
                    testPrayerTimes()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Spacer()
                
                Text("Foundation by Engineer 1")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("Deen Assist")
        }
        .onAppear {
            loadUserSettings()
        }
    }
    
    private func loadUserSettings() {
        userSettings = dependencies.dataManager.getUserSettings()
    }
    
    private func testPrayerTimes() {
        // Test prayer time calculation
        let config = PrayerCalculationConfig(
            calculationMethod: .muslimWorldLeague,
            madhab: .shafi,
            location: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060), // New York
            timeZone: TimeZone.current
        )
        
        do {
            let prayerTimes = try dependencies.prayerCalculator.calculatePrayerTimes(for: Date(), config: config)
            print("Prayer times calculated successfully:")
            print("Fajr: \(prayerTimes.fajr)")
            print("Dhuhr: \(prayerTimes.dhuhr)")
            print("Asr: \(prayerTimes.asr)")
            print("Maghrib: \(prayerTimes.maghrib)")
            print("Isha: \(prayerTimes.isha)")
        } catch {
            print("Failed to calculate prayer times: \(error)")
        }
    }
}
