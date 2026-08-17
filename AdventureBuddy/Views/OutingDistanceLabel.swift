import SwiftData
import SwiftUI

struct OutingDistanceLabel: View {
    let outing: Outing
    var compact = false

    @Query(sort: \Outing.date) private var outings: [Outing]
    @AppStorage(AppPreferences.usesMetricKey) private var usesMetric = false

    var body: some View {
        if let text = OutingDistance.label(
            from: outing,
            among: outings,
            usesMetric: usesMetric,
            compact: compact
        ) {
            Label(text, systemImage: "mappin")
                .accessibilityLabel(text)
                .accessibilityHint("Straight line to the next pin, not a walking route")
        }
    }
}
