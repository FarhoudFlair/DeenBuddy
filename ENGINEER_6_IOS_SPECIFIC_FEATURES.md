# Engineer 6: iOS-Specific Features

## 🚨 **Critical Context: What Went Wrong**
We accidentally built a **macOS Swift Package** instead of an **iOS App** for DeenBuddy. The good news: our Supabase backend is perfect with all 10 prayer guides (5 Sunni + 5 Shia) successfully uploaded and working. We need to add iOS-specific features.

## ✅ **What's Already Working**
- **Supabase Database**: 10 prayer guides with complete Islamic content
- **Prayer Times Data**: Adhan library available for accurate calculations
- **Content Structure**: Rich prayer instructions with Arabic text
- **Core Models**: Prayer, Madhab, and PrayerGuide models will be iOS-ready

## 🎯 **Your Role: iOS-Specific Features**
You're responsible for implementing iOS-specific functionality including location services for prayer times, push notifications for prayer reminders, app lifecycle management, background sync, and user preferences storage.

## 📁 **Your Specific Files to Create**
**Primary Files (Your Ownership):**
```
iOS Features/
├── LocationService.swift          ← Core Location for prayer times
├── NotificationService.swift      ← Push notifications for prayers
├── PrayerTimeService.swift        ← Calculate prayer times using Adhan
├── UserPreferencesService.swift   ← iOS user settings storage
├── AppLifecycleManager.swift      ← iOS app lifecycle handling
├── BackgroundTaskManager.swift    ← Background app refresh
└── WidgetService.swift            ← Prepare for iOS widgets
```

**Secondary Files (Coordinate Changes):**
```
iOS Features/
├── HapticFeedbackService.swift    ← iOS haptic feedback
├── ShareService.swift             ← iOS sharing functionality
└── AccessibilityService.swift     ← iOS accessibility features
```

## 📋 **Expected Integration Points**
You'll work with data from other engineers:

```swift
// From Engineer 2 (Models)
enum Prayer: String, CaseIterable {
    case fajr, dhuhr, asr, maghrib, isha
}

enum Madhab: String, CaseIterable {
    case sunni, shia
}

// From Engineer 3 (Supabase Service)
@Published var prayerGuides: [PrayerGuide] = []
@Published var isOffline = false

// From Engineer 4 (UI)
// Views will need your services for location, notifications, etc.
```

## 🎯 **Deliverables & Acceptance Criteria**

### **1. Create LocationService.swift**
Core Location integration for prayer time calculations:

```swift
import Foundation
import CoreLocation
import Combine

public class LocationService: NSObject, ObservableObject {
    @Published public var location: CLLocation?
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var locationError: String?
    
    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    public override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = 1000 // 1km
    }
    
    public func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // Guide user to settings
            locationError = "Location access denied. Please enable in Settings."
        case .authorizedWhenInUse, .authorizedAlways:
            requestCurrentLocation()
        @unknown default:
            break
        }
    }
    
    public func requestCurrentLocation() {
        guard authorizationStatus == .authorizedWhenInUse || 
              authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        
        locationManager.requestLocation()
    }
    
    // MARK: - Computed Properties
    public var coordinates: (latitude: Double, longitude: Double)? {
        guard let location = location else { return nil }
        return (location.coordinate.latitude, location.coordinate.longitude)
    }
    
    public var isLocationAvailable: Bool {
        return location != nil && 
               (authorizationStatus == .authorizedWhenInUse || 
                authorizationStatus == .authorizedAlways)
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, 
                               didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.location = location
            self.locationError = nil
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, 
                               didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = error.localizedDescription
        }
    }
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}
```

### **2. Create PrayerTimeService.swift**
Prayer time calculations using Adhan library:

