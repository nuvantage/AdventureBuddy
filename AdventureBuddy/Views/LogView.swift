import SwiftData
import SwiftUI

struct LogView: View {
    @Query(sort: \Outing.date, order: .reverse) private var outings: [Outing]

    var body: some View {
        NavigationStack {
            Group {
                if outings.isEmpty {
                    emptyState
                } else {
                    outingList
                }
            }
            .background(AdventureTheme.sand)
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var outingList: some View {
        List(outings) { outing in
            NavigationLink {
                OutingDetailView(outing: outing)
            } label: {
                OutingRow(outing: outing)
            }
            .listRowBackground(AdventureTheme.sand)
            .listRowSeparatorTint(AdventureTheme.trail.opacity(0.18))
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
                Text(outing.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(AdventureTheme.trail)
                Text(outing.activityTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AdventureTheme.ember)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(outing.locationName), \(outing.activityTitle), \(outing.date.formatted(date: .abbreviated, time: .omitted))")
    }
}

#Preview("With outings") {
    LogView()
        .modelContainer(PreviewSupport.container())
}

#Preview("Empty") {
    LogView()
        .modelContainer(PreviewSupport.container(includeSampleOutings: false))
}
