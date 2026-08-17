import SwiftData
import SwiftUI

@main
struct AdventureBuddyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Dog.self, Outing.self, Milestone.self])
    }
}
