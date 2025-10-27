# PNG File Placement Guide for DeenBuddy Live Activities Assets

## Overview
This guide shows exactly where to place each of the 57 PNG files when they're created by your designer.

## File Structure
All PNG files go inside their corresponding `.imageset` folder within `Assets.xcassets`:

```
DeenBuddy-iOS-Xcode-App/DeenBuddy/Resources/Assets.xcassets/
```

## Complete Asset Placement Map

### Core Islamic Symbols (21 files)

#### IslamicSymbol.imageset/
- `islamic-symbol@1x.png` (24x24px)
- `islamic-symbol@2x.png` (48x48px) 
- `islamic-symbol@3x.png` (72x72px)

#### IslamicSymbolSmall.imageset/
- `islamic-symbol-small@1x.png` (20x20px)
- `islamic-symbol-small@2x.png` (40x40px)
- `islamic-symbol-small@3x.png` (60x60px)

#### IslamicSymbolMinimal.imageset/
- `islamic-symbol-minimal@1x.png` (16x16px)
- `islamic-symbol-minimal@2x.png` (32x32px)
- `islamic-symbol-minimal@3x.png` (48x48px)

#### IslamicSymbolCircular.imageset/
- `islamic-symbol-circular@1x.png` (32x32px)
- `islamic-symbol-circular@2x.png` (64x64px)
- `islamic-symbol-circular@3x.png` (96x96px)

#### IslamicSymbolInline.imageset/
- `islamic-symbol-inline@1x.png` (12x12px)
- `islamic-symbol-inline@2x.png` (24x24px)
- `islamic-symbol-inline@3x.png` (36x36px)

#### IslamicSymbolConcentric.imageset/
- `islamic-symbol-concentric@1x.png` (24x24px)
- `islamic-symbol-concentric@2x.png` (48x48px)
- `islamic-symbol-concentric@3x.png` (72x72px)

#### IslamicSymbolAlwaysOn.imageset/
- `islamic-symbol-always-on@1x.png` (24x24px)
- `islamic-symbol-always-on@2x.png` (48x48px)
- `islamic-symbol-always-on@3x.png` (72x72px)

### Prayer-Specific Icons (15 files)

#### FajrIcon.imageset/
- `fajr-icon@1x.png` (24x24px)
- `fajr-icon@2x.png` (48x48px)
- `fajr-icon@3x.png` (72x72px)

#### DhuhrIcon.imageset/
- `dhuhr-icon@1x.png` (24x24px)
- `dhuhr-icon@2x.png` (48x48px)
- `dhuhr-icon@3x.png` (72x72px)

#### AsrIcon.imageset/
- `asr-icon@1x.png` (24x24px)
- `asr-icon@2x.png` (48x48px)
- `asr-icon@3x.png` (72x72px)

#### MaghribIcon.imageset/
- `maghrib-icon@1x.png` (24x24px)
- `maghrib-icon@2x.png` (48x48px)
- `maghrib-icon@3x.png` (72x72px)

#### IshaIcon.imageset/
- `isha-icon@1x.png` (24x24px)
- `isha-icon@2x.png` (48x48px)
- `isha-icon@3x.png` (72x72px)

### Allah Calligraphy (6 files)

#### AllahCalligraphy.imageset/
- `allah-calligraphy@1x.png` (24x24px)
- `allah-calligraphy@2x.png` (48x48px)
- `allah-calligraphy@3x.png` (72x72px)

#### AllahCalligraphySmall.imageset/
- `allah-calligraphy-small@1x.png` (20x20px)
- `allah-calligraphy-small@2x.png` (40x40px)
- `allah-calligraphy-small@3x.png` (60x60px)

### Kaaba/Qibla Symbols (6 files)

#### KaabaQibla.imageset/
- `kaaba-qibla@1x.png` (24x24px)
- `kaaba-qibla@2x.png` (48x48px)
- `kaaba-qibla@3x.png` (72x72px)

#### KaabaQiblaSmall.imageset/
- `kaaba-qibla-small@1x.png` (20x20px)
- `kaaba-qibla-small@2x.png` (40x40px)
- `kaaba-qibla-small@3x.png` (60x60px)

### Always-On Display Variants (3 files)

#### PrayerIconsAlwaysOn.imageset/
- `prayer-icons-always-on@1x.png` (24x24px)
- `prayer-icons-always-on@2x.png` (48x48px)
- `prayer-icons-always-on@3x.png` (72x72px)

## Important Notes

### File Naming
- **Exact match required**: File names must match exactly as shown above
- **Case sensitive**: Use lowercase with hyphens, not spaces or underscores
- **Scale suffixes**: @1x, @2x, @3x are required for iOS resolution scaling

### Technical Requirements
- **Format**: PNG with alpha transparency
- **Color**: Pure black (#000000) design on transparent background
- **Template images**: iOS will automatically apply system colors
- **No compression artifacts**: Use PNG-24 or PNG-32 format

### Verification Steps
1. Place PNG files in their corresponding `.imageset` folders
2. Open Xcode and navigate to Assets.xcassets
3. Verify each image set shows all three scale variants (1x, 2x, 3x)
4. Build and run the app to test Live Activities display
5. Check Dynamic Island and lock screen widget appearance

## File Structure Validation

After placing all files, your Assets.xcassets should contain:
- **19 total .imageset folders** (already created)
- **57 total PNG files** (to be added)
- Each .imageset folder should contain 1 Contents.json + 3 PNG files

## Troubleshooting

**If assets don't appear in Xcode:**
1. Check file names match exactly (case-sensitive)
2. Ensure PNG files are actually PNG format (not renamed JPG)
3. Verify transparent background and pure black design
4. Clean build folder (Product > Clean Build Folder) and rebuild

**If Live Activities don't show assets:**
1. Verify template rendering is working (images should change color with system theme)
2. Check that image sizes are correct for each scale
3. Ensure assets are added to the widget extension target

## Total Asset Count Summary
- Islamic Symbol variants: 21 files
- Prayer-specific icons: 15 files  
- Allah calligraphy: 6 files
- Kaaba/Qibla symbols: 6 files
- Always-On Display: 3 files
- Additional enhanced variants: 6 files
- **Total: 57 PNG files**