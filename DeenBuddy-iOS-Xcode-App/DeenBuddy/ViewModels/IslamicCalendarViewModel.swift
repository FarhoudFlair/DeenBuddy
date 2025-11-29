import SwiftUI
import Combine
import CoreLocation

/// ViewModel for the Islamic Calendar & Future Prayer Times screen
/// Manages prayer time calculations, Islamic events, and user interaction state
@MainActor
public class IslamicCalendarViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published public var selectedDate: Date = Date()
    @Published public var prayerTimeResult: FuturePrayerTimeResult?
    @Published public var islamicEvents: [IslamicEventEstimate] = []
    @Published public var isLoading = false
    @Published public var error: AppError?
    @Published public var showDisclaimer = true
    @Published public var showHighLatitudeWarning = false
    @Published public var lastSuccessfulDate: Date = Date()

    // MARK: - Computed Properties

    public var disclaimerLevel: DisclaimerLevel {
        guard let result = prayerTimeResult else { return .today }
        return result.disclaimerLevel
    }

    public var disclaimerVariant: DisclaimerBanner.Variant {
        switch disclaimerLevel {
        case .today:
            return .shortTerm  // Won't be shown anyway
        case .shortTerm:
            return .shortTerm
        case .mediumTerm, .longTerm:
            return .mediumTerm
        }
    }

    public var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    public var eventOnSelectedDate: IslamicEventEstimate? {
        islamicEvents.first { event in
            Calendar.current.isDate(event.estimatedDate, inSameDayAs: selectedDate)
        }
    }

    public var maxLookaheadDate: Date {
        let maxMonths = settingsService.maxLookaheadMonths
        return Calendar.current.date(byAdding: .month, value: maxMonths, to: Date()) ?? Date.distantFuture
    }

    public var calculationMethod: CalculationMethod {
        settingsService.calculationMethod
    }

    public var madhab: Madhab {
        settingsService.madhab
    }

    // MARK: - Dependencies

    private let prayerTimeService: any PrayerTimeServiceProtocol
    private let islamicCalendarService: any IslamicCalendarServiceProtocol
    private let locationService: any LocationServiceProtocol
    private let settingsService: any SettingsServiceProtocol

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init(
        prayerTimeService: any PrayerTimeServiceProtocol,
        islamicCalendarService: any IslamicCalendarServiceProtocol,
        locationService: any LocationServiceProtocol,
        settingsService: any SettingsServiceProtocol
    ) {
        self.prayerTimeService = prayerTimeService
        self.islamicCalendarService = islamicCalendarService
        self.locationService = locationService
        self.settingsService = settingsService

        setupObservers()
    }

    // MARK: - Public Methods

    public func onAppear() {
        Task {
            await loadAllData()
        }
    }

    public func selectToday() {
        selectedDate = Date()
    }

    public func retry() {
        error = nil
        Task { @MainActor in
            selectedDate = lastSuccessfulDate
            await loadPrayerTimes()
        }
    }

    // MARK: - Private Methods

    private func loadAllData() async {
        await loadPrayerTimes()
        await loadIslamicEvents()
    }

    private func loadPrayerTimes() async {
        isLoading = true
        error = nil

        do {
            // Prefer cached location; fall back to cached+fresh
            let location: CLLocation
            if let cached = locationService.currentLocation {
                location = cached
            } else if let cachedPrefer = try? await locationService.getLocationPreferCached() {
                location = cachedPrefer
            } else {
                location = try await locationService.requestLocation()
            }

            let result = try await prayerTimeService.getFuturePrayerTimes(
                for: selectedDate,
                location: location
            )

            prayerTimeResult = result
            lastSuccessfulDate = selectedDate
            showHighLatitudeWarning = result.isHighLatitude
            isLoading = false
        } catch {
            if let appError = error as? AppError {
                self.error = appError
            } else if error is LocationError {
                self.error = .locationUnavailable
            } else if let prayerError = error as? PrayerTimeError {
                self.error = .serviceUnavailable(prayerError.localizedDescription)
            } else if let apiError = error as? APIError {
                self.error = .serviceUnavailable(apiError.localizedDescription)
            } else {
                self.error = .unknownError(error)
            }
            isLoading = false
        }
    }

    private func loadIslamicEvents() async {
        let hijriYear = HijriDate(from: selectedDate).year

        async let ramadan = islamicCalendarService.estimateRamadanDates(for: hijriYear)
        async let eidFitr = islamicCalendarService.estimateEidAlFitr(for: hijriYear)
        async let eidAdha = islamicCalendarService.estimateEidAlAdha(for: hijriYear)

        var events: [IslamicEventEstimate] = []

        if let ramadanInterval = await ramadan {
            events.append(IslamicEventEstimate(
                event: IslamicEvent.ramadanStart,
                estimatedDate: ramadanInterval.start,
                hijriDate: HijriDate(from: ramadanInterval.start),
                confidenceLevel: islamicCalendarService.getEventConfidence(for: ramadanInterval.start)
            ))
        }

        if let fitrDate = await eidFitr {
            events.append(IslamicEventEstimate(
                event: IslamicEvent.eidAlFitr,
                estimatedDate: fitrDate,
                hijriDate: HijriDate(from: fitrDate),
                confidenceLevel: islamicCalendarService.getEventConfidence(for: fitrDate)
            ))
        }

        if let adhaDate = await eidAdha {
            events.append(IslamicEventEstimate(
                event: IslamicEvent.eidAlAdha,
                estimatedDate: adhaDate,
                hijriDate: HijriDate(from: adhaDate),
                confidenceLevel: islamicCalendarService.getEventConfidence(for: adhaDate)
            ))
        }

        islamicEvents = events
    }

    // MARK: - Observation

    private func setupObservers() {
        // React to date changes
        $selectedDate
            .dropFirst()
            .debounce(for: 0.3, scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadPrayerTimes()
                }
            }
            .store(in: &cancellables)
    }
}
