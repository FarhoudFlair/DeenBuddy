import Foundation

/// Service for validating Quran data completeness and integrity
public class QuranDataValidator {
    
    // MARK: - Constants
    
    /// Expected total number of verses in the complete Quran
    public static let EXPECTED_TOTAL_VERSES = 6236
    
    /// Expected total number of surahs in the complete Quran
    public static let EXPECTED_TOTAL_SURAHS = 114
    
    /// Expected verse counts for each surah
    public static let EXPECTED_SURAH_VERSE_COUNTS: [Int: Int] = [
        1: 7,    // Al-Fatiha
        2: 286,  // Al-Baqarah
        3: 200,  // Ali 'Imran
        4: 176,  // An-Nisa
        5: 120,  // Al-Ma'idah
        6: 165,  // Al-An'am
        7: 206,  // Al-A'raf
        8: 75,   // Al-Anfal
        9: 129,  // At-Tawbah
        10: 109, // Yunus
        11: 123, // Hud
        12: 111, // Yusuf
        13: 43,  // Ar-Ra'd
        14: 52,  // Ibrahim
        15: 99,  // Al-Hijr
        16: 128, // An-Nahl
        17: 111, // Al-Isra
        18: 110, // Al-Kahf
        19: 98,  // Maryam
        20: 135, // Ta-Ha
        21: 112, // Al-Anbiya
        22: 78,  // Al-Hajj
        23: 118, // Al-Mu'minun
        24: 64,  // An-Nur
        25: 77,  // Al-Furqan
        26: 227, // Ash-Shu'ara
        27: 93,  // An-Naml
        28: 88,  // Al-Qasas
        29: 69,  // Al-Ankabut
        30: 60,  // Ar-Rum
        31: 34,  // Luqman
        32: 30,  // As-Sajdah
        33: 73,  // Al-Ahzab
        34: 54,  // Saba
        35: 45,  // Fatir
        36: 83,  // Ya-Sin
        37: 182, // As-Saffat
        38: 88,  // Sad
        39: 75,  // Az-Zumar
        40: 85,  // Ghafir
        41: 54,  // Fussilat
        42: 53,  // Ash-Shura
        43: 89,  // Az-Zukhruf
        44: 59,  // Ad-Dukhan
        45: 37,  // Al-Jathiyah
        46: 35,  // Al-Ahqaf
        47: 38,  // Muhammad
        48: 29,  // Al-Fath
        49: 18,  // Al-Hujurat
        50: 45,  // Qaf
        51: 60,  // Adh-Dhariyat
        52: 49,  // At-Tur
        53: 62,  // An-Najm
        54: 55,  // Al-Qamar
        55: 78,  // Ar-Rahman
        56: 96,  // Al-Waqi'ah
        57: 29,  // Al-Hadid
        58: 22,  // Al-Mujadila
        59: 24,  // Al-Hashr
        60: 13,  // Al-Mumtahanah
        61: 14,  // As-Saff
        62: 11,  // Al-Jumu'ah
        63: 11,  // Al-Munafiqun
        64: 18,  // At-Taghabun
        65: 12,  // At-Talaq
        66: 12,  // At-Tahrim
        67: 30,  // Al-Mulk
        68: 52,  // Al-Qalam
        69: 52,  // Al-Haqqah
        70: 44,  // Al-Ma'arij
        71: 28,  // Nuh
        72: 28,  // Al-Jinn
        73: 20,  // Al-Muzzammil
        74: 56,  // Al-Muddaththir
        75: 40,  // Al-Qiyamah
        76: 31,  // Al-Insan
        77: 50,  // Al-Mursalat
        78: 40,  // An-Naba
        79: 46,  // An-Nazi'at
        80: 42,  // Abasa
        81: 29,  // At-Takwir
        82: 19,  // Al-Infitar
        83: 36,  // Al-Mutaffifin
        84: 25,  // Al-Inshiqaq
        85: 22,  // Al-Buruj
        86: 17,  // At-Tariq
        87: 19,  // Al-A'la
        88: 26,  // Al-Ghashiyah
        89: 30,  // Al-Fajr
        90: 20,  // Al-Balad
        91: 15,  // Ash-Shams
        92: 21,  // Al-Layl
        93: 11,  // Ad-Dhuha
        94: 8,   // Ash-Sharh
        95: 8,   // At-Tin
        96: 19,  // Al-Alaq
        97: 5,   // Al-Qadr
        98: 8,   // Al-Bayyinah
        99: 8,   // Az-Zalzalah
        100: 11, // Al-Adiyat
        101: 11, // Al-Qari'ah
        102: 8,  // At-Takathur
        103: 3,  // Al-Asr
        104: 9,  // Al-Humazah
        105: 5,  // Al-Fil
        106: 4,  // Quraysh
        107: 7,  // Al-Ma'un
        108: 3,  // Al-Kawthar
        109: 6,  // Al-Kafirun
        110: 3,  // An-Nasr
        111: 5,  // Al-Masad
        112: 4,  // Al-Ikhlas
        113: 5,  // Al-Falaq
        114: 6   // An-Nas
    ]
    
    // MARK: - Validation Results
    
