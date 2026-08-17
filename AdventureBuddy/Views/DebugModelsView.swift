import SwiftData
import SwiftUI

struct DebugModelsView: View {
    @Query private var dogs: [Dog]
    @Query(sort: \Outing.date, order: .reverse) private var outings: [Outing]
    @Query(sort: \Milestone.name) private var milestones: [Milestone]

    var body: some View {
        NavigationStack {
            List {
                Section("Dog") {
                    if let dog = CurrentDog.resolve(from: dogs) {
                        LabeledContent("Name", value: dog.name)
                        LabeledContent("Breed", value: dog.breed ?? "—")
                    } else {
                        Text("No dog saved yet.")
                    }
                }

                Section("Outings") {
                    if outings.isEmpty {
                        Text("No outings saved yet.")
                    } else {
                        ForEach(outings) { outing in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(outing.locationName)
                                    .font(.headline)
                                Text("\(outing.activityType) · \(outing.listDateText)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Milestones") {
                    ForEach(milestones) { milestone in
                        LabeledContent(milestone.name, value: milestone.isEarned ? "Earned" : "Not yet")
                    }
                }
            }
            .navigationTitle("Model Debug")
        }
    }
}

#Preview("Sample models") {
    DebugModelsView()
        .modelContainer(PreviewSupport.container())
}
