//
//  PrayerTimeComponents.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-04.
//

import SwiftUI

// MARK: - Date Header Component

/// Header showing both Gregorian and Hijri dates
struct DateHeaderView: View {
    let dualCalendarDate: DualCalendarDate
    let todaysEvents: [IslamicEvent]
    
    var body: some View {
        VStack(spacing: 8) {
            // Gregorian Date
            Text(gregorianDateString)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Hijri Date
            Text(dualCalendarDate.hijriDate.formatted)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Islamic Events (if any)
            if !todaysEvents.isEmpty {
                ForEach(todaysEvents, id: \.id) { event in
                    EventBadge(event: event)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var gregorianDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: dualCalendarDate.gregorianDate)
    }
}

// MARK: - Event Badge

struct EventBadge: View {
    let event: IslamicEvent
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.caption)
                .foregroundColor(.yellow)
            
            Text(event.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.yellow.opacity(0.1))
        )
    }
}

// MARK: - Location Header

struct LocationHeaderView: View {
    let locationName: String
    let isLocationAvailable: Bool
    let onLocationTapped: () -> Void
    
    var body: some View {
        Button(action: onLocationTapped) {
            HStack(spacing: 8) {
                Image(systemName: isLocationAvailable ? "location.fill" : "location.slash")
                    .font(.subheadline)
                    .foregroundColor(isLocationAvailable ? .green : .red)
                
                Text(locationName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Prayer Times List

struct PrayerTimesList: View {
    let prayerTimes: [PrayerTime]
    let timeFormat: TimeFormat
    let nextPrayerIndex: Int?
    
    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(prayerTimes.indices, id: \.self) { index in
                PrayerTimeCard(
                    prayer: prayerTimes[index],
                    status: determineStatus(for: prayerTimes[index]),
                    isNext: nextPrayerIndex == index
                )
            }
        }
    }
    
    private func determineStatus(for prayerTime: PrayerTime) -> PrayerStatus {
        let now = Date()
        if prayerTime.time < now {
            return .passed
        } else {
            return .upcoming
        }
    }
}

// MARK: - Loading View

struct PrayerTimesLoadingView: View {
    var body: some View {
        ContextualLoadingView(context: .prayerTimes)
            .padding()
    }
}

// MARK: - Error View

struct PrayerTimesErrorView: View {
    let error: PrayerTimeError
    let onRetry: () -> Void
    let onRequestLocation: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Error Icon
            Image(systemName: errorIcon)
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            // Error Message
            VStack(spacing: 8) {
                Text("Unable to Load Prayer Times")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Action Buttons
            VStack(spacing: 12) {
                if error.isLocationIssue {
                    Button("Enable Location Access") {
                        onRequestLocation()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                
                Button("Try Again") {
                    onRetry()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding()
    }
    
    private var errorIcon: String {
        switch error {
        case .locationUnavailable, .permissionDenied:
            return "location.slash"
        case .networkError:
            return "wifi.slash"
        case .calculationFailed:
            return "exclamationmark.triangle"
        default:
            return "xmark.circle"
        }
    }
}

private extension PrayerTimeError {
    var isLocationIssue: Bool {
        switch self {
        case .locationUnavailable, .permissionDenied:
            return true
        default:
            return false
        }
    }
}

// MARK: - Empty State View

struct PrayerTimesEmptyView: View {
    let onRequestLocation: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            // Message
            VStack(spacing: 8) {
                Text("Prayer Times Not Available")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Enable location access to see accurate prayer times for your area")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Action Button
            Button("Enable Location") {
                onRequestLocation()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
    }
}

// MARK: - Settings Quick Access

struct PrayerTimesSettingsBar: View {
    let calculationMethod: CalculationMethod
    let madhab: Madhab
    let timeFormat: TimeFormat
    let onSettingsTapped: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Text(calculationMethod.displayName)
                        .font(.caption2)
                        .foregroundColor(.primary)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(madhab.displayName)
                        .font(.caption2)
                        .foregroundColor(.primary)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(timeFormat.displayName)
                        .font(.caption2)
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            Button("Change") {
                onSettingsTapped()
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Ramadan Banner

struct RamadanBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.stars.fill")
                .font(.title2)
                .foregroundColor(.purple)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Ramadan Kareem")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("May this holy month bring you peace and blessings")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.blue)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Previews

#Preview("Date Header") {
    DateHeaderView(
        dualCalendarDate: DualCalendarDate(gregorianDate: Date()),
        todaysEvents: [] // Empty for preview - events would be loaded from service
    )
    .padding()
}

#Preview("Location Header") {
    VStack(spacing: 16) {
        LocationHeaderView(
            locationName: "New York, United States",
            isLocationAvailable: true,
            onLocationTapped: {}
        )
        
        LocationHeaderView(
            locationName: "Location not available",
            isLocationAvailable: false,
            onLocationTapped: {}
        )
    }
    .padding()
}

#Preview("Error View") {
    PrayerTimesErrorView(
        error: .locationUnavailable,
        onRetry: {},
        onRequestLocation: {}
    )
    .padding()
}

#Preview("Ramadan Banner") {
    RamadanBanner()
        .padding()
}
