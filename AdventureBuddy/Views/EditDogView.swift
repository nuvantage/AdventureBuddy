import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct EditDogView: View {
    let dog: Dog

    @State private var viewModel: DogSetupViewModel
    @State private var selectedPhoto: PhotosPickerItem?

    init(dog: Dog) {
        self.dog = dog
        _viewModel = State(initialValue: DogSetupViewModel(dog: dog))
    }

    var body: some View {
        EditDogForm(dog: dog, viewModel: viewModel, selectedPhoto: $selectedPhoto)
    }
}

private struct EditDogForm: View {
    let dog: Dog
    @Bindable var viewModel: DogSetupViewModel
    @Binding var selectedPhoto: PhotosPickerItem?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isShowingCamera = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(AdventureTheme.ember)
                        .frame(width: 80, height: 80)
                        .background(AdventureTheme.ember.opacity(0.16), in: Circle())

                    Text("Your companion")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(AdventureTheme.forest)
                    Text("Update their name, breed, birthday, or photo. This stays with the same profile — no new dog is created.")
                        .font(.subheadline)
                        .foregroundStyle(AdventureTheme.trail)
                        .multilineTextAlignment(.center)
                }

                photoControls

                VStack(spacing: 14) {
                    TextField("Name", text: $viewModel.name, prompt: Text("Scout"))
                        .textContentType(.name)
                        .padding(14)
                        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    TextField("Breed (optional)", text: $viewModel.breed, prompt: Text("Australian Shepherd"))
                        .padding(14)
                        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    DogBirthdayField(viewModel: viewModel)
                }

                if viewModel.photoData != nil {
                    Button("Remove photo", role: .destructive) {
                        selectedPhoto = nil
                        viewModel.photoData = nil
                    }
                    .font(.subheadline.weight(.semibold))
                }

                Button(action: save) {
                    Text("Save changes")
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
        .navigationTitle("Companion")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhoto) { _, item in
            Task { await loadPhoto(from: item) }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker(isPresented: $isShowingCamera) { data in
                selectedPhoto = nil
                viewModel.photoData = data
            }
            .ignoresSafeArea()
        }
    }

    private var photoControls: some View {
        VStack(spacing: 10) {
            photoPicker
            if DeviceCamera.isAvailable {
                TakePhotoButton {
                    isShowingCamera = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AdventureTheme.ember)
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
        .accessibilityLabel("Change profile photo")
    }

    private func save() {
        dog.name = viewModel.trimmedName
        dog.breed = viewModel.trimmedBreed
        dog.birthdate = viewModel.selectedBirthdate
        dog.photoData = viewModel.photoData
        try? modelContext.save()
        dismiss()
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        viewModel.photoData = JPEGPhoto.data(from: data)
    }
}

#Preview {
    NavigationStack {
        EditDogView(dog: Dog(name: "Scout", breed: "Australian Shepherd"))
    }
    .modelContainer(PreviewSupport.container(includeSampleOutings: false))
}