```swift
import Foundation
import Adhan
import Combine

public class PrayerTimeService: ObservableObject {
    @Published public var prayerTimes: PrayerTimes?
    @Published public var nextPrayer: Prayer?
    @Published public var timeToNextPrayer: TimeInterval = 0
    @Published public var calculationError: String?
    
    private let locationService: LocationService
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    public init(locationService: LocationService) {
        self.locationService = locationService
        setupLocationObserver()
        startTimer()
    }
    
    private func setupLocationObserver() {
        locationService.$location
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.calculatePrayerTimes(for: location)
            }
            .store(in: &cancellables)
    }
    
    private func calculatePrayerTimes(for location: CLLocation) {
        let coordinates = Coordinates(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        
        let date = Date()
        let calculationParameters = CalculationMethod.muslimWorldLeague.params
        
        do {
            let times = try PrayerTimes(
                coordinates: coordinates,
                date: date,
                calculationParameters: calculationParameters
            )
            
            DispatchQueue.main.async {
                self.prayerTimes = times
                self.updateNextPrayer()
                self.calculationError = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.calculationError = "Failed to calculate prayer times: \(error.localizedDescription)"
            }
        }
    }
    
    private func updateNextPrayer() {
        guard let prayerTimes = prayerTimes else { return }
        
        let now = Date()
        let prayers: [(Prayer, Date)] = [
            (.fajr, prayerTimes.fajr),
            (.dhuhr, prayerTimes.dhuhr),
            (.asr, prayerTimes.asr),
            (.maghrib, prayerTimes.maghrib),
            (.isha, prayerTimes.isha)
        ]
        
        // Find next prayer
        for (prayer, time) in prayers {
            if time > now {
                nextPrayer = prayer
                timeToNextPrayer = time.timeIntervalSince(now)
                return
            }
        }
        
        // If no prayer today, next is Fajr tomorrow
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        if let tomorrowCoordinates = locationService.coordinates {
            let coords = Coordinates(
                latitude: tomorrowCoordinates.latitude,
                longitude: tomorrowCoordinates.longitude
            )
            
            if let tomorrowTimes = try? PrayerTimes(
                coordinates: coords,
                date: tomorrow,
                calculationParameters: CalculationMethod.muslimWorldLeague.params
            ) {
                nextPrayer = .fajr
                timeToNextPrayer = tomorrowTimes.fajr.timeIntervalSince(now)
            }
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateNextPrayer()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - Public Methods
    public func getPrayerTime(for prayer: Prayer) -> Date? {
        guard let prayerTimes = prayerTimes else { return nil }
        
        switch prayer {
        case .fajr: return prayerTimes.fajr
        case .dhuhr: return prayerTimes.dhuhr
        case .asr: return prayerTimes.asr
        case .maghrib: return prayerTimes.maghrib
        case .isha: return prayerTimes.isha
        }
    }
    
    public func refreshPrayerTimes() {
        guard let location = locationService.location else {
            locationService.requestCurrentLocation()
            return
        }
        
        calculatePrayerTimes(for: location)
    }
}
```

### **3. Create NotificationService.swift**
Push notifications for prayer reminders:

```swift
import Foundation
import UserNotifications
import Combine

public class NotificationService: ObservableObject {
    @Published public var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published public var notificationsEnabled = false
    @Published public var notificationError: String?
    
    private let prayerTimeService: PrayerTimeService
    private var cancellables = Set<AnyCancellable>()
    
    public init(prayerTimeService: PrayerTimeService) {
        self.prayerTimeService = prayerTimeService
        checkAuthorizationStatus()
        setupPrayerTimeObserver()
    }
    
    public func requestNotificationPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            
            await MainActor.run {
                self.notificationsEnabled = granted
                self.notificationError = granted ? nil : "Notification permission denied"
            }
            
            if granted {
                await scheduleAllPrayerNotifications()
            }
        } catch {
            await MainActor.run {
                self.notificationError = error.localizedDescription
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                self.notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    private func setupPrayerTimeObserver() {
        prayerTimeService.$prayerTimes
            .compactMap { $0 }
            .sink { [weak self] _ in
                Task {
                    await self?.scheduleAllPrayerNotifications()
                }
            }
            .store(in: &cancellables)
    }
    
    private func scheduleAllPrayerNotifications() async {
        guard notificationsEnabled,
              let prayerTimes = prayerTimeService.prayerTimes else { return }
        
        // Cancel existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let prayers: [(Prayer, Date)] = [
            (.fajr, prayerTimes.fajr),
            (.dhuhr, prayerTimes.dhuhr),
            (.asr, prayerTimes.asr),
            (.maghrib, prayerTimes.maghrib),
            (.isha, prayerTimes.isha)
        ]
        
        for (prayer, time) in prayers {
            await scheduleNotification(for: prayer, at: time)
        }
    }
    
    private func scheduleNotification(for prayer: Prayer, at time: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Prayer Time"
        content.body = "It's time for \(prayer.displayName) prayer"
        content.sound = .default
        content.badge = 1
        
        // Add prayer-specific information
        content.userInfo = [
            "prayer": prayer.rawValue,
            "arabic_name": prayer.arabicName
        ]
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "prayer_\(prayer.rawValue)_\(time.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            await MainActor.run {
                self.notificationError = "Failed to schedule notification: \(error.localizedDescription)"
            }
        }
    }
    
    public func enableNotifications(for prayers: Set<Prayer>) async {
        // Store user preferences for which prayers to notify
        let prayerNames = prayers.map { $0.rawValue }
        UserDefaults.standard.set(prayerNames, forKey: "enabled_prayer_notifications")
        
        await scheduleAllPrayerNotifications()
    }
}
```

### **4. Create UserPreferencesService.swift**
iOS user settings and preferences:

