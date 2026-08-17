import SwiftData
import SwiftUI

struct RootView: View {
    @Query private var dogs: [Dog]

    var body: some View {
        if dogs.isEmpty {
            DogSetupView()
        } else {
            MainTabView()
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
