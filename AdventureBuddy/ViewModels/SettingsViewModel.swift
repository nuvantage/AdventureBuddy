import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    private let defaults: UserDefaults

    var usesMetric: Bool {
        didSet { defaults.set(usesMetric, forKey: AppPreferences.usesMetricKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.usesMetric = defaults.bool(forKey: AppPreferences.usesMetricKey)
    }
}
