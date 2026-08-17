import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case map
    case log
    case settings
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .map
    @State private var isAddingOuting = false
    @State private var outingToFocusID: PersistentIdentifier?

    var body: some View {
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
        .sheet(isPresented: $isAddingOuting) {
            AddOutingView { outing in
                selectedTab = .map
                outingToFocusID = outing.persistentModelID
            }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(PreviewSupport.container())
}
