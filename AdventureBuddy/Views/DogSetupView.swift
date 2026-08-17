import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct DogSetupView: View {
    @State private var viewModel = DogSetupViewModel()
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        DogSetupForm(viewModel: viewModel, selectedPhoto: $selectedPhoto)
    }
}

private struct DogSetupForm: View {
    @Bindable var viewModel: DogSetupViewModel
    @Binding var selectedPhoto: PhotosPickerItem?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 10) {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(AdventureTheme.ember)
                            .frame(width: 80, height: 80)
                            .background(AdventureTheme.ember.opacity(0.16), in: Circle())

                        Text("Who’s coming along?")
                            .font(.title.weight(.semibold))
                            .foregroundStyle(AdventureTheme.forest)
                        Text("Add your dog so every walk, hike, and outing has someone to remember it with.")
                            .font(.subheadline)
                            .foregroundStyle(AdventureTheme.trail)
                            .multilineTextAlignment(.center)
                    }

                    photoPicker

                    VStack(spacing: 14) {
                        TextField("Name", text: $viewModel.name, prompt: Text("Scout"))
                            .textContentType(.name)
                            .padding(14)
                            .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        TextField("Breed (optional)", text: $viewModel.breed, prompt: Text("Australian Shepherd"))
                            .padding(14)
                            .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Button(action: save) {
                        Text("Let’s go")
                            .font(.headline)
                            .foregroundStyle(AdventureTheme.sand)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                viewModel.canContinue ? AdventureTheme.ember : AdventureTheme.trail.opacity(0.35),
                                in: Capsule()
                            )
                    }
                    .disabled(!viewModel.canContinue)
                }
                .padding(24)
            }
            .background(AdventureTheme.sand)
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: selectedPhoto) { _, item in
                Task { await loadPhoto(from: item) }
            }
        }
    }

    private var photoPicker: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            ZStack {
                Circle()
                    .fill(AdventureTheme.forest.opacity(0.12))
                    .frame(width: 132, height: 132)

                if let photoData = viewModel.photoData, let image = UIImage(data: photoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 132, height: 132)
                        .clipShape(Circle())
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                        Text("Add a photo")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(AdventureTheme.forest)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add a profile photo")
    }

    private func save() {
        let dog = Dog(
            name: viewModel.trimmedName,
            breed: viewModel.trimmedBreed,
            photoData: viewModel.photoData
        )
        modelContext.insert(dog)
        MilestoneCatalog.seed(into: modelContext, dog: dog)
        try? modelContext.save()
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else {
            viewModel.photoData = nil
            return
        }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        if let image = UIImage(data: data) {
            viewModel.photoData = image.jpegData(compressionQuality: 0.82)
        } else {
            viewModel.photoData = data
        }
    }
}

#Preview {
    DogSetupView()
        .modelContainer(for: [Dog.self, Outing.self, Milestone.self], inMemory: true)
}
