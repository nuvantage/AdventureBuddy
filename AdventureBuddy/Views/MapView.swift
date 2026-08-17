import MapKit
import SwiftData
import SwiftUI
import UIKit

struct MapView: View {
    @Query(sort: \Outing.date) private var allOutings: [Outing]
    @Binding var outingToFocusID: PersistentIdentifier?
    var onAddOuting: () -> Void

    @Environment(\.currentDog) private var currentDog
    @State private var viewModel = MapViewModel()
    @State private var isEditingSelectedOuting = false
    @State private var isConfirmingDelete = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    private var outings: [Outing] {
        CurrentDog.outings(allOutings, for: currentDog)
    }

    var body: some View {
        ZStack {
            mapContent

            VStack(spacing: 12) {
                header
                if viewModel.isLocationDenied {
                    locationDeniedBanner
                }
                Spacer()
                bottomChrome
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if viewModel.showsLocationPrompt {
                LocationPermissionPrompt(
                    onAllow: viewModel.requestLocationAccess,
                    onNotNow: viewModel.deferLocationAccess
                )
            }
        }
        .animation(.easeInOut(duration: 0.28), value: viewModel.selectedOuting?.persistentModelID)
        .animation(.easeInOut(duration: 0.28), value: viewModel.showsLocationPrompt)
        .onChange(of: outingToFocusID) { _, _ in
            focusPendingOuting()
        }
        .onChange(of: outings.count) { _, _ in
            focusPendingOuting()
            dropSelectionIfOutingWasRemoved()
        }
        .sheet(item: Binding(
            get: { viewModel.clusterPick },
            set: { viewModel.clusterPick = $0 }
        )) { cluster in
            ClusterMemberSheet(
                cluster: cluster,
                onSelect: { outing in
                    viewModel.select(outing)
                },
                onClose: {
                    viewModel.clusterPick = nil
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isEditingSelectedOuting) {
            if let outing = viewModel.selectedOuting {
                AddOutingView(outingToEdit: outing) { updated, _ in
                    viewModel.select(updated)
                }
            }
        }
        .confirmationDialog(
            "Delete this outing?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete outing", role: .destructive, action: deleteSelectedOuting)
            Button("Cancel", role: .cancel) {}
        } message: {
            if let outing = viewModel.selectedOuting {
                Text("“\(outing.locationName)” will be removed from the map and log. This can’t be undone.")
            }
        }
    }

    private func dropSelectionIfOutingWasRemoved() {
        guard let selectedID = viewModel.selectedOuting?.persistentModelID,
              !outings.contains(where: { $0.persistentModelID == selectedID }) else { return }
        viewModel.clearSelection()
    }

    private func deleteSelectedOuting() {
        guard let outing = viewModel.selectedOuting else { return }
        let remaining = outings.filter { $0.persistentModelID != outing.persistentModelID }
        let dog = outing.dog
        viewModel.clearSelection()
        modelContext.delete(outing)
        try? modelContext.save()
        if let dog {
            MilestoneEvaluator.evaluate(dog: dog, in: modelContext)
        }
        viewModel.showAllOutings(remaining)
    }

    private func focusPendingOuting() {
        guard let id = outingToFocusID,
              let outing = outings.first(where: { $0.persistentModelID == id }) else { return }
        viewModel.select(outing)
        outingToFocusID = nil
    }

    private var mapContent: some View {
        let clustered = viewModel.clusteredContent(for: outings)
        return Map(position: $viewModel.cameraPosition) {
            if viewModel.isLocationAuthorized {
                UserAnnotation()
            }

            ForEach(clustered.pins) { outing in
                Annotation(outing.locationName, coordinate: outing.coordinate, anchor: .bottom) {
                    Button {
                        viewModel.select(outing)
                    } label: {
                        OutingMapPin(
                            symbolName: outing.activitySymbolName,
                            isSelected: viewModel.selectedOuting?.persistentModelID == outing.persistentModelID
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(clustered.clusters) { cluster in
                Annotation(
                    "\(cluster.count) outings",
                    coordinate: cluster.coordinate,
                    anchor: .bottom
                ) {
                    Button {
                        viewModel.handleClusterTap(cluster)
                    } label: {
                        OutingClusterBadge(count: cluster.count)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            viewModel.noteVisibleRegion(context.region)
        }
        .ignoresSafeArea(edges: .top)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your adventures")
                    .font(.headline.weight(.semibold))
                Text("Places you’ve been together")
                    .font(.caption)
                    .foregroundStyle(AdventureTheme.sand.opacity(0.85))
            }
            Spacer()
            Button("Memories") {
                viewModel.showAllOutings(outings)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AdventureTheme.ember)
        }
        .foregroundStyle(AdventureTheme.sand)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AdventureTheme.forest.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: AdventureTheme.trail.opacity(0.28), radius: 10, y: 4)
    }

    private var locationDeniedBanner: some View {
        Button {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(url)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "location.slash")
                Text("Location is off. Turn it on in Settings to center the map on you.")
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(AdventureTheme.trail)
            .padding(12)
            .background(AdventureTheme.sand.opacity(0.94), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var bottomChrome: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if let outing = viewModel.selectedOuting {
                OutingInfoCard(
                    outing: outing,
                    onEdit: { isEditingSelectedOuting = true },
                    onDelete: { isConfirmingDelete = true },
                    onClose: viewModel.clearSelection
                )
            } else {
                Spacer(minLength: 0)
            }

            VStack(spacing: 12) {
                if viewModel.isLocationAuthorized {
                    MapCircleButton(systemName: "location.fill", action: viewModel.centerOnUserIfAvailable)
                }
                MapCircleButton(systemName: "plus", emphasized: true, action: onAddOuting)
            }
        }
    }
}

private struct MapCircleButton: View {
    let systemName: String
    var emphasized = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(emphasized ? AdventureTheme.sand : AdventureTheme.forest)
                .frame(width: 56, height: 56)
                .background(
                    emphasized ? AdventureTheme.ember : AdventureTheme.sand,
                    in: Circle()
                )
                .shadow(color: AdventureTheme.trail.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(emphasized ? "Add outing" : "Center on my location")
    }
}

private struct ClusterMemberSheet: View {
    let cluster: OutingMapClustering.Cluster
    var onSelect: (Outing) -> Void
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            List(cluster.outings) { outing in
                Button {
                    onSelect(outing)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(outing.locationName)
                            .font(.headline)
                            .foregroundStyle(AdventureTheme.forest)
                        Text("\(outing.activityTitle) · \(outing.listDateText)")
                            .font(.subheadline)
                            .foregroundStyle(AdventureTheme.trail)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(AdventureTheme.sand)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AdventureTheme.sand)
            .navigationTitle("Outings here")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                        .foregroundStyle(AdventureTheme.ember)
                }
            }
        }
        .tint(AdventureTheme.ember)
    }
}

#Preview {
    CurrentDogScope {
        MapView(outingToFocusID: .constant(nil), onAddOuting: {})
    }
    .modelContainer(PreviewSupport.container())
}
