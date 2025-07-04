import SwiftUI
import CoreLocation
import CoreMotion

@main
struct DeenAssistMainApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    setupApp()
                }
        }
    }
    
    // MARK: - App Setup
    
    private func setupApp() {
        // Configure app-wide settings
        configureAppearance()
        
        // Start location services if needed
        startLocationServices()
    }
    
    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        // Configure tab bar appearance if needed in future
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
    
    private func startLocationServices() {
        // Location services will be started when needed by the coordinator
        // This is just a placeholder for any initial setup
    }
}

// MARK: - Content View

struct ContentView: View {
    @State private var showingQiblaCompass = false

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // App Icon and Title
                VStack(spacing: 16) {
                    Image(systemName: "moon.stars")
                        .font(.system(size: 80))
                        .foregroundColor(.green)

                    Text("Deen Assist")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Islamic Prayer Companion")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                // Quick Actions
                VStack(spacing: 16) {
                    Text("Quick Actions")
                        .font(.title2)
                        .fontWeight(.semibold)

                    HStack(spacing: 16) {
                        QuickActionButton(
                            icon: "safari.fill",
                            title: "Qibla Compass",
                            description: "Find direction to Kaaba",
                            color: .green
                        ) {
                            showingQiblaCompass = true
                        }

                        QuickActionButton(
                            icon: "clock.fill",
                            title: "Prayer Times",
                            description: "Today's prayer schedule",
                            color: .blue
                        ) {
                            // TODO: Navigate to Prayer Times
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Deen Assist")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingQiblaCompass) {
            QiblaCompassView(onDismiss: {
                showingQiblaCompass = false
            })
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)

                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - App Info

extension Bundle {
    var appName: String {
        return infoDictionary?["CFBundleDisplayName"] as? String ??
               infoDictionary?["CFBundleName"] as? String ??
               "Deen Assist"
    }

    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
