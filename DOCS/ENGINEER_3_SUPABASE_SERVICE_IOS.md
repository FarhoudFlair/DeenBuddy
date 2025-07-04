# Engineer 3: Supabase Service iOS Adaptation

## 🚨 **Critical Context: What Went Wrong**
We accidentally built a **macOS Swift Package** instead of an **iOS App** for DeenBuddy. The good news: our Supabase backend is perfect with all 10 prayer guides (5 Sunni + 5 Shia) successfully uploaded and working. We need to adapt the Supabase service for iOS.

## ✅ **What's Already Working**
- **Supabase Database**: 10 prayer guides successfully uploaded and accessible
- **API Endpoints**: All REST endpoints working correctly
- **Authentication**: Supabase anon key and service role configured
- **Database Schema**: Proper `prayer_guides` table structure
- **Test Verification**: Connection test confirms all 10 guides load correctly

**Working Supabase Credentials:**
- URL: `https://hjgwbkcjjclwqamtmhsa.supabase.co`
- Anon Key: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhqZ3dia2NqamNsd3FhbXRtaHNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1NzQwOTYsImV4cCI6MjA2NzE1MDA5Nn0.pipfeKNNDclXlfOimWQnhkf_VY-YTsV3_vZaoEbWSGM`

## 🎯 **Your Role: Supabase Service iOS Adaptation**
You're responsible for converting the existing Supabase service from macOS-compatible to iOS-compatible, implementing proper iOS networking patterns, offline caching, and background sync capabilities.

## 📁 **Your Specific Files to Work On**
**Primary Files (Your Ownership):**
```
Sources/DeenAssistCore/Services/
├── SupabaseService.swift      ← Convert to iOS-compatible
├── NetworkService.swift       ← Create iOS networking layer
├── OfflineService.swift       ← Create iOS offline caching
└── SyncService.swift          ← Create iOS background sync
```

**Secondary Files (Coordinate Changes):**
```
Sources/DeenAssistCore/Services/
├── ErrorHandling.swift        ← Create iOS error handling
└── NetworkMonitor.swift       ← Create iOS network monitoring
```

## 📋 **Current Working Supabase Integration**
Our test confirms this query works perfectly:
```
GET /rest/v1/prayer_guides?select=id,content_id,title,prayer_name,sect,rakah_count
Returns: 10 prayer guides (5 Sunni + 5 Shia)
```

## 🎯 **Deliverables & Acceptance Criteria**

### **1. Convert SupabaseService.swift to iOS**
Remove macOS dependencies and add iOS-specific features:

```swift
import Foundation
import Combine
import Network  // iOS network monitoring
import UIKit    // iOS lifecycle

@MainActor
public class SupabaseService: ObservableObject {
    // Published properties for SwiftUI
    @Published public var prayerGuides: [PrayerGuide] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var isOffline = false
    @Published public var syncProgress: Double = 0.0
    
    // Supabase configuration (keep existing working values)
    private let supabaseUrl = "https://hjgwbkcjjclwqamtmhsa.supabase.co"
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhqZ3dia2NqamNsd3FhbXRtaHNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1NzQwOTYsImV4cCI6MjA2NzE1MDA5Nn0.pipfeKNNDclXlfOimWQnhkf_VY-YTsV3_vZaoEbWSGM"
    
    // iOS-specific services
    private let networkMonitor = NetworkMonitor()
    private let offlineService = OfflineService()
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        setupNetworkMonitoring()
        setupBackgroundSync()
    }
    
    // MARK: - Main API Methods (Keep Working Logic)
    
    public func fetchPrayerGuides(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil
        
        // Try offline first if not forcing refresh
        if !forceRefresh, let cachedGuides = await offlineService.getCachedGuides() {
            self.prayerGuides = cachedGuides
            self.isLoading = false
            
            // Fetch updates in background
            Task {
                await fetchFromSupabase()
            }
            return
        }
        
        await fetchFromSupabase()
    }
    
    private func fetchFromSupabase() async {
        guard let url = URL(string: "\(supabaseUrl)/rest/v1/prayer_guides") else {
            await MainActor.run {
                self.errorMessage = "Invalid URL"
                self.isLoading = false
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add iOS-specific query parameters
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "select", value: "id,content_id,title,prayer_name,sect,rakah_count,text_content,video_url,thumbnail_url,is_available_offline,version,created_at,updated_at"),
            URLQueryItem(name: "order", value: "prayer_name,sect")
        ]
        
        guard let finalUrl = components?.url else {
            await MainActor.run {
                self.errorMessage = "Failed to build URL"
                self.isLoading = false
            }
            return
        }
        
        request.url = finalUrl
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run {
                    self.errorMessage = "Invalid response"
                    self.isLoading = false
                }
                return
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let guides = try decoder.decode([PrayerGuide].self, from: data)
                
                await MainActor.run {
                    self.prayerGuides = guides
                    self.isLoading = false
                }
                
                // Cache for offline use
                await offlineService.cacheGuides(guides)
                
            } else {
                await MainActor.run {
                    self.errorMessage = "Server error: \(httpResponse.statusCode)"
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Network error: \(error.localizedDescription)"
                self.isLoading = false
                
                // Try to load from cache on error
                Task {
                    if let cachedGuides = await self.offlineService.getCachedGuides() {
                        self.prayerGuides = cachedGuides
                        self.isOffline = true
                    }
                }
            }
        }
    }
    
    // iOS-specific methods
    private func setupNetworkMonitoring() {
        networkMonitor.isConnectedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.isOffline = !isConnected
                if isConnected {
                    Task {
                        await self?.syncIfNeeded()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupBackgroundSync() {
        // iOS background app refresh handling
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.syncIfNeeded()
                }
            }
            .store(in: &cancellables)
    }
    
    private func syncIfNeeded() async {
        guard !isOffline else { return }
        
        let lastSync = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
        let shouldSync = lastSync == nil || Date().timeIntervalSince(lastSync!) > 3600 // 1 hour
        
        if shouldSync {
            await fetchPrayerGuides(forceRefresh: true)
            UserDefaults.standard.set(Date(), forKey: "lastSyncDate")
        }
    }
}

