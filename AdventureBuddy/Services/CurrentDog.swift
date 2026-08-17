import SwiftData
import SwiftUI

/// The one companion Adventure Buddy keeps on this device.
/// Does not create a dog, show a picker, or support a household.
enum CurrentDog {
    /// Oldest stored companion (first / only). `nil` if setup has not happened.
    static func resolve(from dogs: [Dog]) -> Dog? {
        dogs.min { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    /// Fetch-only lookup. Never inserts.
    @MainActor
    static func resolve(in context: ModelContext) -> Dog? {
        var descriptor = FetchDescriptor<Dog>(
            sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func outings(_ outings: [Outing], for dog: Dog?) -> [Outing] {
        guard let dog else { return [] }
        let id = dog.persistentModelID
        return outings.filter { $0.dog?.persistentModelID == id }
    }
}

private struct CurrentDogEnvironmentKey: EnvironmentKey {
    static let defaultValue: Dog? = nil
}

extension EnvironmentValues {
    var currentDog: Dog? {
        get { self[CurrentDogEnvironmentKey.self] }
        set { self[CurrentDogEnvironmentKey.self] = newValue }
    }
}

/// For previews that are not rooted in `RootView`. Live app injects from `RootView`.
struct CurrentDogScope<Content: View>: View {
    @Query(sort: \Dog.createdAt) private var dogs: [Dog]
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .environment(\.currentDog, CurrentDog.resolve(from: dogs))
    }
}
