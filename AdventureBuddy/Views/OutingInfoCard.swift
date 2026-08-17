import SwiftUI

struct OutingInfoCard: View {
    let outing: Outing
    var onEdit: () -> Void
    var onDelete: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: outing.activitySymbolName)
                    .font(.title3)
                    .foregroundStyle(AdventureTheme.ember)
                    .frame(width: 36, height: 36)
                    .background(AdventureTheme.ember.opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(outing.locationName)
                        .font(.headline)
                        .foregroundStyle(AdventureTheme.forest)
                    Text(outing.listDateText)
                        .font(.subheadline)
                        .foregroundStyle(AdventureTheme.trail)
                    Text(outing.activityTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AdventureTheme.ember)
                    OutingDistanceLabel(outing: outing)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AdventureTheme.trail)
                }

                Spacer(minLength: 8)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AdventureTheme.trail)
                        .frame(width: 28, height: 28)
                        .background(AdventureTheme.trail.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close outing details")
            }

            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AdventureTheme.ember)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AdventureTheme.ember.opacity(0.16), in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AdventureTheme.trail)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AdventureTheme.trail.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AdventureTheme.sand.opacity(0.96), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: AdventureTheme.trail.opacity(0.22), radius: 12, y: 6)
    }
}

#Preview {
    OutingInfoCard(
        outing: Outing(
            date: .now,
            latitude: 38.5916,
            longitude: -121.5044,
            locationName: "Riverside Trail",
            activityType: "walk"
        ),
        onEdit: {},
        onDelete: {},
        onClose: {}
    )
    .padding()
    .background(AdventureTheme.forest)
}
