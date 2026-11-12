import Foundation
import Observation

@Observable
final class TimerStore {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key = "timer.startedAt"

    private(set) var startedAt: Date?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.double(forKey: key)
        self.startedAt = stored > 0 ? Date(timeIntervalSince1970: stored) : nil
    }

    var isRunning: Bool { startedAt != nil }

    func start() {
        let now = Date.now
        startedAt = now
        defaults.set(now.timeIntervalSince1970, forKey: key)
    }

    func clear() {
        startedAt = nil
        defaults.removeObject(forKey: key)
    }
}