// MARK: - iOS-specific extensions
extension SupabaseService {
    public func getPrayerGuides(for madhab: Madhab) -> [PrayerGuide] {
        return prayerGuides.filter { $0.sect == madhab.rawValue }
    }
    
    public func getPrayerGuide(for prayer: Prayer, madhab: Madhab) -> PrayerGuide? {
        return prayerGuides.first { 
            $0.prayerName == prayer.rawValue && $0.sect == madhab.rawValue 
        }
    }
    
    public func refreshData() async {
        await fetchPrayerGuides(forceRefresh: true)
    }
}
```

### **2. Create NetworkMonitor.swift**
iOS network connectivity monitoring:

```swift
import Foundation
import Network
import Combine

public class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published public var isConnected = false
    @Published public var connectionType: NWInterface.InterfaceType?
    
    public var isConnectedPublisher: AnyPublisher<Bool, Never> {
        $isConnected.eraseToAnyPublisher()
    }
    
    public init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}
```

### **3. Create OfflineService.swift**
iOS offline caching and storage:

```swift
import Foundation

public actor OfflineService {
    private let cacheDirectory: URL
    private let guidesFileName = "cached_prayer_guides.json"
    
    public init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                                   in: .userDomainMask).first!
        self.cacheDirectory = documentsPath.appendingPathComponent("DeenBuddyCache")
        
        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, 
                                               withIntermediateDirectories: true)
    }
    
    public func cacheGuides(_ guides: [PrayerGuide]) async {
        let cacheFile = cacheDirectory.appendingPathComponent(guidesFileName)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(guides)
            try data.write(to: cacheFile)
        } catch {
            print("Failed to cache guides: \(error)")
        }
    }
    
    public func getCachedGuides() async -> [PrayerGuide]? {
        let cacheFile = cacheDirectory.appendingPathComponent(guidesFileName)
        
        guard FileManager.default.fileExists(atPath: cacheFile.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: cacheFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([PrayerGuide].self, from: data)
        } catch {
            print("Failed to load cached guides: \(error)")
            return nil
        }
    }
    
    public func clearCache() async {
        let cacheFile = cacheDirectory.appendingPathComponent(guidesFileName)
        try? FileManager.default.removeItem(at: cacheFile)
    }
    
    public func getCacheSize() async -> Int64 {
        let cacheFile = cacheDirectory.appendingPathComponent(guidesFileName)
        
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: cacheFile.path) else {
            return 0
        }
        
        return attributes[.size] as? Int64 ?? 0
    }
}
```

## 🔗 **Dependencies & Coordination**

### **You Enable:**
- **Engineer 4**: Needs working Supabase service for SwiftUI views
- **Engineer 6**: Needs offline and sync capabilities for iOS features

### **You Depend On:**
- **Engineer 1**: Needs iOS project configured with proper networking permissions
- **Engineer 2**: Needs updated models for proper iOS integration

### **Coordination Points:**
- **With Engineer 2**: Ensure model changes work with your service
- **With Engineer 4**: Provide proper @Published properties for SwiftUI
- **With Engineer 6**: Coordinate on background sync and offline features

## ⚠️ **Critical Requirements**

### **iOS Compatibility:**
1. **Remove macOS imports**: No `import AppKit` or macOS-specific networking
2. **Add iOS imports**: `import UIKit`, `import Network`, `import Combine`
3. **iOS lifecycle**: Handle app backgrounding and foregrounding
4. **Main actor**: Ensure UI updates happen on main thread

### **Maintain Working Integration:**
1. **Keep existing URLs and keys**: Don't break working Supabase connection
2. **Preserve API calls**: Maintain the working query structure
3. **Same data format**: Ensure models decode correctly

## ✅ **Acceptance Criteria**

### **Must Have:**
- [ ] Service compiles for iOS (no macOS dependencies)
- [ ] Successfully fetches all 10 prayer guides from Supabase
- [ ] Proper iOS networking with URLSession
- [ ] @Published properties work with SwiftUI
- [ ] Offline caching implemented
- [ ] Network monitoring working

### **Should Have:**
- [ ] Background sync capabilities
- [ ] Error handling for iOS scenarios
- [ ] Cache management (clear, size)
- [ ] Proper iOS app lifecycle handling

### **Nice to Have:**
- [ ] Background app refresh support
- [ ] Retry logic for failed requests
- [ ] Progress tracking for large operations

## 🚀 **Success Validation**
1. **Connection Test**: Service connects to Supabase and loads 10 guides
2. **iOS Test**: Works properly in iOS Simulator
3. **Offline Test**: Caching and offline mode work correctly
4. **Integration Test**: SwiftUI views can use the service

**Estimated Time**: 8-10 hours
**Priority**: HIGH - Engineer 4 depends on your work
