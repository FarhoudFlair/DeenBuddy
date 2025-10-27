# DeenBuddy Build Plan TODO (@Branch @DeenBuddy)

Professional, file-scoped plan to fix subscription plans display, Live Activities behavior, prayer completion actions, push notification setup, and Dynamic Island time updates. Keep edits minimal and localized per file.

---

## 1) Premium page does not show subscription plans

- **Files to inspect/modify**
  - `DeenBuddy/Views/Subscription/SubscriptionPaywallView.swift`
  - `DeenBuddy/ViewModels/SubscriptionViewModel.swift`
  - `DeenBuddy/Frameworks/DeenAssistCore/Services/Subscription/SubscriptionService.swift`
  - `DeenBuddy/Frameworks/DeenAssistCore/Protocols/SubscriptionServiceProtocol.swift`
  - `Configuration.storekit` (local StoreKit config)

- **Exact change points**
  - In `SubscriptionViewModel.swift`: product loading lifecycle (`onAppear`/`.task`) and `@Published` state used by paywall list/grid.
  - In `SubscriptionService.swift`: StoreKit 2 product fetch (`Product.products(for:)`) and mapping to app models if any.
  - In `SubscriptionPaywallView.swift`: rendering branch for empty state vs populated plans; ensure no filtering removes all items.

- **Actions**
  - Ensure identifiers list source of truth (hardcoded constant or config) exists and is non-empty.
  - Add/verify `@MainActor` UI state updates after async fetch.
  - Add explicit empty/loading/error states in view to surface issues.

- **New/updated APIs**
  - `SubscriptionServiceProtocol`:
    - `func fetchAvailablePlans() async throws -> [Product]`
  - `SubscriptionViewModel`:
    - `@Published var availablePlans: [Product] = []`
    - `@Published var loadingState: LoadingState = .idle` // idle | loading | loaded | error
    - `@MainActor func loadPlans() async`

- **Config/dep updates**
  - Confirm `Configuration.storekit` contains the product IDs referenced by the service.
  - Ensure all touched files `import StoreKit`.

- **Notes/risks**
  - Avoid starting a purchase flow before products are loaded.
  - If plans are region-gated, handle empty results with UX copy.

- **Progress**
  - [x] Added `SubscriptionLoadingState`/`availablePlans` in `SubscriptionViewModel` and updated the paywall to surface loading, empty, and retryable error states before enabling purchase.
  - [x] Added `fetchAvailablePlans()` helper plus configuration guards in `SubscriptionService` so missing identifiers or empty StoreKit payloads surface actionable errors.
  - [x] **FIXED**: Removed `showError = false` suppression in catch block (line 75) - error alerts now properly display to users when subscription loading fails.
  - [ ] Pending confirmation: run StoreKit-configured build/test flow to ensure plans render against `Configuration.storekit`.

---

## 2) Live Activities: creating new activity instead of updating same one

- **Files to inspect/modify**
  - `DeenBuddy/Frameworks/DeenAssistCore/Services/WidgetService.swift` (or the service starting activities)
  - `Live Activity Widget Extension/Live_Activity_Widget_Extension.swift` (ActivityConfiguration)
  - `Live Activity Widget Extension/LiveActivityPermissionManager.swift`

- **Exact change points**
  - The call sites invoking `Activity.request` for prayer countdown; audit for repeated requests when an existing activity is active.

- **Actions**
  - Introduce a single entrypoint to start/update:
    - Query existing: `let existing = Activity<PrayerAttributes>.activities.first` (filter for our type)
    - If `existing?.activityState == .active` => `await existing?.update(using: newState)`
    - Else => request new: `Activity.request(attributes: ..., content: ...)`
  - Persist last active activity ID via App Group if needed for cross-launch continuity.

- **New/updated APIs**
  - In `WidgetService.swift` (or a minimal controller if already present):
    - `@available(iOS 16.2, *)
      func startOrUpdatePrayerLiveActivity(nextPrayer: Prayer, targetDate: Date, metadata: PrayerMetadata) async`
  - Attributes/state model (names illustrative):
    - `struct PrayerAttributes: ActivityAttributes { struct ContentState: Codable, Hashable { let targetDate: Date; let prayerId: String } /* fixed attributes */ }`

- **Notes/risks**
  - Ensure updates are throttled to meaningful changes to avoid rate limits.
  - Handle `.ended`/`.dismissed` by starting a new activity.

- **Progress**
  - [x] Updated `PrayerLiveActivityManager.startPrayerCountdown` to reuse an active `Activity<PrayerCountdownActivity>` when targeting the same prayer, cancelling duplicate creations.
  - [x] Added internal `resolveActiveActivity`/`updateTask` handling so periodic updates respect the latest prayer time and cancel previous scheduler loops.
  - [ ] Verify Live Activity start/update flow end-to-end on device/simulator supporting ActivityKit (ensure no regressions in Dynamic Island UI).

