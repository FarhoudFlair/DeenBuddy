import SwiftUI
import DeenAssistCore

struct ContentView: View {
    @EnvironmentObject var container: DependencyContainer
    
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "moon.stars")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Deen Assist")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Location & Network Services Ready")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DependencyContainer())
}
