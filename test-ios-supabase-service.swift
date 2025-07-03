#!/usr/bin/env swift

import Foundation

// Simple test script to verify our iOS Supabase service works
print("🚀 Testing iOS-compatible Supabase Service")
print("=" * 50)

// Test the REST API endpoint directly
func testSupabaseAPI() async {
    let supabaseUrl = "https://hjgwbkcjjclwqamtmhsa.supabase.co"
    let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhqZ3dia2NqamNsd3FhbXRtaHNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1NzQwOTYsImV4cCI6MjA2NzE1MDA5Nn0.pipfeKNNDclXlfOimWQnhkf_VY-YTsV3_vZaoEbWSGM"
    
    guard let url = URL(string: "\(supabaseUrl)/rest/v1/prayer_guides") else {
        print("❌ Invalid URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
    request.setValue(anonKey, forHTTPHeaderField: "apikey")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    // Add query parameters
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    components?.queryItems = [
        URLQueryItem(name: "select", value: "id,content_id,title,prayer_name,sect,rakah_count"),
        URLQueryItem(name: "order", value: "prayer_name,sect")
    ]
    
    guard let finalUrl = components?.url else {
        print("❌ Failed to build URL")
        return
    }
    
    request.url = finalUrl
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response")
            return
        }
        
        print("📡 HTTP Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("✅ Successfully connected to Supabase!")
                print("📊 Response data preview:")
                
                // Parse JSON to count items
                if let jsonData = jsonString.data(using: .utf8),
                   let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                    print("   - Found \(jsonArray.count) prayer guides")
                    
                    // Show first few items
                    for (index, item) in jsonArray.prefix(3).enumerated() {
                        if let title = item["title"] as? String,
                           let prayerName = item["prayer_name"] as? String,
                           let sect = item["sect"] as? String {
                            print("   \(index + 1). \(title) (\(prayerName), \(sect))")
                        }
                    }
                } else {
                    print("   - Raw response: \(jsonString.prefix(200))...")
                }
            }
        } else {
            print("❌ Server error: \(httpResponse.statusCode)")
            if let errorData = String(data: data, encoding: .utf8) {
                print("   Error details: \(errorData)")
            }
        }
    } catch {
        print("❌ Network error: \(error.localizedDescription)")
    }
}

// Run the test
Task {
    await testSupabaseAPI()
    print("\n🏁 Test completed")
    exit(0)
}

// Keep the script running
RunLoop.main.run()
