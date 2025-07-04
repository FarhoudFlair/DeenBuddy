# Engineer 2: Core Models Migration

## 🚨 **Critical Context: What Went Wrong**
We accidentally built a **macOS Swift Package** instead of an **iOS App** for DeenBuddy. The good news: our Supabase backend is perfect with all 10 prayer guides (5 Sunni + 5 Shia) successfully uploaded and working. We need to convert the core models to work properly with iOS.

## ✅ **What's Already Working**
- **Supabase Database**: 10 prayer guides with correct schema
  - Fajr (2 rakah), Dhuhr (4 rakah), Asr (4 rakah), Maghrib (3 rakah), Isha (4 rakah)
  - Both Sunni and Shia versions for each prayer
- **Database Schema**: `prayer_guides` table with proper structure
- **Content Pipeline**: All Islamic prayer content validated and uploaded

## 🎯 **Your Role: Core Models Migration**
You're responsible for converting our core data models from macOS-compatible to iOS-compatible, ensuring they work seamlessly with Supabase and iOS-specific features like Core Data, UserDefaults, and iOS lifecycle management.

## 📁 **Your Specific Files to Work On**
**Primary Files (Your Ownership):**
```
Sources/DeenAssistCore/Models/
├── PrayerGuide.swift           ← Convert to iOS-compatible
├── Prayer.swift                ← Add iOS-specific features
├── Madhab.swift               ← Ensure iOS compatibility
└── PrayerStep.swift           ← Update for iOS UI
```

**Secondary Files (Coordinate Changes):**
```
Sources/DeenAssistCore/Models/
├── User.swift                 ← Create for iOS user preferences
├── PrayerTime.swift          ← Create for iOS location-based times
└── OfflineContent.swift      ← Create for iOS offline storage
```

## 📋 **Current Model Structure (Supabase Compatible)**
Our Supabase database has this working structure:
```sql
prayer_guides table:
- id (UUID)
- content_id (VARCHAR) - e.g., "fajr_sunni_guide"
- title (VARCHAR) - e.g., "Fajr Prayer Guide (Sunni)"
- prayer_name (VARCHAR) - "fajr", "dhuhr", "asr", "maghrib", "isha"
- sect (VARCHAR) - "sunni", "shia"
- rakah_count (INTEGER) - 2, 3, or 4
- text_content (JSONB) - Structured prayer instructions
- video_url (TEXT) - Optional video content
- thumbnail_url (TEXT) - Optional thumbnail
- is_available_offline (BOOLEAN)
- version (INTEGER)
- created_at, updated_at (TIMESTAMP)
```

## 🎯 **Deliverables & Acceptance Criteria**

### **1. Update PrayerGuide.swift**
Convert from macOS to iOS-compatible model:

```swift
import Foundation
import SwiftUI  // Add iOS UI support

public struct PrayerGuide: Codable, Identifiable, Hashable {
    public let id: String
    public let contentId: String
    public let title: String
    public let prayerName: String
    public let sect: String
    public let rakahCount: Int
    public let contentType: String
    public let textContent: PrayerContent?
    public let videoUrl: String?
    public let thumbnailUrl: String?
    public let isAvailableOffline: Bool
    public let version: Int
    public let createdAt: Date
    public let updatedAt: Date
    
    // iOS-specific properties
    public var isBookmarked: Bool = false
    public var lastReadDate: Date?
    public var readingProgress: Double = 0.0
    
    enum CodingKeys: String, CodingKey {
        case id, title, version
        case contentId = "content_id"
        case prayerName = "prayer_name"
        case sect
        case rakahCount = "rakah_count"
        case contentType = "content_type"
        case textContent = "text_content"
        case videoUrl = "video_url"
        case thumbnailUrl = "thumbnail_url"
        case isAvailableOffline = "is_available_offline"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // iOS-specific computed properties
    public var prayer: Prayer {
        Prayer(rawValue: prayerName) ?? .fajr
    }
    
    public var madhab: Madhab {
        Madhab(rawValue: sect) ?? .sunni
    }
    
    // iOS display helpers
    public var displayTitle: String {
        "\(prayer.displayName) (\(madhab.displayName))"
    }
    
    public var rakahText: String {
        "\(rakahCount) Rakah"
    }
}
```

### **2. Update Prayer.swift**
Add iOS-specific features and proper display support:

```swift
import Foundation
import SwiftUI

public enum Prayer: String, CaseIterable, Codable {
    case fajr = "fajr"
    case dhuhr = "dhuhr"
    case asr = "asr"
    case maghrib = "maghrib"
    case isha = "isha"
    
    // iOS display properties
    public var displayName: String {
        switch self {
        case .fajr: return "Fajr"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        }
    }
    
    public var arabicName: String {
        switch self {
        case .fajr: return "الفجر"
        case .dhuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        }
    }
    
    // iOS-specific properties
    public var defaultRakahCount: Int {
        switch self {
        case .fajr: return 2
        case .dhuhr: return 4
        case .asr: return 4
        case .maghrib: return 3
        case .isha: return 4
        }
    }
    
    public var systemImageName: String {
        switch self {
        case .fajr: return "sunrise"
        case .dhuhr: return "sun.max"
        case .asr: return "sun.and.horizon"
        case .maghrib: return "sunset"
        case .isha: return "moon.stars"
        }
    }
    
    public var color: Color {
        switch self {
        case .fajr: return .orange
        case .dhuhr: return .yellow
        case .asr: return .blue
        case .maghrib: return .red
        case .isha: return .purple
        }
    }
}
```

