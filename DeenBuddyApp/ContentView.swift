import SwiftUI

struct PrayerGuide: Codable, Identifiable {
    let id: String
    let contentId: String
    let title: String
    let prayerName: String
    let sect: String
    let rakahCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case contentId = "content_id"
        case title
        case prayerName = "prayer_name"
        case sect
        case rakahCount = "rakah_count"
    }
}

class SupabaseService: ObservableObject {
    @Published var prayerGuides: [PrayerGuide] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let url = "https://hjgwbkcjjclwqamtmhsa.supabase.co"
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhqZ3dia2NqamNsd3FhbXRtaHNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1NzQwOTYsImV4cCI6MjA2NzE1MDA5Nn0.pipfeKNNDclXlfOimWQnhkf_VY-YTsV3_vZaoEbWSGM"
    
    func fetchPrayerGuides() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        guard let requestUrl = URL(string: "\(url)/rest/v1/prayer_guides?select=id,content_id,title,prayer_name,sect,rakah_count&order=prayer_name,sect") else {
            await MainActor.run {
                errorMessage = "Invalid URL"
                isLoading = false
            }
            return
        }
        
        var request = URLRequest(url: requestUrl)
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let guides = try JSONDecoder().decode([PrayerGuide].self, from: data)
                await MainActor.run {
                    self.prayerGuides = guides
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    errorMessage = "Failed to fetch data"
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Network error: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var supabaseService = SupabaseService()
    
    var body: some View {
        NavigationView {
            VStack {
                if supabaseService.isLoading {
                    ProgressView("Loading prayer guides...")
                        .padding()
                } else if let errorMessage = supabaseService.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("Error")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                await supabaseService.fetchPrayerGuides()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                    }
                    .padding()
                } else if supabaseService.prayerGuides.isEmpty {
                    VStack {
                        Image(systemName: "book.closed")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No prayer guides found")
                            .font(.headline)
                        Button("Load Guides") {
                            Task {
                                await supabaseService.fetchPrayerGuides()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                    }
                    .padding()
                } else {
                    List {
                        Section("Prayer Guides (\(supabaseService.prayerGuides.count))") {
                            ForEach(supabaseService.prayerGuides) { guide in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(guide.title)
                                        .font(.headline)
                                    HStack {
                                        Text(guide.prayerName.capitalized)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.2))
                                            .cornerRadius(4)
                                        
                                        Text(guide.sect.capitalized)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(guide.sect == "sunni" ? Color.green.opacity(0.2) : Color.purple.opacity(0.2))
                                            .cornerRadius(4)
                                        
                                        Spacer()
                                        
                                        Text("\(guide.rakahCount) Rakah")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        
                        Section("Summary") {
                            let sunniCount = supabaseService.prayerGuides.filter { $0.sect == "sunni" }.count
                            let shiaCount = supabaseService.prayerGuides.filter { $0.sect == "shia" }.count
                            
                            HStack {
                                Text("Total Guides")
                                Spacer()
                                Text("\(supabaseService.prayerGuides.count)")
                                    .fontWeight(.semibold)
                            }
                            
                            HStack {
                                Text("Sunni Guides")
                                Spacer()
                                Text("\(sunniCount)")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                            
                            HStack {
                                Text("Shia Guides")
                                Spacer()
                                Text("\(shiaCount)")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                }
            }
            .navigationTitle("DeenBuddy")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await supabaseService.fetchPrayerGuides()
                        }
                    }
                }
            }
        }
        .task {
            await supabaseService.fetchPrayerGuides()
        }
    }
}

#Preview {
    ContentView()
}
