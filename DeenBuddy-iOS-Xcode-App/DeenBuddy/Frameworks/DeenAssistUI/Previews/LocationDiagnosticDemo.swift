import SwiftUI
import CoreLocation
import DeenAssistCore
import DeenAssistProtocols

/// Demo view showing the location diagnostic feature
public struct LocationDiagnosticDemo: View {
    @State private var showDiagnostic = false
    @State private var mockLocationService = MockLocationService()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("Location Diagnostic Demo")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("This demo shows the new location diagnostic popup feature")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            // Mock location display (similar to home screen)
            VStack(spacing: 8) {
                Text("Current Location")
                    .font(.headline)
                
                Button(action: {
                    showDiagnostic = true
                }) {
                    HStack(spacing: 6) {
                        Text("New York, United States")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
            
            Text("Tap the location text above to see diagnostic information")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .overlay(
            Group {
                if showDiagnostic {
                    LocationDiagnosticPopup(
                        location: CLLocation(latitude: 40.7128, longitude: -74.0060),
                        locationService: mockLocationService,
                        isPresented: $showDiagnostic
                    )
                }
            }
        )
    }
}

#Preview("Location Diagnostic Demo") {
    LocationDiagnosticDemo()
}
