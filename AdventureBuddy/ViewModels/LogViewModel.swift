import Foundation
import Observation

@MainActor
@Observable
final class LogViewModel {
    static let allFilterValue = "all"

    var searchText = ""
    var activityFilterRaw: String {
        didSet { defaults.set(activityFilterRaw, forKey: AppPreferences.logActivityFilterKey) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: AppPreferences.logActivityFilterKey) ?? Self.allFilterValue
        if stored == Self.allFilterValue || Outing.Activity(rawValue: stored) != nil {
            self.activityFilterRaw = stored
        } else {
            self.activityFilterRaw = Self.allFilterValue
        }
    }

    var selectedActivity: Outing.Activity? {
        get { Outing.Activity(rawValue: activityFilterRaw) }
        set { activityFilterRaw = newValue?.rawValue ?? Self.allFilterValue }
    }

    var isShowingAllActivities: Bool {
        selectedActivity == nil
    }

    func filtered(_ outings: [Outing]) -> [Outing] {
        outings.filter(matches)
    }

    private func matches(_ outing: Outing) -> Bool {
        if let selectedActivity,
           outing.activityType.lowercased() != selectedActivity.rawValue {
            return false
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        if outing.locationName.localizedCaseInsensitiveContains(query) {
            return true
        }
        if let notes = outing.notes, notes.localizedCaseInsensitiveContains(query) {
            return true
        }
        return false
    }
}
