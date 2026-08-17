import MapKit
import SwiftData
import SwiftUI
import UIKit

struct OutingDetailView: View {
    let outing: Outing

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var isConfirmingDelete = false
    @State private var isViewingPhoto = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroPhoto

                VStack(alignment: .leading, spacing: 10) {
                    Text(outing.locationName)
                        .font(.title.weight(.semibold))
                        .foregroundStyle(AdventureTheme.forest)

                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            outing.detailDateText,
                            systemImage: "calendar"
                        )
                        Label(outing.activityTitle, systemImage: outing.activitySymbolName)
                        OutingDistanceLabel(outing: outing)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AdventureTheme.trail)
                }

                miniMap

                if let notes = outing.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                            .foregroundStyle(AdventureTheme.forest)
                        Text(notes)
                            .font(.body)
                            .foregroundStyle(AdventureTheme.trail)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AdventureTheme.ember.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Button("Delete outing", role: .destructive) {
                    isConfirmingDelete = true
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AdventureTheme.trail.opacity(0.08), in: Capsule())
            }
            .padding(20)
        }
        .background(AdventureTheme.sand)
        .navigationTitle(outing.activityTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
                    .fontWeight(.semibold)
                    .foregroundStyle(AdventureTheme.ember)
            }
        }
        .sheet(isPresented: $isEditing) {
            AddOutingView(outingToEdit: outing) { _, _ in }
        }
        .fullScreenCover(isPresented: $isViewingPhoto) {
            OutingPhotoViewer(outing: outing)
        }
        .confirmationDialog(
            "Delete this outing?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete outing", role: .destructive, action: deleteOuting)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“\(outing.locationName)” will be removed from the map and log. This can’t be undone.")
        }
    }

    @ViewBuilder
    private var heroPhoto: some View {
        let photo = OutingPhotoView(outing: outing, style: .hero)
        if outing.photoData != nil {
            Button {
                isViewingPhoto = true
            } label: {
                photo
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AdventureTheme.sand)
                            .padding(8)
                            .background(AdventureTheme.forest.opacity(0.72), in: Circle())
                            .padding(10)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Photo from \(outing.locationName)")
            .accessibilityHint("Opens the photo full screen")
        } else {
            photo
        }
    }

    private var miniMap: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Place")
                .font(.headline)
                .foregroundStyle(AdventureTheme.forest)

            Map(position: .constant(.region(miniMapRegion)), interactionModes: []) {
                Annotation(outing.locationName, coordinate: outing.coordinate, anchor: .bottom) {
                    OutingMapPin(symbolName: outing.activitySymbolName, isSelected: true)
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .frame(height: 176)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: AdventureTheme.trail.opacity(0.16), radius: 8, y: 3)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Map showing \(outing.locationName)")
        }
    }

    private var miniMapRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: outing.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        )
    }

    private func deleteOuting() {
        let dog = outing.dog
        modelContext.delete(outing)
        try? modelContext.save()
        if let dog {
            MilestoneEvaluator.evaluate(dog: dog, in: modelContext)
        }
        dismiss()
    }
}

private struct OutingPhotoViewer: View {
    let outing: Outing

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var gestureScale: CGFloat = 1

    var body: some View {
        ZStack {
            AdventureTheme.forest.ignoresSafeArea()

            if let image = outing.photoImage {
                image
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale * gestureScale)
                    .gesture(magnifyGesture)
                    .onTapGesture(count: 2) {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            scale = 1
                            gestureScale = 1
                        }
                    }
                    .accessibilityLabel("Photo from \(outing.locationName)")
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AdventureTheme.sand)
                            .frame(width: 36, height: 36)
                            .background(AdventureTheme.ember, in: Circle())
                    }
                    .accessibilityLabel("Close photo")
                }
                Spacer()
            }
            .padding(20)
        }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                gestureScale = value
            }
            .onEnded { value in
                scale = min(max(scale * value, 1), 4)
                gestureScale = 1
            }
    }
}

struct OutingPhotoView: View {
    enum Style {
        case thumbnail
        case hero
    }

    let outing: Outing
    var style: Style = .thumbnail

    var body: some View {
        Group {
            if let image = outing.photoImage {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [AdventureTheme.forest, AdventureTheme.trail],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: outing.activitySymbolName)
                        .font(.system(size: style == .hero ? 42 : 20, weight: .semibold))
                        .foregroundStyle(AdventureTheme.sand)
                }
            }
        }
        .frame(width: style == .thumbnail ? 64 : nil, height: style == .hero ? 220 : 64)
        .frame(maxWidth: style == .hero ? .infinity : nil)
        .clipShape(RoundedRectangle(cornerRadius: style == .hero ? 22 : 14, style: .continuous))
        .shadow(color: AdventureTheme.trail.opacity(style == .hero ? 0.18 : 0.12), radius: style == .hero ? 10 : 3, y: 3)
        .accessibilityHidden(style == .thumbnail)
        .accessibilityLabel("Photo from \(outing.locationName)")
    }
}

private extension Outing {
    var photoImage: Image? {
        guard let photoData, let uiImage = UIImage(data: photoData) else { return nil }
        return Image(uiImage: uiImage)
    }
}

#Preview {
    NavigationStack {
        OutingDetailView(
            outing: Outing(
                date: .now,
                latitude: 38.7999,
                longitude: -120.0324,
                locationName: "Eagle Peak",
                activityType: "hike",
                notes: "First real climb together."
            )
        )
    }
    .modelContainer(PreviewSupport.container())
}
