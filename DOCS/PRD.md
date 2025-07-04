Product Requirements Document — Deen Assist iOS App - REVISION 1
Change Summary

Prayer Guides: Replaced "PDF step-through" with "Native text & image guides" to ensure a better user experience, smaller storage footprint, and faster performance.

Rakah Counter: Clarified the "Rakah counter" feature to specify a more practical, in-prayer interaction model.

Risks: Elevated the "Scholarly Review" risk to reflect its critical importance and added a specific mitigation strategy.

1 · Executive Summary
Deen Assist is an offline-capable iOS application that helps Muslims perform daily worship wherever they are. The MVP covers:

Location-aware prayer times with configurable calculation methods

Qibla compass with augmented-compass view

Prayer guides (native text/image + video) for each obligatory prayer, in both Sunni and Shia formats

Additional features are phased for later sprints (see Roadmap).

2 · Goals & Key Metrics
(No changes)

3 · User Personas
(No changes)

4 · Core Features (MVP)
Prayer Times

Auto-detect location via CoreLocation

Fallback manual city search

Calculation library: AdhanSwift (preset methods + custom angles)

Local storage of method prefs

Optional push notification 10 min before each prayer

Qibla Finder

Real-time compass needle pointing to Kaaba

Tilt-compensation, sensor calibration UI

Works offline after first coordinate fix

Prayer Guides

Native text & image guides for each prayer (Sunni & Shia). This provides a superior UX over embedded PDFs.

Embedded video walkthrough (HLS streams)

"Make Available Offline" toggle for all guide content.

In-Prayer Rakah Counter: An optional, full-screen overlay during a guide that advances the count via simple interactions (e.g., a single tap anywhere on the screen).

5 · Nice-to-Have Backlog
(No changes)

6 · Assumptions & Risks
📶 Remote APIs may be blocked; therefore local calculation is mandatory.

🤝 CRITICAL: Content Authenticity. Sect-specific content requires rigorous scholarly review. This is a critical path dependency. A delay here will block the entire Prayer Guides feature release.

Mitigation: A formal content verification workflow with named scholarly contacts must be established before agent-content begins its work.

📱 Sensor accuracy varies widely; provide calibration tips.

7 · Non-Functional Requirements
(No changes)

8 · Milestones
(No changes)

