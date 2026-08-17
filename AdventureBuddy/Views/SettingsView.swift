import SwiftData
import SwiftUI
import UIKit

struct SettingsView: View {
    @Query private var dogMilestones: [Milestone]
    @Query(sort: \Outing.date) private var allOutings: [Outing]
    @AppStorage(AppPreferences.usesMetricKey) private var usesMetric = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currentDog) private var currentDog
    @State private var viewModel = SettingsViewModel()
    @State private var exportViewModel = JournalExportViewModel()
    @State private var isConfirmingExport = false
    @State private var isConfirmingRemoveCompanion = false

    var body: some View {
        @Bindable var exportViewModel = exportViewModel
        NavigationStack {
            List {
                Section {
                    if let dog = currentDog {
                        NavigationLink {
                            EditDogView(dog: dog)
                        } label: {
                            HStack(spacing: 14) {
                                dogPhoto(dog)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(dog.name)
                                        .font(.headline)
                                        .foregroundStyle(AdventureTheme.forest)
                                    Text(companionSubtitle(for: dog))
                                        .font(.subheadline)
                                        .foregroundStyle(AdventureTheme.trail)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .accessibilityHint("Opens the companion editor")
                        .accessibilityLabel("\(dog.name), \(companionSubtitle(for: dog))")
                    } else {
                        Label("No dog profile yet", systemImage: "pawprint.fill")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Companion")
                } footer: {
                    Text("Adventure Buddy keeps one companion on this device.")
                }

                togetherSoFarSection

                Section {
                    if let dog = currentDog {
                        ForEach(milestones(for: dog)) { milestone in
                            MilestoneRow(milestone: milestone)
                        }
                    }
                } header: {
                    Text("Milestones")
                } footer: {
                    Text("First snow is earned when a place name or notes mention snow, blizzard, powder, sleet, or whiteout — not from a winter date alone. Weather data is never used.")
                }

                Section {
                    Picker("Distance units", selection: $usesMetric) {
                        Text("Miles").tag(false)
                        Text("Kilometers").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityLabel("Units for next-pin labels")
                    .onChange(of: usesMetric) { _, newValue in
                        viewModel.usesMetric = newValue
                    }
                } header: {
                    Text("Distance units")
                } footer: {
                    Text("Labels on the map, log, and outing details are a straight line to the next pin — not a walk, and not a route. Saved on this device.")
                }

                if currentDog != nil {
                    exportSection
                }

                Section("About") {
                    LabeledContent("App", value: "Adventure Buddy")
                    LabeledContent("Status", value: "Early development")
                }

                if let dog = currentDog {
                    Section {
                        Button("Remove companion", role: .destructive) {
                            isConfirmingRemoveCompanion = true
                        }
                        .accessibilityHint("Deletes \(dog.name) and the whole journal, then returns to setup")
                    } header: {
                        Text("Start over")
                    } footer: {
                        Text("Removes \(dog.name) and every outing and milestone in the journal. You’ll begin setup again. This can’t be undone, and there’s no restore.")
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Export journal?",
                isPresented: $isConfirmingExport,
                titleVisibility: .visible
            ) {
                Button("Share a copy") { prepareJournalExport() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(exportConfirmationMessage)
            }
            .alert("Couldn’t export journal", isPresented: $exportViewModel.isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportViewModel.errorMessage)
            }
            .confirmationDialog(
                removeCompanionTitle,
                isPresented: $isConfirmingRemoveCompanion,
                titleVisibility: .visible
            ) {
                if let dog = currentDog {
                    Button("Remove \(dog.name)", role: .destructive, action: removeCompanion)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(removeCompanionMessage)
            }
        }
    }

    private var exportConfirmationMessage: String {
        let name = currentDog.map(displayedCompanionName) ?? "your companion"
        return "This shares a copy of \(name)’s journal — outing dates, map coordinates, places, activities, notes, and when milestones were earned. It is not a live backup. Removing the companion or losing this phone still wipes the journal here."
    }

    private var exportSection: some View {
        Section {
            Button("Export journal") {
                isConfirmingExport = true
            }
            .disabled(exportViewModel.isPreparing)
            .foregroundStyle(AdventureTheme.forest)
            .accessibilityHint("Asks first, then builds a copy to share. Not a live backup.")

            if let file = exportViewModel.preparedFile {
                JournalExportShareLink(file: file)
            }
        } header: {
            Text("Export journal")
        } footer: {
            Text(exportFooter)
        }
    }

    private var exportFooter: String {
        if exportViewModel.photosOmittedBecauseTooLarge {
            return "This copy is JSON only. Photos stay on this phone because they would make the file too large. It is not a live backup, and Adventure Buddy does not use iCloud."
        }
        if exportViewModel.photosIncluded {
            return "A zip with journal JSON and JPEG photos you can save in Files or another app. This is a copy, not a live backup — it will not update itself, and Adventure Buddy does not use iCloud."
        }
        if exportViewModel.preparedFile != nil {
            return "A JSON copy you can save in Files or another app. No photos were stored with this journal. It is not a live backup, and Adventure Buddy does not use iCloud."
        }
        return "Shares a copy you can save in Files or another app. Photos are included when the file stays a practical size; otherwise they stay on this phone. This is not a live backup, and Adventure Buddy does not use iCloud."
    }

    private func prepareJournalExport() {
        guard let dog = currentDog else {
            exportViewModel.errorMessage = "There’s no companion to export. Nothing was shared."
            exportViewModel.isShowingError = true
            return
        }
        exportViewModel.prepare(
            dog: dog,
            outings: outings(for: dog),
            milestones: milestones(for: dog)
        )
    }

    private var removeCompanionTitle: String {
        if let name = currentDog?.name.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return "Remove \(name)?"
        }
        return "Remove companion?"
    }

    private var removeCompanionMessage: String {
        guard let dog = currentDog else {
            return "Every outing and milestone will be deleted. You’ll return to setup. This can’t be undone."
        }
        let name = displayedCompanionName(dog)
        let outingCount = outings(for: dog).count
        let outingPhrase: String
        switch outingCount {
        case 0:
            outingPhrase = "every outing"
        case 1:
            outingPhrase = "1 outing"
        default:
            outingPhrase = "\(outingCount) outings"
        }
        return "“\(name)” will be removed, along with \(outingPhrase) and all milestones. You’ll return to setup. This can’t be undone."
    }

    private func displayedCompanionName(_ dog: Dog) -> String {
        let name = dog.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "this companion" : name
    }

    private func removeCompanion() {
        guard let dog = currentDog else { return }
        modelContext.delete(dog)
        try? modelContext.save()
    }

    private var togetherSoFarSection: some View {
        Section {
            if let dog = currentDog {
                let stats = JournalStats.from(outings: outings(for: dog))
                if stats.hasOutings {
                    recapRow(title: "Outings", value: "\(stats.outingCount)", symbolName: "book.pages.fill")
                    recapRow(title: "Places", value: "\(stats.distinctPlaceCount)", symbolName: "map.fill")
                    if let first = stats.firstOutingDate {
                        recapRow(
                            title: "First outing",
                            value: first.formatted(date: .abbreviated, time: .omitted),
                            symbolName: "flag.fill"
                        )
                    }
                    if let last = stats.lastOutingDate {
                        recapRow(
                            title: "Latest outing",
                            value: last.formatted(date: .abbreviated, time: .omitted),
                            symbolName: "leaf.fill"
                        )
                    }
                    ForEach(stats.activityCounts, id: \.activity.id) { item in
                        recapRow(
                            title: item.activity.title,
                            value: "\(item.count)",
                            symbolName: item.activity.symbolName
                        )
                    }
                } else {
                    Text("Adventures you log will add up here — outings, places, and how you like to go out together.")
                        .font(.subheadline)
                        .foregroundStyle(AdventureTheme.trail)
                        .padding(.vertical, 4)
                }
            }
        } header: {
            Text("Together so far")
        } footer: {
            Text("From your saved outings. Place names match the 10 Places milestone. This is not GPS mileage.")
        }
    }

    private func recapRow(title: String, value: String, symbolName: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AdventureTheme.ember)
                .frame(width: 22)
            Text(title)
                .foregroundStyle(AdventureTheme.forest)
            Spacer()
            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(AdventureTheme.ember)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }

    private func outings(for dog: Dog) -> [Outing] {
        CurrentDog.outings(allOutings, for: dog)
    }

    private func milestones(for dog: Dog) -> [Milestone] {
        let order = MilestoneCatalog.items.map(\.catalogID)
        let dogID = dog.persistentModelID
        return dogMilestones
            .filter { $0.dog?.persistentModelID == dogID }
            .sorted { lhs, rhs in
                let left = order.firstIndex(of: lhs.catalogID) ?? .max
                let right = order.firstIndex(of: rhs.catalogID) ?? .max
                return left < right
            }
    }

    private func companionSubtitle(for dog: Dog) -> String {
        let breed = dog.breed?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasBreed = !(breed?.isEmpty ?? true)
        let age = dog.ageDescription

        switch (hasBreed ? breed : nil, age) {
        case let (breed?, age?):
            return "\(breed) · \(age)"
        case let (breed?, nil):
            return breed
        case let (nil, age?):
            return age
        default:
            return "Breed not set"
        }
    }

    @ViewBuilder
    private func dogPhoto(_ dog: Dog) -> some View {
        if let photoData = dog.photoData, let image = UIImage(data: photoData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(Circle())
        } else {
            Image(systemName: "pawprint.fill")
                .foregroundStyle(AdventureTheme.sand)
                .frame(width: 56, height: 56)
                .background(AdventureTheme.forest, in: Circle())
        }
    }
}

private struct MilestoneRow: View {
    let milestone: Milestone

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(milestone.isEarned ? AdventureTheme.ember : AdventureTheme.trail.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: milestone.iconName)
                    .font(.headline)
                    .foregroundStyle(milestone.isEarned ? AdventureTheme.sand : AdventureTheme.trail.opacity(0.45))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.name)
                    .font(.headline)
                    .foregroundStyle(milestone.isEarned ? AdventureTheme.forest : AdventureTheme.trail.opacity(0.7))
                Text(milestone.details)
                    .font(.subheadline)
                    .foregroundStyle(AdventureTheme.trail.opacity(milestone.isEarned ? 1 : 0.7))
                if let dateEarned = milestone.dateEarned {
                    Text("Earned \(dateEarned.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AdventureTheme.ember)
                } else {
                    Text("Not earned yet")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AdventureTheme.trail.opacity(0.55))
                }
            }

            Spacer(minLength: 0)

            if !milestone.isEarned {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(AdventureTheme.trail.opacity(0.4))
                    .accessibilityLabel("Locked")
            }
        }
        .padding(.vertical, 4)
        .opacity(milestone.isEarned ? 1 : 0.9)
    }
}

#Preview {
    CurrentDogScope {
        SettingsView()
    }
    .modelContainer(PreviewSupport.container())
}
