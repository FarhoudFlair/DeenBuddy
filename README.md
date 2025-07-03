# DeenBuddy - Islamic Prayer Companion iOS App

[![iOS Build](https://github.com/FarhoudFlair/DeenBuddy/actions/workflows/ios-build.yml/badge.svg)](https://github.com/FarhoudFlair/DeenBuddy/actions/workflows/ios-build.yml)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![iOS 15.0+](https://img.shields.io/badge/iOS-15.0+-blue.svg)](https://developer.apple.com/ios/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

DeenBuddy is an offline-capable iOS application that helps Muslims perform daily worship wherever they are. The app provides accurate prayer times, Qibla direction, and comprehensive prayer guides for both Sunni and Shia traditions.

## 🌟 Features

### Core Features (MVP)
- **Prayer Times**: Location-aware prayer times with configurable calculation methods
- **Qibla Compass**: Real-time compass with augmented view pointing to Kaaba
- **Prayer Guides**: Native text & image guides with video walkthroughs for each prayer
- **Offline Support**: Works completely offline after initial setup
- **Dual Tradition Support**: Separate guides for Sunni and Shia practices

### Advanced Features
- **Interactive Rakah Counter**: Full-screen overlay during prayer with tap-to-advance
- **Smart Notifications**: Configurable alerts 10 minutes before each prayer
- **Multiple Calculation Methods**: Support for various Islamic calculation methods
- **Sensor Fusion**: Advanced compass with tilt compensation and calibration
- **Content Management**: Automated content updates and offline caching

## 🏗️ Architecture

The app follows a clean, modular architecture with protocol-first design:

```
├── iOS App (SwiftUI + Combine)
│   ├── Views & ViewModels
│   ├── Domain Layer
│   └── Data Layer (CoreData + Network)
├── QiblaKit (Standalone Swift Package)
├── Content Pipeline (Node.js)
└── CI/CD (GitHub Actions + Fastlane)
```

## 🚀 Getting Started

### Prerequisites
- Xcode 15.2+
- iOS 15.0+ deployment target
- Node.js 20+ (for content pipeline)
- Supabase account (for content management)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/FarhoudFlair/DeenBuddy.git
   cd DeenBuddy
   ```

2. **Set up content pipeline**
   ```bash
   cd content-pipeline
   npm install
   cp .env.example .env
   # Edit .env with your Supabase credentials
   ```

3. **Test content pipeline**
   ```bash
   npm run validate
   npm run ingest -- --dry-run
   ```

4. **Set up iOS project** (when created)
   ```bash
   # Install Fastlane
   gem install fastlane
   
   # Set up code signing
   fastlane setup_signing
   ```

## 📱 Current Implementation Status

### ✅ Completed (Engineer 4 Work)

#### Content Management Infrastructure
- **Supabase Database**: Complete schema for prayer guides with JSONB content storage
- **Content Pipeline**: Node.js-based ingestion system for Markdown → JSON conversion
- **Sample Content**: Working examples of Fajr and Asr prayer guides
- **CLI Tools**: Command-line interface for content management and validation

#### Qibla Calculation Engine
- **QiblaKit**: Standalone Swift package with high-precision calculations
- **Great Circle Formulas**: Accurate bearing and distance calculations
- **Magnetic Declination**: Support for compass correction
- **Comprehensive Tests**: 15+ test cases covering global cities and edge cases

#### CI/CD Pipeline
- **GitHub Actions**: Automated iOS build, test, and content validation
- **Fastlane**: Complete lanes for development, beta, and release builds
- **Code Quality**: SwiftLint integration and automated testing
- **Multi-platform**: Support for iOS, macOS, watchOS, and tvOS

### 🔄 In Progress (Other Engineers)
- iOS Xcode project setup (Engineer 1)
- CoreData implementation (Engineer 1)
- Prayer time calculations (Engineer 1)
- Location services (Engineer 2)
- API integration (Engineer 2)
- SwiftUI interface (Engineer 3)
- Navigation and UX (Engineer 3)

## 🛠️ Content Pipeline

The content management system allows for easy creation and maintenance of prayer guides:

### Content Structure
```markdown
---
contentId: fajr_sunni_guide
title: Fajr Prayer Guide (Sunni)
prayerName: fajr
sect: sunni
rakahCount: 2
---

# Prayer Guide Content
## Step 1: Intention
...
```

### Pipeline Commands
```bash
# Validate all content
npm run validate

# Ingest content (dry run)
npm run ingest -- --dry-run --verbose

# Sync with Supabase
npm run sync

# Check pipeline status
npm start status
```

## 🧭 QiblaKit Usage

The standalone Qibla calculation package can be used independently:

```swift
import QiblaKit
import CoreLocation

let userLocation = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
let result = QiblaCalculator.calculateQibla(from: userLocation)

print("Qibla direction: \(result.formattedDirection)")
print("Distance to Kaaba: \(result.formattedDistance)")
print("Compass bearing: \(result.compassBearing)")
```

## 🔧 Development Workflow

### For Content Updates
1. Add/edit Markdown files in `content-pipeline/content/`
2. Run validation: `npm run validate`
3. Test ingestion: `npm run ingest -- --dry-run`
4. Deploy: `npm run ingest`

### For iOS Development
1. Create feature branch
2. Make changes
3. Run tests: `fastlane test`
4. Submit PR (triggers CI)
5. Merge to main (triggers beta build)

### For Releases
1. Update version: `fastlane release`
2. Create GitHub release
3. Submit to App Store

## 📊 Database Schema

### Prayer Guides Table
```sql
CREATE TABLE prayer_guides (
  id UUID PRIMARY KEY,
  content_id VARCHAR(100) UNIQUE,
  title VARCHAR(200),
  prayer_name VARCHAR(50),
  sect VARCHAR(20) CHECK (sect IN ('sunni', 'shia')),
  rakah_count INTEGER,
  content_type VARCHAR(20),
  text_content JSONB,
  video_url TEXT,
  is_available_offline BOOLEAN,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE
);
```

## 🧪 Testing

### QiblaKit Tests
```bash
cd QiblaKit
swift test
```

### Content Pipeline Tests
```bash
cd content-pipeline
npm test
```

### iOS Tests (when project exists)
```bash
fastlane test
```

## 📈 Performance Considerations

- **Offline-first**: All core functionality works without internet
- **Efficient Storage**: JSONB for flexible content, binary data for offline assets
- **Lazy Loading**: Content downloaded on-demand with progress tracking
- **Sensor Optimization**: Efficient compass updates with configurable refresh rates

## 🔐 Security & Privacy

- **No Personal Data**: App doesn't collect or store personal information
- **Local Storage**: All user preferences stored locally in CoreData
- **Secure API**: Supabase with Row Level Security for content management
- **Privacy-First**: Location used only for calculations, never transmitted

## 🤝 Contributing

This project follows a 4-engineer parallel development model:

- **Engineer 1**: Core Data & Prayer Engine
- **Engineer 2**: Location & Network Services  
- **Engineer 3**: UI/UX & User Experience
- **Engineer 4**: Specialized Features & DevOps (this implementation)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **AdhanSwift**: Prayer time calculation library
- **Supabase**: Backend infrastructure
- **Islamic Community**: For guidance on authentic prayer practices

---

**Note**: This is an active development project. The iOS app is currently in development by a team of 4 engineers working in parallel. This README reflects the current state of Engineer 4's contributions to the project.