```swift
import Foundation
import Combine

public class UserPreferencesService: ObservableObject {
    @Published public var preferredMadhab: Madhab = .sunni
    @Published public var notificationsEnabled = true
    @Published public var enabledPrayerNotifications: Set<Prayer> = Set(Prayer.allCases)
    @Published public var bookmarkedGuides: Set<String> = []
    @Published public var offlineGuides: Set<String> = []
    
    private let userDefaults = UserDefaults.standard
    
    public init() {
        loadPreferences()
        setupObservers()
    }
    
    private func loadPreferences() {
        // Load madhab preference
        if let madhabString = userDefaults.string(forKey: "preferred_madhab"),
           let madhab = Madhab(rawValue: madhabString) {
            preferredMadhab = madhab
        }
        
        // Load notification preferences
        notificationsEnabled = userDefaults.bool(forKey: "notifications_enabled")
        
        if let prayerNames = userDefaults.array(forKey: "enabled_prayer_notifications") as? [String] {
            enabledPrayerNotifications = Set(prayerNames.compactMap { Prayer(rawValue: $0) })
        }
        
        // Load bookmarks
        if let bookmarks = userDefaults.array(forKey: "bookmarked_guides") as? [String] {
            bookmarkedGuides = Set(bookmarks)
        }
        
        // Load offline guides
        if let offline = userDefaults.array(forKey: "offline_guides") as? [String] {
            offlineGuides = Set(offline)
        }
    }
    
    private func setupObservers() {
        $preferredMadhab
            .sink { [weak self] madhab in
                self?.userDefaults.set(madhab.rawValue, forKey: "preferred_madhab")
            }
            .store(in: &cancellables)
        
        $notificationsEnabled
            .sink { [weak self] enabled in
                self?.userDefaults.set(enabled, forKey: "notifications_enabled")
            }
            .store(in: &cancellables)
        
        $enabledPrayerNotifications
            .sink { [weak self] prayers in
                let prayerNames = prayers.map { $0.rawValue }
                self?.userDefaults.set(prayerNames, forKey: "enabled_prayer_notifications")
            }
            .store(in: &cancellables)
        
        $bookmarkedGuides
            .sink { [weak self] bookmarks in
                self?.userDefaults.set(Array(bookmarks), forKey: "bookmarked_guides")
            }
            .store(in: &cancellables)
        
        $offlineGuides
            .sink { [weak self] offline in
                self?.userDefaults.set(Array(offline), forKey: "offline_guides")
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Methods
    public func toggleBookmark(for guideId: String) {
        if bookmarkedGuides.contains(guideId) {
            bookmarkedGuides.remove(guideId)
        } else {
            bookmarkedGuides.insert(guideId)
        }
    }
    
    public func isBookmarked(_ guideId: String) -> Bool {
        return bookmarkedGuides.contains(guideId)
    }
    
    public func toggleOfflineAvailability(for guideId: String) {
        if offlineGuides.contains(guideId) {
            offlineGuides.remove(guideId)
        } else {
            offlineGuides.insert(guideId)
        }
    }
    
    public func isAvailableOffline(_ guideId: String) -> Bool {
        return offlineGuides.contains(guideId)
    }
    
    public func resetToDefaults() {
        preferredMadhab = .sunni
        notificationsEnabled = true
        enabledPrayerNotifications = Set(Prayer.allCases)
        bookmarkedGuides.removeAll()
        offlineGuides.removeAll()
    }
}
```

## 🔗 **Dependencies & Coordination**

### **You Enable:**
- **Complete iOS experience** with location-based prayer times
- **Push notifications** for prayer reminders
- **User preferences** and personalization
- **Offline functionality** and bookmarking

### **You Depend On:**
- **Engineer 1**: Needs iOS project with proper capabilities configured
- **Engineer 2**: Needs Prayer and Madhab models
- **Engineer 3**: Needs SupabaseService for data integration
- **Engineer 4**: Views will use your services for functionality

### **Coordination Points:**
- **With Engineer 1**: Ensure location and notification capabilities are enabled
- **With Engineer 2**: Use proper model types and enums
- **With Engineer 4**: Provide @Published properties for SwiftUI binding

## ⚠️ **Critical Requirements**

### **iOS Permissions:**
1. **Location Services**: Must request and handle location permissions
2. **Push Notifications**: Must request notification permissions
3. **Background App Refresh**: Handle app lifecycle properly
4. **Privacy**: Respect user privacy and permission choices

### **Islamic Accuracy:**
1. **Prayer Time Calculations**: Use proper calculation methods
2. **Location Accuracy**: Ensure accurate coordinates for prayer times
3. **Timezone Handling**: Handle timezone changes correctly

## ✅ **Acceptance Criteria**

### **Must Have:**
- [ ] Location services working with proper permissions
- [ ] Prayer time calculations accurate using Adhan library
- [ ] Push notifications scheduled for prayer times
- [ ] User preferences persist across app launches
- [ ] Bookmark and offline functionality working

### **Should Have:**
- [ ] Background app refresh handling
- [ ] Proper error handling for all services
- [ ] Timezone change detection
- [ ] Battery-efficient location updates

### **Nice to Have:**
- [ ] Haptic feedback for interactions
- [ ] Accessibility support
- [ ] Widget preparation
- [ ] Share functionality

## 🚀 **Success Validation**
1. **Location Test**: App requests and receives location permissions
2. **Prayer Time Test**: Accurate prayer times calculated for current location
3. **Notification Test**: Prayer notifications scheduled correctly
4. **Preferences Test**: User settings persist and work correctly

**Estimated Time**: 8-10 hours
**Priority**: MEDIUM - Enhances the core app experience
