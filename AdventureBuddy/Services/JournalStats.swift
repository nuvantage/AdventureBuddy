import Foundation

struct JournalStats {
    let outingCount: Int
    let distinctPlaceCount: Int
    let firstOutingDate: Date?
    let lastOutingDate: Date?
    let activityCounts: [(activity: Outing.Activity, count: Int)]

    var hasOutings: Bool { outingCount > 0 }

    /// Recap of saved outings for one dog. Place names use the same trimmed,
    /// lowercase key as the ten-places milestone. No GPS mileage is included.
    static func from(outings: [Outing]) -> JournalStats {
        var placeKeys = Set<String>()
        var counts: [Outing.Activity: Int] = [:]
        var firstDate: Date?
        var lastDate: Date?

        for outing in outings {
            if let key = outing.distinctLocationKey {
                placeKeys.insert(key)
            }

            let activity = Outing.Activity(rawValue: outing.activityType.lowercased()) ?? .other
            counts[activity, default: 0] += 1

            if let currentFirst = firstDate {
                if outing.date < currentFirst { firstDate = outing.date }
            } else {
                firstDate = outing.date
            }

            if let currentLast = lastDate {
                if outing.date > currentLast { lastDate = outing.date }
            } else {
                lastDate = outing.date
            }
        }

        let breakdown = Outing.Activity.allCases.compactMap { activity -> (Outing.Activity, Int)? in
            let count = counts[activity] ?? 0
            return count > 0 ? (activity, count) : nil
        }

        return JournalStats(
            outingCount: outings.count,
            distinctPlaceCount: placeKeys.count,
            firstOutingDate: firstDate,
            lastOutingDate: lastDate,
            activityCounts: breakdown
        )
    }
}