### **3. Update Madhab.swift**
Ensure iOS compatibility and proper display:

```swift
import Foundation
import SwiftUI

public enum Madhab: String, CaseIterable, Codable {
    case sunni = "sunni"
    case shia = "shia"
    
    public var displayName: String {
        switch self {
        case .sunni: return "Sunni"
        case .shia: return "Shia"
        }
    }
    
    public var arabicName: String {
        switch self {
        case .sunni: return "سني"
        case .shia: return "شيعي"
        }
    }
    
    // iOS-specific properties
    public var color: Color {
        switch self {
        case .sunni: return .green
        case .shia: return .purple
        }
    }
    
    public var description: String {
        switch self {
        case .sunni: return "Sunni Islamic tradition"
        case .shia: return "Shia Islamic tradition"
        }
    }
}
```

### **4. Create PrayerContent.swift**
New model for structured prayer content:

```swift
import Foundation

public struct PrayerContent: Codable {
    public let steps: [PrayerStep]
    public let rakahInstructions: [String]?
    public let importantNotes: [String]?
    
    enum CodingKeys: String, CodingKey {
        case steps
        case rakahInstructions = "rakah_instructions"
        case importantNotes = "important_notes"
    }
}

public struct PrayerStep: Codable, Identifiable {
    public let id = UUID()
    public let step: Int
    public let title: String
    public let description: String
    public let arabic: String?
    public let transliteration: String?
    public let translation: String?
    
    enum CodingKeys: String, CodingKey {
        case step, title, description, arabic, transliteration, translation
    }
}
```

### **5. Create User.swift**
iOS user preferences model:

```swift
import Foundation

public struct User: Codable {
    public let id: UUID
    public var preferredMadhab: Madhab
    public var enabledNotifications: Bool
    public var locationPermissionGranted: Bool
    public var bookmarkedGuides: Set<String>
    public var offlineGuides: Set<String>
    
    public init(
        id: UUID = UUID(),
        preferredMadhab: Madhab = .sunni,
        enabledNotifications: Bool = true,
        locationPermissionGranted: Bool = false,
        bookmarkedGuides: Set<String> = [],
        offlineGuides: Set<String> = []
    ) {
        self.id = id
        self.preferredMadhab = preferredMadhab
        self.enabledNotifications = enabledNotifications
        self.locationPermissionGranted = locationPermissionGranted
        self.bookmarkedGuides = bookmarkedGuides
        self.offlineGuides = offlineGuides
    }
}
```

## 🔗 **Dependencies & Coordination**

### **You Enable:**
- **Engineer 3**: Needs updated models for Supabase service
- **Engineer 4**: Needs iOS-compatible models for SwiftUI views
- **Engineer 6**: Needs User model for iOS-specific features

### **You Depend On:**
- **Engineer 1**: Needs iOS project configured before testing models

### **Coordination Points:**
- **With Engineer 3**: Ensure model changes don't break Supabase integration
- **With Engineer 4**: Provide iOS-friendly display properties and computed values
- **With Engineer 6**: Coordinate on User model requirements

## ⚠️ **Critical Requirements**

### **iOS Compatibility:**
1. **Remove macOS imports**: No `import AppKit` or `import Cocoa`
2. **Add iOS imports**: `import SwiftUI`, `import Foundation`
3. **iOS-specific features**: Color, SF Symbols, display helpers
4. **Proper Codable**: Must work with Supabase JSON structure

### **Supabase Compatibility:**
1. **Maintain CodingKeys**: Don't break existing API integration
2. **Date handling**: Proper ISO8601 date parsing
3. **Optional fields**: Handle nullable database fields correctly

## ✅ **Acceptance Criteria**

### **Must Have:**
- [ ] All models compile for iOS (no macOS dependencies)
- [ ] Supabase integration remains working (same CodingKeys)
- [ ] Models include iOS-specific display properties
- [ ] Proper SwiftUI Color and SF Symbols integration
- [ ] User preferences model created for iOS features

### **Should Have:**
- [ ] Computed properties for UI display
- [ ] Proper Arabic text support
- [ ] Bookmark and offline functionality models
- [ ] Reading progress tracking

### **Nice to Have:**
- [ ] Accessibility support properties
- [ ] Search and filtering helpers
- [ ] Export/sharing functionality

## 🚀 **Success Validation**
1. **Compilation Test**: All models build for iOS without errors
2. **Supabase Test**: Models can decode existing prayer guide data
3. **UI Test**: Models provide proper display properties for SwiftUI
4. **Integration Test**: Other engineers can use your models immediately

**Estimated Time**: 6-8 hours
**Priority**: HIGH - Engineers 3, 4, and 6 depend on your work
