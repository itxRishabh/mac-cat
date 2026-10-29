import Foundation
import SwiftUI
import Combine

/// Central observable store. Owns pet state, chat, memory, reminders, settings.
/// Persists to Application Support as JSON.
@MainActor
final class Store: ObservableObject {

    // MARK: Persisted state

    @Published var settings: AppSettings {
        didSet { scheduleSave() }
    }
    @Published var chat: [ChatMessage] = [] { didSet { scheduleSave() } }
    @Published var memories: [PetMemory] = [] { didSet { scheduleSave() } }
    @Published var reminders: [PetReminder] = [] { didSet { scheduleSave() } }
    @Published var species: PetSpecies = .tuxedo { didSet { scheduleSave() } }
    @Published var accessory: Accessory = .none { didSet { scheduleSave() } }

    // MARK: Live state (not persisted)

    @Published var activity: Activity = .idle
    @Published var mood: Double = 0.85          // 0 = grumpy, 1 = delighted
    @Published var energy: Double = 0.8         // 0 = asleep, 1 = hyper
    @Published var hunger: Double = 0.3         // 0 = full, 1 = starving
    @Published var affection: Double = 0.4      // grows with interaction
    @Published var facingRight: Bool = true
    @Published var isThinking: Bool = false
    @Published var isSpeaking: Bool = false
    @Published var bubbleText: String? = nil
    @Published var bubbleKind: BubbleKind = .plain

    enum BubbleKind: String, Codable {
        case plain, happy, sad, alert, thought
    }

    /// Rolling one-shot dialogue lines the cat can say unprompted.
    @Published var ambientLine: String? = nil

    // MARK: Services

    let brain = PetBrain()
    let ai = AIEngine()
    private var saveTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: Paths

