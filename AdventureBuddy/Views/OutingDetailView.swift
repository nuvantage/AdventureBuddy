import SwiftUI
import UIKit

struct OutingDetailView: View {
    let outing: Outing

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                OutingPhotoView(outing: outing, style: .hero)

                VStack(alignment: .leading, spacing: 10) {
                    Text(outing.locationName)
                        .font(.title.weight(.semibold))
                        .foregroundStyle(AdventureTheme.forest)

                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            outing.date.formatted(date: .long, time: .omitted),
                            systemImage: "calendar"
                        )
                        Label(outing.activityTitle, systemImage: outing.activitySymbolName)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AdventureTheme.trail)
                }

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
            }
            .padding(20)
        }
        .background(AdventureTheme.sand)
        .navigationTitle(outing.activityTitle)
        .navigationBarTitleDisplayMode(.inline)
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
}
