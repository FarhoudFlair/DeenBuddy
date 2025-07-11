# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DeenBuddy is an iOS application that helps Muslims perform daily worship with prayer times, Qibla direction, and prayer guides. The project follows a modular architecture with Swift Package Manager and includes both iOS app code and a Node.js content management pipeline.

## Development Commands

### iOS Development
```bash
# Open the iOS project in Xcode
open DeenBuddy-iOS-Xcode-App/DeenBuddy.xcodeproj

# Run tests via Fastlane
fastlane test

# Build for development
fastlane build_dev

# Deploy to TestFlight
fastlane beta

# Deploy to App Store
fastlane release

# Run SwiftLint
fastlane lint

# Setup code signing
fastlane setup_signing
```

### Swift Package Development
```bash
# Build Swift packages
swift build

# Run tests for Swift packages
swift test

# Test specific package
cd QiblaKit && swift test
```

### Content Pipeline
```bash
# Navigate to content pipeline
cd content-pipeline

# Install dependencies
npm install

# Validate content
npm run validate

# Test content ingestion (dry run)
npm run ingest -- --dry-run --verbose

# Sync with Supabase
npm run sync

# Check pipeline status
npm start status
```

## Architecture

### High-Level Structure
The project uses a protocol-first architecture enabling parallel development:

```
DeenBuddy/
├── DeenBuddy-iOS-Xcode-App/          # Main iOS Xcode project
├── Sources/                          # Swift Package Manager modules
│   ├── DeenAssistCore/              # Core business logic and services
│   ├── DeenAssistProtocols/         # Service protocols for dependency injection
│   └── DeenAssistUI/                # SwiftUI components and design system
├── QiblaKit/                        # Standalone Qibla calculation package
├── content-pipeline/                # Node.js content management system
└── Tests/                           # Unit and integration tests
```

### Core Components

#### DeenAssistCore
- **Location Services**: CoreLocation-based location detection with caching
- **API Client**: AlAdhan API integration with offline fallback
- **Prayer Time Service**: Prayer calculation using Adhan library
- **Notification Service**: Prayer reminders with customizable settings
- **Supabase Service**: Content management and data synchronization
- **Configuration Manager**: App settings and user preferences

#### DeenAssistUI
- **Design System**: Colors, typography, and themes (Light/Dark/System)
- **Components**: Reusable UI elements (cards, buttons, loading states)
- **Screens**: Complete onboarding flow and main app screens
- **Navigation**: App coordinator with deep linking support

#### QiblaKit
- Standalone Swift package for Qibla calculations
- High-precision bearing calculations using great circle formulas
- Magnetic declination support for compass correction

### Key Dependencies
- **Adhan Swift**: Prayer time calculations
- **Supabase Swift**: Backend integration
- **Composable Architecture**: State management
- **SwiftUI + Combine**: UI framework

## Testing Strategy

### Unit Tests
- Service protocols have comprehensive mock implementations
- Critical business logic is extensively tested
- QiblaKit has 15+ test cases covering global cities and edge cases

### Running Tests
```bash
# Run all iOS tests
fastlane test

# Run Swift package tests
swift test

# Run content pipeline tests
cd content-pipeline && npm test

# Run QiblaKit tests specifically
cd QiblaKit && swift test
```

## Development Workflow

### Feature Development
1. Create feature branch from `main`
2. Implement changes using protocol-first approach
3. Add/update tests
4. Run `fastlane lint` to check code style
5. Run `fastlane test` to verify tests pass
6. Submit PR (triggers CI/CD pipeline)

### Content Updates
1. Edit Markdown files in `content-pipeline/content/`
2. Run `npm run validate` to check content structure
3. Test with `npm run ingest -- --dry-run`
4. Deploy with `npm run ingest`

### Release Process
1. Update version: `fastlane release`
2. Create GitHub release
3. Submit to App Store via App Store Connect

## Code Conventions

### Swift Code Style
- Follow Swift API Design Guidelines
- Use protocol-first architecture for testability
- Prefer dependency injection over singletons
- Use meaningful error types and comprehensive error handling
- Follow existing patterns in the codebase

### File Organization
- Models in `Models/` directories
- Services in `Services/` directories
- Views in `Views/` directories with subdirectories by feature
- ViewModels alongside their corresponding views
- Protocols in dedicated `Protocols/` directories

### Testing Patterns
- Use mock implementations for all external dependencies
- Test business logic separately from UI
- Use descriptive test names that explain expected behavior
- Group related tests in test suites

## Important Notes

### Parallel Development
The project was designed for parallel development by multiple engineers:
- Protocol-first architecture enables independent development
- Mock services allow UI development without backend dependencies
- Modular structure supports concurrent feature development

### Offline-First Design
- All core functionality works without internet connection
- Location and prayer times are cached locally
- Content is synchronized in background when available

### Security Considerations
- No personal data is collected or stored
- All user preferences stored locally in CoreData
- Location used only for calculations, never transmitted
- Secure API communication with Supabase

## Content Management

### Structure
Content is managed through a Node.js pipeline that converts Markdown files to JSON and syncs with Supabase:

```markdown
---
contentId: fajr_sunni_guide
title: Fajr Prayer Guide (Sunni)
prayerName: fajr
sect: sunni
rakahCount: 2
---

# Prayer Guide Content
...
```

### Database Schema
Prayer guides are stored in Supabase with JSONB content structure for flexible content management.

## CI/CD Pipeline

### GitHub Actions
- Automated iOS build and test
- Content validation
- SwiftLint code quality checks
- Multi-platform support (iOS, macOS, watchOS, tvOS)

### Fastlane Integration
- Development, beta, and release build lanes
- Automated version bumping
- TestFlight and App Store deployment
- Screenshot generation for App Store

## Environment Setup

### Prerequisites
- Xcode 15.2+
- iOS 15.0+ deployment target
- Node.js 20+ (for content pipeline)
- Supabase account (for content management)
- Fastlane (for build automation)

### Getting Started
1. Clone repository
2. Set up content pipeline: `cd content-pipeline && npm install`
3. Configure Supabase credentials in content-pipeline/.env
4. Open iOS project in Xcode
5. Build and run on simulator or device[byterover-mcp]

# important 
always use byterover-retrive-knowledge tool to get the related context before any tasks 
always use byterover-store-knowledge to store all the critical informations after sucessful tasks