    public struct ValidationResult {
        let isValid: Bool
        let totalVerses: Int
        let totalSurahs: Int
        let missingVerses: [String]
        let missingSurahs: [Int]
        let invalidVerses: [String]
        let summary: String
        
        var hasErrors: Bool {
            return !missingVerses.isEmpty || !missingSurahs.isEmpty || !invalidVerses.isEmpty
        }
    }
    
    // MARK: - Public Methods
    
    /// Validate complete Quran data for completeness and integrity
    public static func validateQuranData(_ verses: [QuranVerse]) -> ValidationResult {
        var missingVerses: [String] = []
        var missingSurahs: [Int] = []
        var invalidVerses: [String] = []
        
        // Group verses by surah
        let versesBySurah = Dictionary(grouping: verses) { $0.surahNumber }
        
        // Check for missing surahs
        for surahNumber in 1...EXPECTED_TOTAL_SURAHS {
            if versesBySurah[surahNumber] == nil {
                missingSurahs.append(surahNumber)
            }
        }
        
        // Check each surah for completeness
        for surahNumber in 1...EXPECTED_TOTAL_SURAHS {
            guard let surahVerses = versesBySurah[surahNumber],
                  let expectedCount = EXPECTED_SURAH_VERSE_COUNTS[surahNumber] else {
                continue
            }
            
            // Check verse count
            if surahVerses.count != expectedCount {
                missingVerses.append("Surah \(surahNumber): Expected \(expectedCount) verses, found \(surahVerses.count)")
            }
            
            // Check verse numbers are sequential
            let sortedVerses = surahVerses.sorted { $0.verseNumber < $1.verseNumber }
            for (index, verse) in sortedVerses.enumerated() {
                let expectedVerseNumber = index + 1
                if verse.verseNumber != expectedVerseNumber {
                    invalidVerses.append("Surah \(surahNumber), Verse \(verse.verseNumber): Expected verse number \(expectedVerseNumber)")
                }
                
                // Check for empty content
                if verse.textArabic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    invalidVerses.append("Surah \(surahNumber), Verse \(verse.verseNumber): Empty Arabic text")
                }
                
                if verse.textTranslation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    invalidVerses.append("Surah \(surahNumber), Verse \(verse.verseNumber): Empty translation")
                }
                
                if let transliteration = verse.textTransliteration, 
                   transliteration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    invalidVerses.append("Surah \(surahNumber), Verse \(verse.verseNumber): Empty transliteration")
                }
            }
        }
        
        // Generate summary
        let isValid = verses.count == EXPECTED_TOTAL_VERSES && 
                     versesBySurah.count == EXPECTED_TOTAL_SURAHS && 
                     missingVerses.isEmpty && 
                     missingSurahs.isEmpty && 
                     invalidVerses.isEmpty
        
        let summary = generateValidationSummary(
            totalVerses: verses.count,
            totalSurahs: versesBySurah.count,
            isValid: isValid,
            missingVerses: missingVerses,
            missingSurahs: missingSurahs,
            invalidVerses: invalidVerses
        )
        
        return ValidationResult(
            isValid: isValid,
            totalVerses: verses.count,
            totalSurahs: versesBySurah.count,
            missingVerses: missingVerses,
            missingSurahs: missingSurahs,
            invalidVerses: invalidVerses,
            summary: summary
        )
    }
    
    // MARK: - Private Methods
    
    private static func generateValidationSummary(
        totalVerses: Int,
        totalSurahs: Int,
        isValid: Bool,
        missingVerses: [String],
        missingSurahs: [Int],
        invalidVerses: [String]
    ) -> String {
        var summary = """
        📊 QURAN DATA VALIDATION REPORT
        ═══════════════════════════════════
        
        📈 STATISTICS:
        • Total Verses: \(totalVerses) / \(EXPECTED_TOTAL_VERSES) (\(totalVerses == EXPECTED_TOTAL_VERSES ? "✅" : "❌"))
        • Total Surahs: \(totalSurahs) / \(EXPECTED_TOTAL_SURAHS) (\(totalSurahs == EXPECTED_TOTAL_SURAHS ? "✅" : "❌"))
        
        🔍 VALIDATION STATUS: \(isValid ? "✅ PASSED" : "❌ FAILED")
        """
        
        if !missingSurahs.isEmpty {
            summary += "\n\n❌ MISSING SURAHS (\(missingSurahs.count)):\n"
            summary += missingSurahs.map { "• Surah \($0)" }.joined(separator: "\n")
        }
        
        if !missingVerses.isEmpty {
            summary += "\n\n⚠️ VERSE COUNT ISSUES (\(missingVerses.count)):\n"
            summary += missingVerses.map { "• \($0)" }.joined(separator: "\n")
        }
        
        if !invalidVerses.isEmpty {
            summary += "\n\n🚫 INVALID VERSES (\(invalidVerses.count)):\n"
            summary += invalidVerses.prefix(10).map { "• \($0)" }.joined(separator: "\n")
            if invalidVerses.count > 10 {
                summary += "\n• ... and \(invalidVerses.count - 10) more issues"
            }
        }
        
        if isValid {
            summary += "\n\n🎉 All validation checks passed! The Quran data is complete and ready for search."
        }
        
        return summary
    }
}
