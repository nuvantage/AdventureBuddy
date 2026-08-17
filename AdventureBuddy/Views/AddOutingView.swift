import MapKit
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct AddOutingView: View {
    var onSave: (Outing) -> Void

    @State private var viewModel = AddOutingViewModel()
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        AddOutingForm(
            onSave: onSave,
            viewModel: viewModel,
            selectedPhoto: $selectedPhoto
        )
    }
}

private struct AddOutingForm: View {
    var onSave: (Outing) -> Void
    @Bindable var viewModel: AddOutingViewModel
    @Binding var selectedPhoto: PhotosPickerItem?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var dogs: [Dog]

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    Picker("Activity type", selection: $viewModel.activity) {
                        ForEach(Outing.Activity.allCases) { activity in
                            Label(activity.title, systemImage: activity.symbolName)
                                .tag(activity)
                        }
                    }
                }

                Section("Details") {
                    DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                    TextField("Location name", text: $viewModel.locationName, prompt: Text("Riverside Trail"))
                    TextField(
                        "Notes (optional)",
                        text: $viewModel.notes,
                        prompt: Text("A favorite stick, the long way home…"),
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }

                Section("Photo") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(
                            viewModel.photoData == nil ? "Add a photo" : "Choose a different photo",
                            systemImage: "photo.on.rectangle.angled"
                        )
                    }

                    if let photoData = viewModel.photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, minHeight: 140, maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                        Button("Remove photo", role: .destructive) {
                            selectedPhoto = nil
                            viewModel.photoData = nil
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(viewModel.hasPlacedPin
                             ? "Pan the map to move the pin, or use where you are now."
                             : "We’ll drop a pin using your current location, or you can pan the map to mark a past outing.")
                            .font(.subheadline)
                            .foregroundStyle(AdventureTheme.trail)

                        ZStack {
                            Map(position: $viewModel.cameraPosition)
                                .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
                                .onMapCameraChange(frequency: .onEnd) { context in
                                    viewModel.updatePinFromCamera(context.camera.centerCoordinate)
                                }

                            OutingMapPin(symbolName: viewModel.activity.symbolName, isSelected: true)
                                .allowsHitTesting(false)
                                .offset(y: -12)
                        }
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        Button(action: viewModel.useCurrentLocation) {
                            Label("Use current location", systemImage: "location.fill")
                                .font(.subheadline.weight(.semibold))
                        }
                        .disabled(!viewModel.isLocationAuthorized && viewModel.authorizationStatus != .notDetermined)
                    }
                    .listRowBackground(AdventureTheme.sand)
                } header: {
                    Text("Place")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AdventureTheme.sand)
            .tint(AdventureTheme.ember)
            .navigationTitle("New outing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!viewModel.canSave)
                }
            }
            .onAppear(perform: viewModel.onAppear)
            .onChange(of: selectedPhoto) { _, item in
                Task { await loadPhoto(from: item) }
            }
        }
    }

    private func save() {
        guard let dog = dogs.first,
              let outing = viewModel.makeOuting(dog: dog) else { return }
        modelContext.insert(outing)
        try? modelContext.save()
        onSave(outing)
        dismiss()
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
    AddOutingView { _ in }
        .modelContainer(PreviewSupport.container(includeSampleOutings: false))
}
