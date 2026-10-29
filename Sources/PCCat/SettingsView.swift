import SwiftUI
import AppKit
import Foundation

/// Settings window content. Hosted inside a plain window (no NavigationStack).
struct SettingsView: View {

    @ObservedObject var store: Store
    @ObservedObject private var art = CatArt.shared

    @State private var reminderTitleDraft: String = ""
    @State private var reminderMinutesDraft: Double = 30

    private let accent = Color(hex: 0x7B61FF)

    // MARK: - Root

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                petSection
                artSection
                routineSection
                remindersSection
                footerNote
            }
            .padding(24)
            .frame(width: 520)
        }
        .frame(minWidth: 540, minHeight: 520)
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                LinearGradient(
                    colors: [accent.opacity(0.10), .clear],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            }
            .ignoresSafeArea()
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(
                    LinearGradient(colors: [accent, accent.opacity(0.65)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                Text(String(store.settings.petName.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("PCCat")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text("Preferences for \(store.settings.petName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
        }
    }

    // MARK: - Pet

    private var petSection: some View {
        SettingsCard(title: "Pet", subtitle: "Your desktop companion") {
            VStack(alignment: .leading, spacing: 8) {
                Text("NAME")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
                TextField("Pet name", text: petNameBinding)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    // MARK: - Art

    private var artSection: some View {
        SettingsCard(title: "Art", subtitle: "Furever Dock illustrations, played as video") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: art.hasImages ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(art.hasImages ? .green : .orange)
                    if art.hasImages {
                        Text(art.sourceDescription)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("No illustration files found — drop the .webp + flowers.gif files into  local/illustrations  then reopen PCCat.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack(spacing: 10) {
                    Button("Rescan folders") {
                        art.rescan()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Text("Idle · morning · play · meditating · sleep — each plays as a looping animation.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Routine

    private var routineSection: some View {
        SettingsCard(title: "Routine", subtitle: "Your pet keeps time with you") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: dailyRoutineBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Follow my daily rhythm")
                            .font(.body.weight(.medium))
                        Text("9:00 AM stretch · 10:30 AM assist · 2:30 PM play · 4:30 PM break · 9:30 PM nap")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)

                Divider()

                Toggle("Show reminder popups", isOn: showRemindersBinding)
                    .toggleStyle(.switch)
                Toggle("Sound when a reminder fires", isOn: soundBinding)
                    .toggleStyle(.switch)
            }
        }
    }

    // MARK: - Reminders

    private var remindersSection: some View {
        SettingsCard(title: "Reminders", subtitle: "Things your cat will nag you about") {
            VStack(alignment: .leading, spacing: 12) {
                if store.reminders.isEmpty {
                    Text("No reminders yet.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 0) {
                        ForEach(store.reminders) { reminder in
                            reminderRow(reminder)
                            if reminder.id != store.reminders.last?.id {
                                Divider().opacity(0.5)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
                }

                HStack(spacing: 8) {
                    TextField("Remind me to…", text: $reminderTitleDraft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addReminder)
                    Stepper(value: $reminderMinutesDraft, in: 1...720, step: 5) {
                        Text("\(Int(reminderMinutesDraft)) min")
                            .font(.callout.monospacedDigit())
                            .frame(minWidth: 58, alignment: .leading)
                    }
                    .fixedSize()
                    Button {
                        addReminder()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(reminderTitleDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func reminderRow(_ reminder: PetReminder) -> some View {
        HStack(spacing: 10) {
            Image(systemName: reminder.isFired ? "checkmark.circle.fill" : "bell.fill")
                .font(.caption)
                .foregroundStyle(reminder.isFired ? Color.green : accent)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.callout)
                    .strikethrough(reminder.isFired)
                    .foregroundStyle(reminder.isFired ? Color.secondary : Color.primary)
                Text(reminder.fireDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button {
                store.removeReminder(reminder)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Delete reminder")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Footer

    private var footerNote: some View {
        Text("PCCat keeps everything on this machine. Settings and reminders live in Application Support; the illustration files live in your local/illustrations folder.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }

    // MARK: - Actions & bindings

    private func addReminder() {
        let title = reminderTitleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        store.addReminder(title: title, minutes: reminderMinutesDraft)
        reminderTitleDraft = ""
        reminderMinutesDraft = 30
    }

    private var petNameBinding: Binding<String> {
        Binding(get: { store.settings.petName },
                set: { store.settings.petName = $0 })
    }

    private var dailyRoutineBinding: Binding<Bool> {
        Binding(get: { store.settings.dailyRoutineEnabled },
                set: { store.settings.dailyRoutineEnabled = $0 })
    }

    private var showRemindersBinding: Binding<Bool> {
        Binding(get: { store.settings.showReminders },
                set: { store.settings.showReminders = $0 })
    }

    private var soundBinding: Binding<Bool> {
        Binding(get: { store.settings.soundEnabled },
                set: { store.settings.soundEnabled = $0 })
    }
}

// MARK: - Card chrome

private struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
