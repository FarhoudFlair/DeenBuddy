# Agent Master Plan

1. **Bootstrap**  
   * `agent-devops` generates project with Xcode 15 template, adds SwiftLint, Sourcery.  
2. **Parallel Execution**  
   * `agent-prayer-core` & `agent-qibla` work concurrently; mock services provided via protocols.  
   * `agent-ui` builds with protocol mocks to avoid tight coupling.  
3. **Integration Phase**  
   * Feature branches merged into `develop`; Xcode‐build runs unit + UI tests.  
4. **Beta Phase**  
   * Fastlane uploads TestFlight build, invites QA group.  
5. **Release**  
   * Tag v1.0.0 → `main` → notarization → App Store Connect submit.  
6. **Post-Launch Automation**  
   * `agent-devops` sets weekly cron to pull updated guide content, trigger metadata submit if size changes.  
