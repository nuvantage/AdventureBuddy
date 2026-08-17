import Foundation
import SwiftData

/// Evaluates catalog milestones for a dog from their saved outings.
///
/// Time-of-day awards (golden hour, early morning) are intentionally omitted:
/// outing dates are stored with a date picker that does not capture a reliable
/// time of day.
///
/// Rules:
/// - `first-walk`: first outing whose `activityType` is `walk` (case-insensitive).
/// - `first-hike`: first outing whose `activityType` is `hike` (case-insensitive).
/// - `first-park`: first outing whose `activityType` is `park` (case-insensitive).
/// - `first-beach`: first outing whose `activityType` is `beach` (case-insensitive).
/// - `first-trip`: first outing whose `activityType` is `trip` (case-insensitive).
/// - `ten-outings`: earned on the 10th outing, ordered by date.
/// - `ten-places`: 10 distinct location names (trimmed, case-insensitive).
/// - `first-snow`: keyword-only — never weather APIs, GPS snow cover, or calendar
///   winter. An outing counts when the location name or notes mention a snow
///   keyword (snow, snowy, snowfall, blizzard, powder, sleet, whiteout).
///   A December–February hike, walk, or trip without those words does not count.
///
/// `dateEarned` is set once, using the qualifying outing’s date, and is never cleared
/// if later outings are edited or deleted. A hike remains “first hike” even if that
/// outing is later removed.
enum MilestoneEvaluator {
    static let firstWalkID = "first-walk"
    static let firstHikeID = "first-hike"
    static let firstParkID = "first-park"
    static let firstBeachID = "first-beach"
    static let firstTripID = "first-trip"
    static let tenOutingsID = "ten-outings"
    static let tenPlacesID = "ten-places"
    static let firstSnowID = "first-snow"

    private static let snowKeywords = [
        "snow", "snowy", "snowfall", "blizzard", "powder", "sleet", "whiteout"
    ]

    /// Returns milestones newly earned in this pass.
    @MainActor
    @discardableResult
    static func evaluate(dog: Dog, in context: ModelContext) -> [Milestone] {
        let outings = outings(for: dog, in: context)
        var newlyEarned: [Milestone] = []

        func earn(catalogID: String, on date: Date) {
            guard let milestone = milestone(catalogID: catalogID, dog: dog, in: context),
                  milestone.dateEarned == nil else { return }
            milestone.dateEarned = date
            newlyEarned.append(milestone)
        }

        if let firstWalk = firstOuting(with: .walk, in: outings) {
            earn(catalogID: firstWalkID, on: firstWalk.date)
        }
        if let firstHike = firstOuting(with: .hike, in: outings) {
            earn(catalogID: firstHikeID, on: firstHike.date)
        }
        if let firstPark = firstOuting(with: .park, in: outings) {
            earn(catalogID: firstParkID, on: firstPark.date)
        }
        if let firstBeach = firstOuting(with: .beach, in: outings) {
            earn(catalogID: firstBeachID, on: firstBeach.date)
        }
        if let firstTrip = firstOuting(with: .trip, in: outings) {
            earn(catalogID: firstTripID, on: firstTrip.date)
        }

        if let tenthOutingDate = dateReachingOutingCount(10, in: outings) {
            earn(catalogID: tenOutingsID, on: tenthOutingDate)
        }

        if let tenthPlaceDate = dateReachingTenPlaces(in: outings) {
            earn(catalogID: tenPlacesID, on: tenthPlaceDate)
        }

        if let firstSnow = outings
            .filter(isSnowOuting)
            .min(by: { $0.date < $1.date })
        {
            earn(catalogID: firstSnowID, on: firstSnow.date)
        }

        if !newlyEarned.isEmpty {
            try? context.save()
        }

        return newlyEarned
    }

    /// Merges the relationship with a fetch so a just-saved outing is included
    /// even if one of those paths has not materialized yet.
    private static func outings(for dog: Dog, in context: ModelContext) -> [Outing] {
        let dogID = dog.persistentModelID
        let fetched = ((try? context.fetch(FetchDescriptor<Outing>())) ?? [])
            .filter { $0.dog?.persistentModelID == dogID }

        var seen = Set<PersistentIdentifier>()
        var result: [Outing] = []
        for outing in fetched + dog.outings {
            if seen.insert(outing.persistentModelID).inserted {
                result.append(outing)
            }
        }
        return result
    }

    private static func milestone(catalogID: String, dog: Dog, in context: ModelContext) -> Milestone? {
        if let local = dog.milestones.first(where: { $0.catalogID == catalogID }) {
            return local
        }
        let dogID = dog.persistentModelID
        return ((try? context.fetch(FetchDescriptor<Milestone>())) ?? [])
            .first { $0.catalogID == catalogID && $0.dog?.persistentModelID == dogID }
    }

    private static func firstOuting(with activity: Outing.Activity, in outings: [Outing]) -> Outing? {
        outings
            .filter { $0.activityType.lowercased() == activity.rawValue }
            .min(by: { $0.date < $1.date })
    }

    private static func dateReachingOutingCount(_ count: Int, in outings: [Outing]) -> Date? {
        guard count > 0 else { return nil }
        let ordered = outings.sorted { $0.date < $1.date }
        guard ordered.count >= count else { return nil }
        return ordered[count - 1].date
    }

    private static func dateReachingTenPlaces(in outings: [Outing]) -> Date? {
        var seen = Set<String>()
        for outing in outings.sorted(by: { $0.date < $1.date }) {
            guard let key = outing.distinctLocationKey else { continue }
            if seen.insert(key).inserted, seen.count == 10 {
                return outing.date
            }
        }
        return nil
    }

    static func isSnowOuting(_ outing: Outing) -> Bool {
        textMentionsSnow(outing.locationName) || textMentionsSnow(outing.notes ?? "")
    }

    private static func textMentionsSnow(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return snowKeywords.contains { lowered.contains($0) }
    }
}
