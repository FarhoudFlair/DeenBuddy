import Foundation

/// Simple test to verify the iOS-compatible Supabase service
public class SupabaseServiceTest {
    
    public static func testConnection() async {
        print("🧪 Testing iOS-compatible Supabase service...")
        
        let service = SupabaseService()
        
        // Test fetching prayer guides
        await service.fetchPrayerGuides(forceRefresh: true)
        
        // Check results
        if service.prayerGuides.isEmpty {
            if let errorMessage = service.errorMessage {
                print("❌ Test failed with error: \(errorMessage)")
            } else {
                print("❌ Test failed: No prayer guides found and no error message")
            }
        } else {
            print("✅ Test passed: Successfully fetched \(service.prayerGuides.count) prayer guides")
            
            // Print some details
            for guide in service.prayerGuides.prefix(3) {
                print("   - \(guide.title) (\(guide.prayer.displayName), \(guide.madhab.displayName))")
            }
            
            // Test filtering methods
            let shafiGuides = service.getPrayerGuides(for: .shafi)
            let hanafiGuides = service.getPrayerGuides(for: .hanafi)
            
            print("   - Shafi guides: \(shafiGuides.count)")
            print("   - Hanafi guides: \(hanafiGuides.count)")
            
            // Test specific guide lookup
            if let fajrShafi = service.getPrayerGuide(for: .fajr, madhab: .shafi) {
                print("   - Found Fajr Shafi guide: \(fajrShafi.title)")
            }
        }
        
        // Test offline service
        let offlineService = OfflineService()
        let cacheInfo = await offlineService.getCacheInfo()
        
        if cacheInfo.exists {
            print("📱 Cache info: \(cacheInfo.itemCount) items, \(cacheInfo.formattedSize), \(cacheInfo.ageDescription)")
        } else {
            print("📱 No cache found")
        }
        
        print("🧪 Test completed")
    }
}
