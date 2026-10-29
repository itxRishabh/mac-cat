import SwiftUI
import AppKit
import Foundation

/// Settings window content. Hosted inside a plain window (no NavigationStack).
struct SettingsView: View {

    @ObservedObject var store: Store

    @State private var apiKeyDraft: String = ""
    @State private var reminderTitleDraft: String = ""
    @State private var reminderMinutesDraft: Double = 30
    @State private var memoryDraft: String = ""
    @State private var didLoadKey: Bool = false

    private let accent = Color(hex: 0x7B61FF)
    private let cardRadius: CGFloat = 14

    // MARK: - Root

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                petSection
                aiSection
                routineSection
                remindersSection
                memorySection
                footerNote
            }
            .padding(24)
        }
        .frame(minWidth: 560, minHeight: 480)
        .background(background)
        .onAppear(perform: loadKeyIfNeeded)
    }

    // MARK: - Background & header

    private var background: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [accent.opacity(0.10), .clear],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
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
        SettingsCard(title: "Pet", subtitle: "Who lives on your desktop") {
            VStack(alignment: .leading, spacing: 18) {
                // Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("NAME")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.8)
                    TextField("Pet name", text: petNameBinding)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                }

                // Species grid
                VStack(alignment: .leading, spacing: 8) {
                    Text("BREED")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.8)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                              spacing: 10) {
                        ForEach(PetSpecies.allCases) { species in
                            speciesCell(species)
                        }
                    }
                }

                // Accessory
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ACCESSORY")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.8)
                        Picker("Accessory", selection: accessoryBinding) {
                            ForEach(Accessory.allCases) { item in
                                Text(item.displayName).tag(item)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: 220, alignment: .leading)
                    }
                    Spacer(minLength: 12)
                    paletteSwatch
                }
            }
        }
    }

    private func speciesCell(_ species: PetSpecies) -> some View {
        let isSelected = store.species == species
        return Button {
            store.species = species
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(species.palette.base)
                    Circle()
                        .strokeBorder(species.palette.shade.opacity(0.7), lineWidth: 1)
                        .padding(2)
                    Text(String(species.displayName.prefix(1)))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(species.palette.shade)
                }
                .frame(width: 30, height: 30)

                Text(species.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(species.blurb)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: 32, alignment: .top)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.12) : Color.primary.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .strokeBorder(isSelected ? accent : Color.primary.opacity(0.10),
                                  lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(species.blurb)
    }

    private var paletteSwatch: some View {
        let palette = store.species.palette
        let swatches: [(String, Color)] = [
            ("Base", palette.base),
            ("Shade", palette.shade),
            ("Belly", palette.belly),
            ("Inner ear", palette.innerEar),
            ("Nose", palette.nose),
            ("Eye", palette.eye)
        ]
        return VStack(alignment: .leading, spacing: 8) {
            Text("PALETTE")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.8)
            HStack(spacing: 6) {
                ForEach(0..<swatches.count, id: \.self) { index in
                    Circle()
                        .fill(swatches[index].1)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
                        .frame(width: 18, height: 18)
                        .help(swatches[index].0)
                }
            }
            Text(store.species.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - AI

    private var aiSection: some View {
        SettingsCard(title: "AI", subtitle: "Claude powers the conversation") {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("API KEY")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.8)
                    HStack(spacing: 8) {
                        SecureField("sk-ant-…", text: $apiKeyDraft)
                            .textFieldStyle(.roundedBorder)
                        Button("Save Key") {
                            persistAPIKey()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Text("Your key is stored in the macOS Keychain and never leaves this device except to call Anthropic's API.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("MODEL")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.8)
                    Picker("Model", selection: modelBinding) {
                        ForEach(ModelCatalog.options, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 260, alignment: .leading)

                    if store.settings.model != ModelCatalog.current {
                        Text("Saved as \(store.settings.model). The shared catalog still points at \(ModelCatalog.current), so it will be used until that constant is updated.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Requests are sent to \(ModelCatalog.current).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Routine

    private var routineSection: some View {
        SettingsCard(title: "Routine", subtitle: "Your pet keeps time with you") {
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: dailyRoutineBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Follow my daily rhythm")
                            .font(.body.weight(.medium))
                        Text("9:00 AM wake & stretch · 10:30 AM assist · 2:30 PM play · 4:30 PM break · 9:30 PM sleep")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)
                .disabled(!store.settings.dailyRoutineEnabled)

                Divider()

                Toggle("Show reminders", isOn: showRemindersBinding)
                    .toggleStyle(.switch)
                Toggle("Sound effects", isOn: soundBinding)
                    .toggleStyle(.switch)
                Toggle("Allow GIFs in chat", isOn: giphyBinding)
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

    // MARK: - Memory

    private var memorySection: some View {
        SettingsCard(title: "Memory", subtitle: "What your cat knows about you") {
            VStack(alignment: .leading, spacing: 12) {
                if store.memories.isEmpty {
                    Text("Nothing remembered yet. Try telling your cat a fact — it may save it for later.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 0) {
                        ForEach(store.memories) { memory in
                            memoryRow(memory)
                            if memory.id != store.memories.last?.id {
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
                    TextField("Remember that…", text: $memoryDraft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addMemory)
                    Button {
                        addMemory()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(memoryDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func memoryRow(_ memory: PetMemory) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "brain")
                .font(.caption)
                .foregroundStyle(accent)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(memory.text)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Text(memory.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button {
                store.removeMemory(memory)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Forget this")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var footerNote: some View {
        Text("PCCat keeps everything on this machine. Conversations, memories and reminders live in Application Support; the API key lives in the Keychain.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }

    // MARK: - Actions

    private func loadKeyIfNeeded() {
        guard !didLoadKey else { return }
        didLoadKey = true
        if apiKeyDraft.isEmpty {
            apiKeyDraft = KeychainHelper.read() ?? ""
        }
    }

    private func persistAPIKey() {
        let trimmed = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        KeychainHelper.save(trimmed)
        store.settings.apiKey = trimmed
        store.saveNow()
    }

    private func addReminder() {
        let title = reminderTitleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        store.addReminder(title: title, minutes: reminderMinutesDraft)
        reminderTitleDraft = ""
        reminderMinutesDraft = 30
    }

    private func addMemory() {
        let text = memoryDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.addMemory(text)
        memoryDraft = ""
    }

    // MARK: - Bindings

    private var petNameBinding: Binding<String> {
        Binding(
            get: { store.settings.petName },
            set: { store.settings.petName = $0 }
        )
    }

    private var accessoryBinding: Binding<Accessory> {
        Binding(
            get: { store.accessory },
            set: { store.accessory = $0 }
        )
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { store.settings.model },
            set: { store.settings.model = $0 }
        )
    }

    private var dailyRoutineBinding: Binding<Bool> {
        Binding(
            get: { store.settings.dailyRoutineEnabled },
            set: { store.settings.dailyRoutineEnabled = $0 }
        )
    }

    private var showRemindersBinding: Binding<Bool> {
        Binding(
            get: { store.settings.showReminders },
            set: { store.settings.showReminders = $0 }
        )
    }

    private var soundBinding: Binding<Bool> {
        Binding(
            get: { store.settings.soundEnabled },
            set: { store.settings.soundEnabled = $0 }
        )
    }

    private var giphyBinding: Binding<Bool> {
        Binding(
            get: { store.settings.giphyEnabled },
            set: { store.settings.giphyEnabled = $0 }
        )
    }
}

// MARK: - Card chrome

/// A titled group of controls with a soft card background.
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
