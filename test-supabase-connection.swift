#!/usr/bin/env swift

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Simple test to verify Supabase connection and data retrieval
struct SupabaseTest {
    let url = "https://hjgwbkcjjclwqamtmhsa.supabase.co"
    let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhqZ3dia2NqamNsd3FhbXRtaHNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1NzQwOTYsImV4cCI6MjA2NzE1MDA5Nn0.pipfeKNNDclXlfOimWQnhkf_VY-YTsV3_vZaoEbWSGM"
    
    func testConnection() async {
        print("🔍 Testing Supabase connection...")
        print("URL: \(url)")
        
        guard let requestUrl = URL(string: "\(url)/rest/v1/prayer_guides?select=id,content_id,title,prayer_name,sect,rakah_count") else {
            print("❌ Invalid URL")
            return
        }
        
        var request = URLRequest(url: requestUrl)
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("✅ Successfully connected to Supabase!")
                        print("📊 Raw Response:")
                        print(jsonString)
                        
                        // Try to parse the JSON
                        if let jsonData = jsonString.data(using: .utf8),
                           let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                            print("\n📚 Prayer Guides Found: \(jsonArray.count)")
                            
                            for (index, guide) in jsonArray.enumerated() {
                                print("\n\(index + 1). \(guide["title"] ?? "Unknown")")
                                print("   ID: \(guide["content_id"] ?? "Unknown")")
                                print("   Prayer: \(guide["prayer_name"] ?? "Unknown")")
                                print("   Sect: \(guide["sect"] ?? "Unknown")")
                                print("   Rakah: \(guide["rakah_count"] ?? "Unknown")")
                            }
                            
                            // Summary by sect
                            let sunniCount = jsonArray.filter { ($0["sect"] as? String) == "sunni" }.count
                            let shiaCount = jsonArray.filter { ($0["sect"] as? String) == "shia" }.count
                            
                            print("\n📈 Summary:")
                            print("   Total Guides: \(jsonArray.count)")
                            print("   Sunni Guides: \(sunniCount)")
                            print("   Shia Guides: \(shiaCount)")
                            
                            if jsonArray.count == 10 && sunniCount == 5 && shiaCount == 5 {
                                print("✅ All prayer guides are present and correctly distributed!")
                            } else {
                                print("⚠️  Expected 10 guides (5 Sunni + 5 Shia), but found different counts")
                            }
                        }
                    }
                } else {
                    print("❌ HTTP Error: \(httpResponse.statusCode)")
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("Error details: \(errorString)")
                    }
                }
            }
        } catch {
            print("❌ Network Error: \(error)")
        }
    }
}

// Run the test
let test = SupabaseTest()
await test.testConnection()
print("\n🏁 Test completed!")
