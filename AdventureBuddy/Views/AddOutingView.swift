import MapKit
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct AddOutingView: View {
    var outingToEdit: Outing? = nil
    var onSave: (Outing, [Milestone]) -> Void

    @State private var viewModel: AddOutingViewModel
    @State private var selectedPhoto: PhotosPickerItem?

    init(outingToEdit: Outing? = nil, onSave: @escaping (Outing, [Milestone]) -> Void) {
        self.outingToEdit = outingToEdit
        self.onSave = onSave
        _viewModel = State(initialValue: AddOutingViewModel(outing: outingToEdit))
    }

    var body: some View {
        AddOutingForm(
            outingToEdit: outingToEdit,
            onSave: onSave,
            viewModel: viewModel,
            selectedPhoto: $selectedPhoto
        )
    }
}

private struct AddOutingForm: View {
    var outingToEdit: Outing?
    var onSave: (Outing, [Milestone]) -> Void
    @Bindable var viewModel: AddOutingViewModel
    @Binding var selectedPhoto: PhotosPickerItem?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currentDog) private var currentDog
    @State private var isShowingCamera = false

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
                    DatePicker("When", selection: $viewModel.date, displayedComponents: [.date, .hourAndMinute])
                    TextField(
                        "Location name",
                        text: locationNameBinding,
                        prompt: Text("We’ll name this from the pin")
                    )
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
                            viewModel.photoData == nil ? "Choose from library" : "Choose a different photo",
                            systemImage: "photo.on.rectangle.angled"
                        )
                    }

                    if DeviceCamera.isAvailable {
                        TakePhotoButton {
                            isShowingCamera = true
                        }
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

                        if let caption = viewModel.placeCaption {
                            Button(action: viewModel.refreshPlaceName) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    if viewModel.isLookingUpPlace {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "mappin.and.ellipse")
                                    }
                                    Text(caption)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                    Image(systemName: "arrow.clockwise")
                                        .font(.caption.weight(.semibold))
                                }
                                .font(.caption)
                                .foregroundStyle(AdventureTheme.trail)
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isLookingUpPlace)
                            .accessibilityLabel(caption)
                            .accessibilityHint("Looks up the place name for the current pin")
                        }
                    }
                    .listRowBackground(AdventureTheme.sand)
                } header: {
                    Text("Place")
                } footer: {
                    Text("We’ll fill the name from the pin. Type one if the lookup misses.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AdventureTheme.sand)
            .tint(AdventureTheme.ember)
            .navigationTitle(viewModel.navigationTitle)
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
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraPicker(isPresented: $isShowingCamera) { data in
                    selectedPhoto = nil
                    viewModel.photoData = data
                }
                .ignoresSafeArea()
            }
        }
    }

    private var locationNameBinding: Binding<String> {
        Binding(
            get: { viewModel.locationName },
            set: { viewModel.updateLocationNameFromUser($0) }
        )
    }

    private func save() {
        if let outingToEdit {
            guard viewModel.applyChanges(to: outingToEdit) else { return }
            try? modelContext.save()
            let newlyEarned = outingToEdit.dog.map { MilestoneEvaluator.evaluate(dog: $0, in: modelContext) } ?? []
            onSave(outingToEdit, newlyEarned)
            dismiss()
            return
        }

        guard let dog = currentDog,
              let outing = viewModel.makeOuting(dog: dog) else { return }
        modelContext.insert(outing)
        outing.dog = dog
        try? modelContext.save()
        let newlyEarned = MilestoneEvaluator.evaluate(dog: dog, in: modelContext)
        onSave(outing, newlyEarned)
        dismiss()
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }

        guard let data = try? await item.loadTransferable(type: Data.self) else { return }

        viewModel.photoData = JPEGPhoto.data(from: data)
    }
}

#Preview("New") {
    CurrentDogScope {
        AddOutingView { _, _ in }
    }
    .modelContainer(PreviewSupport.container(includeSampleOutings: false))
}

#Preview("Edit") {
    CurrentDogScope {
        AddOutingView(
            outingToEdit: Outing(
                date: .now,
                latitude: 38.7999,
                longitude: -120.0324,
                locationName: "Eagle Peak",
                activityType: "hike",
                notes: "First real climb together."
            )
        ) { _, _ in }
    }
    .modelContainer(PreviewSupport.container())
}
