//
//  PrayerTimeCard.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-04.
//

import SwiftUI

/// Card component for displaying individual prayer times
struct PrayerTimeCard: View {
    let prayerTime: PrayerTime
    let timeFormat: TimeFormat
    let isHighlighted: Bool
    
    init(prayerTime: PrayerTime, timeFormat: TimeFormat = .twelveHour, isHighlighted: Bool = false) {
        self.prayerTime = prayerTime
        self.timeFormat = timeFormat
        self.isHighlighted = isHighlighted
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Prayer Icon
            ZStack {
                Circle()
                    .fill(prayerTime.prayer.color.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: prayerTime.prayer.systemImageName)
                    .font(.title2)
                    .foregroundColor(prayerTime.prayer.color)
            }
            
            // Prayer Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(prayerTime.prayer.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(prayerTime.prayer.arabicName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(prayerTime.formattedTime(format: timeFormat))
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(prayerTime.status.color)
                    
                    Spacer()
                    
                    // Status indicator
                    StatusIndicator(status: prayerTime.status)
                }
                
                // Time remaining (if applicable)
                if let timeRemaining = prayerTime.timeRemainingFormatted,
                   prayerTime.status == .upcoming || prayerTime.status == .current {
                    Text("in \(timeRemaining)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: isHighlighted ? 2 : 0)
                )
        )
        .scaleEffect(isHighlighted ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHighlighted)
    }
    
    private var backgroundColor: Color {
        if isHighlighted {
            return prayerTime.prayer.color.opacity(0.05)
        }
        
        switch prayerTime.status {
        case .current:
            return Color.green.opacity(0.05)
        case .upcoming:
            return Color(.systemBackground)
        case .passed:
            return Color(.systemGray6)
        }
    }
    
    private var borderColor: Color {
        if isHighlighted {
            return prayerTime.prayer.color
        }
        return .clear
    }
}

// MARK: - Status Indicator

struct StatusIndicator: View {
    let status: PrayerStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            
            Text(status.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(status.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(status.color.opacity(0.1))
        )
    }
}

// MARK: - Compact Prayer Time Card

/// Compact version of prayer time card for smaller spaces
struct CompactPrayerTimeCard: View {
    let prayerTime: PrayerTime
    let timeFormat: TimeFormat
    let showArabic: Bool
    
    init(prayerTime: PrayerTime, timeFormat: TimeFormat = .twelveHour, showArabic: Bool = true) {
        self.prayerTime = prayerTime
        self.timeFormat = timeFormat
        self.showArabic = showArabic
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Prayer Icon
            ZStack {
                Circle()
                    .fill(prayerTime.prayer.color.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: prayerTime.prayer.systemImageName)
                    .font(.title3)
                    .foregroundColor(prayerTime.prayer.color)
            }
            
            // Prayer Name
            VStack(spacing: 2) {
                Text(prayerTime.prayer.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if showArabic {
                    Text(prayerTime.prayer.arabicName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Time
            Text(prayerTime.formattedTime(format: timeFormat))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(prayerTime.status.color)
            
            // Status dot
            Circle()
                .fill(prayerTime.status.color)
                .frame(width: 6, height: 6)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Next Prayer Card

/// Special card for highlighting the next prayer
struct NextPrayerCard: View {
    let prayerTime: PrayerTime
    let timeFormat: TimeFormat
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Next Prayer")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let timeRemaining = prayerTime.timeRemainingFormatted {
                    Text("in \(timeRemaining)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }
            
            // Prayer Info
            HStack(spacing: 16) {
                // Large Icon
                ZStack {
                    Circle()
                        .fill(prayerTime.prayer.color.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: prayerTime.prayer.systemImageName)
                        .font(.largeTitle)
                        .foregroundColor(prayerTime.prayer.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(prayerTime.prayer.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(prayerTime.prayer.arabicName)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(prayerTime.formattedTime(format: timeFormat))
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(prayerTime.prayer.color)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(prayerTime.prayer.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Prayer Time List Row

/// List row version of prayer time display
struct PrayerTimeListRow: View {
    let prayerTime: PrayerTime
    let timeFormat: TimeFormat
    let showStatus: Bool
    
    init(prayerTime: PrayerTime, timeFormat: TimeFormat = .twelveHour, showStatus: Bool = true) {
        self.prayerTime = prayerTime
        self.timeFormat = timeFormat
        self.showStatus = showStatus
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Prayer Icon
            Image(systemName: prayerTime.prayer.systemImageName)
                .font(.title3)
                .foregroundColor(prayerTime.prayer.color)
                .frame(width: 24)
            
            // Prayer Name
            VStack(alignment: .leading, spacing: 2) {
                Text(prayerTime.prayer.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(prayerTime.prayer.arabicName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Time and Status
            VStack(alignment: .trailing, spacing: 2) {
                Text(prayerTime.formattedTime(format: timeFormat))
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(prayerTime.status.color)
                
                if showStatus {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(prayerTime.status.color)
                            .frame(width: 6, height: 6)
                        
                        Text(prayerTime.status.displayName)
                            .font(.caption2)
                            .foregroundColor(prayerTime.status.color)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

#Preview("Prayer Time Card") {
    VStack(spacing: 16) {
        PrayerTimeCard(
            prayerTime: PrayerTime(
                prayer: .fajr,
                time: Date().addingTimeInterval(3600),
                status: .upcoming
            ),
            timeFormat: .twelveHour,
            isHighlighted: false
        )
        
        PrayerTimeCard(
            prayerTime: PrayerTime(
                prayer: .dhuhr,
                time: Date(),
                status: .current
            ),
            timeFormat: .twelveHour,
            isHighlighted: true
        )
        
        PrayerTimeCard(
            prayerTime: PrayerTime(
                prayer: .asr,
                time: Date().addingTimeInterval(-3600),
                status: .passed
            ),
            timeFormat: .twelveHour,
            isHighlighted: false
        )
    }
    .padding()
}

#Preview("Compact Cards") {
    HStack(spacing: 12) {
        CompactPrayerTimeCard(
            prayerTime: PrayerTime(
                prayer: .fajr,
                time: Date(),
                status: .upcoming
            )
        )
        
        CompactPrayerTimeCard(
            prayerTime: PrayerTime(
                prayer: .dhuhr,
                time: Date(),
                status: .current
            )
        )
        
        CompactPrayerTimeCard(
            prayerTime: PrayerTime(
                prayer: .asr,
                time: Date(),
                status: .passed
            )
        )
    }
    .padding()
}

#Preview("Next Prayer Card") {
    NextPrayerCard(
        prayerTime: PrayerTime(
            prayer: .maghrib,
            time: Date().addingTimeInterval(1800),
            status: .upcoming
        ),
        timeFormat: .twelveHour
    )
    .padding()
}
