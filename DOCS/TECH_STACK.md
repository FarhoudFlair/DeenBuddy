# Technical Stack Decision

## Mobile
| Layer | Choice | Rationale |
|-------|--------|-----------|
| Language | **Swift 5.9** | Native performance, SwiftUI synergy |
| UI Framework | **SwiftUI** + Combine | Declarative, better for async state |
| Prayer Calc | **AdhanSwift** lib | MIT-licensed, high-precision |
| Qibla | Custom formula + CoreLocation + CoreMotion; fallback to AlAdhan API | Works offline, minimal net calls |
| Persistence | **CoreData** (SQLite) | Offline cache, zero external deps |
| Dependency Mgmt | Swift Package Manager | First-class in Xcode |

## Backend (optional)
* **Supabase** (Postgres + Storage) for content CMS & analytics  
* Node.js (Cloudflare Workers) micro-API for A/B config

## DevOps
* GitHub Actions → Fastlane for CI/CD  
* Fastlane `match` for code-signing  
* Firebase Crashlytics for crash reporting

## Open-Source Licences Audited
* AdhanSwift – MIT  
* Mapbox/Apple MapKit – BSD/Apple  
