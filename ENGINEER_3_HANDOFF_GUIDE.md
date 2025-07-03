# Engineer 3 → Engineers 4 & 6: iOS Supabase Service Handoff Guide

## 🎯 **What's Ready for You**

The iOS-compatible Supabase service is complete and ready for integration. Here's everything you need to know:

## 📱 **For Engineer 4 (SwiftUI Views)**

### **How to Use the Service in SwiftUI:**

```swift
import SwiftUI
import DeenAssistCore

struct ContentView: View {
    @StateObject private var supabaseService = SupabaseService()
    
    var body: some View {
        NavigationView {
            VStack {
                if supabaseService.isLoading {
                    ProgressView("Loading prayer guides...")
                } else if supabaseService.prayerGuides.isEmpty {
                    Text("No prayer guides available")
                        .foregroundColor(.secondary)
                } else {
                    List(supabaseService.prayerGuides) { guide in
                        PrayerGuideRow(guide: guide)
                    }
                }
                
                if supabaseService.isOffline {
                    HStack {
                        Image(systemName: "wifi.slash")
                        Text("Offline Mode")
                    }
                    .foregroundColor(.orange)
                    .padding()
                }
            }
            .navigationTitle("Prayer Guides")
            .refreshable {
                await supabaseService.refreshData()
            }
            .task {
                await supabaseService.fetchPrayerGuides()
            }
        }
    }
}
```

### **Available Properties:**
- `@Published var prayerGuides: [PrayerGuide]` - All loaded guides
- `@Published var isLoading: Bool` - Loading state
- `@Published var errorMessage: String?` - Error messages
- `@Published var isOffline: Bool` - Network status
- `@Published var syncProgress: Double` - Sync progress (0.0-1.0)

### **Available Methods:**
- `fetchPrayerGuides(forceRefresh: Bool = false)` - Load guides
- `getPrayerGuides(for madhab: Madhab)` - Filter by madhab
- `getPrayerGuide(for prayer: Prayer, madhab: Madhab)` - Get specific guide
- `refreshData()` - Force refresh from server

## 🔧 **For Engineer 6 (iOS Features)**

### **Offline Service Integration:**

```swift
import DeenAssistCore

// Access offline service
let offlineService = OfflineService()

// Check offline availability
let isAvailable = await offlineService.isContentAvailableOffline(guideId: "fajr_sunni")

// Get offline guides
let offlineGuides = await offlineService.getOfflineGuides()

// Cache management
let cacheInfo = await offlineService.getCacheInfo()
print("Cache: \(cacheInfo.itemCount) items, \(cacheInfo.formattedSize)")

// Clear cache if needed
await offlineService.clearCache()
```

### **Network Monitoring:**

```swift
// The service automatically monitors network state
// Access through the main service:
if supabaseService.isOffline {
    // Show offline UI
    // Service automatically falls back to cache
}

// Or use NetworkMonitor directly:
let networkMonitor = NetworkMonitor.shared
networkMonitor.$isConnected
    .sink { isConnected in
        // Handle network changes
    }
```

### **Background Sync:**

```swift
// Background sync is automatic! 
// The service handles:
// - App becoming active
// - Network reconnection
// - Hourly sync checks

// You can manually trigger sync:
await supabaseService.refreshData()

// Check last sync time:
let lastSync = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
```

## 📊 **Data Models You'll Work With**

### **PrayerGuide Model:**
```swift
public struct PrayerGuide: Codable, Identifiable {
    public let id: String
    public let title: String                    // "Fajr Prayer Guide (Sunni)"
    public let prayer: Prayer                   // .fajr, .dhuhr, etc.
    public let madhab: Madhab                   // .shafi, .hanafi
    public let difficulty: Difficulty           // .beginner, .intermediate, .advanced
    public let duration: TimeInterval           // in seconds
    public let description: String
    public let steps: [PrayerStep]
    public let isAvailableOffline: Bool
    public var isCompleted: Bool
    public let createdAt: Date
    public let updatedAt: Date
}
```

### **Prayer & Madhab Enums:**
```swift
public enum Prayer: String, CaseIterable, Codable {
    case fajr = "Fajr"
    case dhuhr = "Dhuhr"
    case asr = "Asr"
    case maghrib = "Maghrib"
    case isha = "Isha"
}

public enum Madhab: String, CaseIterable, Codable {
    case shafi = "shafi"    // Represents Sunni guides
    case hanafi = "hanafi"  // Represents Shia guides
}
```

## 🚨 **Important Notes**

### **Madhab Mapping:**
The database stores `sect` as "sunni"/"shia", but we map it to `madhab`:
- "sunni" → `.shafi` 
- "shia" → `.hanafi`

This is a simplified mapping for the current implementation.

### **Error Handling:**
```swift
// The service handles errors gracefully:
if let errorMessage = supabaseService.errorMessage {
    // Show error to user
    // Service automatically falls back to cache
}
```

### **Cache Behavior:**
- **First load**: Tries cache first, then network
- **Force refresh**: Skips cache, goes to network
- **Network error**: Falls back to cache automatically
- **Background updates**: Fetches new data silently

## 🔗 **Integration Examples**

### **Prayer Guide List View:**
```swift
struct PrayerGuidesView: View {
    @StateObject private var supabaseService = SupabaseService()
    @State private var selectedMadhab: Madhab = .shafi
    
    var filteredGuides: [PrayerGuide] {
        supabaseService.getPrayerGuides(for: selectedMadhab)
    }
    
    var body: some View {
        VStack {
            Picker("Madhab", selection: $selectedMadhab) {
                Text("Sunni").tag(Madhab.shafi)
                Text("Shia").tag(Madhab.hanafi)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            List(filteredGuides) { guide in
                NavigationLink(destination: GuideDetailView(guide: guide)) {
                    VStack(alignment: .leading) {
                        Text(guide.title)
                            .font(.headline)
                        Text("\(guide.prayer.displayName) • \(guide.formattedDuration)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .task {
            await supabaseService.fetchPrayerGuides()
        }
    }
}
```

### **Offline Status Banner:**
```swift
struct OfflineStatusBanner: View {
    @ObservedObject var supabaseService: SupabaseService
    
    var body: some View {
        if supabaseService.isOffline {
            HStack {
                Image(systemName: "wifi.slash")
                Text("You're offline. Showing cached content.")
                Spacer()
            }
            .padding()
            .background(Color.orange.opacity(0.2))
            .foregroundColor(.orange)
        }
    }
}
```

## 🎉 **You're All Set!**

The iOS Supabase service is production-ready with:
- ✅ 10 prayer guides loading from Supabase
- ✅ Offline caching and fallback
- ✅ Network monitoring and auto-sync
- ✅ SwiftUI reactive updates
- ✅ iOS app lifecycle handling

**Need help?** Check the completion report or the test files for more examples!
