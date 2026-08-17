import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// JPEG payload for `ShareLink`. Uses the outing’s stored bytes so share matches the journal photo.
struct OutingSharePhoto: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .jpeg) { $0.data }
    }
}

struct OutingShareLink: View {
    enum Chrome {
        case toolbar
        case card
    }

    let outing: Outing
    var chrome: Chrome = .toolbar

    var body: some View {
        shareLink
            .tint(AdventureTheme.ember)
            .accessibilityLabel("Share outing")
            .accessibilityHint("Shares the place, activity, date, and photo if there is one")
    }

    @ViewBuilder
    private var shareLink: some View {
        if let photoData = outing.photoData,
           !photoData.isEmpty,
           let preview = UIImage(data: photoData) {
            ShareLink(
                item: OutingSharePhoto(data: photoData),
                subject: Text(outing.locationName),
                message: Text(outing.shareText),
                preview: SharePreview(outing.shareText, image: Image(uiImage: preview))
            ) {
                label
            }
        } else {
            ShareLink(item: outing.shareText) {
                label
            }
        }
    }

    @ViewBuilder
    private var label: some View {
        switch chrome {
        case .toolbar:
            Image(systemName: "square.and.arrow.up")
                .font(.body.weight(.semibold))
                .foregroundStyle(AdventureTheme.ember)
        case .card:
            Image(systemName: "square.and.arrow.up")
                .font(.caption.weight(.bold))
                .foregroundStyle(AdventureTheme.ember)
                .frame(width: 28, height: 28)
                .background(AdventureTheme.ember.opacity(0.16), in: Circle())
        }
    }
}
