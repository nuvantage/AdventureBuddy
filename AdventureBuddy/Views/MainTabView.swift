import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case map
    case log
    case settings
}

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currentDog) private var currentDog
    @State private var selectedTab: AppTab = .map
    @State private var isAddingOuting = false
    @State private var outingToFocusID: PersistentIdentifier?
    @State private var pendingCelebration: [Milestone] = []
    @State private var celebrationMilestones: [Milestone] = []

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                MapView(outingToFocusID: $outingToFocusID, onAddOuting: { isAddingOuting = true })
                    .tabItem {
                        Label("Map", systemImage: "map.fill")
                    }
                    .tag(AppTab.map)

                LogView()
                    .tabItem {
                        Label("Log", systemImage: "book.pages.fill")
                    }
                    .tag(AppTab.log)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(AppTab.settings)
            }
            .tint(AdventureTheme.ember)

            if !celebrationMilestones.isEmpty {
                MilestoneCelebrationView(milestones: celebrationMilestones) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        celebrationMilestones = []
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: celebrationMilestones.isEmpty)
        .sheet(isPresented: $isAddingOuting) {
            AddOutingView { outing, newlyEarned in
                selectedTab = .map
                outingToFocusID = outing.persistentModelID
                pendingCelebration = newlyEarned
            }
        }
        .onChange(of: isAddingOuting) { _, isPresented in
            guard !isPresented, !pendingCelebration.isEmpty else { return }
            withAnimation(.easeInOut(duration: 0.28)) {
                celebrationMilestones = pendingCelebration
            }
            pendingCelebration = []
        }
        .onAppear {
            guard let dog = currentDog else { return }
            MilestoneCatalog.seed(into: modelContext, dog: dog)
            try? modelContext.save()
            MilestoneEvaluator.evaluate(dog: dog, in: modelContext)
        }
    }
}

#Preview {
    CurrentDogScope {
        MainTabView()
    }
    .modelContainer(PreviewSupport.container())
}
