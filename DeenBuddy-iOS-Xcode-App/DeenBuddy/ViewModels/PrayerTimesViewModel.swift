//
//  PrayerTimesViewModel.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-04.
//

import Foundation
import Combine
import DeenAssistCore

class PrayerTimesViewModel: ObservableObject {
    @Published var prayerTimes: PrayerTimes?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var prayerTimeService: PrayerTimeServiceProtocol
    private var locationService: LocationServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(container: DependencyContainer) {
        guard let prayerTimeService = container.resolve(PrayerTimeServiceProtocol.self),
              let locationService = container.resolve(LocationServiceProtocol.self) else {
            self.prayerTimeService = DummyPrayerTimeService()
            self.locationService = DummyLocationService()
            self.errorMessage = "Dependency resolution failed. Please restart the app or contact support."
            return
        }
        self.prayerTimeService = prayerTimeService
        self.locationService = locationService
        fetchPrayerTimes()
    }

    convenience init() {
        self.init(container: DependencyContainer.shared)
    }

    func fetchPrayerTimes() {
        isLoading = true
        locationService.requestLocation()
        
        locationService.locationPublisher
            .compactMap { $0 }
            .flatMap { location in
                self.prayerTimeService.fetchPrayerTimes(latitude: location.latitude, longitude: location.longitude)
                    .retry(2)
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                self.isLoading = false
                if case .failure(let error) = completion {
                    if let prayerError = error as? PrayerTimeError {
                        self.errorMessage = prayerError.errorDescription ?? "An error occurred."
                    } else if let localized = error as? LocalizedError, let desc = localized.errorDescription {
                        self.errorMessage = desc
                    } else {
                        self.errorMessage = "Failed to fetch prayer times. Please try again."
                    }
                }
            }, receiveValue: { prayerTimes in
                self.prayerTimes = prayerTimes
            })
            .store(in: &cancellables)
    }
}

// MARK: - Dummy Services for Fallback

private class DummyPrayerTimeService: PrayerTimeServiceProtocol {
    func fetchPrayerTimes(latitude: Double, longitude: Double) -> AnyPublisher<PrayerTimes, Error> {
        return Fail(error: NSError(domain: "DummyPrayerTimeService", code: -1, userInfo: nil)).eraseToAnyPublisher()
    }
}

private class DummyLocationService: LocationServiceProtocol {
    var locationPublisher: AnyPublisher<Location, Never> {
        Empty().eraseToAnyPublisher()
    }
    func requestLocation() {}
}
