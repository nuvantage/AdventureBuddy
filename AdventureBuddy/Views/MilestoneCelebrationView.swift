import SwiftUI

struct MilestoneCelebrationView: View {
    let milestones: [Milestone]
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture(perform: onContinue)

            VStack(spacing: 20) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(AdventureTheme.ember)
                    .frame(width: 72, height: 72)
                    .background(AdventureTheme.ember.opacity(0.16), in: Circle())

                VStack(spacing: 6) {
                    Text(milestones.count == 1 ? "A new milestone" : "New milestones")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AdventureTheme.forest)
                    Text("Your adventures are adding up. This one is worth remembering.")
                        .font(.subheadline)
                        .foregroundStyle(AdventureTheme.trail)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    ForEach(milestones, id: \.catalogID) { milestone in
                        HStack(spacing: 12) {
                            Image(systemName: milestone.iconName)
                                .font(.headline)
                                .foregroundStyle(AdventureTheme.sand)
                                .frame(width: 40, height: 40)
                                .background(AdventureTheme.forest, in: Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(milestone.name)
                                    .font(.headline)
                                    .foregroundStyle(AdventureTheme.forest)
                                Text(milestone.details)
                                    .font(.caption)
                                    .foregroundStyle(AdventureTheme.trail)
                            }

                            Spacer(minLength: 0)
                        }
                    }
                }

                Button("Back to the map", action: onContinue)
                    .font(.headline)
                    .foregroundStyle(AdventureTheme.sand)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AdventureTheme.ember, in: Capsule())
            }
            .padding(24)
            .background(AdventureTheme.sand, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: AdventureTheme.trail.opacity(0.28), radius: 16, y: 8)
            .padding(.horizontal, 28)
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    MilestoneCelebrationView(
        milestones: [
            Milestone(
                catalogID: "first-hike",
                name: "First Hike",
                details: "Share your first hike together.",
                iconName: "figure.hiking",
                dateEarned: .now
            )
        ],
        onContinue: {}
    )
}
