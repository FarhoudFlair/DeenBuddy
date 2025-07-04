# Engineer 4: SwiftUI Views for iOS

## 🚨 **Critical Context: What Went Wrong**
We accidentally built a **macOS Swift Package** instead of an **iOS App** for DeenBuddy. The good news: our Supabase backend is perfect with all 10 prayer guides (5 Sunni + 5 Shia) successfully uploaded and working. We need to create proper iOS SwiftUI views.

## ✅ **What's Already Working**
- **Supabase Database**: 10 prayer guides successfully uploaded
  - Fajr, Dhuhr, Asr, Maghrib, Isha (both Sunni and Shia versions)
  - Proper rakah counts: Fajr (2), Dhuhr (4), Asr (4), Maghrib (3), Isha (4)
- **Content Structure**: Rich Islamic content with Arabic text, transliterations, translations
- **API Integration**: Supabase service will provide @Published properties for SwiftUI

## 🎯 **Your Role: SwiftUI Views for iOS**
You're responsible for creating the entire iOS user interface using SwiftUI, including navigation, prayer guide lists, detail views, and iOS-specific UI patterns like tab bars, pull-to-refresh, and search.

## 📁 **Your Specific Files to Create**
**Primary Files (Your Ownership):**
```
Views/
├── ContentView.swift              ← Main app view with tab navigation
├── PrayerGuideListView.swift      ← List of prayer guides
├── PrayerGuideDetailView.swift    ← Detailed prayer instructions
├── PrayerGuideRowView.swift       ← Individual list row component
├── SettingsView.swift             ← App settings and preferences
├── SearchView.swift               ← Search and filter functionality
└── Components/
    ├── LoadingView.swift          ← Loading states
    ├── ErrorView.swift            ← Error handling UI
    ├── EmptyStateView.swift       ← Empty state handling
    └── PrayerStepView.swift       ← Individual prayer step component
```

**Secondary Files (Coordinate Changes):**
```
Views/
├── OnboardingView.swift           ← First-time user experience
├── BookmarksView.swift            ← Bookmarked prayer guides
└── OfflineView.swift              ← Offline content management
```

## 📋 **Expected Data Structure**
You'll receive this data from Engineer 3's SupabaseService:

```swift
// From SupabaseService
@Published var prayerGuides: [PrayerGuide] = []
@Published var isLoading = false
@Published var errorMessage: String?
@Published var isOffline = false

// PrayerGuide structure (from Engineer 2)
struct PrayerGuide {
    let id: String
    let title: String           // "Fajr Prayer Guide (Sunni)"
    let prayerName: String      // "fajr"
    let sect: String           // "sunni" or "shia"
    let rakahCount: Int        // 2, 3, or 4
    let textContent: PrayerContent?
    // ... other properties
    
    var prayer: Prayer         // Computed property
    var madhab: Madhab        // Computed property
    var displayTitle: String  // Computed property
}
```

## 🎯 **Deliverables & Acceptance Criteria**

### **1. Create ContentView.swift**
Main app view with iOS tab navigation:

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var supabaseService = SupabaseService()
    @State private var selectedTab = 0
    @State private var selectedMadhab: Madhab = .sunni
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Prayer Guides Tab
            NavigationStack {
                PrayerGuideListView(
                    guides: supabaseService.prayerGuides,
                    selectedMadhab: $selectedMadhab,
                    isLoading: supabaseService.isLoading,
                    errorMessage: supabaseService.errorMessage,
                    isOffline: supabaseService.isOffline,
                    onRefresh: {
                        Task {
                            await supabaseService.refreshData()
                        }
                    }
                )
                .navigationTitle("Prayer Guides")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Picker("Madhab", selection: $selectedMadhab) {
                            ForEach(Madhab.allCases, id: \.self) { madhab in
                                Text(madhab.displayName)
                                    .tag(madhab)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
            .tabItem {
                Image(systemName: "book.closed")
                Text("Guides")
            }
            .tag(0)
            
            // Search Tab
            NavigationStack {
                SearchView(guides: supabaseService.prayerGuides)
            }
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Search")
            }
            .tag(1)
            
            // Bookmarks Tab
            NavigationStack {
                BookmarksView(guides: supabaseService.prayerGuides)
            }
            .tabItem {
                Image(systemName: "bookmark")
                Text("Bookmarks")
            }
            .tag(2)
            
            // Settings Tab
            NavigationStack {
                SettingsView(selectedMadhab: $selectedMadhab)
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(3)
        }
        .task {
            await supabaseService.fetchPrayerGuides()
        }
    }
}
```

### **2. Create PrayerGuideListView.swift**
iOS-optimized list with pull-to-refresh:

```swift
import SwiftUI

