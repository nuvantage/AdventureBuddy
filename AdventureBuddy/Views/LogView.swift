import SwiftData
import SwiftUI

struct LogView: View {
    @Query(sort: \Outing.date, order: .reverse) private var allOutings: [Outing]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currentDog) private var currentDog
    @State private var viewModel = LogViewModel()
    @State private var outingToEdit: Outing?
    @State private var outingPendingDelete: Outing?

    private var outings: [Outing] {
        CurrentDog.outings(allOutings, for: currentDog)
    }

    var body: some View {
        NavigationStack {
            Group {
                if outings.isEmpty {
                    emptyState
                } else {
                    filteredContent
                }
            }
            .background(AdventureTheme.sand)
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.large)
            .tint(AdventureTheme.ember)
        }
    }

    @ViewBuilder
    private var filteredContent: some View {
        let visibleOutings = viewModel.filtered(outings)

        VStack(spacing: 0) {
            activityChips
            if visibleOutings.isEmpty {
                filteredEmptyState
            } else {
                outingList(visibleOutings)
            }
        }
        .searchable(text: searchBinding, prompt: "Place or notes")
        .sheet(isPresented: Binding(
            get: { outingToEdit != nil },
            set: { if !$0 { outingToEdit = nil } }
        )) {
            if let outing = outingToEdit {
                AddOutingView(outingToEdit: outing) { _, _ in }
            }
        }
        .confirmationDialog(
            "Delete this outing?",
            isPresented: Binding(
                get: { outingPendingDelete != nil },
                set: { if !$0 { outingPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete outing", role: .destructive, action: deletePendingOuting)
            Button("Cancel", role: .cancel) {
                outingPendingDelete = nil
            }
        } message: {
            if let outing = outingPendingDelete {
                Text("“\(outing.locationName)” will be removed from the map and log. This can’t be undone.")
            }
        }
    }

    private var activityChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ActivityChip(
                    title: "All",
                    isSelected: viewModel.isShowingAllActivities
                ) {
                    viewModel.selectedActivity = nil
                }

                ForEach(Outing.Activity.allCases) { activity in
                    ActivityChip(
                        title: activity.title,
                        symbolName: activity.symbolName,
                        isSelected: viewModel.selectedActivity == activity
                    ) {
                        viewModel.selectedActivity = activity
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(AdventureTheme.sand)
    }

    private func outingList(_ visibleOutings: [Outing]) -> some View {
        List {
            ForEach(visibleOutings) { outing in
                NavigationLink {
                    OutingDetailView(outing: outing)
                } label: {
                    OutingRow(outing: outing)
                }
                .listRowBackground(AdventureTheme.sand)
                .listRowSeparatorTint(AdventureTheme.trail.opacity(0.18))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", role: .destructive) {
                        outingPendingDelete = outing
                    }
                    Button("Edit") {
                        outingToEdit = outing
                    }
                    .tint(AdventureTheme.ember)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 40))
                .foregroundStyle(AdventureTheme.ember)
                .frame(width: 88, height: 88)
                .background(AdventureTheme.ember.opacity(0.16), in: Circle())

            Text("Your first adventure is waiting")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AdventureTheme.forest)
                .multilineTextAlignment(.center)

            Text("When you log a walk, hike, or outing, it’ll show up here as a trail of memories you can look back on together.")
                .font(.subheadline)
                .foregroundStyle(AdventureTheme.trail)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 32))
                .foregroundStyle(AdventureTheme.ember)
                .frame(width: 72, height: 72)
                .background(AdventureTheme.ember.opacity(0.16), in: Circle())

            Text("Nothing matches that trail")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AdventureTheme.forest)
                .multilineTextAlignment(.center)

            Text("Try another activity, or search a different place name or note. Your adventures are still here.")
                .font(.subheadline)
                .foregroundStyle(AdventureTheme.trail)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { viewModel.searchText },
            set: { viewModel.searchText = $0 }
        )
    }

    private func deletePendingOuting() {
        guard let outing = outingPendingDelete else { return }
        let dog = outing.dog
        outingPendingDelete = nil
        modelContext.delete(outing)
        try? modelContext.save()
        if let dog {
            MilestoneEvaluator.evaluate(dog: dog, in: modelContext)
        }
    }
}

private struct ActivityChip: View {
    let title: String
    var symbolName: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.caption.weight(.semibold))
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? AdventureTheme.sand : AdventureTheme.forest)
            .background(
                isSelected ? AdventureTheme.ember : AdventureTheme.forest.opacity(0.1),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct OutingRow: View {
    let outing: Outing

    var body: some View {
        HStack(spacing: 14) {
            OutingPhotoView(outing: outing, style: .thumbnail)

            VStack(alignment: .leading, spacing: 4) {
                Text(outing.locationName)
                    .font(.headline)
                    .foregroundStyle(AdventureTheme.forest)
                Text(outing.listDateText)
                    .font(.subheadline)
                    .foregroundStyle(AdventureTheme.trail)
                Text(outing.activityTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AdventureTheme.ember)
                OutingDistanceLabel(outing: outing, compact: true)
                    .font(.caption)
                    .foregroundStyle(AdventureTheme.trail)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(outing.locationName), \(outing.activityTitle), \(outing.listDateText)")
    }
}

#Preview("With outings") {
    CurrentDogScope {
        LogView()
    }
    .modelContainer(PreviewSupport.container())
}

#Preview("Empty") {
    CurrentDogScope {
        LogView()
    }
    .modelContainer(PreviewSupport.container(includeSampleOutings: false))
}
