import SwiftData
import SwiftUI
import UIKit

struct SettingsView: View {
    @Query private var dogs: [Dog]
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            List {
                Section("Companion") {
                    if let dog = dogs.first {
                        HStack(spacing: 14) {
                            dogPhoto(dog)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(dog.name)
                                    .font(.headline)
                                    .foregroundStyle(AdventureTheme.forest)
                                Text(dog.breed ?? "Breed not set")
                                    .font(.subheadline)
                                    .foregroundStyle(AdventureTheme.trail)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Label("No dog profile yet", systemImage: "pawprint.fill")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Preferences") {
                    Picker("Distance units", selection: $viewModel.usesMetric) {
                        Text("Miles").tag(false)
                        Text("Kilometers").tag(true)
                    }
                }

                Section("About") {
                    LabeledContent("App", value: "Adventure Buddy")
                    LabeledContent("Status", value: "Early development")
                }
            }
            .navigationTitle("Settings")
        }
    }

    @ViewBuilder
    private func dogPhoto(_ dog: Dog) -> some View {
        if let photoData = dog.photoData, let image = UIImage(data: photoData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(Circle())
        } else {
            Image(systemName: "pawprint.fill")
                .foregroundStyle(AdventureTheme.sand)
                .frame(width: 56, height: 56)
                .background(AdventureTheme.forest, in: Circle())
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(PreviewSupport.container(includeSampleOutings: false))
}
