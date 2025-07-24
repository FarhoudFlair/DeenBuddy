import SwiftUI

/// Comprehensive view showing calculation methods and data sources used in DeenBuddy
public struct CalculationMethodsSourcesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expandedSections: Set<String> = []
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection
                    
                    // Prayer Time Calculations
                    prayerTimeCalculationsSection
                    
                    // Qibla Direction
                    qiblaDirectionSection
                    
                    // Quran Text Sources
                    quranTextSourcesSection
                    
                    // Hijri Calendar
                    hijriCalendarSection
                    
                    // Technical Notes
                    technicalNotesSection
                }
                .padding()
            }
            .navigationTitle("Calculation Methods & Sources")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(ColorPalette.primary)
                    .font(.title2)
                
                Text("Transparency & Accuracy")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.textPrimary)
            }
            
            Text("DeenBuddy is committed to providing accurate Islamic calculations and transparent data sources. This page details the methods and sources used throughout the app.")
                .font(.body)
                .foregroundColor(ColorPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(ColorPalette.backgroundSecondary)
        .cornerRadius(12)
    }
    
    // MARK: - Prayer Time Calculations Section
    
    private var prayerTimeCalculationsSection: some View {
        ExpandableSection(
            title: "Prayer Time Calculations",
            icon: "clock.fill",
            isExpanded: expandedSections.contains("prayer"),
            onToggle: { toggleSection("prayer") }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // Calculation Library
                InfoCard(
                    title: "Calculation Library",
                    content: "DeenBuddy uses the Adhan Swift library (v1.4.0) by Batoul Apps, which implements precise astronomical calculations based on established Islamic jurisprudence."
                )
                
                // Supported Methods
                InfoCard(
                    title: "Supported Calculation Methods",
                    content: """
                    • Muslim World League (18°/17°) - Global standard
                    • Egyptian General Authority (19.5°/17.5°) - Egypt, Syria, Iraq, Lebanon
                    • University of Islamic Sciences, Karachi (18°/18°) - Pakistan, Bangladesh, India
                    • Umm Al-Qura University, Makkah (18.5°/90 min after Maghrib) - Saudi Arabia
                    • Dubai (18.2°/18.2°) - UAE
                    • Moonsighting Committee Worldwide (18°/18°) - Moon sighting communities
                    • Islamic Society of North America (15°/15°) - North America
                    • Kuwait (18°/17.5°) - Kuwait
                    • Qatar (18°/90 min after Maghrib) - Qatar
                    • Singapore (20°/18°) - Singapore
                    • Ja'fari (Leva Institute) (16°/14°) - Shia calculations
                    • Ja'fari (Tehran IOG) (17.7°/14°) - Alternative Shia method
                    """
                )
                
                // Madhab Differences
                InfoCard(
                    title: "Madhab (School of Jurisprudence) Differences",
                    content: """
                    **Asr Prayer Timing:**
                    • Hanafi: When shadow length = 2× object height (later timing)
                    • Shafi'i/Maliki/Hanbali: When shadow length = 1× object height (earlier timing)
                    • Ja'fari: When shadow length = 1× object height, with 15-minute delay after Maghrib
                    
                    **Astronomical Parameters:**
                    The angles shown (e.g., 18°/17°) represent the sun's position below the horizon for Fajr and Isha prayers respectively.
                    """
                )
            }
        }
    }
    
    // MARK: - Qibla Direction Section
    
    private var qiblaDirectionSection: some View {
        ExpandableSection(
            title: "Qibla Direction",
            icon: "location.north.fill",
            isExpanded: expandedSections.contains("qibla"),
            onToggle: { toggleSection("qibla") }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                InfoCard(
                    title: "Calculation Method",
                    content: """
                    DeenBuddy uses the great circle calculation method to determine the shortest path on Earth's surface to the Kaaba. This method accounts for Earth's curvature and provides the most accurate direction.
                    
                    **Formula:** Uses spherical trigonometry with the haversine formula for precise bearing calculations.
                    """
                )
                
                InfoCard(
                    title: "Kaaba Coordinates",
                    content: """
                    **Reference Point:** Kaaba, Masjid al-Haram, Mecca
                    **Latitude:** 21.422487°N
                    **Longitude:** 39.826206°E
                    
                    These coordinates represent the center of the Kaaba structure and are used as the universal reference point for all Qibla calculations.
                    """
                )
                
                InfoCard(
                    title: "Device Integration",
                    content: """
                    **Location Services:** Uses GPS and network-based location for your coordinates
                    **Compass Integration:** Combines device magnetometer with magnetic declination correction
                    **Magnetic Declination:** Automatically calculated using the World Magnetic Model to correct for the difference between magnetic north and true north at your location
                    """
                )
            }
        }
    }
    
    // MARK: - Quran Text Sources Section

    private var quranTextSourcesSection: some View {
        ExpandableSection(
            title: "Quran Text Sources",
            icon: "book.fill",
            isExpanded: expandedSections.contains("quran"),
            onToggle: { toggleSection("quran") }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                InfoCard(
                    title: "Arabic Text Source",
                    content: """
                    **Primary Source:** Mushaf Al-Madinah An-Nabawiyah
                    **Publisher:** King Fahd Complex for the Printing of the Holy Quran
                    **Standard:** Hafs 'an 'Asim recitation (Qira'ah)

                    This is the most widely accepted and distributed version of the Quran text, used by the majority of Muslims worldwide.
                    """
                )

                InfoCard(
                    title: "Translation Sources",
                    content: """
                    **English Translation:** Sahih International
                    **Verification:** Cross-referenced with multiple scholarly translations
                    **Approach:** Clear, contemporary English while maintaining accuracy to the original Arabic

                    **Note:** Translations are provided for understanding only. The Arabic text remains the authoritative source.
                    """
                )

                InfoCard(
                    title: "Search & Indexing",
                    content: """
                    **Search Method:** Case-insensitive text matching with Arabic normalization
                    **Famous Verses:** Includes common names like "Ayat al-Kursi" for easy discovery
                    **Diacritics:** Handles Arabic text with and without diacritical marks (Tashkeel)
                    """
                )
            }
        }
    }

    // MARK: - Hijri Calendar Section

    private var hijriCalendarSection: some View {
        ExpandableSection(
            title: "Hijri Calendar",
            icon: "calendar.badge.clock",
            isExpanded: expandedSections.contains("hijri"),
            onToggle: { toggleSection("hijri") }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                InfoCard(
                    title: "Calculation Method",
                    content: """
                    **Primary Method:** Umm Al-Qura Calendar System
                    **Authority:** Used by Saudi Arabia and many Islamic organizations
                    **Approach:** Astronomical calculations based on lunar cycles

                    **Note:** This is a calculated calendar, not based on physical moon sighting. Actual Islamic dates may vary by 1-2 days depending on local moon sighting practices.
                    """
                )

                InfoCard(
                    title: "Astronomical Calculations",
                    content: """
                    **Lunar Cycle:** Based on precise astronomical calculations of moon phases
                    **Month Length:** Alternates between 29 and 30 days (354-355 days per year)
                    **New Moon:** Months begin when the new moon is calculated to be visible

                    **Regional Variations:** Some communities may observe dates 1-2 days earlier or later based on local moon sighting committees.
                    """
                )

                InfoCard(
                    title: "Islamic Events",
                    content: """
                    **Event Dates:** Based on traditional Hijri calendar dates
                    **Holy Months:** Muharram, Rajab, Dhul-Qi'dah, Dhul-Hijjah (Sacred Months)
                    **Major Events:** Ramadan, Eid al-Fitr, Eid al-Adha, Day of Arafah, etc.

                    **Disclaimer:** For religious observances, consult your local Islamic authority or moon sighting committee for confirmed dates.
                    """
                )
            }
        }
    }

    // MARK: - Technical Notes Section

    private var technicalNotesSection: some View {
        ExpandableSection(
            title: "Technical Notes & Disclaimers",
            icon: "info.circle.fill",
            isExpanded: expandedSections.contains("technical"),
            onToggle: { toggleSection("technical") }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                InfoCard(
                    title: "Accuracy & Precision",
                    content: """
                    **Prayer Times:** Accurate to within ±1 minute under normal conditions
                    **Qibla Direction:** Accurate to within ±1° with proper device calibration
                    **Location Dependency:** Accuracy depends on GPS precision and device sensors

                    **Factors Affecting Accuracy:** Weather conditions, device calibration, magnetic interference, and geographic location.
                    """
                )

                InfoCard(
                    title: "Local Variations",
                    content: """
                    **Community Practices:** Some communities may follow different calculation methods or adjustments
                    **Moon Sighting:** Hijri dates may vary based on local moon sighting practices
                    **Regional Authorities:** Always consult local Islamic authorities for official prayer times and religious dates

                    **Recommendation:** Use DeenBuddy as a guide, but verify with local mosques and Islamic centers for community-specific practices.
                    """
                )

                InfoCard(
                    title: "Data Updates",
                    content: """
                    **Calculation Methods:** Based on established Islamic jurisprudence and astronomical science
                    **Regular Updates:** App calculations are updated with library improvements and bug fixes
                    **Feedback:** User feedback helps improve accuracy and add new features

                    **Open Source:** Some calculation libraries used are open source and peer-reviewed by the Islamic tech community.
                    """
                )
            }
        }
    }

    // MARK: - Helper Methods

    private func toggleSection(_ section: String) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
    }
}

// MARK: - Supporting Views

private struct ExpandableSection<Content: View>: View {
    let title: String
    let icon: String
    let isExpanded: Bool
    let onToggle: () -> Void
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(ColorPalette.primary)
                        .frame(width: 24)
                    
                    Text(title)
                        .font(.headline)
                        .foregroundColor(ColorPalette.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(ColorPalette.textTertiary)
                        .font(.system(size: 12))
                }
                .padding()
                .background(ColorPalette.backgroundSecondary)
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    content()
                }
                .padding(.top, 12)
            }
        }
    }
}

private struct InfoCard: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ColorPalette.primary)
            
            Text(content)
                .font(.caption)
                .foregroundColor(ColorPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(ColorPalette.backgroundTertiary)
        .cornerRadius(8)
    }
}

#Preview {
    CalculationMethodsSourcesView()
}
