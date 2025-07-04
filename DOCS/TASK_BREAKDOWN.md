# Parallel Task Breakdown for Agentic Build System - REVISION 2

## Change Summary
**CRITICAL FIX:** Eliminated SystemServices bottleneck by moving to protocol-first architecture. All agents now work against shared interfaces defined in a lightweight protocols module, enabling true parallel execution.

## Phase 1: Protocols Definition (Day 1)
**Single responsibility:** Define all service protocols in shared module.

| Task | Owner | Output |
|------|-------|--------|
| Define `LocationServiceProtocol`, `NotificationServiceProtocol`, `PermissionManagerProtocol` | `agent-protocols` | Swift protocols module |

## Phase 2: Parallel Development (Day 2+)
**True parallel execution:** All agents work simultaneously against protocol mocks.

| Stream | Tasks | Owner Agent | Dependencies |
|--------|-------|-------------|--------------|
| **CoreLib** | Implement PrayerTimeCalculator wrapper around AdhanSwift; Write unit tests (city fixtures); Mock LocationServiceProtocol | `agent-prayer-core` | Protocols module only |
| **Qibla** | Build QiblaDirectionService (sensor fusion); Design CompassView; Mock location & motion protocols | `agent-qibla` | Protocols module only |
| **Content** | Set up Supabase bucket; Write ingestion script to convert Markdown + MP4 to JSON manifest for native guides | `agent-content` | none |
| **UI/UX** | Create SwiftUI flows: Onboarding, Home, Compass, Guides; Build against protocol mocks | `agent-ui` | Protocols module only |
| **Notifications** | Schedule UNUserNotification triggers using NotificationServiceProtocol mock | `agent-notify` | Protocols module only |
| **System Implementation** | Implement concrete LocationService, NotificationService, PermissionManager | `agent-system` | Protocols module only |
| **Testing** | UI tests via XCUITest; snapshot tests | `agent-test` | All feature streams |
| **DevOps** | Configure GitHub Actions, Fastlane lanes: test, beta, release | `agent-devops` | All artifacts |
| **Compliance** | Automate licence scan, privacy-policy generator | `agent-legal` | Dependency list |

## Phase 3: Integration (Day 5+)
Replace protocol mocks with concrete implementations via dependency injection.

**Key Benefit:** No agent blocks another. If SystemServices is delayed, other agents continue with mocks until integration phase.