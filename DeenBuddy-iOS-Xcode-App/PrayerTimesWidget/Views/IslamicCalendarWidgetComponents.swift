import SwiftUI
import WidgetKit

// MARK: - Islamic Calendar Widget Components

/// Component for displaying Hijri date in widgets
struct HijriDateView: View {
    let hijriDate: HijriDate
    let style: HijriDisplayStyle
    let color: Color
    
    enum HijriDisplayStyle {
        case full
        case compact
        case monthOnly
        case dayOnly
    }
    
    init(hijriDate: HijriDate, style: HijriDisplayStyle = .full, color: Color = .secondary) {
        self.hijriDate = hijriDate
        self.style = style
        self.color = color
    }
    
    var body: some View {
        switch style {
        case .full:
            Text(hijriDate.formatted)
                .font(.caption)
                .foregroundColor(color)
        case .compact:
            Text(hijriDate.shortFormatted)
                .font(.caption2)
                .foregroundColor(color)
        case .monthOnly:
            Text(hijriDate.month.displayName)
                .font(.caption)
                .foregroundColor(color)
        case .dayOnly:
            Text("\(hijriDate.day)")
                .font(.caption)
                .foregroundColor(color)
        }
    }
}

/// Component for displaying Islamic events in widgets
struct IslamicEventView: View {
    let events: [IslamicEvent]
    let maxEvents: Int
    let color: Color
    
    init(events: [IslamicEvent], maxEvents: Int = 2, color: Color = .green) {
        self.events = events
        self.maxEvents = maxEvents
        self.color = color
    }
    
    var body: some View {
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(events.prefix(maxEvents), id: \.id) { event in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(color)
                            .frame(width: 4, height: 4)
                        
                        Text(event.title)
                            .font(.caption2)
                            .foregroundColor(color)
                            .lineLimit(1)
                    }
                }
                
                if events.count > maxEvents {
                    Text("+\(events.count - maxEvents) more")
                        .font(.caption2)
                        .foregroundColor(color.opacity(0.7))
                }
            }
        }
    }
}

/// Component for displaying sacred month indicator
struct SacredMonthIndicator: View {
    let hijriDate: HijriDate
    
    var body: some View {
        if hijriDate.month.isSacred {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)
                
                Text("Sacred Month")
                    .font(.caption2)
                    .foregroundColor(.yellow)
            }
        }
    }
}

/// Component for displaying Ramadan indicator
struct RamadanIndicator: View {
    let hijriDate: HijriDate
    
    var body: some View {
        if hijriDate.month == .ramadan {
            HStack(spacing: 4) {
                Image(systemName: "moon.stars.fill")
                    .font(.caption2)
                    .foregroundColor(.purple)
                
                Text("Ramadan")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.purple)
            }
        }
    }
}

/// Enhanced Islamic calendar header for large widgets
struct IslamicCalendarHeader: View {
    let hijriDate: HijriDate
    let events: [IslamicEvent]
    let showGregorianDate: Bool
    
    init(hijriDate: HijriDate, events: [IslamicEvent] = [], showGregorianDate: Bool = true) {
        self.hijriDate = hijriDate
        self.events = events
        self.showGregorianDate = showGregorianDate
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Hijri date with month color
            HStack(spacing: 8) {
                Circle()
                    .fill(hijriDate.month.color)
                    .frame(width: 12, height: 12)
                
                Text(hijriDate.formatted)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            // Gregorian date (if enabled)
            if showGregorianDate {
                Text(formatGregorianDate(hijriDate.toGregorianDate()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Special month indicators
            HStack(spacing: 8) {
                SacredMonthIndicator(hijriDate: hijriDate)
                RamadanIndicator(hijriDate: hijriDate)
            }
            
            // Islamic events
            if !events.isEmpty {
                IslamicEventView(events: events, maxEvents: 1, color: .green)
            }
        }
    }
    
    private func formatGregorianDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

/// Compact Islamic calendar info for small/medium widgets
struct CompactIslamicInfo: View {
    let hijriDate: HijriDate
    let events: [IslamicEvent]
    let layout: CompactLayout
    
    enum CompactLayout {
        case horizontal
        case vertical
    }
    
    init(hijriDate: HijriDate, events: [IslamicEvent] = [], layout: CompactLayout = .horizontal) {
        self.hijriDate = hijriDate
        self.events = events
        self.layout = layout
    }
    
    var body: some View {
        Group {
            if layout == .horizontal {
                HStack(spacing: 8) {
                    content
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    content
                }
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        // Hijri date
        HStack(spacing: 4) {
            Circle()
                .fill(hijriDate.month.color)
                .frame(width: 6, height: 6)
            
            Text(hijriDate.shortFormatted)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        
        // Special indicators
        if hijriDate.month == .ramadan {
            Image(systemName: "moon.stars.fill")
                .font(.caption2)
                .foregroundColor(.purple)
        } else if hijriDate.month.isSacred {
            Image(systemName: "star.fill")
                .font(.caption2)
                .foregroundColor(.yellow)
        }
        
        // Event indicator
        if !events.isEmpty {
            Image(systemName: "calendar.badge.plus")
                .font(.caption2)
                .foregroundColor(.green)
        }
    }
}

/// Islamic calendar widget overlay for prayer time widgets
struct IslamicCalendarOverlay: View {
    let hijriDate: HijriDate
    let events: [IslamicEvent]
    let position: OverlayPosition
    
    enum OverlayPosition {
        case topLeading
        case topTrailing
        case bottomLeading
        case bottomTrailing
    }
    
    init(hijriDate: HijriDate, events: [IslamicEvent] = [], position: OverlayPosition = .topTrailing) {
        self.hijriDate = hijriDate
        self.events = events
        self.position = position
    }
    
    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            // Hijri date
            Text(hijriDate.shortFormatted)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.3))
                .cornerRadius(4)
            
            // Event indicator
            if !events.isEmpty {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
            }
        }
    }
    
    private var alignment: HorizontalAlignment {
        switch position {
        case .topLeading, .bottomLeading:
            return .leading
        case .topTrailing, .bottomTrailing:
            return .trailing
        }
    }
}

// MARK: - Preview

#if DEBUG
struct IslamicCalendarWidgetComponents_Previews: PreviewProvider {
    static let sampleHijriDate = HijriDate(day: 15, month: .ramadan, year: 1445)
    static let sampleEvents = [
        IslamicEvent(
            id: UUID(),
            title: "Laylat al-Qadr",
            description: "Night of Power",
            hijriDate: sampleHijriDate,
            type: .religious,
            importance: .high,
            isRecurring: true,
            location: nil,
            reminder: nil
        )
    ]
    
    static var previews: some View {
        VStack(spacing: 20) {
            HijriDateView(hijriDate: sampleHijriDate, style: .full)
            
            IslamicEventView(events: sampleEvents)
            
            IslamicCalendarHeader(hijriDate: sampleHijriDate, events: sampleEvents)
            
            CompactIslamicInfo(hijriDate: sampleHijriDate, events: sampleEvents)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