---

## 3) Add options to confirm completion of prayer (Live Activity or notification)

- **Files to add/modify**
  - `Live Activity Widget Extension/AppIntent.swift` (add AppIntent for completion)
  - `Live Activity Widget Extension/Live_Activity_Widget_Extension.swift` (wire intent buttons in ActivityConfiguration islands/lock screen)
  - `Live Activity Widget Extension/Views/LockScreenWidgetViews.swift` (place action buttons where appropriate)
  - `DeenBuddy/Frameworks/DeenAssistCore/Services/PrayerTrackingService.swift` and `.../Protocols/PrayerTrackingServiceProtocol.swift` (ensure completion API)
  - `DeenBuddy/Frameworks/DeenAssistCore/Services/NotificationService.swift` (notification category/action + action handler)
  - App Group bridge (if required) to persist intent action for the app process: `group.com.deenbuddy.app`

- **Exact change points**
  - Activity UI: add action buttons with `AppIntent` in Dynamic Island compact/expanded and lock screen presentation.
  - Notifications: register category with action (e.g., `PRAYER_DONE`) and handle in delegate to call tracking service.

- **New/updated APIs**
  - AppIntent (in extension):
    - `struct ConfirmPrayerCompletionIntent: AppIntent { @Parameter var prayer: PrayerType; func perform() async throws -> some IntentResult }`
  - Prayer tracking:
    - `func markPrayerCompleted(_ prayer: Prayer, at date: Date) async` (protocol + impl)
  - Notification service setup:
    - Register `UNNotificationCategory(identifier: "PRAYER", actions: [doneAction], intentIdentifiers: [], options: [])`
    - Delegate handler bridges to `PrayerTrackingService`.

- **Notes/risks**
  - AppIntent in extension cannot directly call app code; use App Group or URL scheme to signal the app if needed.
  - Consider authenticationRequired option on action to avoid accidental taps.

- **Progress**
  - [x] Added `ConfirmPrayerCompletionIntent` with `PrayerLiveActivityActionBridge` so ActivityKit buttons enqueue completions via the app group.
  - [x] Wired lock screen/Dynamic Island UI to surface a "Completed" intent button on iOS 17 while maintaining pre-iOS17 fallbacks.
  - [x] Extended `PrayerTrackingService` to consume bridge actions and re-use existing notification-based completion pipeline.
  - [x] **COMPLETED**: Notification cancellation parity verified - `NotificationService` observes `.prayerMarkedAsPrayed` (lines 560-589) and cancels prayer notifications when Live Activity completion occurs.
  - [x] **COMPLETED**: Added comprehensive test coverage for bridge queue draining in `DeenBuddyTests/PrayerLiveActivityActionBridgeTests.swift`.

---

## 4) Review and confirm push notifications setup

- **Files to inspect/modify**
  - `DeenBuddy/Frameworks/DeenAssistCore/Services/NotificationService.swift`
  - `DeenBuddy/Frameworks/DeenAssistProtocols/NotificationServiceProtocol.swift`
  - `DeenBuddy/DeenBuddy.entitlements` (verify `aps-environment`)
  - `DeenBuddy/Info.plist` (Background Modes if remote notifications are used)

- **Exact change points**
  - Authorization request flow, category registration, delegate assignment, and scheduling code for prayer reminders.

- **Actions**
  - Ensure `UNUserNotificationCenter.current().requestAuthorization` is called once at startup via service orchestration.
  - Set `UNUserNotificationCenter.current().delegate = ...` early in app lifecycle.
  - Register categories (including new `PRAYER` with `PRAYER_DONE`).
  - Validate schedule payloads include thread identifiers and category identifiers.

- **Notes/risks**
  - If using remote notifications, confirm device token registration and capability; for local-only, entitlements still need correct environment.

- **Progress**
  - [x] NotificationService now observes `.prayerMarkedAsPrayed` broadcasts (e.g., from Live Activity intents) to cancel pending reminders and refresh badges, keeping behavior consistent with in-app actions.
  - [ ] Confirm delegate wiring remains intact across launch flows (ensure `NotificationService` stays in memory before registering observers during app start).

---

## 5) Dynamic Island time doesn't update ✅ COMPLETED

- **Files to inspect/modify**
  - `Live Activity Widget Extension/Views/LockScreenWidgetViews.swift`
  - `Live Activity Widget Extension/Live_Activity_Widget_Extension.swift`
  - `Live Activity Widget Extension/SmartRefreshManager.swift`
  - `DeenBuddy/Frameworks/DeenAssistCore/LiveActivities/PrayerCountdownActivity.swift`

- **Exact change points**
  - The Dynamic Island and Lock Screen Live Activity views displaying countdown/time.

