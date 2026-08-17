import SwiftUI

struct JournalExportShareLink: View {
    let file: JournalExport.File

    var body: some View {
        ShareLink(
            item: file,
            subject: Text(file.filename),
            message: Text("A copy of the Adventure Buddy journal. Not a live backup."),
            preview: SharePreview(file.filename, icon: Image(systemName: "book.pages.fill"))
        ) {
            Label("Share journal file", systemImage: "square.and.arrow.up")
                .font(.body.weight(.semibold))
                .foregroundStyle(AdventureTheme.ember)
        }
        .tint(AdventureTheme.ember)
        .accessibilityLabel("Share journal file")
        .accessibilityHint("Opens the share sheet for a copy of the journal. Stays in Settings.")
    }
}
