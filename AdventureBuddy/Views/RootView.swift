import SwiftData
import SwiftUI

struct RootView: View {
    @Query(sort: \Dog.createdAt) private var dogs: [Dog]

    var body: some View {
        if let companion = CurrentDog.resolve(from: dogs) {
            MainTabView()
                .environment(\.currentDog, companion)
        } else {
            DogSetupView()
        }
    }
}

#Preview("Setup") {
    RootView()
        .modelContainer(for: [Dog.self, Outing.self, Milestone.self], inMemory: true)
}

#Preview("Main") {
    RootView()
        .modelContainer(PreviewSupport.container())
}