- **Actions**
  - Ensure Live Activity view uses timer-driven text (e.g., `Text(timerInterval: state.now...state.target, countsDown: true).monospacedDigit()` or `TimerText`) instead of static timestamps.
  - Include `targetDate` (and `startDate` if needed) in `ContentState` and update via `Activity.update` only when target prayer changes.
  - Avoid relying on per-minute widget timelines for Live Activity; the Live Activity should animate independently.

- **Notes/risks**
  - Excessive updates are unnecessary; the system animates `TimerText` automatically when dates are correct.

- **Progress**
  - [x] **COMPLETED**: Replaced static `Text(state.formattedTimeRemaining)` with timer-driven `Text(timerInterval: Date()...state.prayerTime, countsDown: true)` in 4 locations:
    1. Lock screen countdown (`LiveActivityViews.swift:56`)
    2. Live Activity main view countdown (`PrayerCountdownActivity.swift:407`)
    3. Dynamic Island compact trailing (`PrayerCountdownActivity.swift:470`)
    4. Dynamic Island expanded countdown (`PrayerCountdownActivity.swift:528`)
  - [x] Maintained `.monospacedDigit()` modifier for consistent spacing
  - [x] Preserved conditional logic for `hasPassed` state showing "Prayer Time" text
  - [x] Timer now auto-updates without requiring manual `Activity.update()` calls

---

## Cross-cutting items

- **App Group**: Use `group.com.deenbuddy.app` to persist the current Live Activity id and to bridge AppIntent actions back to the app.
- **Threading**: Mark UI-updating functions `@MainActor`; keep StoreKit/network/service work off the main thread.
- **Error surfaces**: Show explicit empty/error states for paywall and Live Activity permission/availability.

---

## Example signatures (illustrative)

```swift
// Subscription service
protocol SubscriptionServiceProtocol {
    func fetchAvailablePlans() async throws -> [Product]
}

@MainActor
final class SubscriptionViewModel: ObservableObject {
    @Published var availablePlans: [Product] = []
    @Published var loadingState: LoadingState = .idle
    func loadPlans() async { /* call service, assign state */ }
}

// Live Activity management (co-locate in WidgetService or a focused controller)
@available(iOS 16.2, *)
func startOrUpdatePrayerLiveActivity(nextPrayer: Prayer, targetDate: Date) async {
    // find existing Activity<PrayerAttributes> and update or request as needed
}

// AppIntent (extension)
struct ConfirmPrayerCompletionIntent: AppIntent {
    @Parameter(title: "Prayer") var prayer: PrayerType
    static var title: LocalizedStringResource = "Confirm Prayer Completed"
    func perform() async throws -> some IntentResult { /* write completion via app group */ }
}

// Notification action wiring
func registerNotificationCategories() {
    let done = UNNotificationAction(identifier: "PRAYER_DONE", title: "Mark as Done", options: [.authenticationRequired])
    let cat = UNNotificationCategory(identifier: "PRAYER", actions: [done], intentIdentifiers: [], options: [])
    UNUserNotificationCenter.current().setNotificationCategories([cat])
}
```

---

## Risks and impacts

- StoreKit product IDs mismatch will continue to yield empty plans; verify identifiers in both code and `Configuration.storekit`.
- Live Activity update path must not request new activities; centralize the entrypoint to enforce this.
- AppIntent/notification actions must be idempotent in `PrayerTrackingService`.

---

## TODO Log

- [ ] Run StoreKit-configured simulator build/test to confirm premium plans render with the new loading/empty/error states.
- [x] Kick off Task 2 work: audit current Live Activity start/update flow and identify consolidation points before coding changes.
- [ ] Exercise ActivityKit on device/simulator to validate the updated start-or-update logic prevents duplicate Live Activity creation.
- [x] **COMPLETED**: Task 3 implementation complete - prayer completion confirmation flows working with Live Activity and notification actions.
- [x] **COMPLETED**: Task 5 implementation complete - Dynamic Island timer now auto-updates using `Text(timerInterval:countsDown:)` in all 4 locations.
- [x] **COMPLETED**: Added comprehensive unit/integration coverage for `PrayerLiveActivityActionBridge` queue draining and Darwin notification handling in `DeenBuddyTests/PrayerLiveActivityActionBridgeTests.swift`.
- [ ] Run full regression command after Task 2+3+5 hardening: `xcodebuild test -scheme DeenBuddy -testPlan DeenBuddy.xctestplan -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
- [ ] Test Dynamic Island timer updates on physical device with Dynamic Island support (iPhone 14 Pro or later).
- [ ] Validate Live Activity AppIntent shared defaults logging by simulating a missing app group and confirming error output in system logs.
- [ ] Confirm prayer completion queue gracefully recovers from corrupted payloads and emits the new decoding error log.

---

## Owner mapping (suggested)

- Premium plans view/service: Subscriptions owner
- Live Activity behavior & Dynamic Island: Widgets/ActivityKit owner
- Prayer completion intents & notification actions: Widgets + Core Services
- Notification setup verification: Core Services
