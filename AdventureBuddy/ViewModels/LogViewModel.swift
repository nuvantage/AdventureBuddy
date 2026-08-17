import Foundation
import Observation

@MainActor
@Observable
final class LogViewModel {
    var chronologicalOutings: [Outing]

    init(outings: [Outing] = []) {
        self.chronologicalOutings = outings.sorted { $0.date > $1.date }
    }
}
