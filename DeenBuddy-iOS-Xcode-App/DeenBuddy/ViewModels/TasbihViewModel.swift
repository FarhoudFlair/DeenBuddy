import Foundation
import Combine

@MainActor
public final class TasbihViewModel<Service: TasbihServiceProtocol>: ObservableObject {
    @Published public private(set) var currentSession: TasbihSession?
    @Published public private(set) var currentCount: Int = 0
    @Published public private(set) var availableDhikr: [Dhikr] = []
    @Published public private(set) var statistics: TasbihStatistics = .init()
    @Published public var selectedDhikrID: UUID?
    @Published public var targetCount: Int = 33
    @Published public var isLoadingSelection = false
    @Published public var errorMessage: String = ""
    @Published public var showError: Bool = false

    public let service: Service
    private var cancellables = Set<AnyCancellable>()

    public init(service: Service) {
        self.service = service
        bind()
    }

    private func bind() {
        // Initial snapshot
        self.currentSession = service.currentSession
        self.currentCount = service.currentCount
        self.availableDhikr = service.availableDhikr
        self.statistics = service.statistics

        // Observe via Combine (service conforms to ObservableObject)
        service.objectWillChange
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.currentSession = self.service.currentSession
                self.currentCount = self.service.currentCount
                self.availableDhikr = self.service.availableDhikr
                self.statistics = self.service.statistics
            }
            .store(in: &cancellables)
    }

    public func ensureSession() async {
        if let session = service.currentSession {
            selectedDhikrID = session.dhikr.id
            targetCount = session.targetCount
            return
        }

        if let selected = selectedDhikrID,
           let dhikr = service.availableDhikr.first(where: { $0.id == selected }) {
            targetCount = dhikr.targetCount
            await startSession(dhikr: dhikr)
            return
        }

        if let first = service.availableDhikr.first {
            selectedDhikrID = first.id
            targetCount = first.targetCount
            await startSession(dhikr: first)
        }
    }

    public func startSession(dhikr: Dhikr) async {
        do {
            await service.startSession(with: dhikr, targetCount: self.targetCount, counter: service.currentCounter)
            guard service.currentSession != nil else { throw TasbihError.sessionStartFailed }
        } catch {
            present(error)
        }
    }

    public func changeDhikr(to dhikr: Dhikr) async {
        guard !isLoadingSelection else { return }
        isLoadingSelection = true
        defer { isLoadingSelection = false }
        selectedDhikrID = dhikr.id
        targetCount = dhikr.targetCount
        await startSession(dhikr: dhikr)
    }

    public func increment(by value: Int, feedback: Bool = true) async {
        if service.currentSession == nil { await ensureSession() }
        guard service.currentSession != nil else { return }
        do {
            await service.incrementCount(by: value, feedback: feedback)
            if let error = service.error { throw error }
        } catch { present(error) }
    }

    public func completeSession() async {
        guard service.currentSession != nil else { return }
        do {
            await service.completeSession(notes: nil, mood: nil)
            if let error = service.error { throw error }
            await ensureSession()
        } catch { present(error) }
    }

    public func adjustTarget(by delta: Int) async {
        let originalTarget = targetCount
        let newTarget = max(1, targetCount + delta)

        // Update locally first for immediate UI feedback
        targetCount = newTarget

        do {
            await service.updateTargetCount(newTarget)
            // Service call succeeded, keep the local change
        } catch {
            // Service call failed, revert the local change to maintain consistency
            targetCount = originalTarget
            present(error)
            print("⚠️ Failed to update target count in service, reverted local change: \(error.localizedDescription)")
        }
    }

    public func syncStateWithSession() {
        if let session = service.currentSession {
            selectedDhikrID = session.dhikr.id
            targetCount = session.targetCount
        }
    }

    private func present(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }

    public enum TasbihError: LocalizedError {
        case sessionStartFailed
        public var errorDescription: String? {
            switch self {
            case .sessionStartFailed: return "Failed to start session. Please try again."
            }
        }
    }
}





