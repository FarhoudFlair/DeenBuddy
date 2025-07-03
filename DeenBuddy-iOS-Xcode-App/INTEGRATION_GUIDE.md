# Integration Guide: SwiftUI Views → DeenAssistCore

## 🎯 **Quick Integration Steps**

### **Step 1: Add Package Dependency**
1. Open `DeenBuddy.xcodeproj` in Xcode
2. Select the project in navigator
3. Go to "Package Dependencies" tab
4. Click "+" to add package
5. Add local path: `../Sources/DeenAssistCore`
6. Add to DeenBuddy target

### **Step 2: Replace Mock Models**
```bash
# Delete the mock file
rm DeenBuddy/Models/MockModels.swift
```

### **Step 3: Update Imports**
Replace in all view files:
```swift
// Remove this line from all files:
// (MockModels.swift will be deleted)

// Add this line to all files that need models:
import DeenAssistCore
```

### **Step 4: Update ViewModel**
In `PrayerGuideViewModel.swift`:
```swift
// Replace mock configuration with real Supabase config
let config = SupabaseConfiguration(
    url: ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "YOUR_SUPABASE_URL",
    anonKey: ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? "YOUR_SUPABASE_ANON_KEY"
)
```

## 🔧 **Files to Update**

### **Add DeenAssistCore Import**
- `ContentView.swift`
- `ViewModels/PrayerGuideViewModel.swift`
- `Views/PrayerGuideListView.swift`
- `Views/PrayerGuideDetailView.swift`
- `Views/PrayerGuideRowView.swift`
- `Views/SearchView.swift`
- `Views/SettingsView.swift`
- `Views/BookmarksView.swift`
- `Views/Components/PrayerStepView.swift`

### **Delete Mock File**
- `Models/MockModels.swift` (no longer needed)

## ⚠️ **Potential Issues & Solutions**

### **Issue 1: Model Differences**
If the real PrayerGuide model differs from mock:
```swift
// Check these properties exist in real model:
- prayer.systemImageName
- prayer.color
- prayer.arabicName
- madhab.sectDisplayName
- madhab.color
- guide.formattedDuration
- guide.rakahText
```

### **Issue 2: Service Interface**
If SupabaseService interface differs:
```swift
// Expected interface in ViewModel:
@Published var isLoading: Bool
@Published var error: Error?
@Published var isConnected: Bool

func syncPrayerGuides() async throws -> [PrayerGuide]
```

### **Issue 3: Supabase Configuration**
Add environment variables or hardcode:
```swift
// Option 1: Environment variables
SUPABASE_URL=your_url_here
SUPABASE_ANON_KEY=your_key_here

// Option 2: Direct configuration
let config = SupabaseConfiguration(
    url: "https://your-project.supabase.co",
    anonKey: "your-anon-key"
)
```

## 🧪 **Testing After Integration**

### **1. Build Test**
```bash
# Should compile without errors
⌘+B in Xcode
```

### **2. Data Test**
- Launch app in simulator
- Check if real prayer guides load
- Verify Arabic text displays correctly
- Test search and filtering

### **3. Network Test**
- Test with WiFi on/off
- Verify offline mode indicators
- Check error handling

## 📱 **Expected Behavior**

### **On First Launch**
1. Loading indicator appears
2. App fetches 10 prayer guides from Supabase
3. Guides display in list with proper formatting
4. Arabic text renders right-to-left

### **Navigation Flow**
1. **Guides Tab**: Shows filtered list by tradition
2. **Search Tab**: Full-text search with filters
3. **Bookmarks Tab**: Saved guides (initially empty)
4. **Settings Tab**: App configuration

### **Data Display**
- **Sunni guides**: Green badges, Shafi madhab
- **Shia guides**: Purple badges, Hanafi madhab
- **Prayer times**: Color-coded with SF Symbols
- **Arabic names**: Right-aligned with proper font

## 🔄 **Rollback Plan**

If integration fails, restore mock data:
```bash
# Restore MockModels.swift
git checkout HEAD -- DeenBuddy/Models/MockModels.swift

# Remove DeenAssistCore imports
# Add back mock data usage
```

## 📞 **Support**

### **Common Issues**
1. **Build errors**: Check package dependency is added correctly
2. **Missing models**: Verify DeenAssistCore exports all needed types
3. **Runtime crashes**: Check model property names match
4. **No data**: Verify Supabase configuration and network

### **Debug Steps**
1. Check Xcode console for error messages
2. Verify package is properly linked
3. Test with mock data first
4. Add print statements to track data flow

---

**Estimated Integration Time**: 30-60 minutes
**Prerequisites**: DeenAssistCore package must be complete and tested
