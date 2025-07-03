import SwiftUI
import CoreLocation
import DeenAssistProtocols

/// Location permission request screen
public struct LocationPermissionScreen: View {
    @ObservedObject private var locationService: any LocationServiceProtocol
    let onContinue: () -> Void
    let onSkip: () -> Void
    
    @State private var showingManualLocationEntry = false
    
    public init(
        locationService: any LocationServiceProtocol,
        onContinue: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.locationService = locationService
        self.onContinue = onContinue
        self.onSkip = onSkip
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(ColorPalette.primary)
                
                Text("Location Access")
                    .headlineLarge()
                    .foregroundColor(ColorPalette.textPrimary)
                
                Text("We need your location to provide accurate prayer times for your area")
                    .bodyLarge()
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 60)
            
            Spacer()
            
            // Benefits
            VStack(spacing: 20) {
                BenefitRow(
                    icon: "clock.arrow.circlepath",
                    title: "Automatic Updates",
                    description: "Prayer times update automatically as you travel"
                )
                
                BenefitRow(
                    icon: "bell.fill",
                    title: "Timely Notifications",
                    description: "Get notified before each prayer time"
                )
                
                BenefitRow(
                    icon: "safari.fill",
                    title: "Accurate Qibla",
                    description: "Find the exact direction to Kaaba"
                )
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Status and actions
            VStack(spacing: 16) {
                statusView
                actionButtons
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(ColorPalette.backgroundPrimary)
        .sheet(isPresented: $showingManualLocationEntry) {
            ManualLocationEntryView(
                locationService: locationService,
                onLocationSelected: {
                    showingManualLocationEntry = false
                    onContinue()
                },
                onCancel: {
                    showingManualLocationEntry = false
                }
            )
        }
    }
    
    @ViewBuilder
    private var statusView: some View {
        switch locationService.authorizationStatus {
        case .notDetermined:
            EmptyView()
            
        case .denied, .restricted:
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(ColorPalette.warning)
                
                Text("Location access denied")
                    .titleMedium()
                    .foregroundColor(ColorPalette.textPrimary)
                
                Text("You can enable location access in Settings or enter your city manually")
                    .bodyMedium()
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
        case .authorizedWhenInUse, .authorizedAlways:
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(ColorPalette.success)
                    .font(.system(size: 32))
                
                Text("Location access granted")
                    .titleMedium()
                    .foregroundColor(ColorPalette.success)
            }
            
        @unknown default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        switch locationService.authorizationStatus {
        case .notDetermined:
            VStack(spacing: 12) {
                CustomButton.primary("Allow Location Access") {
                    locationService.requestLocationPermission()
                }
                
                CustomButton.tertiary("Enter City Manually") {
                    showingManualLocationEntry = true
                }
                
                Button("Skip for now") {
                    onSkip()
                }
                .foregroundColor(ColorPalette.textTertiary)
            }
            
        case .denied, .restricted:
            VStack(spacing: 12) {
                CustomButton.primary("Open Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                
                CustomButton.secondary("Enter City Manually") {
                    showingManualLocationEntry = true
                }
            }
            
        case .authorizedWhenInUse, .authorizedAlways:
            CustomButton.primary("Continue") {
                onContinue()
            }
            
        @unknown default:
            CustomButton.tertiary("Skip") {
                onSkip()
            }
        }
    }
}

/// Benefit row component
private struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(ColorPalette.primary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .titleMedium()
                    .foregroundColor(ColorPalette.textPrimary)
                
                Text(description)
                    .bodyMedium()
                    .foregroundColor(ColorPalette.textSecondary)
            }
            
            Spacer()
        }
    }
}

/// Manual location entry view
private struct ManualLocationEntryView: View {
    @ObservedObject private var locationService: any LocationServiceProtocol
    let onLocationSelected: () -> Void
    let onCancel: () -> Void
    
    @State private var cityName = ""
    @State private var isSearching = false
    @State private var searchError: String?
    
    init(
        locationService: any LocationServiceProtocol,
        onLocationSelected: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.locationService = locationService
        self.onLocationSelected = onLocationSelected
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Enter Your City")
                        .headlineSmall()
                        .foregroundColor(ColorPalette.textPrimary)
                    
                    TextField("City name", text: $cityName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            searchForCity()
                        }
                    
                    if let error = searchError {
                        Text(error)
                            .bodySmall()
                            .foregroundColor(ColorPalette.error)
                    }
                }
                
                if isSearching {
                    LoadingView.dots(message: "Searching for city...")
                } else {
                    CustomButton.primary("Search") {
                        searchForCity()
                    }
                    .disabled(cityName.isEmpty)
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Manual Location")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
    
    private func searchForCity() {
        guard !cityName.isEmpty else { return }
        
        isSearching = true
        searchError = nil
        
        Task {
            do {
                _ = try await locationService.geocodeCity(cityName)
                await MainActor.run {
                    isSearching = false
                    onLocationSelected()
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    searchError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Location Permission Screen") {
    LocationPermissionScreen(
        locationService: MockLocationService(),
        onContinue: { print("Continue") },
        onSkip: { print("Skip") }
    )
}
