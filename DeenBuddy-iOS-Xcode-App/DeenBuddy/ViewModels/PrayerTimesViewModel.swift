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
        self.prayerTimeService = container.resolve(PrayerTimeServiceProtocol.self)!
        self.locationService = container.resolve(LocationServiceProtocol.self)!
        fetchPrayerTimes()
    }

    func fetchPrayerTimes() {
        isLoading = true
        locationService.requestLocation()
        
        locationService.locationPublisher
            .compactMap { $0 }
            .flatMap { location in
                self.prayerTimeService.fetchPrayerTimes(latitude: location.latitude, longitude: location.longitude)
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = error.localizedDescription
                }
            }, receiveValue: { prayerTimes in
                self.prayerTimes = prayerTimes
            })
            .store(in: &cancellables)
    }
}