struct PrayerGuideListView: View {
    let guides: [PrayerGuide]
    @Binding var selectedMadhab: Madhab
    let isLoading: Bool
    let errorMessage: String?
    let isOffline: Bool
    let onRefresh: () -> Void
    
    private var filteredGuides: [PrayerGuide] {
        guides.filter { $0.madhab == selectedMadhab }
            .sorted { $0.prayer.rawValue < $1.prayer.rawValue }
    }
    
    var body: some View {
        Group {
            if isLoading && guides.isEmpty {
                LoadingView(message: "Loading prayer guides...")
            } else if let errorMessage = errorMessage, guides.isEmpty {
                ErrorView(
                    message: errorMessage,
                    onRetry: onRefresh
                )
            } else if filteredGuides.isEmpty {
                EmptyStateView(
                    title: "No Prayer Guides",
                    message: "No guides found for \(selectedMadhab.displayName) tradition",
                    systemImage: "book.closed"
                )
            } else {
                List {
                    if isOffline {
                        Section {
                            HStack {
                                Image(systemName: "wifi.slash")
                                    .foregroundColor(.orange)
                                Text("Offline Mode")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Section("Prayer Guides (\(filteredGuides.count))") {
                        ForEach(filteredGuides) { guide in
                            NavigationLink(destination: PrayerGuideDetailView(guide: guide)) {
                                PrayerGuideRowView(guide: guide)
                            }
                        }
                    }
                    
                    Section("Summary") {
                        SummaryRowView(
                            title: "Total Guides",
                            value: "\(guides.count)",
                            color: .primary
                        )
                        
                        SummaryRowView(
                            title: "Sunni Guides",
                            value: "\(guides.filter { $0.madhab == .sunni }.count)",
                            color: .green
                        )
                        
                        SummaryRowView(
                            title: "Shia Guides",
                            value: "\(guides.filter { $0.madhab == .shia }.count)",
                            color: .purple
                        )
                    }
                }
                .refreshable {
                    onRefresh()
                }
                .searchable(text: .constant(""), prompt: "Search prayer guides...")
            }
        }
    }
}

struct SummaryRowView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}
```

### **3. Create PrayerGuideRowView.swift**
Individual list row component:

```swift
import SwiftUI

struct PrayerGuideRowView: View {
    let guide: PrayerGuide
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(guide.title)
                .font(.headline)
                .foregroundColor(.primary)
            
            // Prayer info badges
            HStack(spacing: 8) {
                // Prayer name badge
                HStack(spacing: 4) {
                    Image(systemName: guide.prayer.systemImageName)
                        .font(.caption)
                    Text(guide.prayer.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(guide.prayer.color.opacity(0.2))
                .foregroundColor(guide.prayer.color)
                .cornerRadius(6)
                
                // Madhab badge
                Text(guide.madhab.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(guide.madhab.color.opacity(0.2))
                    .foregroundColor(guide.madhab.color)
                    .cornerRadius(6)
                
                Spacer()
                
                // Rakah count
                Text(guide.rakahText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Arabic name
            HStack {
                Text(guide.prayer.arabicName)
                    .font(.title3)
                    .fontWeight(.medium)
                    .environment(\.layoutDirection, .rightToLeft)
                
                Spacer()
                
                if guide.isAvailableOffline {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
```

### **4. Create PrayerGuideDetailView.swift**
Detailed prayer instructions view:

```swift
import SwiftUI

struct PrayerGuideDetailView: View {
    let guide: PrayerGuide
    @State private var isBookmarked = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text(guide.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    HStack {
                        Label(guide.prayer.displayName, systemImage: guide.prayer.systemImageName)
                            .foregroundColor(guide.prayer.color)
                        
                        Spacer()
                        
                        Text(guide.rakahText)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(guide.prayer.arabicName)
                        .font(.title)
                        .fontWeight(.semibold)
                        .environment(\.layoutDirection, .rightToLeft)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Prayer steps
                if let content = guide.textContent {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(content.steps) { step in
                            PrayerStepView(step: step)
                        }
                    }
                }
                
                // Important notes
                if let content = guide.textContent,
                   let notes = content.importantNotes,
                   !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Important Notes")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        ForEach(notes, id: \.self) { note in
                            HStack(alignment: .top) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text(note)
                                    .font(.callout)
                            }
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: toggleBookmark) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundColor(isBookmarked ? .yellow : .gray)
                }
            }
        }
    }
    
    private func toggleBookmark() {
        isBookmarked.toggle()
        // TODO: Coordinate with Engineer 6 for bookmark persistence
    }
}
```

### **5. Create Supporting Views**
LoadingView, ErrorView, EmptyStateView, and PrayerStepView components.

## 🔗 **Dependencies & Coordination**

### **You Enable:**
- **Complete iOS user interface** for the DeenBuddy app
- **User interaction** with all 10 prayer guides
- **iOS-native experience** with proper navigation and UI patterns

### **You Depend On:**
- **Engineer 1**: Needs iOS project configured before building views
- **Engineer 2**: Needs iOS-compatible models with display properties
- **Engineer 3**: Needs working SupabaseService with @Published properties

### **Coordination Points:**
- **With Engineer 2**: Use provided display properties and computed values
- **With Engineer 3**: Use @Published properties for reactive UI updates
- **With Engineer 6**: Coordinate on bookmark and offline features

## ⚠️ **Critical Requirements**

### **iOS-Specific UI:**
1. **Native iOS patterns**: TabView, NavigationStack, List with pull-to-refresh
2. **iOS design system**: SF Symbols, iOS colors, proper spacing
3. **Accessibility**: VoiceOver support, Dynamic Type
4. **Responsive design**: Works on iPhone and iPad

### **Prayer Guide Display:**
1. **Proper Arabic text**: Right-to-left layout for Arabic content
2. **Clear hierarchy**: Easy to follow prayer instructions
3. **Visual distinction**: Clear difference between Sunni and Shia guides
4. **Offline indicators**: Show when content is available offline

## ✅ **Acceptance Criteria**

### **Must Have:**
- [ ] App builds and runs on iOS Simulator
- [ ] Displays all 10 prayer guides correctly
- [ ] Tab navigation works properly
- [ ] Pull-to-refresh functionality
- [ ] Proper loading and error states
- [ ] Arabic text displays correctly

### **Should Have:**
- [ ] Search functionality
- [ ] Bookmark capability (UI only)
- [ ] Settings view for preferences
- [ ] Offline mode indicators
- [ ] Smooth animations and transitions

### **Nice to Have:**
- [ ] Dark mode support
- [ ] Accessibility features
- [ ] iPad optimization
- [ ] Haptic feedback

## 🚀 **Success Validation**
1. **UI Test**: All views display correctly in iOS Simulator
2. **Data Test**: All 10 prayer guides show proper content
3. **Navigation Test**: Tab and detail navigation work smoothly
4. **Interaction Test**: Pull-to-refresh and search work correctly

**Estimated Time**: 10-12 hours
**Priority**: HIGH - This creates the complete user experience
