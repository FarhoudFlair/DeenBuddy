import Foundation
import Combine

/// Service for fetching complete Quran data from Al-Quran Cloud API
public class QuranAPIService: ObservableObject {
    
    // MARK: - Properties
    
    private let baseURL = "https://api.alquran.cloud/v1"
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Data Models
    
    public struct QuranAPIResponse: Codable {
        let code: Int
        let status: String
        let data: QuranData
    }
    
    public struct QuranData: Codable {
        let surahs: [APISurah]
        let edition: Edition
    }
    
    public struct APISurah: Codable {
        let number: Int
        let name: String
        let englishName: String
        let englishNameTranslation: String
        let revelationType: String
        let ayahs: [APIAyah]
    }
    
    public struct APIAyah: Codable {
        let number: Int
        let text: String
        let numberInSurah: Int
        let juz: Int
        let manzil: Int
        let page: Int
        let ruku: Int
        let hizbQuarter: Int
        let sajda: SajdaInfo?

        // Custom decoding to handle sajda field that can be either boolean false or SajdaInfo object
        private enum CodingKeys: String, CodingKey {
            case number, text, numberInSurah, juz, manzil, page, ruku, hizbQuarter, sajda
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            number = try container.decode(Int.self, forKey: .number)
            text = try container.decode(String.self, forKey: .text)
            numberInSurah = try container.decode(Int.self, forKey: .numberInSurah)
            juz = try container.decode(Int.self, forKey: .juz)
            manzil = try container.decode(Int.self, forKey: .manzil)
            page = try container.decode(Int.self, forKey: .page)
            ruku = try container.decode(Int.self, forKey: .ruku)
            hizbQuarter = try container.decode(Int.self, forKey: .hizbQuarter)

            // Handle sajda field that can be either false (boolean) or SajdaInfo object
            if let sajdaObject = try? container.decode(SajdaInfo.self, forKey: .sajda) {
                sajda = sajdaObject
            } else {
                // If it's a boolean false or any other type, set to nil
                sajda = nil
            }
        }
    }

    public struct SajdaInfo: Codable {
        let id: Int
        let recommended: Bool
        let obligatory: Bool
    }
    
    public struct Edition: Codable {
        let identifier: String
        let language: String
        let name: String
        let englishName: String
        let format: String
        let type: String
    }
    
    // MARK: - Public Methods
    
    /// Fetch complete Quran with Arabic text
    public func fetchCompleteQuranArabic() -> AnyPublisher<QuranAPIResponse, Error> {
        return fetchQuranData(edition: "quran-uthmani")
    }
    
    /// Fetch complete Quran with English translation
    public func fetchCompleteQuranTranslation() -> AnyPublisher<QuranAPIResponse, Error> {
        return fetchQuranData(edition: "en.sahih")
    }
    
    /// Fetch complete Quran with transliteration
    public func fetchCompleteQuranTransliteration() -> AnyPublisher<QuranAPIResponse, Error> {
        return fetchQuranData(edition: "en.transliteration")
    }
    
    /// Fetch combined Quran data (Arabic + Translation + Transliteration)
    public func fetchCompleteQuranCombined() -> AnyPublisher<[QuranVerse], Error> {
        let arabicPublisher = fetchCompleteQuranArabic()
        let translationPublisher = fetchCompleteQuranTranslation()
        let transliterationPublisher = fetchCompleteQuranTransliteration()
        
        return Publishers.Zip3(arabicPublisher, translationPublisher, transliterationPublisher)
            .map { arabicResponse, translationResponse, transliterationResponse in
                return self.combineQuranData(
                    arabic: arabicResponse.data,
                    translation: translationResponse.data,
                    transliteration: transliterationResponse.data
                )
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func fetchQuranData(edition: String) -> AnyPublisher<QuranAPIResponse, Error> {
        guard let url = URL(string: "\(baseURL)/quran/\(edition)") else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: QuranAPIResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    private func combineQuranData(
        arabic: QuranData,
        translation: QuranData,
        transliteration: QuranData
    ) -> [QuranVerse] {
        var combinedVerses: [QuranVerse] = []
        
        for (index, arabicSurah) in arabic.surahs.enumerated() {
            let translationSurah = translation.surahs[index]
            let transliterationSurah = transliteration.surahs[index]
            
            for (ayahIndex, arabicAyah) in arabicSurah.ayahs.enumerated() {
                let translationAyah = translationSurah.ayahs[ayahIndex]
                let transliterationAyah = transliterationSurah.ayahs[ayahIndex]
                
                let verse = QuranVerse(
                    surahNumber: arabicSurah.number,
                    surahName: arabicSurah.englishName,
                    surahNameArabic: arabicSurah.name,
                    verseNumber: arabicAyah.numberInSurah,
                    textArabic: arabicAyah.text,
                    textTranslation: translationAyah.text,
                    textTransliteration: transliterationAyah.text,
                    juz: arabicAyah.juz,
                    page: arabicAyah.page,
                    revelationType: arabicSurah.revelationType,
                    sajda: arabicAyah.sajda != nil
                )
                
                combinedVerses.append(verse)
            }
        }
        
        return combinedVerses
    }
}

// MARK: - QuranVerse Extension for API Integration

extension QuranVerse {
    /// Initialize from API data
    init(
        surahNumber: Int,
        surahName: String,
        surahNameArabic: String,
        verseNumber: Int,
        textArabic: String,
        textTranslation: String,
        textTransliteration: String,
        juz: Int,
        page: Int,
        revelationType: String,
        sajda: Bool
    ) {
        // Convert revelation type string to RevelationPlace enum
        let revelationPlace: RevelationPlace
        if revelationType.lowercased().contains("mecca") || revelationType.lowercased().contains("makk") {
            revelationPlace = .mecca
        } else {
            revelationPlace = .medina
        }
        
        self.init(
            surahNumber: surahNumber,
            surahName: surahName,
            surahNameArabic: surahNameArabic,
            verseNumber: verseNumber,
            textArabic: textArabic,
            textTranslation: textTranslation,
            textTransliteration: textTransliteration,
            revelationPlace: revelationPlace,
            juzNumber: juz,
            hizbNumber: 0, // Default value, can be updated if API provides this
            rukuNumber: 0, // Default value, can be updated if API provides this
            manzilNumber: 0, // Default value, can be updated if API provides this
            pageNumber: page,
            sajda: sajda
        )
    }
}
