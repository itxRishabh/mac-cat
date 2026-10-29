import Foundation
import SwiftUI
import Combine

/// Central observable store: settings, reminders, and the pet's speech bubble.
@MainActor
final class Store: ObservableObject {

    @Published var settings: AppSettings {
        didSet { scheduleSave() }
    }
    @Published var reminders: [PetReminder] = [] { didSet { scheduleSave() } }

    @Published var bubbleText: String? = nil
    @Published var bubbleKind: BubbleKind = .plain

    enum BubbleKind: String, Codable {
        case plain, happy, sad, alert, thought
    }

    let brain = PetBrain()
    private var saveTask: Task<Void, Never>?

    private let supportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("PCCat", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private var stateURL: URL { supportDir.appendingPathComponent("state.json") }

    private struct PersistedState: Codable {
        var settings: AppSettings
        var reminders: [PetReminder]
    }

    init() {
        self.settings = AppSettings()
        load()
        brain.attach(self)
    }

    // MARK: - Persistence

    private func load() {
        if let data = try? Data(contentsOf: stateURL),
           let s = try? JSONDecoder().decode(PersistedState.self, from: data) {
            settings = s.settings
            reminders = s.reminders
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
        let state = PersistedState(settings: settings, reminders: reminders)
        if let d = try? JSONEncoder().encode(state) { try? d.write(to: stateURL) }
    }

    // MARK: - Speech

    func say(_ text: String, kind: BubbleKind = .plain, seconds: Double = 4) {
        bubbleText = text
        bubbleKind = kind
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self, self.bubbleText == text else { return }
            self.bubbleText = nil
        }
    }

    // MARK: - Interaction

    private var lastShoo: Date = .distantPast

    func shoo() {
        guard Date().timeIntervalSince(lastShoo) > 6 else { return }
        lastShoo = Date()
        say("shoo! 🚫", kind: .alert, seconds: 2.5)
    }

    func pet() {
        say("hehe! pats received 💜", kind: .happy, seconds: 3)
        brain.play(.sitting, duration: 4)
    }

    func giveFood() {
        say("nom nom nom", kind: .happy, seconds: 3)
        brain.play(.eating, duration: 4)
    }

    func giveWater() {
        say("ahhh, water. life.", kind: .happy, seconds: 3)
        brain.play(.drinking, duration: 3.5)
    }

    func meditate() {
        brain.play(.meditating, duration: 8)
    }

    func playTrick() {
        say("zoomies!!", kind: .happy, seconds: 3)
        brain.play(.playing, duration: 6)
    }

    func nap() {
        say("time for a little nap…", kind: .plain, seconds: 4)
        brain.play(.sleeping, duration: 300)
    }

    // MARK: - Reminders

    func addReminder(title: String, minutes: Double) {
        let r = PetReminder(title: title, fireDate: Date().addingTimeInterval(minutes * 60))
        reminders.append(r)
        say("noted: \(title)", kind: .alert)
    }

    func removeReminder(_ r: PetReminder) {
        reminders.removeAll { $0.id == r.id }
    }

    func checkReminders() {
        guard settings.showReminders else { return }
        for i in reminders.indices where !reminders[i].isFired && reminders[i].fireDate <= Date() {
            reminders[i].isFired = true
            say("⏰ \(reminders[i].title)", kind: .alert, seconds: 8)
            if settings.soundEnabled { NSSound.beep() }
        }
    }
}
