//
//  PrayerGuideRowView.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-03.
//

import SwiftUI

struct PrayerGuideRowView: View {
    let guide: PrayerGuide
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(guide.title)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            // Prayer info badges
            HStack(spacing: 8) {
                // Prayer name badge
                HStack(spacing: 4) {
                    Image(systemName: guide.prayer.systemImageName)
                        .font(.caption)
                    Text(guide.prayer.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(guide.prayer.color.opacity(0.2))
                .foregroundColor(guide.prayer.color)
                .cornerRadius(6)
                
                // Madhab/Sect badge
                Text(guide.sectDisplayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(guide.madhab.color.opacity(0.2))
                    .foregroundColor(guide.madhab.color)
                    .cornerRadius(6)
                
                Spacer()
                
                // Steps count
                Text(guide.rakahText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Arabic name and status
            HStack {
                Text(guide.prayer.arabicName)
                    .font(.title3)
                    .fontWeight(.medium)
                    .environment(\.layoutDirection, .rightToLeft)
                
                Spacer()
                
                HStack(spacing: 8) {
                    // Duration
                    Text(guide.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Offline indicator
                    if guide.isAvailableOffline {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    // Completion indicator
                    if guide.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // Description preview
            if !guide.description.isEmpty {
                Text(guide.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        PrayerGuideRowView(
            guide: PrayerGuide(
                id: "fajr_shafi",
                title: "Fajr Prayer Guide (Sunni)",
                prayer: .fajr,
                madhab: .shafi,
                difficulty: .beginner,
                duration: 300,
                description: "Complete guide for performing Fajr prayer according to Sunni tradition",
                steps: [
                    PrayerStep(
                        id: "step1",
                        title: "Preparation",
                        description: "Perform Wudu and face Qibla",
                        duration: 60
                    ),
                    PrayerStep(
                        id: "step2",
                        title: "Prayer",
                        description: "Perform 2 rakahs",
                        duration: 240
                    )
                ],
                isAvailableOffline: true,
                isCompleted: false
            )
        )
        
        PrayerGuideRowView(
            guide: PrayerGuide(
                id: "dhuhr_hanafi",
                title: "Dhuhr Prayer Guide (Shia)",
                prayer: .dhuhr,
                madhab: .hanafi,
                difficulty: .intermediate,
                duration: 600,
                description: "Complete guide for performing Dhuhr prayer according to Shia tradition",
                steps: [
                    PrayerStep(
                        id: "step1",
                        title: "Preparation",
                        description: "Perform Wudu and face Qibla",
                        duration: 60
                    ),
                    PrayerStep(
                        id: "step2",
                        title: "Prayer",
                        description: "Perform 4 rakahs",
                        duration: 540
                    )
                ],
                isAvailableOffline: false,
                isCompleted: true
            )
        )
    }
}
