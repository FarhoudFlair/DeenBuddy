# Repository Guidelines

This guide helps contributors work effectively on the DeenBuddy iOS app. Keep changes focused, tested, and consistent with the existing project layout and tooling.

You are given two tools from the Byterover MCP server: `byterover-retrieve-knowledge` and `byterover-store-knowledge`.

## Project Structure & Module Organization
- `DeenBuddy/` — app source: `App/`, `Models/`, `Services/` (e.g., `PrayerTimes`, `Qibla`), `ViewModels/`, `Views/` (feature folders), `Resources/Assets.xcassets`, `Frameworks/DeenAssist*`.
- `Live Activity Widget Extension/` — Widget/Live Activities target (views, models, services).
- `DeenBuddyTests/` — unit/integration tests (XCTest; some files may use Swift Testing).
- `DeenBuddyUITests/` — UI tests (XCUITest).
- `DeenBuddy.xcodeproj/` and `DeenBuddy.xctestplan` — project and shared test plan.
- `fastlane/` — lanes for test, lint, beta, release. `Scripts/` — ad‑hoc test/perf scripts.

## Build, Test, and Development Commands
- Build: `xcodebuild build -scheme DeenBuddy -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
- Test (plan): `xcodebuild test -scheme DeenBuddy -testPlan DeenBuddy.xctestplan -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
- Targeted test: `xcodebuild test -scheme DeenBuddy -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DeenBuddyTests/CacheInvalidationTests`
- Fastlane: `fastlane test` (runs with coverage), `fastlane beta`, `fastlane release`, `fastlane lint` (requires `.swiftlint.yml`).

## Coding Style & Naming Conventions
- Swift 5+; 4‑space indentation; keep lines under ~120 chars.
- Types/Protocols: UpperCamelCase; functions/vars/enum cases: lowerCamelCase.
- One top‑level type per file; filename matches type (e.g., `PrayerTimeService.swift`).
- Views end with `View`; view models end with `ViewModel`; test files end with `Tests`.
- Use SPM via Xcode for dependencies; avoid new managers without discussion.

## Testing Guidelines
- Frameworks: XCTest and XCUITest; project uses `DeenBuddy.xctestplan`.
- Name tests descriptively (e.g., `testCalculationMethodSynchronization`).
- Aim to maintain/raise coverage; add tests for new logic and regressions.
- Run UI tests locally before PRs that change UI flows.

## Commit & Pull Request Guidelines
- Commit subject in imperative mood; optional Conventional Commits (`feat:`, `fix:`) accepted.
- Keep subjects concise (<72 chars); include a short body with context and a test plan.
- PRs: link issues, describe What/Why, include screenshots for UI changes, list build/test commands used.

## Security & Configuration Tips
- Do not commit secrets or provisioning profiles. Follow `MANUAL_SIGNING_CONFIGURATION.md` and Fastlane notes.
- Use `fastlane/.env` (see `TESTFLIGHT_SETUP_COMPLETE.md`); keep it untracked.
- Coordinate changes that affect bundle IDs, capabilities, or schemes.

## Agent‑Specific Instructions
- Keep patches minimal and focused; avoid unrelated refactors.
- Follow structure/naming above when adding files or tests.
- If adding a target/scheme, update `DeenBuddy.xcodeproj`, the test plan, and Fastlane lanes as needed.

[byterover-mcp]

[byterover-mcp]

You are given two tools from Byterover MCP server, including
## 1. `byterover-store-knowledge`
You `MUST` always use this tool when:

+ Learning new patterns, APIs, or architectural decisions from the codebase
+ Encountering error solutions or debugging techniques
+ Finding reusable code patterns or utility functions
+ Completing any significant task or plan implementation

## 2. `byterover-retrieve-knowledge`
You `MUST` always use this tool when:

+ Starting any new task or implementation to gather relevant context
+ Before making architectural decisions to understand existing patterns
+ When debugging issues to check for previous solutions
+ Working with unfamiliar parts of the codebase