    private let supportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("PCCat", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private var stateURL: URL { supportDir.appendingPathComponent("state.json") }
    private var memoryURL: URL { supportDir.appendingPathComponent("memory.json") }
    private var chatURL: URL { supportDir.appendingPathComponent("chat.json") }

    // MARK: Init

    init() {
        self.settings = AppSettings()
        load()
        brain.attach(self)
        startNeedsLoop()
    }

    // MARK: Persistence

    private struct PersistedState: Codable {
        var settings: AppSettings
        var species: PetSpecies
        var accessory: Accessory
        var reminders: [PetReminder]
    }

    private func load() {
        if let data = try? Data(contentsOf: stateURL),
           let s = try? JSONDecoder().decode(PersistedState.self, from: data) {
            settings = s.settings
            species = s.species
            accessory = s.accessory
            reminders = s.reminders
        }
        if let data = try? Data(contentsOf: chatURL),
           let c = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            chat = c
        }
        if let data = try? Data(contentsOf: memoryURL),
           let m = try? JSONDecoder().decode([PetMemory].self, from: data) {
            memories = m
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        let state = PersistedState(settings: settings, species: species,
                                   accessory: accessory, reminders: reminders)
        if let d = try? JSONEncoder().encode(state) { try? d.write(to: stateURL) }
        if let d = try? JSONEncoder().encode(chat) { try? d.write(to: chatURL) }
        if let d = try? JSONEncoder().encode(memories) { try? d.write(to: memoryURL) }
    }

    // MARK: Needs loop

    private func startNeedsLoop() {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000) // 20s tick
                guard let self else { return }
                await self.tickNeeds()
            }
        }
    }

    func tickNeeds() {
        let elapsed = 20.0 / 60.0 // minutes
        hunger = min(1, hunger + elapsed * 0.01)
        energy = max(0, energy - elapsed * 0.008)
        if energy < 0.15 { activity = .sleeping }
        if hunger > 0.85 { bubble("feed me", kind: .alert)
        }
        // Mood decays toward neutral but affection keeps it up.
        let target = 0.35 + affection * 0.45 - hunger * 0.3
        mood += (target - mood) * 0.02
    }

    // MARK: Interaction

    func pet() {
        affection = min(1, affection + 0.08)
        mood = min(1, mood + 0.12)
        energy = max(0, energy - 0.01)
        brain.play(.grooming, duration: 2.4)
        bubble("purr purr", kind: .happy)
    }

    func stroke() {
        affection = min(1, affection + 0.04)
        mood = min(1, mood + 0.06)
    }

    func giveFood() {
        hunger = max(0, hunger - 0.5)
        mood = min(1, mood + 0.1)
        brain.play(.eating, duration: 3.0)
        bubble("nom nom", kind: .happy)
    }

    func giveWater() {
        hunger = max(0, hunger - 0.05)
        energy = min(1, energy + 0.08)
        brain.play(.drinking, duration: 2.6)
    }

    func playTrick(_ name: String) {
        energy = max(0, energy - 0.06)
        mood = min(1, mood + 0.15)
        affection = min(1, affection + 0.06)
        brain.play(.playing, duration: 3.6)
        bubble(name, kind: .happy)
    }

    func say(_ text: String, kind: BubbleKind = .plain, seconds: Double = 4) {
        bubbleText = text
        bubbleKind = kind
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self, self.bubbleText == text else { return }
            self.bubbleText = nil
        }
    }

    private func bubble(_ text: String, kind: BubbleKind) {
        say(text, kind: kind)
    }

    // MARK: Chat

    func send(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        chat.append(ChatMessage(role: "user", text: trimmed))
        brain.play(.curious, duration: 2.0)
        reply(to: trimmed)
    }

    private func reply(to prompt: String) {
        isThinking = true
        let history = chat.suffix(20).map {
            ["role": $0.role == "user" ? "user" : "assistant", "content": $0.text]
        }
        let mem = memories.map { $0.text }
        let system = brain.systemPrompt()
        let rem = reminders.map { "\($0.title) at \($0.fireDate.formatted(date: .omitted, time: .shortened))" }

        Task { [weak self] in
            guard let self else { return }
            await self.ai.stream(messages: history,
                                 system: system,
                                 memories: mem,
                                 reminders: rem) { partial in
                Task { @MainActor in
                    if let last = self.chat.last, last.role == "assistant", last.text.hasPrefix(partial.prefix(1)) {
                        self.chat[self.chat.count - 1].text = partial
                    } else {
                        self.chat.append(ChatMessage(role: "assistant", text: partial))
                    }
                }
            } result: { result in
                Task { @MainActor in
                    self.isThinking = false
                    switch result {
                    case .success(let full):
                        self.learn(full)
                    case .failure(let err):
                        self.say("hmm, my brain hiccuped: \(err.localizedDescription)", kind: .sad)
                    }
                }
            }
        }
    }

    /// Pull durable facts out of a completed answer so the pet remembers them.
    private func learn(_ text: String) {
        let candidates = text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.lowercased().hasPrefix("remember:") || $0.lowercased().hasPrefix("note:") }
            .map { String($0).replacingOccurrences(of: "^(remember|note):", with: "", options: [.regularExpression, .caseInsensitive]).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        for c in candidates.prefix(3) {
            if !memories.contains(where: { $0.text.caseInsensitiveCompare(c) == .orderedSame }) {
                memories.append(PetMemory(text: c))
            }
        }
    }

    func addMemory(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        memories.append(PetMemory(text: t))
    }

    func removeMemory(_ m: PetMemory) {
        memories.removeAll { $0.id == m.id }
    }

    // MARK: Reminders

    func addReminder(title: String, minutes: Double) {
        let r = PetReminder(title: title, fireDate: Date().addingTimeInterval(minutes * 60))
        reminders.append(r)
        say("got it — \(title)", kind: .alert)
    }

    func removeReminder(_ r: PetReminder) {
        reminders.removeAll { $0.id == r.id }
    }

    func checkReminders() {
        for i in reminders.indices where !reminders[i].isFired && reminders[i].fireDate <= Date() {
            reminders[i].isFired = true
            say("⏰ \(reminders[i].title)", kind: .alert)
            NSSound.beep()
        }
    }
}
