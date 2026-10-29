import Foundation
import SwiftUI
import Combine

/// Drives the pet: chooses what the cat is doing, keeps the daily routine
/// ticking, and nudges the cat toward natural activity switches.
@MainActor
final class PetBrain: ObservableObject {

    @Published private(set) var activity: Activity = .idle
    @Published private(set) var ambientLine: String? = nil

    private weak var store: Store?
    private var needsTimer: Timer?
    private var nextSwitchAt: Date = .now.addingTimeInterval(20)
    private var lastTimedEnd: Date = .distantPast

    // Ambient chatter, Furever Dock-style.
    private let idleLines = [
        "i'm just watching the screen glow",
        "that notification sound again…",
        "are you still working? i noticed.",
        "the flowers are blooming, i can tell you that",
        "i do a little stretch so you don't forget to",
        "small paws, big opinions"
    ]
    private let playLines = ["zoomies on the desk", "let's play! i'm ready", "wheee"]
    private let breakLines = ["stretch with me, tiny human", "drink some water", "look away from the screen for a sec"]
    private let morningLines = ["morning! let's stretch", "good morning, i'm wide awake"]
    private let nightLines = ["lights out. i'll nap here", "sleep well. purring until morning"]
    private let sitLines = ["comfy spot found", "i'll sit right here"]

    // MARK: - Lifecycle

    func attach(_ store: Store) {
        self.store = store
        activity = .idle
        // 5-second needs/activity nudge.
        needsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.nudge() }
        }
        evaluateRoutine()
    }

    // MARK: - Activity control

    func play(_ activity: Activity, duration: Double = 4.0) {
        self.activity = activity
        lastTimedEnd = Date().addingTimeInterval(duration)
        switch activity {
        case .playing: say(playLines.randomElement() ?? "zoomies!", kind: .happy)
        case .stretching: say(morningLines.randomElement() ?? "stretch", kind: .happy)
        case .sleeping: say(nightLines.randomElement() ?? "shh", kind: .plain)
        case .sitting: say(sitLines.randomElement() ?? "sit", kind: .plain)
        case .eating: say("yum yum", kind: .happy)
        case .drinking: say("ahh", kind: .happy)
        case .meditating: say("inhale… exhale…", kind: .thought)
        default: break
        }
    }

    func set(_ activity: Activity) {
        self.activity = activity
        lastTimedEnd = .distantPast
    }

    private func say(_ text: String, kind: Store.BubbleKind) {
        store?.say(text, kind: kind, seconds: 4)
    }

    // MARK: - Nudges

    private func nudge() {
        // Return from a timed pose to idle when its time is up.
        if Date() >= lastTimedEnd, activity != .idle {
            activity = .idle
        }

        // Natural wandering: occasionally change what the cat is doing.
        if Date() >= nextSwitchAt {
            nextSwitchAt = Date().addingTimeInterval(.random(in: 18...45))
            let roll = Double.random(in: 0...1)
            switch roll {
            case ..<0.55:
                activity = .idle
            case ..<0.70:
                activity = .sitting
            case ..<0.80:
                activity = .stretching
            case ..<0.90:
                activity = .idle
            case ..<0.97:
                say(idleLines.randomElement() ?? "mrrp.", kind: .thought)
                activity = .idle
            default:
                activity = .meditating
            }
        }
    }

    // MARK: - Daily routine

    private func evaluateRoutine() {
        guard let store, store.settings.dailyRoutineEnabled else { return }
        let hour = Calendar.current.component(.hour, from: Date())
        let minute = Calendar.current.component(.minute, from: Date())

        // Fire a slot transition only when crossing a boundary.
        switch hour {
        case 9 where minute < 5:
            play(.stretching, duration: 8)
            store.say(morningLines.randomElement() ?? "morning!", kind: .happy, seconds: 5)
        case 10 where (5...34).contains(minute):
            play(.sitting, duration: 6)
            store.say("good morning. how can i help?", kind: .happy, seconds: 6)
        case 14 where (30...59).contains(minute):
            play(.playing, duration: 8)
        case 16 where (30...59).contains(minute):
            store.say(breakLines.randomElement() ?? "take a break", kind: .alert, seconds: 6)
        case 21 where minute < 10:
            play(.sleeping, duration: 3600)
        default:
            break
        }
    }
}
